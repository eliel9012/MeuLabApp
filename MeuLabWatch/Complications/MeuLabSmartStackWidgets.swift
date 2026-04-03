import SwiftUI
import WidgetKit

// MARK: - Smart Stack Palette

private enum SSPalette {
    static let blue = Color(red: 0.14, green: 0.38, blue: 0.84)
    static let green = Color(red: 0.17, green: 0.78, blue: 0.37)
    static let teal = Color(red: 0.17, green: 0.72, blue: 0.86)
    static let violet = Color(red: 0.52, green: 0.34, blue: 0.88)
    static let orange = Color(red: 0.95, green: 0.57, blue: 0.15)
    static let red = Color(red: 0.82, green: 0.23, blue: 0.32)
}

// ─────────────────────────────────────────────────────────────
// MARK: - 1. Radar Aéreo (ADS-B)
// ─────────────────────────────────────────────────────────────

struct SSADSBEntry: TimelineEntry {
    let date: Date
    let totalNow: Int
    let withPos: Int
    let above10k: Int
    let relevance: TimelineEntryRelevance?
}

struct SSADSBProvider: TimelineProvider {
    func placeholder(in context: Context) -> SSADSBEntry {
        SSADSBEntry(date: .now, totalNow: 12, withPos: 8, above10k: 5, relevance: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SSADSBEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SSADSBEntry>) -> Void) {
        Task {
            var total = 0
            var pos = 0
            var high = 0
            if let data = try? await WatchAPIService.shared.fetchADSBSummary() {
                total = data.totalNow
                pos = data.withPos
                high = data.above10000 ?? 0
            }
            let score = Float(min(total, 30)) / 30.0
            let entry = SSADSBEntry(
                date: .now, totalNow: total, withPos: pos, above10k: high,
                relevance: TimelineEntryRelevance(score: score, duration: 300)
            )
            let next = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct SSADSBRectView: View {
    let entry: SSADSBEntry
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Label("ADS-B", systemImage: "airplane")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SSPalette.blue)
                Text("\(entry.totalNow)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("aeronaves")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(SSPalette.green)
                    Text("\(entry.withPos) c/ posição")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9))
                        .foregroundStyle(SSPalette.teal)
                    Text("\(entry.above10k) acima 10k ft")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SSADSBCircView: View {
    let entry: SSADSBEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "airplane")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SSPalette.blue)
                Text("\(entry.totalNow)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
        }
    }
}

