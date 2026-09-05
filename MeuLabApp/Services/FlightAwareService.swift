import Foundation

// ============================================================
// FLIGHTAWARE AEROAPI — ESTIMATIVA DE CHEGADA
// Cada chamada é paga, então este cliente é deliberadamente avaro: consulta
// um único voo por vez (o próximo a partir ou o que está no ar), guarda a
// resposta em disco e só volta à rede quando o cache envelhece dentro da
// janela que importa. Sem chave, sem rede ou fora da janela, o app segue
// usando o horário do roteiro — silenciosamente.
// ============================================================

/// One cached AeroAPI answer for one itinerary leg.
///
/// Persisted to disk so the estimate captured on the ground survives the flight
/// itself: once the phone goes into airplane mode there is nothing left to ask.
struct FlightAwareEstimate: Codable, Equatable, Sendable {
    /// `FlightLeg.id` this belongs to.
    let legID: String
    /// Ident actually queried ("IBE268"), kept so a retry reuses what worked.
    var ident: String
    /// Best known arrival: actual > estimated > scheduled, gate before runway.
    var arrival: Date?
    /// True when `arrival` is an observed time rather than a prediction.
    var isActual: Bool
    /// Best known departure, for cross-checking that the right flight matched.
    var departure: Date?
    /// When the network answered. Drives the whole reuse policy.
    var fetchedAt: Date
    /// Billed calls already spent on this leg. Hard-capped.
    var refreshCount: Int
    /// Landed or cancelled — nothing left to learn, never call again.
    var isFinal: Bool
    /// Index into the ident candidate list; advances when a query finds nothing.
    var identIndex: Int
}

@MainActor
final class FlightAwareService: ObservableObject {
    static let shared = FlightAwareService()

    // MARK: - Política de economia

    /// Only a leg departing within this window is worth asking about.
    private static let lookAheadWindow: TimeInterval = 24 * 3600
    /// A leg counts as "in the air" from shortly before departure until well
    /// after the expected arrival, covering a delayed take-off or landing.
    private static let departureLead: TimeInterval = 30 * 60
    private static let arrivalTail: TimeInterval = 90 * 60

    /// Cache lifetime, by how close departure is. Far out the estimate is just
    /// the schedule repeated back, so paying for it hourly is waste.
    private static let ttlFarOut: TimeInterval = 6 * 3600  // more than 6h to go
    private static let ttlApproaching: TimeInterval = 3600  // 6h .. 1h to go
    private static let ttlImminent: TimeInterval = 30 * 60  // final hour + in flight

    /// Absolute ceiling of billed calls per leg, whatever the user does with
    /// the app. Eleven legs therefore cost at most `11 * maxRefreshesPerLeg`.
    private static let maxRefreshesPerLeg = 6

    /// After a network failure, stop trying for this long. Airplane mode should
    /// not turn into a retry loop.
    private static let offlineBackoff: TimeInterval = 10 * 60
    /// After a 429, back off longer.
    private static let rateLimitBackoff: TimeInterval = 30 * 60

    /// An arrival further than this from the itinerary's own time means the
    /// wrong flight matched; discard it rather than show nonsense.
    private static let plausibilityWindow: TimeInterval = 6 * 3600

    /// Entries older than this are pruned on load.
    private static let retention: TimeInterval = 30 * 24 * 3600

    // MARK: - Estado

    /// legID → cached answer. `@Published` so a view holding the service
    /// redraws when a fresher estimate lands.
    @Published private(set) var estimates: [String: FlightAwareEstimate] = [:]

    /// Nil when no key is configured — the whole service is then a no-op.
    private let apiKey: String?
    /// Flipped off for the session on 401/403: a rejected key will keep being
    /// rejected, and every attempt is a request we should not be making.
    private var isAuthorized = true
    /// No network attempts before this instant.
    private var quietUntil: Date = .distantPast
    /// One request at a time; views may call `refreshIfNeeded` concurrently.
    private var isFetching = false

    private let session: URLSession

