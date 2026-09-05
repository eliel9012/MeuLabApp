import SwiftUI
import UIKit

// ============================================================
// CARD DE PROGRESSO DE VOO
// Desenha a etapa aérea em curso — código do voo, aeroportos, barra com
// o avião na posição atual, horários em fuso local e quanto falta.
// Só aparece quando existe voo relevante; nunca polui a tela com um voo
// que ainda está a dias de distância.
// ============================================================

// MARK: - Paleta

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Same hue in both appearances, different luminance. A navy that reads as ink on
/// a light card disappears against dark glass, so each accent carries two values.
private func fpAdaptive(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
        UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
    })
}

private enum FPPalette {
    static let ink = Color(uiColor: .label)
    static let muted = Color(uiColor: .secondaryLabel)
    static let track = Color(uiColor: .separator)
    /// The itinerary's "deslocamento" navy — same accent the travel days use.
    static let route = fpAdaptive(light: 0x2E4470, dark: 0x8FAAD9)
    /// Reserved for the live estimate, so green always means "this came from the
    /// airline, not from the printed ticket".
    static let live = fpAdaptive(light: 0x2E7D5A, dark: 0x6FCFA0)
}

// MARK: - Aeroportos

private enum FPAirport {
    /// Airport names as the itinerary writes them, mapped to IATA. The itinerary
    /// often prints the code itself ("Londrina (LDB)") and that always wins.
    private static let known: [String: String] = [
        "guarulhos": "GRU",
        "sao paulo": "GRU",
        "congonhas": "CGH",
        "londrina": "LDB",
        "ribeirao preto": "RAO",
        "madrid": "MAD",
        "madri": "MAD",
        "marseille": "MRS",
        "marselha": "MRS",
        "beauvais": "BVA",
        "paris beauvais": "BVA",
        "porto": "OPO",
        "lisboa": "LIS",
        "lisbon": "LIS",
        "london stansted": "STN",
        "stansted": "STN",
        "londres": "LHR",
        "london": "LHR",
    ]

    /// Three-letter headline for a column.
    static func code(for raw: String) -> String {
        if let match = raw.firstMatch(of: /\(([A-Z]{3})\)/) { return String(match.1) }
        let key = normalized(raw)
        if let hit = known[key] { return hit }
        // Last resort so an airport nobody mapped still gets a headline instead of
        // an empty column.
        return String(key.filter(\.isLetter).prefix(3)).uppercased()
    }

    /// City line under the code, with the parenthesised code stripped — it is
    /// already the headline right above.
    static func name(for raw: String) -> String {
        raw.replacingOccurrences(of: #"\s*\([A-Z]{3}\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func normalized(_ raw: String) -> String {
        name(for: raw)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .lowercased()
    }
}

// MARK: - Fusos e durações

private enum FPClock {
    static func time(_ date: Date, in zone: TimeZone?) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "HH:mm"
        df.timeZone = zone ?? .current
        return df.string(from: date)
    }

    /// Real offset at that instant, so September reads GMT+2 for Madrid rather
    /// than the standard-time GMT+1.
    static func offset(_ zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        let hours = seconds / 3600
        let minutes = abs(seconds % 3600) / 60
        let sign = hours < 0 ? "−" : "+"
        return minutes == 0
            ? "GMT\(sign)\(abs(hours))"
            : String(format: "GMT%@%d:%02d", sign, abs(hours), minutes)
    }

    static func region(for zone: TimeZone) -> String {
        switch zone.identifier {
        case "America/Sao_Paulo": return "Brasil"
        case "Europe/Madrid": return "Espanha"
        case "Europe/Paris": return "França"
        case "Europe/Lisbon": return "Portugal"
        case "Europe/London": return "Inglaterra"
        default:
            return zone.identifier.split(separator: "/").last
                .map { $0.replacingOccurrences(of: "_", with: " ") } ?? zone.identifier
        }
    }

