import SwiftUI

struct WatchInfraView: View {
    @State private var isLoading = true
    @State private var infra: WatchInfraData?
    @State private var error: String?

    var body: some View {
        WatchLabScreen(title: "Infra", icon: "server.rack", tint: WatchLabTheme.orange) {
            if isLoading {
                WatchLabPanel(tint: WatchLabTheme.orange) {
                    WatchLabStateView(
                        icon: "server.rack",
                        title: "Atualizando",
                        subtitle: "Buscando métricas e containers.",
                        tint: WatchLabTheme.orange,
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
            } else if let infra {
                WatchLabPanel(tint: WatchLabTheme.orange) {
                    Text("API e containers")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    if let uptime = infra.metrics.uptime {
                        WatchLabStatRow(icon: "clock", title: "Uptime", value: uptime, tint: WatchLabTheme.blue)
                    }
                    if let requests = infra.metrics.requestsTotal {
                        WatchLabStatRow(icon: "arrow.up.arrow.down", title: "Requests", value: "\(requests)", tint: WatchLabTheme.cyan)
                    }
                    if let latency = infra.metrics.avgLatencyMs {
                        WatchLabStatRow(icon: "timer", title: "Latência", value: String(format: "%.0fms", latency), tint: WatchLabTheme.green)
                    }
                }

                WatchLabPanel(tint: WatchLabTheme.green) {
                    Text("Containers")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    ForEach(infra.docker.containers.prefix(4)) { container in
                        HStack {
                            Circle()
                                .fill(container.state == "running" ? WatchLabTheme.green : WatchLabTheme.red)
                                .frame(width: 7, height: 7)
                            Text(container.name)
                                .font(.caption)
                                .foregroundStyle(WatchLabTheme.ink)
                                .lineLimit(1)
                            Spacer()
                            Text(container.health ?? container.state)
                                .font(.caption2)
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
            infra = try await WatchAPIService.shared.fetchInfraSummary()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    WatchInfraView()
}