    private init() {
        let key = Secrets.flightAwareAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = key.isEmpty ? nil : key

        let config = URLSessionConfiguration.ephemeral
        // Offline must fail fast instead of parking the request until the radio
        // comes back — mid-flight that would be hours.
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpAdditionalHeaders = ["Accept": "application/json; charset=UTF-8"]
        session = URLSession(configuration: config)

        estimates = DiskStore.load(retention: Self.retention)
    }

    // MARK: - API pública

    /// Estimativa de chegada em cache para esse voo, se houver. Nunca faz rede.
    func cachedArrival(for leg: FlightLeg) -> Date? {
        estimates[leg.id]?.arrival
    }

    /// Busca se — e somente se — valer a pena pela política de economia. Silenciosa.
    func refreshIfNeeded(legs: [FlightLeg], now: Date = Date()) async {
        guard let apiKey, isAuthorized, !isFetching, now >= quietUntil else { return }
        guard let leg = relevantLeg(in: legs, now: now) else { return }

        let cached = estimates[leg.id]
        guard shouldRefresh(cached, leg: leg, now: now) else { return }

        let candidates = identCandidates(for: leg)
        guard !candidates.isEmpty else { return }
        let index = min(cached?.identIndex ?? 0, candidates.count - 1)
        let ident = candidates[index]

        isFetching = true
        defer { isFetching = false }

        let outcome = await fetch(ident: ident, leg: leg, apiKey: apiKey)
        apply(outcome, ident: ident, identIndex: index, candidateCount: candidates.count, leg: leg, now: now)
    }

    // MARK: - Escolha do voo relevante

    /// The one leg worth spending a call on: the flight currently under way,
    /// otherwise the next one to depart inside the look-ahead window. Never a
    /// sweep over the itinerary.
    private func relevantLeg(in legs: [FlightLeg], now: Date) -> FlightLeg? {
        let airborne = legs.filter { leg in
            let arrival = estimates[leg.id]?.arrival ?? leg.scheduledArrival
            return now >= leg.departure - Self.departureLead
                && now <= arrival + Self.arrivalTail
        }
        if let current = airborne.min(by: { $0.departure < $1.departure }) { return current }

        return
            legs
            .filter { $0.departure > now && $0.departure.timeIntervalSince(now) <= Self.lookAheadWindow }
            .min(by: { $0.departure < $1.departure })
    }

    private func shouldRefresh(_ entry: FlightAwareEstimate?, leg: FlightLeg, now: Date) -> Bool {
        guard let entry else { return true }
        guard !entry.isFinal else { return false }
        guard entry.refreshCount < Self.maxRefreshesPerLeg else { return false }
        return now.timeIntervalSince(entry.fetchedAt) >= ttl(for: leg, now: now)
    }

    private func ttl(for leg: FlightLeg, now: Date) -> TimeInterval {
        let toDeparture = leg.departure.timeIntervalSince(now)
        if toDeparture > 6 * 3600 { return Self.ttlFarOut }
        if toDeparture > 3600 { return Self.ttlApproaching }
        return Self.ttlImminent
    }

    // MARK: - Ident do AeroAPI