    /// Marks a clock that is not in the phone's zone, so "05:35" is never silently
    /// read as local time. Empty when the zones agree — no noise for nothing.
    static func zoneTag(_ zone: TimeZone?, at date: Date) -> String {
        guard let zone, zone.identifier != TimeZone.current.identifier else { return "" }
        return "\(region(for: zone)) \(offset(zone, at: date))"
    }

    /// "1h17", "21 min", "11h" — the itinerary's own voice.
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(Int(interval.rounded()), 0) / 60
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h)h" : String(format: "%dh%02d", h, m)
    }

    /// Calendar days crossed between the two ends, each read in its own zone.
    /// A red-eye that leaves on the 7th and lands on the 8th earns a "+1".
    static func dayShift(from departure: Date, in departureZone: TimeZone?,
                         to arrival: Date, in arrivalZone: TimeZone?) -> Int {
        var from = Calendar(identifier: .gregorian)
        from.timeZone = departureZone ?? .current
        var to = Calendar(identifier: .gregorian)
        to.timeZone = arrivalZone ?? .current

        // Each end is reduced to the date on its own wall calendar, then both are
        // re-read in UTC. Subtracting there counts pages of a calendar rather than
        // hours, so the two zones' offsets cannot skew the result.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        guard
            let start = utc.date(from: from.dateComponents([.year, .month, .day], from: departure)),
            let end = utc.date(from: to.dateComponents([.year, .month, .day], from: arrival))
        else { return 0 }
        return max(utc.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }
}

// MARK: - Card

/// Progress card for the flight the traveller is on — or about to be on.
///
/// Renders nothing at all outside that window: a flight ten days out belongs in
/// the timeline below, not at the top of the screen.
struct FlightProgressCard: View {
    let legs: [FlightLeg]
    /// Driven by the screen's own one-minute tick. A flight is hours long, so a
    /// minute of granularity moves the plane smoothly enough.
    let now: Date

    /// How early the card takes over the top of the screen. Three hours is about
    /// when the traveller starts heading for the airport.
    private static let upcomingWindow: TimeInterval = 3 * 3600
    /// Kept on screen a little past touchdown, both to absorb drift between the
    /// printed arrival and the live estimate and because "Pousou" is still news.
    private static let landingGrace: TimeInterval = 20 * 60

    /// The service publishes its cache, so the green live arrival appears the
    /// moment AeroAPI answers — no polling on this side.
    @ObservedObject private var flightAware = FlightAwareService.shared

    private var leg: FlightLeg? {
        legs.first { leg in
            now >= leg.departure.addingTimeInterval(-Self.upcomingWindow)
                && now < leg.scheduledArrival.addingTimeInterval(Self.landingGrace)
        }
    }

    /// Re-arms the fetch every five minutes while the card is up. The service
    /// decides whether that actually costs a request.
    private var refreshKey: String {
        "\(leg?.id ?? "-")#\(Int(now.timeIntervalSince1970 / 300))"
    }

    var body: some View {
        if let leg {
            FlightProgressBoard(
                progress: FlightProgress.make(
                    leg: leg,
                    // A cache read, never a request — the fetch lives in `.task`.
                    liveArrival: flightAware.cachedArrival(for: leg),
                    now: now
                )
            )
            .task(id: refreshKey) {
                // The whole list: the service has its own, wider policy about
                // which leg is worth a paid call and when.
                await flightAware.refreshIfNeeded(legs: legs, now: now)
            }
        }
    }
}

// MARK: - Desenho

/// The card proper. Pure: hand it a `FlightProgress` and it draws that, which is
/// what makes the previews below possible without touching the network or the
/// itinerary's real dates.
private struct FlightProgressBoard: View {
    let progress: FlightProgress

    private var leg: FlightLeg { progress.leg }

    private var phaseLabel: String {
        switch progress.phase {
        case .beforeDeparture: return "PRÓXIMO VOO"
        case .inFlight: return "EM VOO"
        case .landed: return "POUSOU"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            airports
            FlightProgressTrack(fraction: progress.fraction, phase: progress.phase)
            times
            Divider()
            footer
        }
        .padding(16)
        .glassCard(tint: FPPalette.route, cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: Cabeçalho

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(FPPalette.route)
            Text(leg.code)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(FPPalette.ink)
            Spacer(minLength: 8)
            Text(phaseLabel)
                .font(.system(size: 10.5, weight: .bold))
                .tracking(1.4)
                .foregroundColor(FPPalette.muted)
        }
    }

