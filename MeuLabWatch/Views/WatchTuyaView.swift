import SwiftUI

struct WatchTuyaView: View {
    @State private var isLoading = true
    @State private var tuyaData: WatchTuyaResponse?
    @State private var error: String?

    var body: some View {
        WatchLabScreen(title: "Sensores", icon: "sensor.fill", tint: WatchLabTheme.green) {
            if isLoading {
                WatchLabPanel(tint: WatchLabTheme.green) {
                    WatchLabStateView(
                        icon: "sensor",
                        title: "Atualizando",
                        subtitle: "Buscando dados dos sensores IoT.",
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
            } else if let data = tuyaData {
                // Status
                WatchLabPanel(tint: data.ok ? WatchLabTheme.green : WatchLabTheme.orange) {
                    HStack {
                        Text("Sensor Tuya")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WatchLabTheme.ink)
                        Spacer()
                        Circle()
                            .fill(data.ok ? WatchLabTheme.green : WatchLabTheme.red)
                            .frame(width: 8, height: 8)
                    }

                    if data.degraded == true, let reason = data.degradedReason {
                        Text(reason)
                            .font(.system(size: 9))
                            .foregroundStyle(WatchLabTheme.orange)
                    }
                }

                // Readings
                if let current = data.current {
                    WatchLabPanel(tint: WatchLabTheme.cyan) {
                        HStack {
                            // Temperature
                            if let temp = current.temperatureC {
                                VStack(spacing: 4) {
                                    Image(systemName: "thermometer")
                                        .font(.system(size: 18))
                                        .foregroundStyle(temperatureColor(temp))

                                    Text(String(format: "%.1f°C", temp))
                                        .font(.system(size: 20, weight: .black, design: .rounded))
                                        .foregroundStyle(WatchLabTheme.ink)

                                    Text("Temperatura")
                                        .font(.system(size: 9))
                                        .foregroundStyle(WatchLabTheme.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }

                            // Humidity
                            if let hum = current.humidityPct {
                                VStack(spacing: 4) {
                                    Image(systemName: "humidity")
                                        .font(.system(size: 18))
                                        .foregroundStyle(humidityColor(hum))

                                    Text(String(format: "%.0f%%", hum))
                                        .font(.system(size: 20, weight: .black, design: .rounded))
                                        .foregroundStyle(WatchLabTheme.ink)

                                    Text("Umidade")
                                        .font(.system(size: 9))
                                        .foregroundStyle(WatchLabTheme.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    // Battery
                    if let battery = current.batteryPct {
                        WatchLabPanel(tint: batteryColor(battery)) {
                            WatchLabStatRow(
                                icon: batteryIcon(battery),
                                title: "Bateria",
                                value: "\(battery)%",
                                tint: batteryColor(battery)
                            )
                        }
                    }
                }
            } else {
                WatchLabPanel(tint: WatchLabTheme.orange) {
                    WatchLabStateView(
                        icon: "sensor.fill",
                        title: "Sem dados",
                        subtitle: "Nenhuma leitura disponível.",
                        tint: WatchLabTheme.orange,
                        actionTitle: "Tentar",
                        action: { Task { await loadData() } }
                    )
                }
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        error = nil
        do {
            tuyaData = try await WatchAPIService.shared.fetchTuyaSensors()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func temperatureColor(_ temp: Double) -> Color {
        if temp > 35 { return WatchLabTheme.red }
        if temp > 28 { return WatchLabTheme.orange }
        if temp < 15 { return WatchLabTheme.blue }
        return WatchLabTheme.green
    }

    private func humidityColor(_ hum: Double) -> Color {
        if hum > 80 { return WatchLabTheme.blue }
        if hum < 30 { return WatchLabTheme.orange }
        return WatchLabTheme.cyan
    }

    private func batteryColor(_ pct: Int) -> Color {
        if pct < 20 { return WatchLabTheme.red }
        if pct < 50 { return WatchLabTheme.orange }
        return WatchLabTheme.green
    }

    private func batteryIcon(_ pct: Int) -> String {
        if pct > 75 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 25 { return "battery.25" }
        return "battery.0"
    }
}

#Preview {
    WatchTuyaView()
}