    /// "IB 268" → ["IBE268", "IB268"]. AeroAPI prefers the ICAO form; the IATA
    /// one is the fallback when the ICAO query comes back empty.
    /// The IATA→ICAO table lives in `TripFlightParser` and is reused here.
    private func identCandidates(for leg: FlightLeg) -> [String] {
        guard let parsed = TripFlightParser.flightNumbers(in: leg.code).first,
            let iata = parsed.iata
        else { return [] }

        let stripped = String(parsed.number.drop(while: { $0 == "0" }))
        let digits = stripped.isEmpty ? parsed.number : stripped

        var out = (TripFlightParser.icaoPrefixes[iata] ?? []).map { $0 + digits }
        out.append(iata + digits)

        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    // MARK: - Rede

    private enum Outcome {
        /// A flight matched; carries its arrival, departure and finality.
        case matched(arrival: Date?, departure: Date?, isActual: Bool, isFinal: Bool)
        /// The call went through but no flight in the response was ours.
        case noMatch
        /// The call went through and was refused or unusable.
        case rejected
        /// No request reached FlightAware — offline, timeout, DNS. Costs nothing
        /// and must not count against the leg's budget.
        case offline
        /// Key refused; the service stands down for the session.
        case unauthorized
        /// Rate limited.
        case throttled
    }

    private func fetch(ident: String, leg: FlightLeg, apiKey: String) async -> Outcome {
        guard var components = URLComponents(string: "https://aeroapi.flightaware.com/aeroapi/flights/\(ident)")
        else { return .rejected }

        // Narrow the window hard: `start`/`end` compare against scheduled_out,
        // so ±12h around the itinerary's departure returns this flight and
        // essentially nothing else. Both bounds stay inside AeroAPI's limit of
        // 10 days past / 2 days future, since the leg is at most 24h away.
        let iso = Date.ISO8601FormatStyle()
        components.queryItems = [
            URLQueryItem(name: "ident_type", value: "designator"),
            URLQueryItem(name: "start", value: iso.format(leg.departure.addingTimeInterval(-12 * 3600))),
            URLQueryItem(name: "end", value: iso.format(leg.departure.addingTimeInterval(12 * 3600))),
            URLQueryItem(name: "max_pages", value: "1"),
        ]
        guard let url = components.url else { return .rejected }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // The key travels only in this header and is never logged or persisted.
        request.setValue(apiKey, forHTTPHeaderField: "x-apikey")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // Any transport failure — no connection, timeout, lost link — is a
            // silent no-op. The itinerary time is a perfectly good answer.
            return .offline
        }

        guard let http = response as? HTTPURLResponse else { return .rejected }
        switch http.statusCode {
        case 200: break
        case 401, 403: return .unauthorized
        case 429: return .throttled
        default: return .rejected
        }

        guard let payload = try? Self.decoder.decode(AeroResponse.self, from: data),
            let flights = payload.flights, !flights.isEmpty
        else { return .noMatch }

        guard let match = Self.bestMatch(among: flights, for: leg) else { return .noMatch }

        let arrival =
            Self.date(match.actualIn) ?? Self.date(match.estimatedIn) ?? Self.date(match.actualOn)
            ?? Self.date(match.estimatedOn) ?? Self.date(match.scheduledIn) ?? Self.date(match.scheduledOn)
        let departure =
            Self.date(match.actualOut) ?? Self.date(match.estimatedOut) ?? Self.date(match.actualOff)
            ?? Self.date(match.scheduledOut) ?? Self.date(match.scheduledOff)
        let isActual = match.actualIn != nil || match.actualOn != nil
        let cancelled = match.cancelled ?? false

        // A cancelled flight has no arrival worth showing; a gate arrival that
        // already happened is the end of the story.
        if cancelled {
            return .matched(arrival: nil, departure: nil, isActual: false, isFinal: true)
        }
        return .matched(
            arrival: arrival,
            departure: departure,
            isActual: isActual,
            isFinal: match.actualIn != nil
        )
    }

    private func apply(
        _ outcome: Outcome,
        ident: String,
        identIndex: Int,
        candidateCount: Int,
        leg: FlightLeg,
        now: Date
    ) {
        switch outcome {
        case .offline:
            // Nothing was billed and nothing was learned: only stop trying.
            quietUntil = now.addingTimeInterval(Self.offlineBackoff)
            return

        case .unauthorized:
            isAuthorized = false
            return

        case .throttled:
            quietUntil = now.addingTimeInterval(Self.rateLimitBackoff)
            return

        case .rejected, .noMatch, .matched:
            break
        }

        var entry =
            estimates[leg.id]
            ?? FlightAwareEstimate(
                legID: leg.id,
                ident: ident,
                arrival: nil,
                isActual: false,
                departure: nil,
                fetchedAt: now,
                refreshCount: 0,
                isFinal: false,
                identIndex: identIndex
            )
        entry.ident = ident
        entry.fetchedAt = now
        // The request reached FlightAware, so it counted — even when it taught
        // us nothing. That is exactly what the budget is there to bound.
        entry.refreshCount += 1

        switch outcome {
        case .matched(let arrival, let departure, let isActual, let isFinal):
            if let arrival, Self.isPlausible(arrival, for: leg) {
                entry.arrival = arrival
                entry.isActual = isActual
            } else if arrival == nil {
                entry.arrival = nil
                entry.isActual = false
            }
            entry.departure = departure
            entry.isFinal = isFinal
        case .noMatch:
            // Try the next ident spelling next time (ICAO → IATA).
            if identIndex + 1 < candidateCount { entry.identIndex = identIndex + 1 }
        case .rejected, .offline, .unauthorized, .throttled:
            break
        }

        estimates[leg.id] = entry
        persist()
    }

