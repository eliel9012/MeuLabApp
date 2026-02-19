import SwiftUI

/// Detalhes do Sistema para watchOS com gauges visuais
struct WatchSystemView: View {
    @State private var isLoading = true
    @State private var system: WatchSystemData?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Text("Carregando...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else if let error {
                    ErrorView(message: error) {
                        Task { await loadData() }
                    }
                } else if let system {
                    // Gauges principais em grid 2x2
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        // CPU Gauge
                        CircularGaugeView(
                            value: system.cpuPercent,
                            label: "CPU",
                            icon: "cpu",
                            color: colorForPercent(system.cpuPercent)
                        )

                        // RAM Gauge
                        CircularGaugeView(
                            value: system.memoryPercent,
                            label: "RAM",
                            icon: "memorychip",
                            color: colorForPercent(system.memoryPercent)
                        )

                        // Disco Gauge
                        CircularGaugeView(
                            value: system.diskPercent,
                            label: "Disco",
                            icon: "externaldrive",
                            color: colorForPercent(system.diskPercent)
                        )

                        // Temperatura Gauge
                        if let temp = system.cpuTemp {
                            CircularGaugeView(
                                value: min(temp, 100),
                                label: "Temp",
                                icon: "thermometer",
                                color: tempColor(temp),
                                suffix: "°"
                            )
                        }
                    }

                    // Informacoes adicionais
                    VStack(spacing: 6) {
                        if let wifi = system.wifiSignal {
                            InfoRow(
                                icon: "wifi",
                                label: "Wi-Fi",
                                value: "\(wifi) dBm",
                                color: wifiColor(wifi)
                            )
                        }

                        if let uptime = system.uptime {
                            InfoRow(
                                icon: "clock",
                                label: "Uptime",
                                value: uptime,
                                color: .blue
                            )
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Sistema")
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            system = try await WatchAPIService.shared.fetchSystemStatus()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func colorForPercent(_ percent: Double) -> Color {
        if percent > 90 { return .red }
        if percent > 70 { return .orange }
        return .green
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp > 70 { return .red }
        if temp > 55 { return .orange }
        return .green
    }

    private func wifiColor(_ signal: Int) -> Color {
        if signal > -50 { return .green }
        if signal > -70 { return .orange }
        return .red
    }
}

// MARK: - Circular Gauge View

struct CircularGaugeView: View {
    let value: Double
    let label: String
    let icon: String
    let color: Color
    var suffix: String = "%"

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 6)

                // Progress arc
                Circle()
                    .trim(from: 0, to: min(value / 100, 1))
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: value)

                // Center content
                VStack(spacing: 0) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(color)

                    Text("\(Int(value))\(suffix)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .frame(width: 60, height: 60)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.caption)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    WatchSystemView()
}
