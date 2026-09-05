import SwiftUI
import WidgetKit

// MARK: - Trip Widget
// Shows the next itinerary event published by WidgetDataManager.updateTrip(...).
// Shares the SharedTimelineProvider / WidgetSharedData defined in MeuLabWidgets.swift.

// MARK: - View Model

struct TripNextEvent {
    let title: String
    let time: String
    let icon: String
    let date: Date?

    /// Just the clock part of "12 set · 17:30" — used where space is tight.
    var shortClock: String {
        if let separatorRange = time.range(of: "·") {
            let tail = time[separatorRange.upperBound...].trimmingCharacters(in: .whitespaces)
            if !tail.isEmpty { return tail }
        }
        return time
    }

    /// Day part of "12 set · 17:30", or the whole string when there is no separator.
    var shortDay: String {
        if let separatorRange = time.range(of: "·") {
            let head = time[..<separatorRange.lowerBound].trimmingCharacters(in: .whitespaces)
            if !head.isEmpty { return head }
        }
        return ""
    }

    static func from(_ data: WidgetSharedData) -> TripNextEvent? {
        let title = data.tripNextTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }
        return TripNextEvent(
            title: title,
            time: data.tripNextTime?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "--:--",
            icon: data.tripNextIcon?.isEmpty == false ? data.tripNextIcon! : "airplane",
            date: data.tripNextDate
        )
    }
}

// MARK: - System Families

#if !os(watchOS)
private struct TripSystemSmallView: View {
    let event: TripNextEvent?

    var body: some View {
        WidgetSurface(tint: WidgetGradients.cyan) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    WidgetHeaderChip(icon: "suitcase.rolling.fill", title: "Viagem", tint: WidgetGradients.cyan)
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                if let event {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(WidgetGradients.cyan.opacity(0.18))
                                .frame(width: 28, height: 28)
                            Image(systemName: event.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(WidgetGradients.cyan)
                        }
                        Text(event.shortClock)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }

                    Text(event.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    if !event.shortDay.isEmpty {
                        Text(event.shortDay)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                } else {
                    TripEmptyStateView(compact: true)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct TripSystemMediumView: View {
    let event: TripNextEvent?

    var body: some View {
        WidgetSurface(tint: WidgetGradients.cyan) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    WidgetHeaderChip(icon: "suitcase.rolling.fill", title: "Próximo na viagem", tint: WidgetGradients.cyan)
                    Spacer()
                    if let event, let date = event.date, date > Date() {
                        Text(date, style: .relative)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                if let event {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(WidgetGradients.cyan.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(WidgetGradients.cyan.opacity(0.24), lineWidth: 1)
                                )
                            Image(systemName: event.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(WidgetGradients.cyan)
                        }
                        .frame(width: 52, height: 52)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.time)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(event.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.82))
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)
                    }
                } else {
                    TripEmptyStateView(compact: false)
                }

                Spacer(minLength: 0)
            }
        }
    }
}
#endif

// MARK: - Empty State

private struct TripEmptyStateView: View {
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: compact ? 16 : 22, weight: .semibold))
                    .foregroundStyle(WidgetGradients.green)
                Text("Viagem concluída")
                    .font(.system(size: compact ? 13 : 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text("Sem eventos no roteiro")
                .font(.system(size: compact ? 10 : 12))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Accessory Families (Lock Screen / Smart Stack)

private struct TripAccessoryRectangularView: View {
    let event: TripNextEvent?

    var body: some View {
        if let event {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: event.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(event.time)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .widgetAccentable()

                Text(event.title)
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
                    Text("Viagem")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .widgetAccentable()
                Text("Viagem concluída")
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TripAccessoryCircularView: View {
    let event: TripNextEvent?

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: event?.icon ?? "checkmark.seal")
                    .font(.system(size: 12, weight: .semibold))
                Text(event?.shortClock ?? "--:--")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .padding(2)
        }
    }
}

private struct TripAccessoryInlineView: View {
    let event: TripNextEvent?

    var body: some View {
        if let event {
            Label("\(event.shortClock) \(event.title)", systemImage: event.icon)
        } else {
            Label("Viagem concluída", systemImage: "checkmark.seal")
        }
    }
}

// MARK: - Entry View

struct ViagemWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MeuLabEntry

    private var event: TripNextEvent? { TripNextEvent.from(entry.data) }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            TripAccessoryRectangularView(event: event)
                .containerBackground(.clear, for: .widget)
        case .accessoryCircular:
            TripAccessoryCircularView(event: event)
                .containerBackground(.clear, for: .widget)
        case .accessoryInline:
            TripAccessoryInlineView(event: event)
                .containerBackground(.clear, for: .widget)
        #if !os(watchOS)
        case .systemMedium, .systemLarge:
            WidgetCanvas { TripSystemMediumView(event: event) }
                .containerBackground(for: .widget) { WidgetGradients.background }
        default:
            WidgetCanvas { TripSystemSmallView(event: event) }
                .containerBackground(for: .widget) { WidgetGradients.background }
        #else
        default:
            TripAccessoryRectangularView(event: event)
                .containerBackground(.clear, for: .widget)
        #endif
        }
    }
}

// MARK: - Widget Definition

struct ViagemWidget: Widget {
    let kind: String = "MeuLabViagemWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            ViagemWidgetView(entry: entry)
        }
        .configurationDisplayName("Viagem")
        .description("Próximo evento do roteiro da viagem.")
        #if os(watchOS)
        .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline])
        #else
        .supportedFamilies([
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
            .systemSmall,
            .systemMedium,
        ])
        #endif
    }
}

// MARK: - Previews

#if !os(watchOS)
private var tripPreviewData: WidgetSharedData {
    var data = WidgetSharedData.placeholder
    data.tripNextTitle = "Check-in Hotel Alfama"
    data.tripNextTime = "12 set · 17:30"
    data.tripNextIcon = "bed.double.fill"
    data.tripNextDate = Date().addingTimeInterval(5400)
    return data
}

private var tripEmptyPreviewData: WidgetSharedData {
    var data = WidgetSharedData.placeholder
    data.tripNextTitle = nil
    data.tripNextTime = nil
    data.tripNextIcon = nil
    data.tripNextDate = nil
    return data
}

#Preview("Viagem Small", as: .systemSmall) { ViagemWidget() } timeline: {
    MeuLabEntry(date: Date(), data: tripPreviewData)
}
#Preview("Viagem Medium", as: .systemMedium) { ViagemWidget() } timeline: {
    MeuLabEntry(date: Date(), data: tripPreviewData)
}
#Preview("Viagem Rectangular", as: .accessoryRectangular) { ViagemWidget() } timeline: {
    MeuLabEntry(date: Date(), data: tripPreviewData)
}
#Preview("Viagem Circular", as: .accessoryCircular) { ViagemWidget() } timeline: {
    MeuLabEntry(date: Date(), data: tripPreviewData)
}
#Preview("Viagem Vazio", as: .systemSmall) { ViagemWidget() } timeline: {
    MeuLabEntry(date: Date(), data: tripEmptyPreviewData)
}
#endif