struct MeuLabADSBSmartWidget: Widget {
    let kind = "MeuLabADSBSmartWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SSADSBProvider()) { entry in
            Group {
                switch (WidgetFamily.accessoryRectangular, WidgetFamily.accessoryCircular) {
                default: SSADSBEntryView(entry: entry)
                }
            }
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Radar Aéreo")
        .description("Aeronaves detectadas em tempo real.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

struct SSADSBEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SSADSBEntry
    var body: some View {
        switch family {
        case .accessoryCircular: SSADSBCircView(entry: entry)
        default: SSADSBRectView(entry: entry)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - 2. Sistema
// ─────────────────────────────────────────────────────────────

struct SSSystemEntry: TimelineEntry {
    let date: Date
    let cpuPercent: Double
    let memPercent: Double
    let cpuTempC: Double?
    let uptimeStr: String?
    let relevance: TimelineEntryRelevance?
}

struct SSSystemProvider: TimelineProvider {
    func placeholder(in context: Context) -> SSSystemEntry {
        SSSystemEntry(
            date: .now, cpuPercent: 42, memPercent: 61, cpuTempC: 52, uptimeStr: "3d 4h",
            relevance: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SSSystemEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SSSystemEntry>) -> Void) {
        Task {
            var cpu = 0.0
            var mem = 0.0
            var temp: Double? = nil
            var up: String? = nil
            if let data = try? await WatchAPIService.shared.fetchSystemStatus() {
                cpu = data.cpuPercent
                mem = data.memoryPercent
                temp = data.cpuTemp
                up = data.uptimeFormatted
            }
            // High relevance when CPU is overloaded
            let score = cpu > 80 ? Float(1.0) : Float(cpu / 100.0 * 0.7)
            let entry = SSSystemEntry(
                date: .now, cpuPercent: cpu, memPercent: mem, cpuTempC: temp, uptimeStr: up,
                relevance: TimelineEntryRelevance(score: score, duration: 600)
            )
            let next = Calendar.current.date(byAdding: .minute, value: 10, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct SSSystemRectView: View {
    let entry: SSSystemEntry
    private var cpuColor: Color { entry.cpuPercent > 80 ? SSPalette.red : SSPalette.blue }
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Label("Sistema", systemImage: "cpu")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SSPalette.blue)
                Text("\(Int(entry.cpuPercent))%")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(cpuColor)
                Text("CPU")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 9))
                        .foregroundStyle(SSPalette.violet)
                    Text("RAM \(Int(entry.memPercent))%")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.primary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 9))
                        .foregroundStyle(SSPalette.orange)
                    if let t = entry.cpuTempC {
                        Text(String(format: "%.0f°C", t))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else if let up = entry.uptimeStr {
                        Text("up \(up)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("--")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SSSystemCircView: View {
    let entry: SSSystemEntry
    private var cpuColor: Color { entry.cpuPercent > 80 ? SSPalette.red : SSPalette.blue }
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "cpu")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(cpuColor)
                Text("\(Int(entry.cpuPercent))%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(cpuColor)
            }
        }
    }
}

struct MeuLabSystemSmartWidget: Widget {
    let kind = "MeuLabSystemSmartWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SSSystemProvider()) { entry in
            SSSystemEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Sistema")
        .description("CPU, RAM e temperatura do servidor.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

struct SSSystemEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SSSystemEntry
    var body: some View {
        switch family {
        case .accessoryCircular: SSSystemCircView(entry: entry)
        default: SSSystemRectView(entry: entry)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - 3. Clima
// ─────────────────────────────────────────────────────────────

struct SSWeatherEntry: TimelineEntry {
    let date: Date
    let tempC: Int
    let condition: String
    let humidity: Int?
    let windKmh: Int?
    let rainChance: Int?
    let relevance: TimelineEntryRelevance?
}

struct SSWeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> SSWeatherEntry {
        SSWeatherEntry(
            date: .now, tempC: 28, condition: "Ensolarado",
            humidity: 65, windKmh: 12, rainChance: 10, relevance: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SSWeatherEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SSWeatherEntry>) -> Void)
    {
        Task {
            var temp = 0
            var cond = "N/A"
            var hum: Int? = nil
            var wind: Int? = nil
            var rain: Int? = nil
            if let data = try? await WatchAPIService.shared.fetchWeather(), let cur = data.current {
                temp = cur.tempC
                cond = cur.description
                hum = cur.humidity
                wind = cur.windKmh
                rain = data.today?.rainChance
            }
            // Higher relevance when rain is likely
            let rainScore = Float(rain ?? 0) / 100.0
            let score = max(0.3, rainScore)
            let entry = SSWeatherEntry(
                date: .now, tempC: temp, condition: cond,
                humidity: hum, windKmh: wind, rainChance: rain,
                relevance: TimelineEntryRelevance(score: score, duration: 1800)
            )
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

private func weatherIcon(for condition: String) -> String {
    let c = condition.lowercased()
    if c.contains("chov") || c.contains("rain") || c.contains("chuv") { return "cloud.rain.fill" }
    if c.contains("trovoada") || c.contains("thunder") { return "cloud.bolt.fill" }
    if c.contains("nuvem") || c.contains("cloud") || c.contains("nebul") { return "cloud.fill" }
    if c.contains("nublado") || c.contains("overcast") { return "cloud.fill" }
    if c.contains("noite") || c.contains("night") { return "moon.stars.fill" }
    return "sun.max.fill"
}

struct SSWeatherRectView: View {
    let entry: SSWeatherEntry
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Label("Clima", systemImage: weatherIcon(for: entry.condition))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SSPalette.teal)
                Text("\(entry.tempC)°")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(entry.condition)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                if let hum = entry.humidity {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(SSPalette.blue)
                        Text("Umid. \(hum)%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
                if let wind = entry.windKmh {
                    HStack(spacing: 4) {
                        Image(systemName: "wind")
                            .font(.system(size: 9))
                            .foregroundStyle(SSPalette.teal)
                        Text("Vento \(wind) km/h")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                } else if let rain = entry.rainChance {
                    HStack(spacing: 4) {
                        Image(systemName: "umbrella.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(SSPalette.blue)
                        Text("Chuva \(rain)%")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SSWeatherCircView: View {
    let entry: SSWeatherEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: weatherIcon(for: entry.condition))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SSPalette.teal)
                Text("\(entry.tempC)°")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
        }
    }
}

struct MeuLabClimaSmartWidget: Widget {
    let kind = "MeuLabClimaSmartWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SSWeatherProvider()) { entry in
            SSWeatherEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Clima")
        .description("Temperatura, umidade e chuva.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

struct SSWeatherEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SSWeatherEntry
    var body: some View {
        switch family {
        case .accessoryCircular: SSWeatherCircView(entry: entry)
        default: SSWeatherRectView(entry: entry)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - 4. Próxima Passagem (Satélite)
// ─────────────────────────────────────────────────────────────

struct SSSatEntry: TimelineEntry {
    let date: Date
    let satName: String
    let timeUntil: String
    let maxElevation: Double?
    let duration: String?
    let relevance: TimelineEntryRelevance?
}

struct SSSatProvider: TimelineProvider {
    func placeholder(in context: Context) -> SSSatEntry {
        SSSatEntry(
            date: .now, satName: "Meteor M2-x", timeUntil: "em 2h 15m",
            maxElevation: 68, duration: "14m", relevance: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SSSatEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SSSatEntry>) -> Void) {
        Task {
            var name = "--"
            var time = "--"
            var elev: Double? = nil
            var dur: String? = nil
            if let resp = try? await WatchAPIService.shared.fetchMeteorPasses(),
                let next = resp.passes?.first(where: { $0.isUpcoming })
            {
                name = next.satellite ?? "Satélite"
                time = next.timeUntil
                elev = next.maxElevation
                dur = next.durationMinutes
            }
            // High relevance when pass is imminent (< 30 min)
            let score: Float
            if time.contains("m") && !time.contains("h") && !time.contains("d") {
                score = 0.9  // imminent
            } else if time.contains("h") {
                score = 0.5
            } else {
                score = 0.2
            }
            let entry = SSSatEntry(
                date: .now, satName: name, timeUntil: time,
                maxElevation: elev, duration: dur,
                relevance: TimelineEntryRelevance(score: score, duration: 900)
            )
            let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct SSSatRectView: View {
    let entry: SSSatEntry
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Label("Satélite", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SSPalette.violet)
                Text(entry.timeUntil)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
                Text(entry.satName)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                if let el = entry.maxElevation {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                            .foregroundStyle(SSPalette.violet)
                        Text(String(format: "El. %.0f°", el))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
                if let dur = entry.duration {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundStyle(SSPalette.teal)
                        Text("Duração \(dur)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SSSatCircView: View {
    let entry: SSSatEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SSPalette.violet)
                Text(entry.timeUntil.replacingOccurrences(of: "em ", with: ""))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
    }
}

struct MeuLabSatSmartWidget: Widget {
    let kind = "MeuLabSatSmartWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SSSatProvider()) { entry in
            SSSatEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Próxima Passagem")
        .description("Próximo satélite e horário da passagem.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

struct SSSatEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SSSatEntry
    var body: some View {
        switch family {
        case .accessoryCircular: SSSatCircView(entry: entry)
        default: SSSatRectView(entry: entry)
        }
    }
}

// ─────────────────────────────────────────────────────────────
// MARK: - 5. Sensores (Tuya)
// ─────────────────────────────────────────────────────────────

struct SSSensorsEntry: TimelineEntry {
    let date: Date
    let tempC: Double?
    let humidity: Double?
    let battery: Int?
    let relevance: TimelineEntryRelevance?
}

struct SSSensorsProvider: TimelineProvider {
    func placeholder(in context: Context) -> SSSensorsEntry {
        SSSensorsEntry(date: .now, tempC: 24.5, humidity: 58, battery: 85, relevance: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SSSensorsEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SSSensorsEntry>) -> Void)
    {
        Task {
            var temp: Double? = nil
            var hum: Double? = nil
            var bat: Int? = nil
            if let data = try? await WatchAPIService.shared.fetchTuyaSensors(),
                let cur = data.current
            {
                temp = cur.temperatureC
                hum = cur.humidityPct
                bat = cur.batteryPct
            }
            // Higher relevance on extreme temps or low battery
            var score: Float = 0.4
            if let t = temp, t > 30 || t < 15 { score = 0.8 }
            if let b = bat, b < 20 { score = max(score, 0.75) }
            let entry = SSSensorsEntry(
                date: .now, tempC: temp, humidity: hum, battery: bat,
                relevance: TimelineEntryRelevance(score: score, duration: 1200)
            )
            let next = Calendar.current.date(byAdding: .minute, value: 20, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }
}

struct SSSensorsRectView: View {
    let entry: SSSensorsEntry
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Label("Sensores", systemImage: "sensor.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(SSPalette.orange)
                if let t = entry.tempC {
                    Text(String(format: "%.1f°", t))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                } else {
                    Text("--°")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text("Temperatura")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                if let hum = entry.humidity {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(SSPalette.blue)
                        Text(String(format: "Umid. %.0f%%", hum))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
                if let bat = entry.battery {
                    let icon = bat < 20 ? "battery.25" : bat < 50 ? "battery.50" : "battery.100"
                    let col = bat < 20 ? SSPalette.red : SSPalette.green
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                            .font(.system(size: 9))
                            .foregroundStyle(col)
                        Text("Bat. \(bat)%")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SSSensorsCircView: View {
    let entry: SSSensorsEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SSPalette.orange)
                if let t = entry.tempC {
                    Text(String(format: "%.0f°", t))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                } else {
                    Text("--")
                        .font(.system(size: 15, weight: .bold))
                }
            }
        }
    }
}

struct MeuLabSensoresSmartWidget: Widget {
    let kind = "MeuLabSensoresSmartWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SSSensorsProvider()) { entry in
            SSSensorsEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Sensores")
        .description("Temperatura e umidade do ambiente.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

struct SSSensorsEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: SSSensorsEntry
    var body: some View {
        switch family {
        case .accessoryCircular: SSSensorsCircView(entry: entry)
        default: SSSensorsRectView(entry: entry)
        }
    }
}