    // MARK: Origem e destino

    private var airports: some View {
        HStack(alignment: .top, spacing: 12) {
            airportColumn(leg.origin, alignment: .leading)
            Spacer(minLength: 0)
            airportColumn(leg.destination, alignment: .trailing)
        }
    }

    private func airportColumn(_ raw: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(FPAirport.code(for: raw))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundColor(FPPalette.ink)
            Text(FPAirport.name(for: raw))
                .font(.system(size: 11.5))
                .foregroundColor(FPPalette.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
    }

    // MARK: Horários

    private var times: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(FPClock.time(leg.departure, in: leg.departureTimeZone))
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundColor(FPPalette.ink)
                caption("PARTIDA", zone: FPClock.zoneTag(leg.departureTimeZone, at: leg.departure), tint: FPPalette.muted)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 5) {
                    if progress.isEstimateLive {
                        // The one green dot on the card: this number is coming off
                        // the wire, not off the ticket.
                        Circle()
                            .fill(FPPalette.live)
                            .frame(width: 6, height: 6)
                    }
                    Text(FPClock.time(progress.effectiveArrival, in: leg.arrivalTimeZone))
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundColor(progress.isEstimateLive ? FPPalette.live : FPPalette.ink)
                    if dayShift > 0 {
                        Text("+\(dayShift)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(FPPalette.muted)
                            .baselineOffset(7)
                    }
                }
                caption(
                    progress.isEstimateLive ? "ESTIMADA AO VIVO" : "PREVISTA",
                    zone: FPClock.zoneTag(leg.arrivalTimeZone, at: progress.effectiveArrival),
                    tint: progress.isEstimateLive ? FPPalette.live : FPPalette.muted
                )
            }
        }
    }

    private var dayShift: Int {
        FPClock.dayShift(
            from: leg.departure, in: leg.departureTimeZone,
            to: progress.effectiveArrival, in: leg.arrivalTimeZone
        )
    }

    private func caption(_ label: String, zone: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.0)
                .foregroundColor(tint)
            if !zone.isEmpty {
                Text(zone)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(FPPalette.muted)
            }
        }
    }

    // MARK: Rodapé

    private var footer: some View {
        HStack(spacing: 10) {
            footerItem(icon: "airplane.departure", text: departureLine)
            Spacer(minLength: 0)
            footerItem(
                icon: "airplane.arrival",
                text: arrivalLine,
                tint: progress.isEstimateLive ? FPPalette.live : FPPalette.muted
            )
        }
    }

    private var departureLine: String {
        switch progress.phase {
        case .beforeDeparture:
            return "Parte em \(FPClock.duration(leg.departure.timeIntervalSince(nowFromProgress)))"
        case .inFlight, .landed:
            return "Partiu há \(FPClock.duration(progress.elapsed))"
        }
    }

    private var arrivalLine: String {
        switch progress.phase {
        case .landed: return "Já pousou"
        case .beforeDeparture, .inFlight:
            return "Chega em \(FPClock.duration(progress.remaining))"
        }
    }

    /// `FlightProgress` does not carry `now`, but it carries both distances from
    /// it, which is enough to recover the instant it was made for.
    private var nowFromProgress: Date {
        progress.effectiveArrival.addingTimeInterval(-progress.remaining)
    }

    private func footerItem(icon: String, text: String, tint: Color = FPPalette.muted) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12.5, weight: .medium))
        }
        .foregroundColor(tint)
    }

    private var accessibilitySummary: String {
        let origin = FPAirport.name(for: leg.origin)
        let destination = FPAirport.name(for: leg.destination)
        let arrival = FPClock.time(progress.effectiveArrival, in: leg.arrivalTimeZone)
        let estimate = progress.isEstimateLive ? "estimativa ao vivo" : "horário previsto"
        return "Voo \(leg.code), \(origin) para \(destination). "
            + "\(departureLine). \(arrivalLine), chegada \(arrival), \(estimate)."
    }
}

