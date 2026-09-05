import Foundation

// ============================================================
// CONTROLE DA LIVE ACTIVITY DE VOO
// Decide QUANDO a Activity nasce, é atualizada e morre.
//
// O que ela NÃO faz: atualizar de minuto em minuto. A tela
// bloqueada e a Ilha Dinâmica desenham a contagem e a barra a
// partir de dois instantes (partida e chegada) com
// Text(timerInterval:) / ProgressView(timerInterval:), então o
// sistema anima sozinho. Num voo de 10h só mandamos update se
// a estimativa de chegada realmente mudar.
// ============================================================

#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import os

@MainActor
final class FlightActivityController {

    static let shared = FlightActivityController()

    /// Wired by whoever owns flight tracking (e.g. `FlightAwareService.cachedArrival(for:)`).
    /// Left nil the controller simply uses the itinerary's own arrival time —
    /// which is the correct degraded behaviour, not an error.
    var liveArrivalProvider: ((FlightLeg) -> Date?)?

    // MARK: Políticas

    /// The Activity appears this long before the scheduled departure.
    private let leadTime: TimeInterval = 90 * 60
    /// It lingers this long after touchdown, then ends.
    private let lingerAfterArrival: TimeInterval = 15 * 60
    /// A revised arrival closer than this to the one already shown is not worth
    /// spending an update on.
    private let meaningfulDrift: TimeInterval = 60
    /// How often we re-evaluate *whether* something changed. This is not a UI
    /// refresh — most ticks push nothing at all.
    private let checkInterval: TimeInterval = 5 * 60

    // MARK: Estado

    private var activity: Activity<FlightActivityAttributes>?
    private var currentLegID: String?
    private var lastPushedState: FlightActivityAttributes.ContentState?
    private var timer: Timer?

    private let log = Logger(subsystem: "com.meulab.app", category: "FlightActivity")

    private init() {
        // Default source for the revised arrival. Overridable, and nil-safe:
        // with nothing cached the itinerary's own arrival is used.
        liveArrivalProvider = { FlightAwareService.shared.cachedArrival(for: $0) }
    }

    // MARK: - Ciclo de vida

    /// Adopts any Activity left running by a previous launch and starts the
    /// low-frequency check loop. Safe to call more than once.
    func startMonitoring() {
        guard areActivitiesEnabled else {
            log.info("ActivityKit indisponível ou desligado — Live Activity de voo desativada.")
            return
        }

        adoptRunningActivity()
        sync()

        guard timer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }
        timer.tolerance = 60
        self.timer = timer
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// True only when the user has Live Activities turned on for this app.
    /// Every entry point checks it, so an unauthorised device degrades in
    /// silence — no alert, no crash.
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Sincronização

    /// Reads the itinerary, decides which leg (if any) deserves an Activity
    /// right now, and starts / updates / ends accordingly.
    func sync(now: Date = Date()) {
        guard areActivitiesEnabled else { return }

        let legs = FlightLegBuilder.legs(from: TripEngine.shared.stops)
        guard let leg = activeLeg(among: legs, now: now) else {
            // Nothing in the window: retire whatever is on screen.
            if activity != nil { end(now: now) }
            return
        }

        let liveArrival = liveArrivalProvider?(leg)
        let progress = FlightProgress.make(leg: leg, liveArrival: liveArrival, now: now)
        let state = contentState(for: progress)

        // Past the linger window the Activity has said everything it can say.
        if progress.phase == .landed,
            now >= progress.effectiveArrival.addingTimeInterval(lingerAfterArrival) {
            end(now: now)
            return
        }

        if activity == nil || currentLegID != leg.id {
            start(leg: leg, state: state)
        } else if shouldPush(state) {
            update(state: state)
        }
    }

    /// Force-refreshes from a caller that just learned a new arrival estimate.
    func estimateDidChange() { sync() }

    // MARK: - Seleção da perna

    /// The leg whose window `[departure - lead, arrival + linger]` contains
    /// `now`. With overlapping windows the earlier departure wins — that is the
    /// flight the traveller is actually on.
    private func activeLeg(among legs: [FlightLeg], now: Date) -> FlightLeg? {
        legs
            .filter { leg in
                let arrival = liveArrivalProvider?(leg) ?? leg.scheduledArrival
                let opens = leg.departure.addingTimeInterval(-leadTime)
                let closes = arrival.addingTimeInterval(lingerAfterArrival)
                return now >= opens && now < closes
            }
            .min { $0.departure < $1.departure }
    }

    // MARK: - Montagem do conteúdo

    private func contentState(for progress: FlightProgress) -> FlightActivityAttributes.ContentState {
        let phase: FlightActivityAttributes.ContentState.Phase =
            switch progress.phase {
            case .beforeDeparture: .beforeDeparture
            case .inFlight: .inFlight
            case .landed: .landed
            }

        return FlightActivityAttributes.ContentState(
            departure: progress.leg.departure,
            arrival: progress.effectiveArrival,
            isEstimateLive: progress.isEstimateLive,
            phase: phase,
            note: note(for: progress)
        )
    }

