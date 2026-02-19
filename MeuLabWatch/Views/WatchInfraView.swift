import SwiftUI

/// Detalhes de Infraestrutura para watchOS
struct WatchInfraView: View {
    @State private var isLoading = true
    @State private var infra: WatchInfraData?
    @State private var error: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if isLoading {
                    ProgressView("Carregando...")
                        .frame(maxWidth: .infinity)
                } else if let error {
                    ErrorView(message: error) {
                        Task { await loadData() }
                    }
                } else if let infra {
                    // Métricas API
                    if let uptime = infra.metrics.uptime {
                        MetricRow(label: "Uptime", value: uptime)
                    }
                    if let requests = infra.metrics.requestsTotal {
                        MetricRow(label: "Requests", value: "\(requests)")
                    }
                    if let latency = infra.metrics.avgLatencyMs {
                        MetricRow(label: "Latência", value: String(format: "%.0fms", latency))
                    }
                    
                    Divider()
                    
                    // Containers
                    Text("Containers")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    let running = infra.docker.containers.filter { $0.state == "running" }.count
                    let total = infra.docker.containers.count
                    
                    Text("\(running)/\(total) running")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    ForEach(infra.docker.containers.prefix(5)) { container in
                        HStack {
                            Circle()
                                .fill(container.state == "running" ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                            Text(container.name)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            if let health = container.health, health != "none" {
                                Text(health)
                                    .font(.caption2)
                                    .foregroundStyle(health == "healthy" ? .green : .orange)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Infra")
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
            infra = try await WatchAPIService.shared.fetchInfraSummary()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

/// Linha de métrica simples
struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    WatchInfraView()
}
