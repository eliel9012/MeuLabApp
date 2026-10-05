import Foundation
import UserNotifications

// ============================================================
// ALERTAS DO ROTEIRO
// Notificações locais: agendadas no aparelho, disparam sem rede,
// sem servidor e em modo avião.
// ============================================================

@MainActor
final class TripNotifications: ObservableObject {
    static let shared = TripNotifications()

    /// Prefix so the trip's notifications can be cleared without touching the
    /// push-driven ones the app already delivers.
    private static let prefix = "trip."

    /// How far ahead of each entry to warn. Flights get the early warning; the
    /// rest are close-range nudges.
    private static let flightLeadMinutes = 150
    private static let defaultLeadMinutes = 45

    @Published private(set) var scheduledCount = 0
    @Published private(set) var isAuthorized = false

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        default:
            isAuthorized = false
        }
    }

    /// Entries that warrant an alarm. Hotel check-ins and meals do not — waking
    /// someone for every one of 70 entries would train them to ignore all of them.
    /// Title only, as whole words: descriptions mention flights and trains in
    /// passing, and substrings misfire ("ter " inside "pôster ").
    private func isAlertWorthy(_ stop: TripStop) -> Bool {
        guard stop.date != nil, !isLodging(stop) else { return false }
        let title = Self.wordLine(stop.title)
        let keywords = [
            "voo", "flight", "trem", "tgv", "ter", "frecciarossa", "shuttle", "ônibus", "onibus",
            "check-in", "embarque", "retirar carro", "devolver carro", "sair para", "chegar a",
            "conexão",
        ]
        return keywords.contains { title.contains(" \($0) ") }
    }

    /// Hotel stays never alert — "Check-in — Hotel Don Luis" would otherwise fire
    /// mid-flight. The bridge carries no type, so the 🏨 icon is the marker, with
    /// the title as a fallback.
    private func isLodging(_ stop: TripStop) -> Bool {
        if stop.icon == "🏨" { return true }
        let title = Self.wordLine(stop.title)
        return ["hotel", "suites", "hostel", "pousada", "airbnb"].contains { title.contains(" \($0) ") }
    }

    /// Only real flights ("Voo IB 0983 — …") get the early warning; "Voo a comprar"
    /// is a reminder, not a departure.
    private func leadMinutes(for stop: TripStop) -> Int {
        let title = stop.title.lowercased()
        let isFlight = title.hasPrefix("voo ") && !title.contains("a comprar")
        return isFlight ? Self.flightLeadMinutes : Self.defaultLeadMinutes
    }

    /// " sair para o terminal 4s " — lowercased words (hyphens kept, for
    /// "check-in"), space-padded so phrases match on word boundaries.
    private static func wordLine(_ text: String) -> String {
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" })
        return " " + words.joined(separator: " ") + " "
    }

    /// Rebuilds the whole schedule. Cheap, idempotent, and safe to call on every
    /// launch — the itinerary is fixed, so re-deriving beats tracking deltas.
    func rescheduleAll(stops: [TripStop], now: Date = Date()) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let mine = pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: mine)

        guard isAuthorized else {
            scheduledCount = 0
            return
        }

        var count = 0
        for stop in stops where isAlertWorthy(stop) {
            guard let date = stop.date else { continue }
            let fireDate = date.addingTimeInterval(-Double(leadMinutes(for: stop)) * 60)
            guard fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(stop.icon) \(stop.title)"
            var body = "\(stop.dayDate) · \(stop.time)"
            if let address = stop.address { body += "\n\(address)" }
            if let ref = stop.ref { body += "\n\(ref)" }
            content.body = body
            content.sound = .default
            content.userInfo = ["tab": "viagem", "stopID": stop.id]

            // Calendar trigger in the event's own zone: crossing into CEST must not
            // shift when the alarm fires.
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = stop.timeZone ?? .current
            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            comps.timeZone = stop.timeZone ?? .current

            let request = UNNotificationRequest(
                identifier: Self.prefix + stop.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            try? await center.add(request)
            count += 1
        }
        scheduledCount = count
    }

    func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        )
        scheduledCount = 0
    }
}
