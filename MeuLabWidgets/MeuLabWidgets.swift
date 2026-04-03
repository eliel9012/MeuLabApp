import WidgetKit
import SwiftUI

// MARK: - Shared Data Model
// Note: This struct must match the one in WidgetDataManager.swift
struct WidgetSharedData: Codable {
    // System
    var cpuUsage: Double?
    var memoryUsage: Double?
    var diskUsage: Double?
    
    // ADS-B
    var adsbTotal: Int?
    var adsbWithPos: Int?
    
    // Radio
    var radioFrequency: String?
    var radioDescription: String?
    var radioSignal: Int? // 0-100
    
    // ACARS
    var acarsLastMessage: String?
    var acarsTotalMessages: Int?
    var acarsLastTime: String?
    
    // Satellite
    var satName: String?
    var satNextPass: String? // "14:30"
    var satElevation: String? // "45°"
    
    var lastUpdate: Date
    
    static var placeholder: WidgetSharedData {
        WidgetSharedData(
            cpuUsage: 45.0,
            memoryUsage: 62.0,
            diskUsage: 55.0,
            adsbTotal: 12,
            adsbWithPos: 8,
            radioFrequency: "125.850",
            radioDescription: "TWR SBGR",
            radioSignal: 85,
            acarsLastMessage: "ACARS Message Received",
            acarsTotalMessages: 154,
            acarsLastTime: "10:45",
            satName: "Meteor M2",
            satNextPass: "14:30",
            satElevation: "85°",
            lastUpdate: Date()
        )
    }
}

// MARK: - Widget Entry
struct MeuLabEntry: TimelineEntry {
    let date: Date
    let data: WidgetSharedData
}

// MARK: - Shared Timeline Provider
struct SharedTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MeuLabEntry {
        MeuLabEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (MeuLabEntry) -> Void) {
        completion(MeuLabEntry(date: Date(), data: .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeuLabEntry>) -> Void) {
        let appGroup = "group.com.meulab"
        let dataKey = "widget_shared_data"
        
        var data = WidgetSharedData.placeholder
        
        if let defaults = UserDefaults(suiteName: appGroup),
           let rawData = defaults.data(forKey: dataKey),
           let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: rawData) {
            data = decoded
        }
        
        let entry = MeuLabEntry(date: Date(), data: data)
        let timeline = Timeline(entries: [entry], policy: .never) // Wait for app to reload
        completion(timeline)
    }
}

// MARK: - Premium Color Gradients
struct WidgetGradients {
    static let blue = Color(hex: "2361D6")
    static let cyan = Color(hex: "2CB7DB")
    static let green = Color(hex: "45C75E")
    static let orange = Color(hex: "F29327")
    static let violet = Color(hex: "8558E7")
    static let red = Color(hex: "D33A52")

