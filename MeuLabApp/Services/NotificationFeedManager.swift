import Foundation
import os.lock
import UserNotifications

final class NotificationFeedManager: ObservableObject {
    static let shared = NotificationFeedManager()

    private let api = APIService.shared
    private let defaults = UserDefaults.standard
    private let latestIdKey = "notification_feed_latest_id"
    private let basePollInterval: TimeInterval = 20
    private let maxPollInterval: TimeInterval = 300

    private struct State {
        var currentPollInterval: TimeInterval = 20
        var pollTask: Task<Void, Never>?
        var isFetching = false
    }
    private let stateLock = OSAllocatedUnfairLock<State>(initialState: State())

    private init() {}

    func start() {
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runLoop()
        }
        let didSet = stateLock.withLock { s in
            if s.pollTask == nil {
                s.pollTask = task
                return true
            }
            return false
        }
        if !didSet {
            task.cancel()
        }
    }

    func stop() {
        let task = stateLock.withLock { s -> Task<Void, Never>? in
            let t = s.pollTask
            s.pollTask = nil
            s.currentPollInterval = basePollInterval
            s.isFetching = false
            return t
        }
        task?.cancel()
    }

    private func runLoop() async {
        // Run immediately, then back off based on success/failure.
        while !Task.isCancelled {
            await poll()
            let interval = stateLock.withLock { s in
                max(1, s.currentPollInterval)
            }
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }

    private func poll() async {
        let didStart = stateLock.withLock { s -> Bool in
            if s.isFetching { return false }
            s.isFetching = true
            return true
        }
        guard didStart else { return }
        defer {
            stateLock.withLock { s in
                s.isFetching = false
            }
        }

        let sinceId = defaults.integer(forKey: latestIdKey)
        do {
            let feed = try await api.fetchNotificationFeed(sinceId: sinceId, limit: 50)
            guard !feed.events.isEmpty else {
                defaults.set(feed.latestId, forKey: latestIdKey)
                resetBackoff()
                return
            }

            let granted = await isNotificationAuthorized()
            let ids = feed.events.map(\.id)

            if granted {
                for event in feed.events {
                    scheduleLocalNotification(event)
                }
            }

            defaults.set(feed.latestId, forKey: latestIdKey)

            Task {
                try? await api.ackNotifications(ids: ids)
            }
            resetBackoff()
        } catch {
            increaseBackoff()
        }
    }

    private func isNotificationAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private func scheduleLocalNotification(_ event: NotificationEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.body
        content.sound = .default

        let category = mapCategory(event.category)
        content.categoryIdentifier = category

        // `UNNotificationContent.userInfo` is encoded over XPC and must contain only
        // property-list / NSSecureCoding-compatible values. Avoid passing raw Swift types
        // (e.g. `[AnyCodable]`, `[String: AnyCodable]`) which become `__SwiftValue` and crash.
        var userInfo: [String: Any] = [
            "category": category,
            "event_id": event.id
        ]
        if let data = event.data {
            var sanitized: [String: Any] = [:]
            sanitized.reserveCapacity(data.count)
            for (k, v) in data {
                if let pv = propertyListValue(from: v.value) {
                    sanitized[k] = pv
                }
            }
            if !sanitized.isEmpty {
                userInfo["data"] = sanitized
            }
        }
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: "feed_\(event.id)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[NotificationFeed] Failed to schedule local notification \(event.id): \(error)")
            }
        }
    }

    private func mapCategory(_ category: String) -> String {
        switch category {
        case "adsb_alert", "adsb_interest", "adsb_alerts", "adsb":
            return "adsb_alert"
        case "acars", "acars_alert":
            return "acars_alert"
        case "weather", "weather_alert":
            return "weather_alert"
        case "satdump", "satdump_pass":
            return "satellite"
        default:
            return "general"
        }
    }

    private func propertyListValue(from value: Any) -> Any? {
        // Allowed-ish primitives (bridged to Foundation types).
        if value is NSNull { return NSNull() }
        if let v = value as? String { return v }
        if let v = value as? NSString { return v }
        if let v = value as? Int { return v }
        if let v = value as? Int64 { return NSNumber(value: v) }
        if let v = value as? Double { return v }
        if let v = value as? Bool { return v }
        if let v = value as? NSNumber { return v }
        if let v = value as? Date { return v }
        if let v = value as? Data { return v }

        // Unwrap AnyCodable and its common nested forms.
        if let v = value as? AnyCodable {
            return propertyListValue(from: v.value)
        }
        if let arr = value as? [AnyCodable] {
            return arr.compactMap { propertyListValue(from: $0.value) }
        }
        if let dict = value as? [String: AnyCodable] {
            var out: [String: Any] = [:]
            out.reserveCapacity(dict.count)
            for (k, v) in dict {
                if let pv = propertyListValue(from: v.value) {
                    out[k] = pv
                }
            }
            return out
        }

        // Best-effort for raw collections.
        if let arr = value as? [Any] {
            return arr.compactMap { propertyListValue(from: $0) }
        }
        if let dict = value as? [String: Any] {
            var out: [String: Any] = [:]
            out.reserveCapacity(dict.count)
            for (k, v) in dict {
                if let pv = propertyListValue(from: v) {
                    out[k] = pv
                }
            }
            return out
        }

        // Fallback: stringify to avoid XPC encoder crashes.
        return String(describing: value)
    }

    private func resetBackoff() {
        stateLock.withLock { s in
            s.currentPollInterval = basePollInterval
        }
    }

    private func increaseBackoff() {
        stateLock.withLock { s in
            let next = min(maxPollInterval, max(basePollInterval, s.currentPollInterval * 2))
            s.currentPollInterval = next
        }
    }
}
