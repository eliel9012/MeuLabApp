import SwiftUI

enum WatchLabTheme {
    static let blue = Color(red: 0.14, green: 0.38, blue: 0.84)
    static let cyan = Color(red: 0.18, green: 0.70, blue: 0.86)
    static let green = Color(red: 0.27, green: 0.78, blue: 0.37)
    static let orange = Color(red: 0.95, green: 0.57, blue: 0.15)
    static let violet = Color(red: 0.52, green: 0.34, blue: 0.88)
    static let red = Color(red: 0.82, green: 0.21, blue: 0.32)
    static let ink = Color.white
    static let secondary = Color.white.opacity(0.66)
    static let tertiary = Color.white.opacity(0.46)
    static let panel = Color.white.opacity(0.08)
    static let panelStrong = Color.white.opacity(0.12)
    static let stroke = Color.white.opacity(0.10)
    static let canvasTop = Color(red: 0.05, green: 0.08, blue: 0.16)
    static let canvasBottom = Color(red: 0.02, green: 0.04, blue: 0.10)
}

struct WatchLabBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WatchLabTheme.canvasTop, WatchLabTheme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(WatchLabTheme.blue.opacity(0.22))
                .frame(width: 170)
                .blur(radius: 26)
                .offset(x: -55, y: -92)

            Circle()
                .fill(WatchLabTheme.green.opacity(0.16))
                .frame(width: 130)
                .blur(radius: 24)
                .offset(x: 62, y: -18)

            Circle()
                .fill(WatchLabTheme.violet.opacity(0.16))
                .frame(width: 110)
                .blur(radius: 22)
                .offset(x: 50, y: 118)
        }
        .ignoresSafeArea()
    }
}

struct WatchLabScreen<Content: View>: View {
    let title: String
    let icon: String
    let tint: Color
    @ViewBuilder let content: Content

    init(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                WatchLabTitle(title: title, icon: icon, tint: tint)
                content
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 18)
        }
        .background(WatchLabBackground())
    }
}

struct WatchLabTitle: View {
    let title: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tint)
                }

            Text(title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(WatchLabTheme.ink)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }
}

struct WatchLabPanel<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: Content

    init(tint: Color, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WatchLabTheme.panel)
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
                        .strokeBorder(tint.opacity(0.22), lineWidth: 1)
                )
        )
    }
}

struct WatchLabMetricPill: View {
    let title: String
    let value: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(WatchLabTheme.tertiary)

            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)

                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchLabTheme.ink)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(tint.opacity(0.13)))
        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 1))
    }
}

struct WatchLabMiniMetricCard: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: 30, height: 30)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tint)
                }

            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .foregroundStyle(WatchLabTheme.ink)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WatchLabTheme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WatchLabTheme.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct WatchLabStatRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint.opacity(0.15))
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tint)
                }

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WatchLabTheme.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(WatchLabTheme.ink)
        }
    }
}

struct WatchLabStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WatchLabTheme.ink)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(WatchLabTheme.secondary)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.caption2.weight(.semibold))
                    .tint(tint)
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