    static let cpu = LinearGradient(colors: [blue, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let memory = LinearGradient(colors: [violet, Color(hex: "C14DEB")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let disk = LinearGradient(colors: [orange, Color(hex: "FFBC52")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let adsb = LinearGradient(colors: [green, Color(hex: "7BE38C")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let radio = LinearGradient(colors: [red, Color(hex: "F15A78")], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let acars = LinearGradient(colors: [violet, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let satellite = LinearGradient(colors: [violet, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let background = LinearGradient(
        colors: [Color(hex: "0D1428"), Color(hex: "101A32"), Color(hex: "0A1020")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardFill = LinearGradient(
        colors: [Color.white.opacity(0.13), Color.white.opacity(0.05)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cardStroke = LinearGradient(
        colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct WidgetSurface<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: Content

    init(tint: Color, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(WidgetGradients.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.12), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(tint.opacity(0.20), lineWidth: 1)
                    )
            )
    }
}

struct WidgetCanvas<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            WidgetGradients.background

            Circle()
                .fill(WidgetGradients.blue.opacity(0.16))
                .frame(width: 160, height: 160)
                .blur(radius: 32)
                .offset(x: -65, y: -70)

            Circle()
                .fill(WidgetGradients.green.opacity(0.12))
                .frame(width: 140, height: 140)
                .blur(radius: 28)
                .offset(x: 85, y: -30)

            Circle()
                .fill(WidgetGradients.violet.opacity(0.12))
                .frame(width: 150, height: 150)
                .blur(radius: 30)
                .offset(x: 70, y: 90)

            content
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - Reusable Components
struct CircularGaugeView: View {
    let value: Double
    let gradient: LinearGradient
    let icon: String
    let label: String
    let size: CGFloat
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: size * 0.08)
                Circle()
                    .trim(from: 0, to: min(max(CGFloat(value) / 100.0, 0), 1))
                    .stroke(gradient, style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)
                VStack(spacing: 2) {
                    Text("\(Int(value))").font(.system(size: size * 0.28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("%").font(.system(size: size * 0.14)).foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: size, height: size)
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9))
                Text(label).font(.system(size: 10, weight: .medium))
            }.foregroundStyle(.white.opacity(0.8))
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }
}

struct WidgetHeaderChip: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.2))
                    .frame(width: 20, height: 20)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
        }
    }
}

struct WidgetKeyValuePill: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))
            }
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().stroke(tint.opacity(0.16), lineWidth: 1))
    }
}

struct AircraftStatsView: View {
    let total: Int
    let pos: Int
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(total)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Aeronaves")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
            
            ContainerRelativeShape()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1)
                
            VStack(alignment: .leading, spacing: 2) {
                Text("\(pos)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color(hex: "10B981"))
                Text("No Mapa")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - 1. System Widget
struct SystemWidgetView: View {
    let entry: MeuLabEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        WidgetCanvas {
            switch family {
            #if !os(watchOS)
            case .systemSmall:
                WidgetSurface(tint: WidgetGradients.blue) {
                    VStack(spacing: 8) {
                        HStack {
                            WidgetHeaderChip(icon: "cpu.fill", title: "Sistema", tint: WidgetGradients.blue)
                            Spacer()
                        }
                        Spacer(minLength: 0)
                        CircularGaugeView(value: entry.data.cpuUsage ?? 0, gradient: WidgetGradients.cpu, icon: "cpu", label: "CPU", size: 60)
                        Spacer(minLength: 0)
                    }
                }
            case .systemMedium:
                WidgetSurface(tint: WidgetGradients.blue) {
                    VStack(spacing: 12) {
                        HStack {
                            WidgetHeaderChip(icon: "cpu.fill", title: "Sistema", tint: WidgetGradients.blue)
                            Spacer()
                            WidgetKeyValuePill(icon: "bolt.horizontal", title: "CPU", value: "\(Int(entry.data.cpuUsage ?? 0))%", tint: WidgetGradients.blue)
                        }

                        HStack(spacing: 15) {
                            CircularGaugeView(value: entry.data.cpuUsage ?? 0, gradient: WidgetGradients.cpu, icon: "cpu", label: "CPU", size: 65)
                            CircularGaugeView(value: entry.data.memoryUsage ?? 0, gradient: WidgetGradients.memory, icon: "memorychip", label: "RAM", size: 65)
                            CircularGaugeView(value: entry.data.diskUsage ?? 0, gradient: WidgetGradients.disk, icon: "externaldrive", label: "Disco", size: 65)
                        }
                    }
                }
            case .systemLarge:
                WidgetSurface(tint: WidgetGradients.blue) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            WidgetHeaderChip(icon: "cpu.fill", title: "Sistema", tint: WidgetGradients.blue)
                            Spacer()
                            WidgetKeyValuePill(icon: "timer", title: "Carga", value: "\(Int(entry.data.cpuUsage ?? 0))%", tint: WidgetGradients.blue)
                        }

                        HStack(spacing: 16) {
                            CircularGaugeView(value: entry.data.cpuUsage ?? 0, gradient: WidgetGradients.cpu, icon: "cpu", label: "CPU", size: 72)
                            CircularGaugeView(value: entry.data.memoryUsage ?? 0, gradient: WidgetGradients.memory, icon: "memorychip", label: "RAM", size: 72)
                            CircularGaugeView(value: entry.data.diskUsage ?? 0, gradient: WidgetGradients.disk, icon: "externaldrive", label: "Disco", size: 72)
                        }

                        VStack(spacing: 10) {
                            StatRow(title: "CPU", value: "\(Int(entry.data.cpuUsage ?? 0))%", icon: "cpu", color: WidgetGradients.blue)
                            StatRow(title: "Memória", value: "\(Int(entry.data.memoryUsage ?? 0))%", icon: "memorychip", color: WidgetGradients.violet)
                            StatRow(title: "Disco", value: "\(Int(entry.data.diskUsage ?? 0))%", icon: "externaldrive", color: WidgetGradients.orange)
                        }
                    }
                }
            #else
            case .accessoryCircular:
                CircularGaugeView(value: entry.data.cpuUsage ?? 0, gradient: WidgetGradients.cpu, icon: "cpu", label: "CPU", size: 45)
            case .accessoryRectangular:
                HStack {
                    CircularGaugeView(value: entry.data.cpuUsage ?? 0, gradient: WidgetGradients.cpu, icon: "cpu", label: "CPU", size: 30)
                    VStack(alignment: .leading) {
                        Text("RAM: \(Int(entry.data.memoryUsage ?? 0))%")
                        Text("Disk: \(Int(entry.data.diskUsage ?? 0))%")
                    }.font(.system(size: 10))
                }
            #endif
            default:
                Text("Status")
            }
        }
        .containerBackground(for: .widget) { WidgetGradients.background }
    }
}

