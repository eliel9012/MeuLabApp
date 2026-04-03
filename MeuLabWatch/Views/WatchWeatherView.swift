import SwiftUI

struct WatchWeatherView: View {
    @State private var isLoading = true
    @State private var weather: WatchWeatherData?
    @State private var error: String?

    var body: some View {
        WatchLabScreen(title: "Clima", icon: "cloud.sun.fill", tint: WatchLabTheme.cyan) {
            if isLoading {
                WatchLabPanel(tint: WatchLabTheme.cyan) {
                    WatchLabStateView(
                        icon: "cloud.sun",
                        title: "Atualizando",
                        subtitle: "Buscando condição atual e previsão.",
                        tint: WatchLabTheme.cyan,
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
            } else if let weather {
                if let current = weather.current {
                    WatchLabPanel(tint: weatherTint(current.condition)) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Agora")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(WatchLabTheme.ink)
                                Text("\(Int(current.temperature))°C")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(WatchLabTheme.ink)
                                Text(current.condition)
                                    .font(.caption2)
                                    .foregroundStyle(WatchLabTheme.secondary)
                            }

                            Spacer()

                            Image(systemName: iconForCondition(current.condition))
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(weatherTint(current.condition))
                        }

                        HStack(spacing: 8) {
                            if let humidity = current.humidity {
                                WatchLabMetricPill(
                                    title: "Umidade",
                                    value: "\(humidity)%",
                                    tint: WatchLabTheme.blue,
                                    icon: "humidity"
                                )
                            }

                            if let wind = current.windKmh {
                                WatchLabMetricPill(
                                    title: "Vento",
                                    value: "\(wind) km/h",
                                    tint: WatchLabTheme.cyan,
                                    icon: "wind"
                                )
                            }
                        }
                    }
                }

                if let forecast = weather.forecast, !forecast.isEmpty {
                    WatchLabPanel(tint: WatchLabTheme.blue) {
                        Text("Próximos dias")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WatchLabTheme.ink)

                        ForEach(forecast.prefix(3)) { day in
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(day.date)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(WatchLabTheme.ink)
                                    Text(day.condition)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(WatchLabTheme.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text("\(Int(day.tempMin))° / \(Int(day.tempMax))°")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(WatchLabTheme.ink)
                            }
                            .padding(.vertical, 3)
                        }
                    }
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
            weather = try await WatchAPIService.shared.fetchWeather()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func iconForCondition(_ condition: String) -> String {
        let c = condition.lowercased()
        if c.contains("sun") || c.contains("clear") || c.contains("limpo") { return "sun.max.fill" }
        if c.contains("cloud") || c.contains("nublado") { return "cloud.fill" }
        if c.contains("rain") || c.contains("chuva") { return "cloud.rain.fill" }
        if c.contains("storm") || c.contains("tempest") { return "cloud.bolt.fill" }
        return "cloud.sun.fill"
    }

    private func weatherTint(_ condition: String) -> Color {
        let c = condition.lowercased()
        if c.contains("sun") || c.contains("clear") || c.contains("limpo") {
            return WatchLabTheme.orange
        }
        if c.contains("rain") || c.contains("chuva") { return WatchLabTheme.blue }
        if c.contains("storm") || c.contains("tempest") { return WatchLabTheme.violet }
        return WatchLabTheme.cyan
    }
}

#Preview {
    WatchWeatherView()
}
