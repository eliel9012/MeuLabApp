import SwiftUI

/// ContentView principal do Apple Watch com TabView
struct EnhancedWatchContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Dashboard
            WatchDashboardView()
                .tag(0)

            // Tab 2: ADS-B
            WatchADSBView()
                .tag(1)

            // Tab 3: Sistema
            WatchSystemView()
                .tag(2)

            // Tab 4: Satelite
            WatchSatDumpView()
                .tag(3)

            // Tab 5: Radio
            WatchRadioView()
                .tag(4)

            // Tab 6: Menu Completo
            WatchMenuView()
                .tag(5)
        }
#if os(watchOS)
        .tabViewStyle(.verticalPage)
#endif
    }
}

// MARK: - Dashboard View (Tela Principal)

struct WatchDashboardView: View {
    @State private var isLoading = true
    @State private var adsb: WatchADSBData?
    @State private var system: WatchSystemData?
    @State private var weather: WatchWeatherData?
    @State private var lastUpdate = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header com hora
                HStack {
                    Text("MeuLab")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Spacer()
                    Text(lastUpdate, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Conectando...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    // Cards de resumo
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        // ADS-B
                        DashboardMiniCard(
                            icon: "airplane",
                            value: "\(adsb?.totalNow ?? 0)",
                            label: "Voos",
                            color: .blue
                        )

                        // Sistema
                        DashboardMiniCard(
                            icon: "cpu",
                            value: "\(Int(system?.cpuPercent ?? 0))%",
                            label: "CPU",
                            color: cpuColor
                        )

                        // Temperatura
                        if let temp = system?.cpuTemp {
                            DashboardMiniCard(
                                icon: "thermometer",
                                value: "\(Int(temp))°",
                                label: "Temp",
                                color: tempColor(temp)
                            )
                        }

                        // Clima
                        if let current = weather?.current {
                            DashboardMiniCard(
                                icon: weatherIcon(current.condition),
                                value: "\(Int(current.temperature))°",
                                label: "Clima",
                                color: .cyan
                            )
                        }
                    }

                    // Barra de RAM/Disco
                    if let sys = system {
                        VStack(spacing: 4) {
                            MiniGaugeRow(label: "RAM", value: sys.memoryPercent)
                            MiniGaugeRow(label: "Disco", value: sys.diskPercent)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 2)
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
        do {
            async let adsbTask = WatchAPIService.shared.fetchADSBSummary()
            async let systemTask = WatchAPIService.shared.fetchSystemStatus()
            async let weatherTask = WatchAPIService.shared.fetchWeather()

            adsb = try? await adsbTask
            system = try? await systemTask
            weather = try? await weatherTask
            lastUpdate = Date()
        }
        isLoading = false
    }

    private var cpuColor: Color {
        guard let cpu = system?.cpuPercent else { return .green }
        if cpu > 90 { return .red }
        if cpu > 70 { return .orange }
        return .green
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp > 70 { return .red }
        if temp > 55 { return .orange }
        return .green
    }

    private func weatherIcon(_ condition: String) -> String {
        let lower = condition.lowercased()
        if lower.contains("rain") || lower.contains("chuva") { return "cloud.rain.fill" }
        if lower.contains("cloud") || lower.contains("nublado") { return "cloud.fill" }
        if lower.contains("sun") || lower.contains("sol") || lower.contains("clear") { return "sun.max.fill" }
        return "cloud.sun.fill"
    }
}

// MARK: - Mini Card para Dashboard

struct DashboardMiniCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(color)
                }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
                .stroke(LinearGradient(
                    colors: [color.opacity(0.5), color.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
    }
}

// MARK: - Mini Gauge Row

struct MiniGaugeRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))

                    Capsule()
                        .fill(LinearGradient(
                            colors: [colorForValue(value), colorForValue(value).opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * min(value / 100, 1))
                }
            }
            .frame(height: 6)

            Text("\(Int(value))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(colorForValue(value))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func colorForValue(_ val: Double) -> Color {
        if val > 90 { return .red }
        if val > 70 { return .orange }
        return .green
    }
}

// MARK: - Menu View (Lista completa)

struct WatchMenuView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        HomeView()
                    } label: {
                        Label("Resumo", systemImage: "rectangle.3.group.bubble.left.fill")
                    }

                    NavigationLink {
                        AlertsView()
                    } label: {
                        Label("Alertas", systemImage: "bell.badge.fill")
                    }
                }

                Section("Monitoramento") {
                    NavigationLink {
                        WatchADSBView()
                    } label: {
                        Label("ADS-B", systemImage: "airplane.radar")
                    }

                    NavigationLink {
                        WatchACARSView()
                    } label: {
                        Label("ACARS", systemImage: "envelope.badge.fill")
                    }

                    NavigationLink {
                        WatchSatDumpView()
                    } label: {
                        Label("Satelite", systemImage: "satellite.fill")
                    }
                }

                Section("Sistema") {
                    NavigationLink {
                        WatchSystemView()
                    } label: {
                        Label("Status", systemImage: "cpu.fill")
                    }

                    NavigationLink {
                        WatchInfraView()
                    } label: {
                        Label("Infra", systemImage: "server.rack")
                    }

                    NavigationLink {
                        WatchWeatherView()
                    } label: {
                        Label("Clima", systemImage: "cloud.sun.fill")
                    }
                }
            }
            .navigationTitle("Menu")
        }
    }
}

#Preview {
    EnhancedWatchContentView()
}
