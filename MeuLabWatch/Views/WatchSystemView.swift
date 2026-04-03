import SwiftUI

struct WatchSystemView: View {
    @State private var isLoading = true
    @State private var system: WatchSystemData?
    @State private var error: String?

    var body: some View {
        WatchLabScreen(title: "Sistema", icon: "cpu", tint: WatchLabTheme.green) {
            if isLoading {
                WatchLabPanel(tint: WatchLabTheme.green) {
                    WatchLabStateView(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Atualizando",
                        subtitle: "Sincronizando telemetria do nó.",
                        tint: WatchLabTheme.green,
                        actionTitle: nil,
                        action: nil
                    )
                }
            } else if let error {
                WatchLabPanel(tint: WatchLabTheme.red) {
                    WatchLabStateView(
                        icon: "wifi.exclamationmark",
                        title: "Falha",
                        subtitle: error,
                        tint: WatchLabTheme.red,
                        actionTitle: "Tentar",
                        action: { Task { await loadData() } }
                    )
                }
            } else if let system {
                WatchLabPanel(tint: WatchLabTheme.green) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Nó monitorado")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WatchLabTheme.ink)
                            Text("Pi5")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(WatchLabTheme.ink)
                        }

                        Spacer()

                        WatchLabMetricPill(
                            title: "Rede",
                            value: system.wifiSignal.map { "\($0) dBm" } ?? "--",
                            tint: wifiColor(system.wifiSignal ?? -90),
                            icon: "wifi"
                        )
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        WatchGaugeCard(
                            label: "CPU",
                            value: system.cpuPercent,
                            tint: percentColor(system.cpuPercent),
                            icon: "cpu",
                            suffix: "%"
                        )

                        WatchGaugeCard(
                            label: "RAM",
                            value: system.memoryPercent,
                            tint: percentColor(system.memoryPercent),
                            icon: "memorychip",
                            suffix: "%"
                        )

                        WatchGaugeCard(
                            label: "Disco",
                            value: system.diskPercent,
                            tint: percentColor(system.diskPercent),
                            icon: "externaldrive",
                            suffix: "%"
                        )

                        WatchGaugeCard(
                            label: "Temp",
                            value: min(system.cpuTemp ?? 0, 100),
                            tint: tempColor(system.cpuTemp ?? 0),
                            icon: "thermometer",
                            suffix: "°"
                        )
                    }
                }

                WatchLabPanel(tint: WatchLabTheme.blue) {
                    Text("Leitura operacional")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    if let uptime = system.uptimeFormatted {
                        WatchLabStatRow(
                            icon: "clock",
                            title: "Uptime",
                            value: uptime,
                            tint: WatchLabTheme.blue
                        )
                    }

                    WatchLabStatRow(
                        icon: "chart.bar.fill",
                        title: "CPU",
                        value: "\(Int(system.cpuPercent))%",
                        tint: percentColor(system.cpuPercent)
                    )

                    WatchLabStatRow(
                        icon: "wifi",
                        title: "Sinal",
                        value: system.wifiSignal.map { "\($0) dBm" } ?? "--",
                        tint: wifiColor(system.wifiSignal ?? -90)
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
        error = nil

        do {
            system = try await WatchAPIService.shared.fetchSystemStatus()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func percentColor(_ percent: Double) -> Color {
        if percent > 90 { return WatchLabTheme.red }
        if percent > 70 { return WatchLabTheme.orange }
        return WatchLabTheme.green
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp > 70 { return WatchLabTheme.red }
        if temp > 55 { return WatchLabTheme.orange }
        return WatchLabTheme.green
    }

    private func wifiColor(_ signal: Int) -> Color {
        if signal > -55 { return WatchLabTheme.green }
        if signal > -70 { return WatchLabTheme.orange }
        return WatchLabTheme.red
    }
}

struct WatchGaugeCard: View {
    let label: String
    let value: Double
    let tint: Color
    let icon: String
    let suffix: String

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 5)

                Circle()
                    .trim(from: 0, to: min(value / 100, 1))
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(tint)
                    Text("\(Int(value))\(suffix)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchLabTheme.ink)
                }
            }
            .frame(width: 62, height: 62)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WatchLabTheme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

#Preview {
    WatchSystemView()
}
