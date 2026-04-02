import SwiftUI

struct InfraView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedContainer: DockerContainer?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let metrics = appState.metrics {
                    metricsSection(metrics)
                } else if let error = appState.metricsError {
                    ErrorCard(message: error)
                }

                if let dockerVersion = appState.dockerVersion {
                    dockerVersionSection(dockerVersion)
                }

                if !appState.dockerContainers.isEmpty {
                    dockerContainersSection(appState.dockerContainers)
                } else if let error = appState.dockerError {
                    ErrorCard(message: error)
                }

                if !appState.systemdServices.isEmpty {
                    systemdSection(appState.systemdServices)
                } else if let error = appState.systemdError {
                    ErrorCard(message: error)
                }
            }
            .padding()
        }
        .navigationTitle("Infra")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Buscar containers")
        .sheet(item: $selectedContainer) { container in
            ContainerLogView(containerName: container.names)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private func metricsSection(_ metrics: MetricsResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.blue)
                Text("Saúde da API")
                    .font(.headline)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                InfraStatCard(
                    title: "Uptime",
                    value: Formatters.formatDuration(seconds: metrics.uptimeSeconds),
                    icon: "clock",
                    color: .blue
                )
                InfraStatCard(
                    title: "Requests", value: "\(metrics.requestCount)",
                    icon: "arrow.up.arrow.down", color: .green)
                InfraStatCard(
                    title: "Latência Média",
                    value: String(format: "%.1f ms", metrics.avgResponseMs), icon: "speedometer",
                    color: .orange)
                InfraStatCard(
                    title: "Última", value: String(format: "%.1f ms", metrics.lastResponseMs),
                    icon: "timer", color: .purple)
            }

            Divider()

            HStack {
                Text("Cache: \(metrics.cacheHits) hits / \(metrics.cacheMisses) misses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .glassCard(cornerRadius: 12)
    }

    @ViewBuilder
    private func dockerVersionSection(_ response: DockerVersionResponse) -> some View {
        // Same as before but visual tweak if needed
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shippingbox")
                    .foregroundStyle(.blue)
                Text("Docker")
                    .font(.headline)
            }

            Text(
                "Server \(response.version.server.version ?? "-") • API \(response.version.server.apiVersion ?? "-")"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .glassCard(cornerRadius: 12)
    }

    @ViewBuilder
    private func dockerContainersSection(_ containers: [DockerContainer]) -> some View {
        let filtered =
            searchText.isEmpty
            ? containers
            : containers.filter {
                $0.names.localizedCaseInsensitiveContains(searchText)
                    || $0.image.localizedCaseInsensitiveContains(searchText)
            }

        VStack(alignment: .leading, spacing: 12) {
            Text("Containers (\(filtered.count))")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(filtered) { container in
                    Button {
                        selectedContainer = container
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(container.names)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Spacer()
                                StatusBadge(status: container.state)
                            }

                            if let health = container.health {
                                Text("Health: \(health.status)")
                                    .font(.caption2)
                                    .foregroundStyle(
                                        health.status == "healthy"
                                            ? .green
                                            : (health.status == "unhealthy" ? .red : .secondary))
                            }

                            HStack {
                                Text(container.image)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(12)
                        .materialCard(cornerRadius: 8)
                    }
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 12)
    }

    @ViewBuilder
    private func systemdSection(_ services: [SystemdService]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Systemd")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(services) { service in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(service.service)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(service.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(status: service.activeState)
                    }
                    .padding(8)
                    .materialCard(cornerRadius: 8)
                }
            }
        }
        .padding()
        .glassCard(cornerRadius: 12)
    }
}

struct StatusBadge: View {
    let status: String

    var color: Color {
        switch status.lowercased() {
        case "running", "active", "healthy": return .green
        case "exited", "inactive": return .orange
        case "unhealthy", "failed": return .red
        default: return .secondary
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

struct ContainerLogView: View {
    let containerName: String
    @State private var logs = ""
    @State private var isLoading = true
    @State private var error: String?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Carregando logs...")
                } else if let error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text(error)
                            .padding()
                        Button("Tentar Novamente") {
                            fetchLogs()
                        }
                        .adaptiveGlassButton()
                    }
                } else {
                    ScrollView {
                        Text(logs)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }
                    .background(Color(white: 0.1))
                }
            }
            .navigationTitle(containerName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        fetchLogs()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                fetchLogs()
            }
        }
    }

    private func fetchLogs() {
        isLoading = true
        error = nil
        Task {
            do {
                let output = try await APIService.shared.fetchDockerLogsRaw(
                    container: containerName, tail: 500, since: 86400)
                await MainActor.run {
                    self.logs = output.isEmpty ? "Nenhum log encontrado nas últimas 24h." : output
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct InfraStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding()
        .glassCard(cornerRadius: 12)
    }
}

#Preview {
    InfraView()
        .environmentObject(AppState())
}
