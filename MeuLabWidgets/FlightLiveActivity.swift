import SwiftUI
import WidgetKit

// ============================================================
// LIVE ACTIVITY DE VOO — tela bloqueada + Ilha Dinâmica
// No espírito do widget do Flightradar24: código do voo,
// origem → destino, barra com o avião, partida, chegada
// estimada e "chega em X".
//
// REGRA DE OURO: nada aqui é redesenhado por update nosso.
// A contagem e a barra saem de Text(timerInterval:) e
// ProgressView(timerInterval:) — o sistema anima sozinho a
// partir de dois instantes. Um voo de 10h consome zero
// atualizações enquanto a estimativa não mudar.
// ============================================================

#if canImport(ActivityKit) && os(iOS)
import ActivityKit

// MARK: - Paleta

private enum FlightPalette {
    static let accent = Color(red: 0.17, green: 0.72, blue: 0.86)   // cyan
    static let live = Color(red: 0.27, green: 0.78, blue: 0.37)     // green
    static let track = Color.white.opacity(0.16)
    static let muted = Color.white.opacity(0.55)
    static let strong = Color.white.opacity(0.92)
}

// MARK: - Peças

/// Range that is always valid for the timer views, counting down to `target`.
private func countdown(to target: Date, from reference: Date) -> ClosedRange<Date> {
    let lower = min(reference, target.addingTimeInterval(-1))
    return lower...max(target, lower.addingTimeInterval(1))
}

/// The animated bar. `ProgressView(timerInterval:)` fills itself from the two
/// instants, so this view never needs to be pushed a new fraction.
private struct FlightBar: View {
    let state: FlightActivityAttributes.ContentState
    var height: CGFloat = 6

    var body: some View {
        switch state.phase {
        case .beforeDeparture:
            Capsule()
                .fill(FlightPalette.track)
                .frame(height: height)
        case .inFlight:
            ProgressView(timerInterval: state.flightRange, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(FlightPalette.accent)
        case .landed:
            Capsule()
                .fill(FlightPalette.accent)
                .frame(height: height)
        }
    }
}

/// GRU ✈ MAD, with the plane sitting where the phase says it is.
private struct RouteLine: View {
    let attributes: FlightActivityAttributes
    let state: FlightActivityAttributes.ContentState
    var codeFont: Font = .system(size: 22, weight: .heavy, design: .rounded)

    private var icon: String {
        switch state.phase {
        case .beforeDeparture: "airplane.departure"
        case .inFlight: "airplane"
        case .landed: "airplane.arrival"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(attributes.originCode)
                .font(codeFont)
                .foregroundStyle(FlightPalette.strong)

            Rectangle()
                .fill(FlightPalette.track)
                .frame(height: 1)

            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FlightPalette.accent)

            Rectangle()
                .fill(FlightPalette.track)
                .frame(height: 1)

            Text(attributes.destinationCode)
                .font(codeFont)
                .foregroundStyle(FlightPalette.strong)
        }
    }
}

/// "chega em 2h 14" — animated by the system, never by an update.
private struct ArrivesIn: View {
    let state: FlightActivityAttributes.ContentState
    var font: Font = .system(size: 13, weight: .semibold, design: .rounded)
    var now: Date = Date()

    var body: some View {
        switch state.phase {
        case .beforeDeparture:
            HStack(spacing: 4) {
                Text("parte em")
                Text(timerInterval: countdown(to: state.departure, from: now), countsDown: true)
                    .monospacedDigit()
            }
            .font(font)
            .foregroundStyle(FlightPalette.muted)
        case .inFlight:
            HStack(spacing: 4) {
                Text("chega em")
                Text(timerInterval: countdown(to: state.arrival, from: now), countsDown: true)
                    .monospacedDigit()
            }
            .font(font)
            .foregroundStyle(FlightPalette.accent)
        case .landed:
            Text("Pousou")
                .font(font)
                .foregroundStyle(FlightPalette.live)
        }
    }
}

/// Hora + rótulo de uma ponta do voo, no fuso do próprio aeroporto.
private struct EndpointColumn: View {
    let clock: String
    let caption: String
    let zone: String?
    var alignment: HorizontalAlignment = .leading
    var live: Bool = false

    var body: some View {
        VStack(alignment: alignment, spacing: 1) {
            HStack(spacing: 4) {
                if live && alignment == .leading { LiveDot() }
                Text(clock)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(FlightPalette.strong)
                    .monospacedDigit()
                if let zone {
                    Text(zone)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(FlightPalette.muted)
                }
                if live && alignment == .trailing { LiveDot() }
            }
            Text(caption)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(FlightPalette.muted)
        }
    }
}

private struct LiveDot: View {
    var body: some View {
        Circle()
            .fill(FlightPalette.live)
            .frame(width: 5, height: 5)
    }
}

// MARK: - Tela bloqueada / banner

