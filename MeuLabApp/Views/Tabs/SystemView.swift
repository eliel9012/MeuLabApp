import SwiftUI

struct SystemView: View {
    @EnvironmentObject var appState: AppState
    @State private var snapshotTarget: FirestickSnapshotTarget?

    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    if let status = appState.systemStatus {
                        systemContent(status)
                    } else if let error = appState.systemError {
                        ErrorCard(message: error)
                    } else {
                        LoadingCard()
                    }
                }
                .padding()
            }
            .navigationTitle("Sistema")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $snapshotTarget) { target in
                FirestickSnapshotView(deviceId: target.id, deviceName: target.name)
            }
    }

    @ViewBuilder
    private func systemContent(_ status: SystemStatus) -> some View {
        // Header
        VStack(spacing: 4) {
            Text(status.hostname)
                .font(.title2)
                .fontWeight(.bold)

            Text(status.location)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let uptime = status.uptime {
                Label(uptime.formatted, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let date = Formatters.isoDate.date(from: status.timestamp) ?? Formatters.isoDateNoFrac.date(from: status.timestamp) {
                Text("Atualizado \(Formatters.relativeDate.localizedString(for: date, relativeTo: Date()))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)

        // CPU
        if let cpu = status.cpu, cpu.error == nil {
            SystemCard(title: "CPU", icon: "cpu", color: .blue) {
                HStack(spacing: 16) {
                    GaugeView(
                        value: cpu.usagePercent ?? 0,
                        maxValue: 100,
                        title: "Uso",
                        color: .blue
                    )

                    if let temp = cpu.temperatureC {
                        GaugeView(
                            value: temp,
                            maxValue: 100,
                            title: "Temp",
                            color: Color.fromName(cpu.temperatureColor),
                            suffix: "°C"
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let l1 = cpu.load1min, let l5 = cpu.load5min, let l15 = cpu.load15min {
                             Text("Load Avg")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                             Text(String(format: "%.2f  %.2f  %.2f", l1, l5, l15))
                                .font(.caption)
                                .monospacedDigit()
                        }
                        
                        Text("\(cpu.cores ?? 4) Cores")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }

        // Memory
        if let memory = status.memory, memory.error == nil {
            SystemCard(title: "Memória RAM", icon: "memorychip", color: .purple) {
                if let total = memory.totalMb, let used = memory.usedMb, let available = memory.availableMb {
                    VStack(spacing: 8) {
                        ProgressView(value: Double(used), total: Double(total)) {
                            HStack {
                                Text("\(used) MB usado")
                                    .font(.caption)
                                Spacer()
                                Text(String(format: "%.1f%%", memory.usedPercent ?? 0))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                        }
                        .tint(.purple)

                        HStack {
                            Label("\(total) MB total", systemImage: "square.stack.3d.up")
                            Spacer()
                            Label("\(available) MB livre", systemImage: "checkmark.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }

        // Disk
        if let disk = status.disk, disk.error == nil {
            SystemCard(title: "Armazenamento", icon: "internaldrive", color: .orange) {
                if let total = disk.totalGb, let used = disk.usedGb, let available = disk.availableGb {
                    VStack(spacing: 8) {
                        ProgressView(value: used, total: total) {
                            HStack {
                                Text(String(format: "%.1f GB usado", used))
                                    .font(.caption)
                                Spacer()
                                Text(String(format: "%.1f%%", disk.usedPercent ?? 0))
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                        }
                        .tint(.orange)

                        HStack {
                            Label(String(format: "%.1f GB total", total), systemImage: "square.stack.3d.up")
                            Spacer()
                            Label(String(format: "%.1f GB livre", available), systemImage: "checkmark.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }

        // WiFi
        if let wifi = status.wifi {
            SystemCard(title: "Wi-Fi", icon: "wifi", color: .green) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        if let ssid = wifi.ssid {
                            Text(ssid)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        if let signal = wifi.signalDbm {
                            HStack(spacing: 4) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("\(signal) dBm")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        }
                    }

                    Spacer()

                    if let quality = wifi.qualityPercent {
                        GaugeView(
                            value: Double(quality),
                            maxValue: 100,
                            title: "Sinal",
                            color: quality > 60 ? .green : (quality > 30 ? .orange : .red)
                        )
                        .frame(width: 80)
                    }
                }
            }
        }

        // Fire Stick TVs
        if !appState.firestickDeviceStatuses.isEmpty || appState.firestickError != nil {
            SystemCard(title: "TVs (Fire Stick)", icon: "tv", color: .red) {
                if let err = appState.firestickError, appState.firestickDeviceStatuses.isEmpty {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(appState.firestickDeviceStatuses) { item in
                            HStack(spacing: 10) {
                                NavigationLink {
                                    FirestickDetailView(deviceId: item.device.id, deviceName: item.device.name)
                                } label: {
                                    FirestickRowView(item: item)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    snapshotTarget = FirestickSnapshotTarget(id: item.device.id, name: item.device.name)
                                } label: {
                                    Image(systemName: "camera")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .buttonStyle(.bordered)
                            }
                            Divider()
                        }
                    }
                }
            }
        }

        // Processes
        if !appState.processes.isEmpty {
            SystemCard(title: "Top Processos (CPU)", icon: "list.bullet.rectangle", color: .blue) {
                VStack(spacing: 8) {
                    ForEach(appState.processes.prefix(5)) { process in
                        HStack {
                            Text(process.command)
                                .font(.subheadline)
                                .lineLimit(1)

                            Spacer()

                            Text(String(format: "%.1f%%", process.cpuPercent))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                }
            }
        }

        // Partitions
        if !appState.partitions.isEmpty {
             SystemCard(title: "Partições", icon: "externaldrive", color: .orange) {
                VStack(spacing: 12) {
                    ForEach(appState.partitions) { partition in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(partition.mount)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(partition.usedPercent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(
                                value: Double(partition.usedBytes),
                                total: Double(max(partition.totalBytes, 1))
                            )
                            .tint(.orange)

                            Text("\(formatBytes(partition.usedBytes)) / \(formatBytes(partition.totalBytes))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        // Network
        if !appState.networkInterfaces.isEmpty {
            SystemCard(title: "Rede", icon: "arrow.left.and.right", color: .green) {
                VStack(spacing: 10) {
                    ForEach(appState.networkInterfaces) { iface in
                        HStack {
                            Text(iface.iface)
                                .font(.subheadline)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("RX \(formatBytes(iface.rxBytes))")
                                Text("TX \(formatBytes(iface.txBytes))")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

struct SystemCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GaugeView: View {
    let value: Double
    let maxValue: Double
    let title: String
    let color: Color
    var suffix: String = "%"

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: min(value / maxValue, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: value)

                Text(suffix == "°C" ? String(format: "%.0f%@", value, suffix) : String(format: "%.0f%@", value, suffix))
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
            .frame(width: 60, height: 60)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct FirestickRowView: View {
    let item: FirestickDeviceStatus

    var body: some View {
        let st = item.status.firestick
        let tvOn = st.tvOn
        let showing = st.tvShowingFirestick
        let pkg = st.foregroundApp?.package
        let adbState = st.adb.deviceState ?? "unknown"

        HStack(spacing: 12) {
            Image(systemName: symbol(for: item.device.id, name: item.device.name))
                .foregroundStyle(.red)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.device.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle(tvOn: tvOn, showing: showing, adbState: adbState, package: pkg))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Circle()
                .fill(tvOn == true ? Color.green : (tvOn == false ? Color.gray : Color.orange))
                .frame(width: 10, height: 10)
        }
        .foregroundStyle(.primary)
    }

    private func symbol(for id: String, name: String) -> String {
        let s = (id + " " + name).lowercased()
        if s.contains("sala") { return "sofa.fill" }
        if s.contains("mae") || s.contains("mãe") { return "person.fill" }
        return "tv"
    }

    private func subtitle(tvOn: Bool?, showing: Bool?, adbState: String, package: String?) -> String {
        var parts: [String] = []
        if let tvOn { parts.append(tvOn ? "Ligada" : "Desligada") } else { parts.append("Estado: ?") }
        if let showing { parts.append(showing ? "HDMI: Fire Stick" : "HDMI: outro") }
        parts.append("ADB: \(adbState)")
        if let package, !package.isEmpty { parts.append(package) }
        return parts.joined(separator: " • ")
    }
}

private struct FirestickSnapshotTarget: Identifiable {
    let id: String
    let name: String
}

private struct FirestickSnapshotView: View {
    let deviceId: String
    let deviceName: String

    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?
    @State private var isLoading = false
    @State private var error: String?
    @State private var lastUpdated: Date?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .failure:
                            VStack(spacing: 8) {
                                Text("Falha ao carregar screenshot")
                                    .foregroundStyle(.secondary)
                                if let error {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.black).opacity(0.05))
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else if isLoading {
                    ProgressView("Carregando...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        Text("Sem screenshot ainda")
                            .foregroundStyle(.secondary)
                        if let error {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if let lastUpdated {
                    Text("Atualizado \(Formatters.relativeDate.localizedString(for: lastUpdated, relativeTo: Date()))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 6)
                }
            }
            .padding()
            .navigationTitle(deviceName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EmptyView()
                }
            }
            .task {
                await refreshOnce()
            }
            .onDisappear {
                // Snapshot view: no polling, nothing to tear down.
            }
        }
    }

    @MainActor
    private func refreshOnce() async {
        if isLoading { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let key = try await APIService.shared.fetchFirestickScreenshotKey(id: deviceId)
            let raw = key.publicUrl ?? ("https://app.meulab.fun" + key.url)
            let sep = raw.contains("?") ? "&" : "?"
            let withBust = raw + "\(sep)t=\(Int(Date().timeIntervalSince1970 * 1000))"
            url = URL(string: withBust)
            lastUpdated = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Fire Stick Detail

private struct FirestickDetailView: View {
    let deviceId: String
    let deviceName: String

    @State private var isLoading = false
    @State private var error: String?
    @State private var status: FirestickStatusResponse?
    @State private var screenshot: FirestickScreenshotKeyResponse?

    var body: some View {
        List {
            Section {
                if let status {
                    let fire = status.firestick
                    LabeledContent("TV", value: deviceName)
                    LabeledContent("Ligada", value: boolText(fire.tvOn))
                    LabeledContent("Mostrando Fire Stick", value: boolText(fire.tvShowingFirestick))
                    LabeledContent("ADB", value: fire.adb.deviceState ?? "unknown")
                    if let pkg = fire.foregroundApp?.package {
                        LabeledContent("App", value: pkg)
                    }
                    LabeledContent("Atualizado", value: status.timestamp)
                } else if isLoading {
                    ProgressView("Carregando...")
                } else if let error {
                    Text(error)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Sem dados")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Screenshot") {
                if let screenshotUrl = screenshot?.publicUrl, let url = URL(string: screenshotUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .failure:
                            Text("Falha ao carregar screenshot")
                                .foregroundStyle(.secondary)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Text("Toque em Atualizar para gerar um link temporario.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(deviceName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Atualizar") {
                    Task { await refresh(force: true) }
                }
                .disabled(isLoading)
            }
        }
        .task {
            await refresh(force: false)
        }
    }

    private func refresh(force: Bool) async {
        if isLoading { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let st = APIService.shared.fetchFirestickStatus(id: deviceId, force: force)
            async let key = APIService.shared.fetchFirestickScreenshotKey(id: deviceId)
            let (status, screenshot) = try await (st, key)
            self.status = status
            self.screenshot = screenshot
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func boolText(_ value: Bool?) -> String {
        guard let value else { return "?" }
        return value ? "Sim" : "Nao"
    }
}

#Preview {
    SystemView()
        .environmentObject(AppState())
}
