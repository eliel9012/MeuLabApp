import CoreLocation
import Foundation

// ============================================================
// MOTOR DA VIAGEM
// Resolve as strings do roteiro ("06 set", "~14:30") em datas reais,
// e decide em que etapa a viagem está — por relógio e por GPS.
// ============================================================

/// One itinerary entry, flattened out of the day/event nesting and resolved to a
/// real point in time.
struct TripStop: Identifiable, Equatable, Sendable {
    let id: String
    let dayID: String
    let dayTitle: String
    let dayDate: String
    let time: String
    let icon: String
    let title: String
    let detail: String
    let address: String?
    let ref: String?
    let latitude: Double?
    let longitude: Double?
    let timeZoneID: String?

    /// Absolute instant, resolved using the event's own time zone. Nil for entries
    /// with no clock time ("dia todo", "noite", "livre").
    let date: Date?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var timeZone: TimeZone? {
        guard let timeZoneID else { return nil }
        return TimeZone(identifier: timeZoneID)
    }

    static func == (lhs: TripStop, rhs: TripStop) -> Bool { lhs.id == rhs.id }
}

enum TripParser {
    /// The itinerary is a single September. Kept explicit so a stale build never
    /// silently schedules against the wrong year.
    static let year = 2026
    static let month = 9

    /// "06 set" -> 6. "19–20 set" -> 19 (ranges take their first day).
    static func day(from dateText: String) -> Int? {
        guard let match = dateText.firstMatch(of: /(\d{1,2})/) else { return nil }
        return Int(match.1)
    }

    /// Handles "06:00", "~04:15", "07:05 → 14:10" (first time wins) and
    /// "14:10 BRT". Returns nil for labels like "noite" or "dia todo".
    static func clock(from timeText: String) -> (hour: Int, minute: Int)? {
        guard let match = timeText.firstMatch(of: /(\d{1,2}):(\d{2})/),
            let h = Int(match.1), let m = Int(match.2),
            (0...23).contains(h), (0...59).contains(m)
        else { return nil }
        return (h, m)
    }

    static func date(dateText: String, timeText: String, timeZone: TimeZone?) -> Date? {
        guard let d = day(from: dateText), let c = clock(from: timeText) else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = d
        comps.hour = c.hour
        comps.minute = c.minute
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone ?? TimeZone(identifier: "America/Sao_Paulo")!
        return cal.date(from: comps)
    }
}

@MainActor
final class TripEngine: ObservableObject {
    static let shared = TripEngine()

    /// Every itinerary entry in chronological order.
    private(set) var stops: [TripStop] = []

    private init() {}

    func load(_ stops: [TripStop]) {
        self.stops = stops
    }

    // MARK: - Onde estamos, pelo relógio

    /// The next entry that has not happened yet.
    func nextStop(now: Date = Date()) -> TripStop? {
        stops.first { stop in
            guard let date = stop.date else { return false }
            return date > now
        }
    }

    /// The most recent entry already started — what is happening right now.
    func currentStop(now: Date = Date()) -> TripStop? {
        stops.last { stop in
            guard let date = stop.date else { return false }
            return date <= now
        }
    }

    /// Day id to open the itinerary on: today when the trip is running, otherwise
    /// the first day (before departure) or the last (after the return).
    func focusDayID(now: Date = Date()) -> String? {
        if let current = currentStop(now: now), let next = nextStop(now: now) {
            // Between two entries, the upcoming one is the more useful anchor.
            return next.dayID == current.dayID ? current.dayID : next.dayID
        }
        return nextStop(now: now)?.dayID ?? stops.last?.dayID
    }

    /// Time zone in force at `now`, taken from the entry the trip is currently on.
    func activeTimeZone(now: Date = Date()) -> TimeZone? {
        currentStop(now: now)?.timeZone ?? stops.first?.timeZone
    }

    // MARK: - Onde estamos, pelo GPS

    /// Radius that counts as "at this place". Airports and estates are large, so
    /// this is deliberately generous — it answers "which stage", not "which door".
    static let arrivalRadius: CLLocationDistance = 3_000

    /// Nearest entry to a position, and how far away it is.
    func nearestStop(to location: CLLocation) -> (stop: TripStop, distance: CLLocationDistance)? {
        var best: (TripStop, CLLocationDistance)?
        for stop in stops {
            guard let coord = stop.coordinate else { continue }
            let d = location.distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
            if best == nil || d < best!.1 { best = (stop, d) }
        }
        return best.map { (stop: $0.0, distance: $0.1) }
    }

    /// The stage the traveller is physically at, if they are close enough to one.
    func stopAtCurrentLocation(_ location: CLLocation) -> TripStop? {
        guard let (stop, distance) = nearestStop(to: location),
            distance <= Self.arrivalRadius
        else { return nil }
        return stop
    }
}