    /// A one-line remark, or nothing. Never repeats what the countdown already
    /// shows.
    private func note(for progress: FlightProgress) -> String? {
        let drift = progress.effectiveArrival.timeIntervalSince(progress.leg.scheduledArrival)
        guard progress.isEstimateLive, abs(drift) >= 5 * 60 else { return nil }

        let amount = FlightActivityFormat.shortDuration(abs(drift))
        return drift > 0 ? "Atrasado \(amount)" : "Adiantado \(amount)"
    }

    private func attributes(for leg: FlightLeg) -> FlightActivityAttributes {
        FlightActivityAttributes(
            flightCode: leg.code,
            origin: leg.origin,
            destination: leg.destination,
            departureTimeZoneID: leg.departureTimeZoneID,
            arrivalTimeZoneID: leg.arrivalTimeZoneID,
            scheduledDeparture: leg.departure,
            scheduledArrival: leg.scheduledArrival
        )
    }

    /// After this instant the system dims the Activity as outdated. Set past the
    /// point where our own numbers stop being trustworthy, not at the next
    /// minute — the timer views stay correct on their own until then.
    private func staleDate(for state: FlightActivityAttributes.ContentState) -> Date {
        switch state.phase {
        case .beforeDeparture:
            state.departure.addingTimeInterval(30 * 60)
        case .inFlight:
            state.arrival.addingTimeInterval(30 * 60)
        case .landed:
            state.arrival.addingTimeInterval(lingerAfterArrival)
        }
    }

    /// Only a real change earns an update: a different phase, a different
    /// estimate source, a new note, or an arrival that moved by more than a
    /// minute. Everything else the system animates for free.
    private func shouldPush(_ state: FlightActivityAttributes.ContentState) -> Bool {
        guard let last = lastPushedState else { return true }
        if last.phase != state.phase { return true }
        if last.isEstimateLive != state.isEstimateLive { return true }
        if last.note != state.note { return true }
        if abs(last.arrival.timeIntervalSince(state.arrival)) >= meaningfulDrift { return true }
        if abs(last.departure.timeIntervalSince(state.departure)) >= meaningfulDrift { return true }
        return false
    }

    // MARK: - Operações ActivityKit

    private func start(leg: FlightLeg, state: FlightActivityAttributes.ContentState) {
        // A leg change means the old Activity is about a flight already flown.
        if activity != nil { end() }

        let content = ActivityContent(
            state: state,
            staleDate: staleDate(for: state),
            relevanceScore: 100
        )

        do {
            activity = try Activity.request(
                attributes: attributes(for: leg),
                content: content,
                pushType: nil
            )
            currentLegID = leg.id
            lastPushedState = state
            log.info("Live Activity iniciada para \(leg.code, privacy: .public).")
        } catch {
            // Denied, over the per-app limit, or the device is in a state that
            // refuses new Activities. None of that is worth bothering the user.
            activity = nil
            currentLegID = nil
            lastPushedState = nil
            log.error("Falha ao iniciar Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func update(state: FlightActivityAttributes.ContentState) {
        guard let activity else { return }
        let content = ActivityContent(
            state: state,
            staleDate: staleDate(for: state),
            relevanceScore: 100
        )
        lastPushedState = state
        Task { await activity.update(content) }
    }

    /// Ends the Activity, leaving the final card up briefly so a glance at the
    /// phone after landing still explains itself.
    func end(now: Date = Date()) {
        guard let activity else {
            currentLegID = nil
            lastPushedState = nil
            return
        }

        let finalState = lastPushedState.map { previous in
            FlightActivityAttributes.ContentState(
                departure: previous.departure,
                arrival: previous.arrival,
                isEstimateLive: previous.isEstimateLive,
                phase: .landed,
                note: previous.note
            )
        } ?? activity.content.state

        let dismissAt = min(
            now.addingTimeInterval(lingerAfterArrival),
            now.addingTimeInterval(4 * 3600)  // ActivityKit ignores anything later
        )

        self.activity = nil
        currentLegID = nil
        lastPushedState = nil

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .after(dismissAt)
            )
        }
    }

    /// Ends every flight Activity this app owns, including ones adopted from a
    /// previous launch.
    func endAll() {
        activity = nil
        currentLegID = nil
        lastPushedState = nil
        Task {
            for running in Activity<FlightActivityAttributes>.activities {
                await running.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Reattaches to an Activity that survived an app restart, so we update it
    /// instead of stacking a second one on top.
    private func adoptRunningActivity() {
        guard activity == nil else { return }
        guard let running = Activity<FlightActivityAttributes>.activities.first else { return }
        activity = running
        lastPushedState = running.content.state
        // The leg id is not carried in the attributes; match on the flight code
        // so a genuinely different leg still forces a restart.
        currentLegID = FlightLegBuilder.legs(from: TripEngine.shared.stops)
            .first { $0.code == running.attributes.flightCode }?
            .id
    }
}
#endif