struct WatchLabMenuLink<Destination: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let destination: Destination

    init(
        title: String, subtitle: String, icon: String, tint: Color,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 26, height: 26)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(tint)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(WatchLabTheme.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(WatchLabTheme.tertiary)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(WatchLabTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(tint.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// ContentView principal do Apple Watch — grid de botões com NavigationStack
struct EnhancedWatchContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    // Dashboard resumo no topo
                    NavigationLink {
                        WatchDashboardView()
                    } label: {
                        WatchHomeCard()
                    }
                    .buttonStyle(.plain)

                    // Grid 2×2 principal
                    let columns = [
                        GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8),
                    ]

                    LazyVGrid(columns: columns, spacing: 8) {
                        WatchGridButton(title: "ADS-B", icon: "airplane", tint: WatchLabTheme.blue)
                        {
                            WatchADSBView()
                        }
                        WatchGridButton(title: "Sistema", icon: "cpu", tint: WatchLabTheme.green) {
                            WatchSystemView()
                        }
                        WatchGridButton(
                            title: "Bíblia", icon: "book.fill", tint: WatchLabTheme.orange
                        ) {
                            WatchBibleView()
                        }
                        WatchGridButton(
                            title: "Clima", icon: "cloud.sun.fill", tint: WatchLabTheme.cyan
                        ) {
                            WatchWeatherView()
                        }
                        WatchGridButton(
                            title: "ACARS", icon: "envelope.badge.fill", tint: WatchLabTheme.orange
                        ) {
                            WatchACARSView()
                        }
                        WatchGridButton(
                            title: "Satélite", icon: "antenna.radiowaves.left.and.right",
                            tint: WatchLabTheme.violet
                        ) {
                            WatchSatDumpView()
                        }
                        WatchGridButton(
                            title: "Rádio", icon: "dot.radiowaves.left.and.right",
                            tint: WatchLabTheme.red
                        ) {
                            WatchRadioView()
                        }
                        WatchGridButton(
                            title: "Infra", icon: "server.rack", tint: WatchLabTheme.orange
                        ) {
                            WatchInfraView()
                        }
                        WatchGridButton(
                            title: "Alertas", icon: "bell.badge.fill", tint: WatchLabTheme.red
                        ) {
                            AlertsView()
                        }
                        WatchGridButton(
                            title: "Analytics", icon: "chart.bar.fill", tint: WatchLabTheme.cyan
                        ) {
                            WatchAnalyticsView()
                        }
                        WatchGridButton(
                            title: "Sensores", icon: "sensor.fill", tint: WatchLabTheme.green
                        ) {
                            WatchTuyaView()
                        }
                        WatchGridButton(
                            title: "Controle", icon: "terminal", tint: WatchLabTheme.violet
                        ) {
                            WatchRemoteControlView()
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 16)
            }
            .background(WatchLabBackground())
            .navigationTitle("MeuLab")
        }
    }
}

// MARK: - Home Card (mini dashboard no topo)

struct WatchHomeCard: View {
    @State private var adsb: WatchADSBData?
    @State private var system: WatchSystemData?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Painel")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchLabTheme.ink)

                HStack(spacing: 6) {
                    Label("\(adsb?.totalNow ?? 0)", systemImage: "airplane")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WatchLabTheme.blue)

                    Label(
                        system.map { "\(Int($0.cpuPercent))%" } ?? "--",
                        systemImage: "cpu"
                    )
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WatchLabTheme.green)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(WatchLabTheme.tertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WatchLabTheme.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(WatchLabTheme.blue.opacity(0.2), lineWidth: 1)
                )
        )
        .task {
            adsb = try? await WatchAPIService.shared.fetchADSBSummary()
            system = try? await WatchAPIService.shared.fetchSystemStatus()
        }
    }
}

// MARK: - Grid Button

struct WatchGridButton<Destination: View>: View {
    let title: String
    let icon: String
    let tint: Color
    let destination: Destination

