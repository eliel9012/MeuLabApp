import SwiftUI

/// Feed de alertas recentes
struct AlertsView: View {
    @State private var isLoading = true
    @State private var alerts: [WatchAlert] = []
    @State private var error: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Carregando...")
            } else if let error {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption2)
                    Button("Tentar novamente") {
                        Task { await loadData() }
                    }
                    .font(.caption)
                }
            } else if alerts.isEmpty {
                ContentUnavailableView(
                    "Sem Alertas",
                    systemImage: "bell.slash",
                    description: Text("Nenhum alerta recente")
                )
            } else {
                List(alerts) { alert in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: iconForCategory(alert.category))
                                .foregroundStyle(colorForCategory(alert.category))
                                .font(.caption2)
                            Text(alert.title)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        if let message = alert.message {
                            Text(message)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Text(alert.timestamp)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Alertas")
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
        case "adsb_alert": return .blue
        case "acars_alert": return .orange
        case "weather_alert": return .yellow
        case "satellite": return .pink
        default: return .gray
        }
    }
}

#Preview {
    AlertsView()
}