    /// Guards against matching a same-numbered flight on the wrong day.
    private static func isPlausible(_ arrival: Date, for leg: FlightLeg) -> Bool {
        abs(arrival.timeIntervalSince(leg.scheduledArrival)) <= plausibilityWindow
    }

    /// The flight in the response whose scheduled departure sits closest to the
    /// itinerary's, within a few hours.
    private static func bestMatch(among flights: [AeroFlight], for leg: FlightLeg) -> AeroFlight? {
        var best: (flight: AeroFlight, delta: TimeInterval)?

        for flight in flights {
            guard let scheduled = date(flight.scheduledOut) ?? date(flight.scheduledOff) else { continue }
            let delta = abs(scheduled.timeIntervalSince(leg.departure))
            guard delta <= plausibilityWindow else { continue }
            if best == nil || delta < best!.delta { best = (flight, delta) }
        }

        if let best { return best.flight }
        // No parseable schedule anywhere, but the window already narrowed the
        // query to a single day — one lone result is still our flight.
        return flights.count == 1 ? flights.first : nil
    }

    // MARK: - Modelo de resposta
    //
    // Everything is optional on purpose: AeroAPI nulls out fields that do not
    // apply yet, and a missing one must degrade to the itinerary rather than
    // fail the decode. Timestamps stay strings and are parsed by hand so one
    // malformed value cannot take the whole payload down with it.

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private struct AeroResponse: Decodable {
        let flights: [AeroFlight]?
    }

    private struct AeroFlight: Decodable {
        let ident: String?
        let identIcao: String?
        let identIata: String?
        let cancelled: Bool?
        let diverted: Bool?
        let origin: AeroAirport?
        let destination: AeroAirport?

        let scheduledOut: String?
        let estimatedOut: String?
        let actualOut: String?
        let scheduledOff: String?
        let estimatedOff: String?
        let actualOff: String?
        let scheduledOn: String?
        let estimatedOn: String?
        let actualOn: String?
        let scheduledIn: String?
        let estimatedIn: String?
        let actualIn: String?
    }

    private struct AeroAirport: Decodable {
        let code: String?
        let codeIcao: String?
        let codeIata: String?
    }

    /// "2026-09-06T05:35:00Z", with or without fractional seconds.
    private static func date(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let parsed = try? Date(raw, strategy: Date.ISO8601FormatStyle()) { return parsed }
        if let parsed = try? Date(raw, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return parsed
        }
        return nil
    }

    // MARK: - Persistência

    private func persist() {
        let snapshot = estimates
        Task.detached(priority: .utility) { DiskStore.save(snapshot) }
    }

    /// Small JSON file in Application Support. Off the main actor for writes;
    /// the file is a handful of entries, so the read at launch is trivial.
    private enum DiskStore {
        private static let fileName = "flightaware-arrivals.json"

        private static var url: URL? {
            guard
                let base = try? FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
            else { return nil }
            let folder = base.appendingPathComponent("FlightAware", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder.appendingPathComponent(fileName)
        }

        static func load(retention: TimeInterval) -> [String: FlightAwareEstimate] {
            guard let url, let data = try? Data(contentsOf: url) else { return [:] }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let stored = try? decoder.decode([String: FlightAwareEstimate].self, from: data) else {
                return [:]
            }
            let cutoff = Date().addingTimeInterval(-retention)
            return stored.filter { $0.value.fetchedAt >= cutoff }
        }

        static func save(_ entries: [String: FlightAwareEstimate]) {
            guard let url else { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(entries) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