struct SystemWidget: Widget {
    let kind: String = "MeuLabStartWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            SystemWidgetView(entry: entry)
        }
        .configurationDisplayName("Status do Sistema")
        .description("Monitoramento de CPU, RAM e Disco.")
        #if os(watchOS)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
        #else
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        #endif
    }
}

// MARK: - 2. Radio Widget
struct RadioWidgetView: View {
    let entry: MeuLabEntry
    
    var body: some View {
        WidgetCanvas {
            WidgetSurface(tint: WidgetGradients.red) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        WidgetHeaderChip(icon: "dot.radiowaves.left.and.right", title: "Rádio", tint: WidgetGradients.red)
                        Spacer()
                        if let signal = entry.data.radioSignal {
                            HStack(spacing: 2) {
                                ForEach(0..<4) { i in
                                    RoundedRectangle(cornerRadius: 1.5)
                                        .fill(signal > (i * 25) ? WidgetGradients.green : Color.white.opacity(0.2))
                                        .frame(width: 3, height: 6 + CGFloat(i * 3))
                                }
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.data.radioFrequency ?? "---.---")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(entry.data.radioDescription ?? "Desconectado")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    Spacer()

                    ViewThatFits {
                        HStack {
                            WidgetKeyValuePill(icon: "airplane", title: "Radar", value: "\(entry.data.adsbTotal ?? 0)", tint: WidgetGradients.blue)
                            WidgetKeyValuePill(icon: "location", title: "Posição", value: "\(entry.data.adsbWithPos ?? 0)", tint: WidgetGradients.green)
                        }
                        AircraftStatsView(total: entry.data.adsbTotal ?? 0, pos: entry.data.adsbWithPos ?? 0)
                    }
                }
            }
        }
        .containerBackground(for: .widget) { WidgetGradients.background }
    }
}

struct RadioWidget: Widget {
    let kind: String = "MeuLabRadioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            RadioWidgetView(entry: entry)
        }
        .configurationDisplayName("Rádio + ADS-B")
        .description("Frequência atual e tráfego aéreo.")
        #if os(watchOS)
        .supportedFamilies([.accessoryRectangular, .accessoryCorner])
        #else
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        #endif
    }
}

// MARK: - 3. ACARS Widget
struct AcarsWidgetView: View {
    let entry: MeuLabEntry
    
