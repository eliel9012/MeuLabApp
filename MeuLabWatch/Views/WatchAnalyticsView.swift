import SwiftUI

struct WatchAnalyticsView: View {
    @State private var isLoading = true
    @State private var analytics: WatchADSBAnalytics?
    @State private var error: String?

    var body: some View {
        WatchLabScreen(title: "Analytics", icon: "chart.bar.fill", tint: WatchLabTheme.cyan) {
            if isLoading {
                WatchLabPanel(tint: WatchLabTheme.cyan) {
                    WatchLabStateView(
                        icon: "chart.bar",
                        title: "Atualizando",
                        subtitle: "Buscando estatísticas de 24h.",
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
            } else if let analytics {
                // KPI Cards
                WatchLabPanel(tint: WatchLabTheme.blue) {
                    Text("ADS-B últimas 24h")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    HStack {
                        WatchLabMiniMetricCard(
                            icon: "airplane",
                            value: "\(analytics.totalFlights ?? 0)",
                            label: "Voos",
                            tint: WatchLabTheme.blue
                        )
                        WatchLabMiniMetricCard(
                            icon: "airplane.circle",
                            value: "\(analytics.uniqueAircraft ?? 0)",
                            label: "Únicos",
                            tint: WatchLabTheme.green
                        )
                    }
                }

                // Top Aircraft Types
                if let types = analytics.topAircraftTypes, !types.isEmpty {
                    WatchLabPanel(tint: WatchLabTheme.violet) {
                        Text("Top Aeronaves")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WatchLabTheme.ink)

                        ForEach(types.prefix(5)) { type in
                            HStack {
                                Text(type.type)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(WatchLabTheme.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(type.count)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(WatchLabTheme.cyan)
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }

                // Hourly mini bar chart
                if let hourly = analytics.hourlyStats, !hourly.isEmpty {
                    WatchLabPanel(tint: WatchLabTheme.green) {
                        Text("Voos por hora")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WatchLabTheme.ink)

                        let maxCount = hourly.map(\.flightCount).max() ?? 1
                        HStack(alignment: .bottom, spacing: 1) {
                            ForEach(hourly.prefix(24)) { stat in
                                VStack(spacing: 1) {
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(barColor(stat.flightCount, max: maxCount))
                                        .frame(
                                            width: 5,
                                            height: max(
                                                2,
                                                CGFloat(stat.flightCount)
                                                    / CGFloat(max(1, maxCount)) * 30)
                                        )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Peak hour
                        if let peak = hourly.max(by: { $0.flightCount < $1.flightCount }) {
                            Text("Pico: \(peak.hour)h (\(peak.flightCount) voos)")
                                .font(.system(size: 9))
                                .foregroundStyle(WatchLabTheme.secondary)
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
            analytics = try await WatchAPIService.shared.fetchADSBAnalytics()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func barColor(_ count: Int, max maxVal: Int) -> Color {
        let ratio = Double(count) / Double(Swift.max(1, maxVal))
        if ratio > 0.7 { return WatchLabTheme.green }
        if ratio > 0.4 { return WatchLabTheme.cyan }
        return WatchLabTheme.blue.opacity(0.6)
    }
}

#Preview {
    WatchAnalyticsView()
}
