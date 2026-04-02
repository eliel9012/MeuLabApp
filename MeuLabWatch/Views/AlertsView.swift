import SwiftUI

struct AlertsView: View {
    @State private var isLoading = true
    @State private var alerts: [WatchAlert] = []
    @State private var error: String?

    var body: some View {
        WatchLabScreen(title: "Alertas", icon: "bell.badge.fill", tint: WatchLabTheme.red) {
            if isLoading {
                WatchLabPanel(tint: WatchLabTheme.red) {
                    WatchLabStateView(
                        icon: "bell",
                        title: "Atualizando",
                        subtitle: "Buscando feed recente de alertas.",
                        tint: WatchLabTheme.red,
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
            } else if alerts.isEmpty {
                WatchLabPanel(tint: WatchLabTheme.green) {
                    WatchLabStateView(
                        icon: "bell.slash",
                        title: "Sem alertas",
                        subtitle: "Nenhum evento recente no feed.",
                        tint: WatchLabTheme.green,
                        actionTitle: nil,
                        action: nil
                    )
                }
            } else {
                WatchLabPanel(tint: WatchLabTheme.red) {
                    Text("Feed recente")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    ForEach(alerts.prefix(6)) { alert in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Image(systemName: iconForCategory(alert.category))
                                    .foregroundStyle(colorForCategory(alert.category))
                                    .font(.caption2)
                                Text(alert.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(WatchLabTheme.ink)
                                    .lineLimit(1)
                            }
                            if let message = alert.message {
                                Text(message)
                                    .font(.caption2)
                                    .foregroundStyle(WatchLabTheme.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 3)
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
            alerts = try await WatchAPIService.shared.fetchAlerts()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func iconForCategory(_ category: String?) -> String {
        switch category {
        case "adsb_alert": return "airplane"
        case "acars_alert": return "envelope.badge"
        case "weather_alert": return "cloud.bolt"
        case "satellite": return "antenna.radiowaves.left.and.right"
        default: return "bell"
        }
    }

    private func colorForCategory(_ category: String?) -> Color {
        switch category {
        case "adsb_alert": return WatchLabTheme.blue
        case "acars_alert": return WatchLabTheme.orange
        case "weather_alert": return WatchLabTheme.cyan
        case "satellite": return WatchLabTheme.violet
        default: return WatchLabTheme.secondary
        }
    }
}

#Preview {
    AlertsView()
}
