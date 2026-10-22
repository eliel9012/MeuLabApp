import SwiftUI

private struct VisionAPIMetrics: Decodable {
    let uptimeSeconds: Int
    let requestCount: Int
    let avgResponseMs: Double
    let cacheHits: Int
    let cacheMisses: Int
    enum CodingKeys: String, CodingKey {
        case uptimeSeconds = "uptime_seconds", requestCount = "request_count"
        case avgResponseMs = "avg_response_ms", cacheHits = "cache_hits", cacheMisses = "cache_misses"
    }
}

private struct VisionDockerStatus: Decodable { let containers: [VisionDockerContainer] }
private struct VisionDockerContainer: Decodable, Identifiable {
    let id: String
    let names: String
    let image: String
    let state: String
    let status: String
    let health: Health?
    struct Health: Decodable {
        let status: String
        enum CodingKeys: String, CodingKey { case status = "Status" }
    }
    enum CodingKeys: String, CodingKey {
        case id = "ID", names = "Names", image = "Image", state = "State"
        case status = "Status", health = "Health"
    }
}

private struct VisionSystemdStatus: Decodable { let services: [VisionSystemdService] }
private struct VisionSystemdService: Decodable, Identifiable {
    let service: String
    let activeState: String
    let subState: String
    let description: String
    var id: String { service }
    enum CodingKeys: String, CodingKey {
        case service, description
        case activeState = "active_state", subState = "sub_state"
    }
}

private struct VisionDiskHealth: Decodable {
    let ok: Bool
    let devices: [Device]
    struct Device: Decodable, Identifiable {
        let device: String
        let model: String?
        let healthPassed: Bool?
        let temperatureC: Double?
        let percentageUsed: Double?
        let mediaErrors: Double?
        var id: String { device }
        enum CodingKeys: String, CodingKey {
            case device, model
            case healthPassed = "health_passed", temperatureC = "temperature_c"
            case percentageUsed = "percentage_used", mediaErrors = "media_errors"
        }
    }
}

struct VisionInfraExtrasView: View {
    @State private var metrics: VisionAPIMetrics?
    @State private var containers: [VisionDockerContainer] = []
    @State private var services: [VisionSystemdService] = []
    @State private var diskHealth: VisionDiskHealth?
    @State private var errors: [String: String] = [:]
    @State private var search = ""
    @State private var selectedContainer: VisionDockerContainer?
    @State private var loading = false

    private var filteredContainers: [VisionDockerContainer] {
        search.isEmpty ? containers : containers.filter {
            $0.names.localizedCaseInsensitiveContains(search) || $0.image.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Saúde da API", systemImage: "waveform.path.ecg").font(.title2.bold())
            if let metrics {
                HStack(spacing: 12) {
                    metric("Uptime", "\(metrics.uptimeSeconds / 3600) h")
                    metric("Requisições", "\(metrics.requestCount)")
                    metric("Latência média", "\(metrics.avgResponseMs.formatted(.number.precision(.fractionLength(1)))) ms")
                    metric("Cache", "\(metrics.cacheHits) / \(metrics.cacheMisses)")
                }
            } else { unavailable("metrics") }

            HStack {
                Label("Containers Docker", systemImage: "shippingbox").font(.title2.bold())
                Spacer()
                Text("\(filteredContainers.count)").foregroundStyle(.secondary)
            }
            TextField("Buscar container", text: $search)
                .textFieldStyle(.roundedBorder)
            if containers.isEmpty {
                unavailable("docker")
            } else {
                ForEach(filteredContainers) { container in
                    Button {
                        selectedContainer = container
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: container.state.lowercased() == "running" ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(container.state.lowercased() == "running" ? .green : .orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(container.names).font(.headline)
                                Text(container.image).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(container.health?.status ?? container.state).font(.caption)
                            Image(systemName: "chevron.right").font(.caption)
                        }
                        .padding(14)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            Label("Serviços systemd", systemImage: "server.rack").font(.title2.bold())
            if services.isEmpty {
                unavailable("systemd")
            } else {
                ForEach(services) { service in
                    HStack(spacing: 12) {
                        Image(systemName: service.activeState == "active" ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(service.activeState == "active" ? .green : .orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(service.service).font(.headline)
                            Text(service.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(service.activeState) · \(service.subState)").font(.caption)
                    }
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            Label("Saúde dos discos", systemImage: "internaldrive").font(.title2.bold())
            if let diskHealth, !diskHealth.devices.isEmpty {
                ForEach(diskHealth.devices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: device.healthPassed == true ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .foregroundStyle(device.healthPassed == true ? .green : .orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.model ?? device.device).font(.headline)
                            Text(device.device).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let temperature = device.temperatureC { Text("\(temperature.formatted())°C") }
                        if let used = device.percentageUsed { Text("\(used.formatted())% usado") }
                        if let failures = device.mediaErrors, failures > 0 {
                            Text("\(failures.formatted()) erros").foregroundStyle(.orange)
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }
            } else { unavailable("disk") }
        }
        .sheet(item: $selectedContainer) { container in
            VisionDockerLogsView(container: container)
        }
        .task {
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(60)) }
                catch { break }
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private func unavailable(_ key: String) -> some View {
        Text(errors[key] ?? (loading ? "Carregando…" : "Sem dados disponíveis."))
            .font(.callout).foregroundStyle(.secondary)
    }

    private func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let api = try VisionAPIClient()
            do { metrics = try await api.fetch("api/metrics"); errors["metrics"] = nil }
            catch { errors["metrics"] = error.localizedDescription }
            do {
                let response: VisionDockerStatus = try await api.fetch("api/docker/status?health=1")
                containers = response.containers
                errors["docker"] = nil
            } catch { errors["docker"] = error.localizedDescription }
            do {
                let response: VisionSystemdStatus = try await api.fetch("api/systemd/status")
                services = response.services
                errors["systemd"] = nil
            } catch { errors["systemd"] = error.localizedDescription }
            do { diskHealth = try await api.fetch("api/system/disk_health"); errors["disk"] = nil }
            catch { errors["disk"] = error.localizedDescription }
        } catch {
            for key in ["metrics", "docker", "systemd", "disk"] { errors[key] = error.localizedDescription }
        }
    }
}

private struct VisionDockerLogsView: View {
    let container: VisionDockerContainer
    @Environment(\.dismiss) private var dismiss
    @State private var logs = ""
    @State private var error: String?
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Logs · \(container.names)").font(.title2.bold())
                Spacer()
                if loading { ProgressView() }
                Button("Atualizar", systemImage: "arrow.clockwise") { Task { await refresh() } }
                Button("Fechar", systemImage: "xmark") { dismiss() }
            }
            if let error { Text(error).foregroundStyle(.orange) }
            ScrollView {
                Text(logs.isEmpty ? "Nenhum log recente." : logs)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(26)
        .frame(width: 760, height: 510)
        .task { await refresh() }
    }

    private func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            logs = try await VisionAPIClient().fetchText("api/docker/logs", query: [
                URLQueryItem(name: "container", value: container.names),
                URLQueryItem(name: "tail", value: "200"),
                URLQueryItem(name: "since", value: "3600")
            ])
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
