import SwiftUI
import WidgetKit

private enum WatchComplicationTheme {
    static let blue = Color(red: 0.14, green: 0.38, blue: 0.84)
    static let green = Color(red: 0.27, green: 0.78, blue: 0.37)
    static let violet = Color(red: 0.52, green: 0.34, blue: 0.88)
    static let orange = Color(red: 0.95, green: 0.57, blue: 0.15)
}

// MARK: - Timeline Provider

struct MeuLabTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeuLabEntry {
        MeuLabEntry(
            date: Date(),
            aircraftCount: 42,
            cpuPercent: 35,
            temperature: 52,
            lastSatellite: "Meteor M2-x",
            weatherTemp: 25,
            weatherCondition: "Ensolarado",
            nextPassIn: "2h 15m",
            sensorTemp: 23.5,
            sensorHumidity: 55
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MeuLabEntry) -> Void) {
        let entry = MeuLabEntry(
            date: Date(),
            aircraftCount: 42,
            cpuPercent: 35,
            temperature: 52,
            lastSatellite: "Meteor M2-x",
            weatherTemp: 25,
            weatherCondition: "Ensolarado",
            nextPassIn: "2h 15m",
            sensorTemp: 23.5,
            sensorHumidity: 55
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeuLabEntry>) -> Void) {
        Task {
            var aircraftCount = 0
            var cpuPercent = 0.0
            var temperature = 0.0
            var lastSatellite = "N/A"
            var weatherTemp: Int?
            var weatherCondition: String?
            var nextPassIn: String?
            var sensorTemp: Double?
            var sensorHumidity: Double?

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

            do {
                let weather = try await WatchAPIService.shared.fetchWeather()
                weatherTemp = weather.current.map { Int($0.temperature) }
                weatherCondition = weather.current?.condition
            } catch {}

            do {
                let meteor = try await WatchAPIService.shared.fetchMeteorPasses()
                if let next = meteor.passes?.first(where: { $0.isUpcoming }) {
                    nextPassIn = next.timeUntil
                }
            } catch {}

            do {
                let tuya = try await WatchAPIService.shared.fetchTuyaSensors()
                sensorTemp = tuya.current?.temperatureC
                sensorHumidity = tuya.current?.humidityPct
            } catch {}

            let entry = MeuLabEntry(
                date: Date(),
                aircraftCount: aircraftCount,
                cpuPercent: Int(cpuPercent),
                temperature: Int(temperature),
                lastSatellite: lastSatellite,
                weatherTemp: weatherTemp,
                weatherCondition: weatherCondition,
                nextPassIn: nextPassIn,
                sensorTemp: sensorTemp,
                sensorHumidity: sensorHumidity
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
    var weatherTemp: Int? = nil
    var weatherCondition: String? = nil
    var nextPassIn: String? = nil
    var sensorTemp: Double? = nil
    var sensorHumidity: Double? = nil
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
                    .foregroundStyle(WatchComplicationTheme.blue)
                Text("\(entry.aircraftCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
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
                        .foregroundStyle(WatchComplicationTheme.blue)
                    Text("\(entry.aircraftCount) voos")
                        .font(.caption2)
                        .foregroundStyle(.white)
                }

                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .font(.caption2)
                        .foregroundStyle(WatchComplicationTheme.green)
                    Text("\(entry.cpuPercent)%  \(entry.temperature)°")
                        .font(.caption2)
                        .foregroundStyle(.white)
                }

                if let wTemp = entry.weatherTemp {
                    HStack(spacing: 4) {
                        Image(systemName: "cloud.sun.fill")
                            .font(.caption2)
                            .foregroundStyle(.cyan)
                        Text("\(wTemp)°C")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "thermometer")
                            .font(.caption2)
                            .foregroundStyle(WatchComplicationTheme.orange)
                        Text("\(entry.temperature)°C")
                            .font(.caption2)
                            .foregroundStyle(.white)
                    }
                }
            }

            Spacer()

            VStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(WatchComplicationTheme.violet)
                Text("MeuLab")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.8))
            }
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
                .foregroundStyle(WatchComplicationTheme.blue)
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
                .foregroundStyle(WatchComplicationTheme.blue)
            Text("\(entry.aircraftCount)")
            Text("|")
            Image(systemName: "cpu")
                .foregroundStyle(WatchComplicationTheme.green)
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
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("MeuLab")
        .description("Monitore seu lab no pulso")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline,
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
    MeuLabEntry(
        date: Date(), aircraftCount: 42, cpuPercent: 35, temperature: 52,
        lastSatellite: "Meteor M2-x")
}

#Preview(as: .accessoryRectangular) {
    MeuLabComplication()
} timeline: {
    MeuLabEntry(
        date: Date(), aircraftCount: 42, cpuPercent: 35, temperature: 52,
        lastSatellite: "Meteor M2-x")
}