struct FlightLockScreenView: View {
    let attributes: FlightActivityAttributes
    let state: FlightActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Image(systemName: "airplane")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(FlightPalette.accent)
                    Text(attributes.flightCode)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(FlightPalette.strong)
                }
                Spacer(minLength: 8)
                ArrivesIn(state: state)
            }

            RouteLine(attributes: attributes, state: state)

            FlightBar(state: state)

            HStack(alignment: .top) {
                EndpointColumn(
                    clock: FlightActivityFormat.clock(state.departure, timeZoneID: attributes.departureTimeZoneID),
                    caption: attributes.origin,
                    zone: FlightActivityFormat.zoneAbbreviation(attributes.departureTimeZoneID, at: state.departure),
                    alignment: .leading
                )
                Spacer(minLength: 8)
                EndpointColumn(
                    clock: FlightActivityFormat.clock(state.arrival, timeZoneID: attributes.arrivalTimeZoneID),
                    caption: state.isEstimateLive ? "\(attributes.destination) · estimado" : attributes.destination,
                    zone: FlightActivityFormat.zoneAbbreviation(attributes.arrivalTimeZoneID, at: state.arrival),
                    alignment: .trailing,
                    live: state.isEstimateLive
                )
            }

            if let note = state.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FlightPalette.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .activityBackgroundTint(Color(red: 0.05, green: 0.08, blue: 0.16))
        .activitySystemActionForegroundColor(FlightPalette.accent)
    }
}

// MARK: - Configuração

struct FlightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightActivityAttributes.self) { context in
            FlightLockScreenView(attributes: context.attributes, state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // --- Expandido ---
                DynamicIslandExpandedRegion(.leading) {
                    EndpointColumn(
                        clock: FlightActivityFormat.clock(
                            context.state.departure,
                            timeZoneID: context.attributes.departureTimeZoneID
                        ),
                        caption: context.attributes.originCode,
                        zone: nil,
                        alignment: .leading
                    )
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    EndpointColumn(
                        clock: FlightActivityFormat.clock(
                            context.state.arrival,
                            timeZoneID: context.attributes.arrivalTimeZoneID
                        ),
                        caption: context.attributes.destinationCode,
                        zone: nil,
                        alignment: .trailing,
                        live: context.state.isEstimateLive
                    )
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.flightCode)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(FlightPalette.muted)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        FlightBar(state: context.state)
                        HStack {
                            Image(systemName: "airplane")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(FlightPalette.accent)
                            Spacer(minLength: 6)
                            ArrivesIn(state: context.state, font: .system(size: 12, weight: .semibold, design: .rounded))
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FlightPalette.accent)
            } compactTrailing: {
                CompactCountdown(state: context.state)
            } minimal: {
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FlightPalette.accent)
            }
            .keylineTint(FlightPalette.accent)
            // No .widgetURL: the app registers no custom scheme, so a tap should
            // just open the app rather than fail against a dead deep link.
        }
    }
}

/// Compact trailing has room for a clock and nothing else.
private struct CompactCountdown: View {
    let state: FlightActivityAttributes.ContentState
    var now: Date = Date()

    var body: some View {
        switch state.phase {
        case .beforeDeparture:
            Text(timerInterval: countdown(to: state.departure, from: now), countsDown: true)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(FlightPalette.muted)
        case .inFlight:
            Text(timerInterval: countdown(to: state.arrival, from: now), countsDown: true)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(FlightPalette.accent)
        case .landed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(FlightPalette.live)
        }
    }
}

// MARK: - Previews
// Conferem os quatro layouts sem precisar de voo real.

extension FlightActivityAttributes {
    static var preview: FlightActivityAttributes {
        FlightActivityAttributes(
            flightCode: "IB 268",
            origin: "Guarulhos",
            destination: "Madrid",
            departureTimeZoneID: "America/Sao_Paulo",
            arrivalTimeZoneID: "Europe/Madrid",
            scheduledDeparture: Date().addingTimeInterval(-3 * 3600),
            scheduledArrival: Date().addingTimeInterval(7 * 3600)
        )
    }
}

extension FlightActivityAttributes.ContentState {
    static var previewBeforeDeparture: Self {
        .init(
            departure: Date().addingTimeInterval(50 * 60),
            arrival: Date().addingTimeInterval(50 * 60 + 10 * 3600),
            isEstimateLive: false,
            phase: .beforeDeparture,
            note: "Portão B12 · embarque às 13:30"
        )
    }

    static var previewInFlight: Self {
        .init(
            departure: Date().addingTimeInterval(-3 * 3600),
            arrival: Date().addingTimeInterval(7 * 3600),
            isEstimateLive: true,
            phase: .inFlight,
            note: nil
        )
    }

    static var previewLanded: Self {
        .init(
            departure: Date().addingTimeInterval(-10 * 3600),
            arrival: Date().addingTimeInterval(-5 * 60),
            isEstimateLive: true,
            phase: .landed,
            note: "Esteira 7"
        )
    }
}

#Preview("Tela bloqueada", as: .content, using: FlightActivityAttributes.preview) {
    FlightLiveActivity()
} contentStates: {
    FlightActivityAttributes.ContentState.previewBeforeDeparture
    FlightActivityAttributes.ContentState.previewInFlight
    FlightActivityAttributes.ContentState.previewLanded
}

#Preview("Ilha compacta", as: .dynamicIsland(.compact), using: FlightActivityAttributes.preview) {
    FlightLiveActivity()
} contentStates: {
    FlightActivityAttributes.ContentState.previewBeforeDeparture
    FlightActivityAttributes.ContentState.previewInFlight
    FlightActivityAttributes.ContentState.previewLanded
}

#Preview("Ilha expandida", as: .dynamicIsland(.expanded), using: FlightActivityAttributes.preview) {
    FlightLiveActivity()
} contentStates: {
    FlightActivityAttributes.ContentState.previewInFlight
    FlightActivityAttributes.ContentState.previewLanded
}

#Preview("Ilha mínima", as: .dynamicIsland(.minimal), using: FlightActivityAttributes.preview) {
    FlightLiveActivity()
} contentStates: {
    FlightActivityAttributes.ContentState.previewInFlight
}
#endif
