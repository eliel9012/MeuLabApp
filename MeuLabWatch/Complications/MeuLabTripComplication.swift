import SwiftUI
import WidgetKit

// MARK: - Trip Complication
// Shows the next itinerary event ("próximo evento da viagem") on the watch face.
//
// The snapshot is read from UserDefaults so the complication has no network
// dependency. The iPhone app publishes the same payload through
// WidgetDataManager.updateTrip(...); on the watch it is written by whatever
// transport delivers it (WatchConnectivity / app refresh) via
// WatchTripStore.save(...). When nothing has been published the complication
// falls back to an elegant empty state instead of stale data.

private enum TripComplicationTheme {
    static let cyan = Color(red: 0.17, green: 0.72, blue: 0.86)
    static let green = Color(red: 0.27, green: 0.78, blue: 0.37)
}

// MARK: - Shared Snapshot

struct WatchTripSnapshot: Codable, Equatable {
    var title: String
    var time: String  // "12 set · 17:30"
    var icon: String  // SF Symbol name
    var date: Date?

    /// Just the clock part of "12 set · 17:30" — used where space is tight.
    var shortClock: String {
        if let separator = time.range(of: "·") {
            let tail = time[separator.upperBound...].trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty { return tail }
        }
        return time
    }
}

enum WatchTripStore {
    private static let appGroup = "group.com.meulab"
    private static let key = "widget_trip_data"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    /// Latest published event, or nil when the trip is over / nothing was sent yet.
    static func load() -> WatchTripSnapshot? {
        guard let raw = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(WatchTripSnapshot.self, from: raw),
            !decoded.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return decoded
    }

    /// Persist the next event and refresh the complication.
    /// Pass nil to clear it (trip finished).
    static func save(_ snapshot: WatchTripSnapshot?) {
        if let snapshot, let encoded = try? JSONEncoder().encode(snapshot) {
            defaults.set(encoded, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "MeuLabTripComplication")
    }

    /// Convenience mirroring WidgetDataManager.updateTrip(title:time:icon:date:).
    static func update(title: String?, time: String?, icon: String?, date: Date?) {
        guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            save(nil)
            return
        }
        save(
            WatchTripSnapshot(
                title: title,
                time: time ?? "--:--",
                icon: icon?.isEmpty == false ? icon! : "airplane",
                date: date
            ))
    }
}

// MARK: - Entry

struct TripComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchTripSnapshot?
}

// MARK: - Provider

struct TripComplicationProvider: TimelineProvider {
    private var sample: WatchTripSnapshot {
        WatchTripSnapshot(
            title: "Check-in Hotel Alfama",
            time: "12 set · 17:30",
            icon: "bed.double.fill",
            date: Date().addingTimeInterval(5400)
        )
    }

    func placeholder(in context: Context) -> TripComplicationEntry {
        TripComplicationEntry(date: .now, snapshot: sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (TripComplicationEntry) -> Void) {
        let snapshot = context.isPreview ? sample : WatchTripStore.load()
        completion(TripComplicationEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TripComplicationEntry>) -> Void) {
        let entry = TripComplicationEntry(date: .now, snapshot: WatchTripStore.load())
        // Refresh when the event is due, otherwise every 15 minutes.
        var nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        if let due = entry.snapshot?.date, due > .now, due < nextUpdate {
            nextUpdate = due
        }
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Views

struct TripComplicationRectangularView: View {
    let snapshot: WatchTripSnapshot?

    var body: some View {
        if let snapshot {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: snapshot.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TripComplicationTheme.cyan)
                    Text(snapshot.time)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .widgetAccentable()

                Text(snapshot.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "suitcase.rolling")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TripComplicationTheme.green)
                    Text("Viagem")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .widgetAccentable()
                Text("Viagem concluída")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct TripComplicationCircularView: View {
    let snapshot: WatchTripSnapshot?

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: snapshot?.icon ?? "checkmark.seal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TripComplicationTheme.cyan)
                Text(snapshot?.shortClock ?? "--:--")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(2)
        }
    }
}

struct TripComplicationCornerView: View {
    let snapshot: WatchTripSnapshot?

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: snapshot?.icon ?? "checkmark.seal")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TripComplicationTheme.cyan)
        }
        .widgetLabel {
            Text(snapshot?.shortClock ?? "sem eventos")
        }
    }
}

struct TripComplicationInlineView: View {
    let snapshot: WatchTripSnapshot?

    var body: some View {
        if let snapshot {
            Label("\(snapshot.shortClock) \(snapshot.title)", systemImage: snapshot.icon)
        } else {
            Label("Viagem concluída", systemImage: "checkmark.seal")
        }
    }
}

// MARK: - Entry View

struct TripComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: TripComplicationEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            TripComplicationRectangularView(snapshot: entry.snapshot)
        case .accessoryCorner:
            TripComplicationCornerView(snapshot: entry.snapshot)
        case .accessoryInline:
            TripComplicationInlineView(snapshot: entry.snapshot)
        default:
            TripComplicationCircularView(snapshot: entry.snapshot)
        }
    }
}

// MARK: - Widget Definition

struct MeuLabTripComplication: Widget {
    let kind: String = "MeuLabTripComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TripComplicationProvider()) { entry in
            TripComplicationEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Viagem")
        .description("Próximo evento do roteiro da viagem")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline,
        ])
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    MeuLabTripComplication()
} timeline: {
    TripComplicationEntry(
        date: .now,
        snapshot: WatchTripSnapshot(
            title: "Check-in Hotel Alfama", time: "12 set · 17:30", icon: "bed.double.fill",
            date: Date().addingTimeInterval(5400)))
    TripComplicationEntry(date: .now, snapshot: nil)
}

#Preview(as: .accessoryCircular) {
    MeuLabTripComplication()
} timeline: {
    TripComplicationEntry(
        date: .now,
        snapshot: WatchTripSnapshot(
            title: "Voo GRU → LIS", time: "12 set · 17:30", icon: "airplane.departure",
            date: Date().addingTimeInterval(5400)))
}