    init(title: String, icon: String, tint: Color, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.icon = icon
        self.tint = tint
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(tint)
                    }

                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchLabTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(WatchLabTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(tint.opacity(0.15), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct WatchDashboardView: View {
    @State private var isLoading = true
    @State private var adsb: WatchADSBData?
    @State private var system: WatchSystemData?
    @State private var weather: WatchWeatherData?
    @State private var acars: WatchACARSData?
    @State private var lastUpdate = Date()

    var body: some View {
        WatchLabScreen(title: "MeuLab", icon: "sparkles", tint: WatchLabTheme.blue) {
            if isLoading {
                WatchLabPanel(tint: WatchLabTheme.blue) {
                    WatchLabStateView(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Atualizando",
                        subtitle: "Buscando sinais, sistema e clima.",
                        tint: WatchLabTheme.blue,
                        actionTitle: nil,
                        action: nil
                    )
                }
            } else {
                WatchLabPanel(tint: WatchLabTheme.blue) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Painel local")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WatchLabTheme.ink)

                            Text(lastUpdate, style: .time)
                                .font(.caption2)
                                .foregroundStyle(WatchLabTheme.secondary)
                        }

                        Spacer()

                        WatchLabMetricPill(
                            title: "Status",
                            value: system == nil && adsb == nil ? "parcial" : "online",
                            tint: WatchLabTheme.green,
                            icon: "bolt.horizontal"
                        )
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        WatchLabMiniMetricCard(
                            icon: "airplane",
                            value: "\(adsb?.totalNow ?? 0)",
                            label: "Radar",
                            tint: WatchLabTheme.blue
                        )

                        WatchLabMiniMetricCard(
                            icon: "cpu",
                            value: "\(Int(system?.cpuPercent ?? 0))%",
                            label: "CPU",
                            tint: dashboardCPUColor
                        )

                        WatchLabMiniMetricCard(
                            icon: "thermometer",
                            value: system?.cpuTemp.map { "\(Int($0))°" } ?? "--",
                            label: "Temp",
                            tint: dashboardTempColor
                        )

                        WatchLabMiniMetricCard(
                            icon: weatherIcon(weather?.current?.condition ?? ""),
                            value: weather?.current.map { "\(Int($0.temperature))°" } ?? "--",
                            label: "Clima",
                            tint: WatchLabTheme.cyan
                        )
                    }
                }

                WatchLabPanel(tint: WatchLabTheme.green) {
                    Text("Leitura rápida")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    WatchLabStatRow(
                        icon: "memorychip",
                        title: "Memória",
                        value: system.map { "\(Int($0.memoryPercent))%" } ?? "--",
                        tint: WatchLabTheme.violet
                    )

                    WatchLabStatRow(
                        icon: "externaldrive",
                        title: "Disco",
                        value: system.map { "\(Int($0.diskPercent))%" } ?? "--",
                        tint: WatchLabTheme.orange
                    )

                    WatchLabStatRow(
                        icon: "envelope.badge",
                        title: "ACARS",
                        value: acars.map { "\($0.messagesTotal) msgs" } ?? "--",
                        tint: WatchLabTheme.orange
                    )
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        async let adsbTask = WatchAPIService.shared.fetchADSBSummary()
        async let systemTask = WatchAPIService.shared.fetchSystemStatus()
        async let weatherTask = WatchAPIService.shared.fetchWeather()
        async let acarsTask = WatchAPIService.shared.fetchACARSSummary()

        adsb = try? await adsbTask
        system = try? await systemTask
        weather = try? await weatherTask
        acars = try? await acarsTask
        lastUpdate = Date()
        isLoading = false
    }

    private var dashboardCPUColor: Color {
        guard let cpu = system?.cpuPercent else { return WatchLabTheme.green }
        if cpu > 85 { return WatchLabTheme.red }
        if cpu > 65 { return WatchLabTheme.orange }
        return WatchLabTheme.green
    }

    private var dashboardTempColor: Color {
        guard let temp = system?.cpuTemp else { return WatchLabTheme.green }
        if temp > 70 { return WatchLabTheme.red }
        if temp > 55 { return WatchLabTheme.orange }
        return WatchLabTheme.green
    }

    private func weatherIcon(_ condition: String) -> String {
        let lower = condition.lowercased()
        if lower.contains("rain") || lower.contains("chuva") { return "cloud.rain.fill" }
        if lower.contains("cloud") || lower.contains("nublado") { return "cloud.fill" }
        if lower.contains("sun") || lower.contains("sol") || lower.contains("clear") {
            return "sun.max.fill"
        }
        return "cloud.sun.fill"
    }
}

#Preview {
    EnhancedWatchContentView()
}
