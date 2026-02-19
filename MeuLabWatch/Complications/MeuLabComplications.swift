import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

struct MeuLabTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeuLabEntry {
        MeuLabEntry(
            date: Date(),
            aircraftCount: 42,
            cpuPercent: 35,
            temperature: 52,
            lastSatellite: "Meteor M2-x"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MeuLabEntry) -> Void) {
        let entry = MeuLabEntry(
            date: Date(),
            aircraftCount: 42,
            cpuPercent: 35,
            temperature: 52,
            lastSatellite: "Meteor M2-x"
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeuLabEntry>) -> Void) {
        Task {
            var aircraftCount = 0
            var cpuPercent = 0.0
            var temperature = 0.0
            var lastSatellite = "N/A"

            // Busca dados da API
            do {
                let adsb = try await WatchAPIService.shared.fetchADSBSummary()
                aircraftCount = adsb.totalNow
            } catch {}

            do {
                let system = try await WatchAPIService.shared.fetchSystemStatus()
                cpuPercent = system.cpuPercent
                temperature = system.cpuTemp ?? 0
            } catch {}

            do {
                let satdump = try await WatchAPIService.shared.fetchSatDumpStatus()
                lastSatellite = satdump.status?.lastPass?.satellite ?? "N/A"
            } catch {}

            let entry = MeuLabEntry(
                date: Date(),
                aircraftCount: aircraftCount,
                cpuPercent: Int(cpuPercent),
                temperature: Int(temperature),
                lastSatellite: lastSatellite
            )

            // Atualiza a cada 15 minutos
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// MARK: - Entry

struct MeuLabEntry: TimelineEntry {
    let date: Date
    let aircraftCount: Int
    let cpuPercent: Int
    let temperature: Int
    let lastSatellite: String
}

// MARK: - Circular Complication (ADS-B)

struct MeuLabCircularView: View {
    let entry: MeuLabEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            VStack(spacing: 0) {
                Image(systemName: "airplane")
                    .font(.system(size: 12))
                Text("\(entry.aircraftCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
        }
    }
}

// MARK: - Rectangular Complication

struct MeuLabRectangularView: View {
    let entry: MeuLabEntry

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.caption2)
                    Text("\(entry.aircraftCount) voos")
                        .font(.caption2)
                }

                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.caption2)
                    Text("\(entry.cpuPercent)%")
                        .font(.caption2)
                }

                HStack(spacing: 4) {
                    Image(systemName: "thermometer")
                        .font(.caption2)
                    Text("\(entry.temperature)°C")
                        .font(.caption2)
                }
            }

            Spacer()

            VStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                Text("MeuLab")
                    .font(.system(size: 8))
            }
            .foregroundStyle(.blue)
        }
    }
}

// MARK: - Corner Complication

struct MeuLabCornerView: View {
    let entry: MeuLabEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Text("\(entry.aircraftCount)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
        }
        .widgetLabel {
            Text("voos")
        }
    }
}

// MARK: - Inline Complication

struct MeuLabInlineView: View {
    let entry: MeuLabEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "airplane")
            Text("\(entry.aircraftCount)")
            Text("|")
            Image(systemName: "cpu")
            Text("\(entry.cpuPercent)%")
        }
    }
}

// MARK: - Widget Definition

struct MeuLabComplication: Widget {
    let kind: String = "MeuLabComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeuLabTimelineProvider()) { entry in
            MeuLabComplicationEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("MeuLab")
        .description("Monitore seu lab no pulso")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

// MARK: - Entry View

struct MeuLabComplicationEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: MeuLabEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            MeuLabCircularView(entry: entry)
        case .accessoryRectangular:
            MeuLabRectangularView(entry: entry)
        case .accessoryCorner:
            MeuLabCornerView(entry: entry)
        case .accessoryInline:
            MeuLabInlineView(entry: entry)
        default:
            MeuLabCircularView(entry: entry)
        }
    }
}

// MARK: - Preview

#Preview(as: .accessoryCircular) {
    MeuLabComplication()
} timeline: {
    MeuLabEntry(date: Date(), aircraftCount: 42, cpuPercent: 35, temperature: 52, lastSatellite: "Meteor M2-x")
}

#Preview(as: .accessoryRectangular) {
    MeuLabComplication()
} timeline: {
    MeuLabEntry(date: Date(), aircraftCount: 42, cpuPercent: 35, temperature: 52, lastSatellite: "Meteor M2-x")
}