    var body: some View {
        WidgetCanvas {
            WidgetSurface(tint: WidgetGradients.violet) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        WidgetHeaderChip(icon: "envelope.badge.fill", title: "ACARS", tint: WidgetGradients.violet)
                        Spacer()
                        Text(entry.data.acarsLastTime ?? "--:--")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Divider().background(Color.white.opacity(0.08))

                    if let msg = entry.data.acarsLastMessage {
                        Text(msg)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.black.opacity(0.22))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(WidgetGradients.violet.opacity(0.16), lineWidth: 1)
                                    )
                            )
                    } else {
                        Text("Nenhuma mensagem")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(entry.data.acarsTotalMessages ?? 0)")
                                .font(.headline)
                                .bold()
                                .foregroundStyle(.white)
                            Text("Msgs hoje")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                        WidgetKeyValuePill(icon: "airplane", title: "Radar", value: "\(entry.data.adsbTotal ?? 0)", tint: WidgetGradients.blue)
                    }
                }
            }
        }
        .containerBackground(for: .widget) { WidgetGradients.background }
    }
}

struct AcarsWidget: Widget {
    let kind: String = "MeuLabAcarsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            AcarsWidgetView(entry: entry)
        }
        .configurationDisplayName("ACARS + ADS-B")
        .description("Últimas mensagens e tráfego.")
        #if os(watchOS)
        .supportedFamilies([.accessoryRectangular])
        #else
        .supportedFamilies([.systemMedium, .systemLarge])
        #endif
    }
}

// MARK: - 4. Satellite Widget
struct SatelliteWidgetView: View {
    let entry: MeuLabEntry
    
    var body: some View {
        WidgetCanvas {
            WidgetSurface(tint: WidgetGradients.violet) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        WidgetHeaderChip(icon: "satellite.fill", title: "Satélite", tint: WidgetGradients.violet)
                        Spacer()
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(WidgetGradients.violet.opacity(0.10))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(WidgetGradients.violet.opacity(0.22), lineWidth: 1))

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.data.satName ?? "Sem previsão").font(.subheadline).bold().foregroundStyle(.white)
                                Text("Próxima passagem").font(.caption2).foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(entry.data.satNextPass ?? "--:--").font(.title3).bold().foregroundStyle(Color(hex: "C084FC"))
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.up.forward").font(.caption2)
                                    Text(entry.data.satElevation ?? "0°").font(.caption2)
                                }.foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding(10)
                    }
                    .frame(height: 60)

                    Spacer()

                    ViewThatFits {
                        HStack {
                            WidgetKeyValuePill(icon: "clock", title: "Passagem", value: entry.data.satNextPass ?? "--:--", tint: WidgetGradients.violet)
                            WidgetKeyValuePill(icon: "arrow.up.forward", title: "Elevação", value: entry.data.satElevation ?? "--", tint: WidgetGradients.cyan)
                        }
                        AircraftStatsView(total: entry.data.adsbTotal ?? 0, pos: entry.data.adsbWithPos ?? 0)
                    }
                }
            }
        }
        .containerBackground(for: .widget) { WidgetGradients.background }
    }
}

struct SatelliteWidget: Widget {
    let kind: String = "MeuLabSatelliteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SharedTimelineProvider()) { entry in
            SatelliteWidgetView(entry: entry)
        }
        .configurationDisplayName("Satélites + ADS-B")
        .description("Previsão de passagem e tráfego.")
        #if os(watchOS)
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
        #else
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        #endif
    }
}


// MARK: - Widget Bundle
@main
struct MeuLabWidgetBundle: WidgetBundle {
    var body: some Widget {
        SystemWidget()
        RadioWidget()
        AcarsWidget()
        SatelliteWidget()
    }
}

// MARK: - Previews
#if !os(watchOS)
#Preview("System Small", as: .systemSmall) { SystemWidget() } timeline: { MeuLabEntry(date: Date(), data: .placeholder) }
#Preview("Radio Medium", as: .systemMedium) { RadioWidget() } timeline: { MeuLabEntry(date: Date(), data: .placeholder) }
#Preview("ACARS Medium", as: .systemMedium) { AcarsWidget() } timeline: { MeuLabEntry(date: Date(), data: .placeholder) }
#Preview("Satellite Small", as: .systemSmall) { SatelliteWidget() } timeline: { MeuLabEntry(date: Date(), data: .placeholder) }
#endif