// MARK: - Barra

/// Horizontal bar with the aircraft sitting at the current fraction. Drawn with
/// absolute positions so the plane's centre lands exactly on the line rather than
/// wherever a stack's rounding puts it.
private struct FlightProgressTrack: View {
    let fraction: Double
    let phase: FlightProgress.Phase

    /// Room reserved at both ends for the aircraft glyph, so it never clips.
    private let badge: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let inset = badge / 2
            let span = max(geo.size.width - badge, 1)
            let y = geo.size.height / 2
            let travelled = span * fraction

            // Remaining leg — a hairline the flown part is drawn over.
            Capsule()
                .fill(FPPalette.track.opacity(0.55))
                .frame(width: span, height: 3)
                .position(x: geo.size.width / 2, y: y)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [FPPalette.route.opacity(0.45), FPPalette.route],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: max(travelled, 3), height: 3)
                .position(x: inset + max(travelled, 3) / 2, y: y)

            Circle()
                .fill(FPPalette.route)
                .frame(width: 7, height: 7)
                .position(x: inset, y: y)

            Circle()
                .strokeBorder(
                    phase == .landed ? FPPalette.route : FPPalette.track,
                    lineWidth: 2
                )
                .frame(width: 8, height: 8)
                .position(x: inset + span, y: y)

            Image(systemName: "airplane")
                .font(.system(size: 14, weight: .black))
                .foregroundColor(FPPalette.route)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                .position(x: inset + travelled, y: y)
        }
        .frame(height: badge)
        .accessibilityHidden(true)
    }
}

// MARK: - Previews

/// Synthetic legs only. The real itinerary starts on 06 Sep 2026, so nothing here
/// touches it — the previews build their own flights relative to "now".
private func fpPreviewLeg(
    code: String = "IB 268",
    origin: String = "Guarulhos",
    destination: String = "Madrid",
    departureOffset: TimeInterval,
    arrivalOffset: TimeInterval,
    departureZone: String? = "America/Sao_Paulo",
    arrivalZone: String? = "Europe/Madrid"
) -> FlightLeg {
    let base = Date()
    return FlightLeg(
        id: "preview.\(code)",
        code: code,
        origin: origin,
        destination: destination,
        departure: base.addingTimeInterval(departureOffset),
        scheduledArrival: base.addingTimeInterval(arrivalOffset),
        departureTimeZoneID: departureZone,
        arrivalTimeZoneID: arrivalZone,
        stopID: "preview"
    )
}

#Preview("Em voo · estimativa ao vivo") {
    // 1h17 flown, 51 min to run — fraction ≈ 0.6, the shape the card was drawn for.
    let leg = fpPreviewLeg(departureOffset: -4_620, arrivalOffset: 3_060)
    return ZStack {
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        FlightProgressBoard(
            progress: FlightProgress.make(
                leg: leg,
                liveArrival: leg.scheduledArrival.addingTimeInterval(-8 * 60),
                now: Date()
            )
        )
        .padding(18)
    }
}

#Preview("Em voo · sem estimativa") {
    let leg = fpPreviewLeg(
        code: "FR 595",
        origin: "Beauvais",
        destination: "Porto",
        departureOffset: -3_300,
        arrivalOffset: 2_700,
        departureZone: "Europe/Paris",
        arrivalZone: "Europe/Lisbon"
    )
    return ZStack {
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        FlightProgressBoard(progress: FlightProgress.make(leg: leg, now: Date()))
            .padding(18)
    }
}

#Preview("Antes da partida · vira o dia") {
    // Leaves in 2h10, lands the next morning in Madrid: the "+1" case.
    let leg = fpPreviewLeg(departureOffset: 7_800, arrivalOffset: 7_800 + 41_100)
    return ZStack {
        Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
        FlightProgressBoard(
            progress: FlightProgress.make(
                leg: leg,
                liveArrival: leg.scheduledArrival.addingTimeInterval(12 * 60),
                now: Date()
            )
        )
        .padding(18)
    }
}
