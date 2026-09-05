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
    private func isAlertWorthy(_ stop: TripStop) -> Bool {
        guard stop.date != nil else { return false }
        let text = (stop.title + " " + stop.detail).lowercased()
        let keywords = [
            "voo", "flight", "trem", "tgv", "ter ", "frecciarossa", "shuttle",
            "check-in", "embarque", "retirar carro", "devolver carro", "sair para",
            "conexão", "casamento", "cerimônia", "cocktail",
        ]
        return keywords.contains { text.contains($0) }
    }

    private func leadMinutes(for stop: TripStop) -> Int {
        let text = (stop.title + " " + stop.detail).lowercased()
        let isFlight = text.contains("voo") || text.contains("flight")
        return isFlight ? Self.flightLeadMinutes : Self.defaultLeadMinutes
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
