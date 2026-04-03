import Charts
import SwiftUI
import UIKit

private func systemAdaptiveColor(light: UIColor, dark: UIColor) -> Color {
    Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    )
}

private func systemRGBA(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1)
    -> UIColor
{
    UIColor(red: red, green: green, blue: blue, alpha: alpha)
}

private func systemParseDate(_ timestamp: String) -> Date? {
    let isoWithFractional = ISO8601DateFormatter()
    isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = isoWithFractional.date(from: timestamp) {
        return date
    }

    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: timestamp) {
        return date
    }

    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    for format in [
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ssZ",
    ] {
        dateFormatter.dateFormat = format
        if let date = dateFormatter.date(from: timestamp) {
            return date
        }
    }

    return nil
}

private enum SystemTheme {
    static let piGreen = Color(red: 0.27, green: 0.78, blue: 0.37)
    static let piLeaf = Color(red: 0.17, green: 0.62, blue: 0.28)
    static let piRed = Color(red: 0.82, green: 0.21, blue: 0.32)
    static let piBlue = Color(red: 0.14, green: 0.38, blue: 0.84)
    static let amber = Color(red: 0.95, green: 0.57, blue: 0.15)
    static let ink = systemAdaptiveColor(
        light: systemRGBA(0.08, 0.11, 0.20),
        dark: systemRGBA(0.92, 0.95, 1.00)
    )
    static let mist = systemAdaptiveColor(
        light: systemRGBA(0.94, 0.97, 1.00),
        dark: systemRGBA(0.09, 0.11, 0.18)
    )
    static let cloud = systemAdaptiveColor(
        light: systemRGBA(0.98, 0.99, 1.00),
        dark: systemRGBA(0.04, 0.06, 0.12)
    )
    static let canvasMid = systemAdaptiveColor(
        light: systemRGBA(1.00, 1.00, 1.00),
        dark: systemRGBA(0.06, 0.08, 0.15)
    )
    static let canvasEnd = systemAdaptiveColor(
        light: systemRGBA(0.98, 0.99, 0.97),
        dark: systemRGBA(0.08, 0.10, 0.17)
    )
    static let surfaceTop = systemAdaptiveColor(
        light: systemRGBA(1.00, 1.00, 1.00, 0.98),
        dark: systemRGBA(0.13, 0.16, 0.24, 0.98)
    )
    static let surfaceStroke = systemAdaptiveColor(
        light: systemRGBA(1.00, 1.00, 1.00, 0.92),
        dark: systemRGBA(0.26, 0.31, 0.42, 0.88)
    )
    static let shadow = systemAdaptiveColor(
        light: systemRGBA(0.05, 0.12, 0.26),
        dark: systemRGBA(0.00, 0.00, 0.00)
    )
}

private struct SystemPanelBackground: View {
    let cornerRadius: CGFloat
    let highlight: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [SystemTheme.surfaceTop, SystemTheme.mist],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [highlight.opacity(0.12), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [highlight.opacity(0.28), SystemTheme.surfaceStroke],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            }
            .shadow(color: SystemTheme.shadow.opacity(0.08), radius: 22, x: 0, y: 12)
            .shadow(color: highlight.opacity(0.07), radius: 14, x: 0, y: 6)
    }
}

extension View {
    fileprivate func systemPanel(cornerRadius: CGFloat = 18, highlight: Color = SystemTheme.piBlue)
        -> some View
    {
        background(SystemPanelBackground(cornerRadius: cornerRadius, highlight: highlight))
    }
}

private struct RaspberryPiGlyph: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Group {
                Circle().offset(x: -size * 0.18, y: -size * 0.05)
                Circle().offset(x: 0, y: -size * 0.12)
                Circle().offset(x: size * 0.18, y: -size * 0.05)
                Circle().offset(x: -size * 0.24, y: size * 0.14)
                Circle().offset(x: 0, y: size * 0.18)
                Circle().offset(x: size * 0.24, y: size * 0.14)
                Circle().frame(width: size * 0.34, height: size * 0.34)
            }
            .frame(width: size * 0.32, height: size * 0.32)
            .foregroundStyle(
                LinearGradient(
                    colors: [SystemTheme.piRed, SystemTheme.piRed.opacity(0.86)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(SystemTheme.piRed.opacity(0.95))
                .frame(width: size * 0.12, height: size * 0.14)
                .offset(y: -size * 0.27)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [SystemTheme.piGreen, SystemTheme.piLeaf],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.28, height: size * 0.15)
                .rotationEffect(.degrees(-28))
                .offset(x: -size * 0.12, y: -size * 0.37)

            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [SystemTheme.piGreen, SystemTheme.piLeaf],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.28, height: size * 0.15)
                .rotationEffect(.degrees(28))
                .offset(x: size * 0.12, y: -size * 0.37)
        }
        .frame(width: size, height: size)
    }
}

private struct SystemToolbarTitle: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                SystemTheme.piGreen.opacity(0.2), SystemTheme.piBlue.opacity(0.12),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "cpu")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SystemTheme.piBlue)
            }

            Text("Sistema")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(
                    LinearGradient(
                        colors: [SystemTheme.piLeaf, SystemTheme.piBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sistema")
    }
}

private struct SystemInfoChip: View {
    let title: String
    let value: String
    let tint: Color
    var icon: String? = nil
    var showsPi = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SystemTheme.ink.opacity(0.56))

            HStack(spacing: 6) {
                if showsPi {
                    RaspberryPiGlyph(size: 16)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                }

                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SystemTheme.ink)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(tint.opacity(0.10))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct SystemQuickMetric: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)

            Text(value)
                .font(.callout.bold())
                .monospacedDigit()
                .foregroundStyle(SystemTheme.ink)

            Text(label)
                .font(.caption)
                .foregroundStyle(SystemTheme.ink.opacity(0.56))
        }
    }
}

private enum SystemAnalyticsDestination: String, Identifiable, CaseIterable {
    case cpu
    case memory
    case disk
    case temperature
    case environment
    case traffic
    case satellite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memória"
        case .disk: return "Disco"
        case .temperature: return "Temperatura"
        case .environment: return "Ambiente"
        case .traffic: return "Radar"
        case .satellite: return "Satélite"
        }
    }

    var subtitle: String {
        switch self {
        case .cpu: return "Uso, pico e tendência"
        case .memory: return "Consumo e disponibilidade"
        case .disk: return "Ocupação e evolução"
        case .temperature: return "Calor e estabilidade"
        case .environment: return "Sensor e histórico recente"
        case .traffic: return "Volume e leitura ADS-B"
        case .satellite: return "Passes e desempenho"
        }
    }

    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .temperature: return "thermometer.medium"
        case .environment: return "humidity.fill"
        case .traffic: return "airplane"
        case .satellite: return "antenna.radiowaves.left.and.right"
        }
    }

    var tint: Color {
        switch self {
        case .cpu: return .blue
        case .memory: return .purple
        case .disk: return .orange
        case .temperature: return SystemTheme.amber
        case .environment: return .cyan
        case .traffic: return SystemTheme.piGreen
        case .satellite: return SystemTheme.piBlue
        }
    }

    var analyticsFocus: AnalyticsFocusPanel {
        switch self {
        case .cpu, .memory, .disk, .temperature: return .system
        case .environment: return .environment
        case .traffic: return .traffic
        case .satellite: return .satellite
        }
    }

    var metricRawValue: String? {
        switch self {
        case .cpu, .memory, .disk, .temperature:
            return rawValue
        case .environment, .traffic, .satellite:
            return nil
        }
    }
}

private struct SystemAnalyticsLaunchTile: View {
    let destination: SystemAnalyticsDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(destination.tint.opacity(0.14))
                        .frame(width: 34, height: 34)

                    Image(systemName: destination.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(destination.tint)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(destination.tint.opacity(0.82))
            }

            Text(destination.title)
                .font(.headline)
                .foregroundStyle(SystemTheme.ink)

            Text(destination.subtitle)
                .font(.caption)
                .foregroundStyle(SystemTheme.ink.opacity(0.58))
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .systemPanel(cornerRadius: 20, highlight: destination.tint)
    }
}

private enum SystemNode: String, CaseIterable, Identifiable {
    case pi = "pi"
    case macMini = "mac"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pi: return "Pi5"
        case .macMini: return "Mac Mini"
        }
    }

    var icon: String {
        switch self {
        case .pi: return "cpu"
        case .macMini: return "desktopcomputer"
        }
    }

    var tint: Color {
        switch self {
        case .pi: return SystemTheme.piGreen
        case .macMini: return .blue
        }
    }
}

struct SystemView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var snapshotTarget: FirestickSnapshotTarget?
    @State private var analyticsDestination: SystemAnalyticsDestination?
    @State private var systemAnalytics: SystemAnalytics?
    @State private var selectedCPUPointID: Date?
    @State private var selectedNode: SystemNode = .pi
    @State private var macMiniCPUPointID: Date?

    private var isCompactLayout: Bool { horizontalSizeClass == .compact }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    nodePickerBar

                    switch selectedNode {
                    case .pi:
                        if let status = appState.systemStatus {
                            systemContent(status)
                        } else if let error = appState.systemError {
                            ErrorCard(message: error)
                        } else {
                            LoadingCard()
                        }

                    case .macMini:
                        if let status = appState.macMiniStatus {
                            macMiniContent(status)
                        } else if let error = appState.macMiniError {
                            ErrorCard(message: error)
                        } else {
                            LoadingCard()
                        }
                    }
                }
                .padding(.horizontal, isCompactLayout ? 14 : 16)
                .padding(.top, isCompactLayout ? 8 : 4)
                .padding(.bottom, 20)
            }
            .background {
                ZStack {
                    LinearGradient(
                        colors: [SystemTheme.cloud, SystemTheme.canvasMid, SystemTheme.canvasEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [SystemTheme.piGreen.opacity(0.10), .clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 420
                    )

                    RadialGradient(
                        colors: [SystemTheme.piRed.opacity(0.08), .clear],
                        center: .topTrailing,
                        startRadius: 30,
                        endRadius: 360
                    )
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Sistema")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SystemToolbarTitle()
                }
            }
            .task {
                await loadSystemAnalyticsIfNeeded()
                if appState.macMiniStatus == nil {
                    await appState.refreshMacMini()
                }
            }
            .sheet(item: $snapshotTarget) { target in
                FirestickSnapshotView(deviceId: target.id, deviceName: target.name)
            }
            .fullScreenCover(item: $analyticsDestination) { destination in
                AnalyticsView(
                    focus: destination.analyticsFocus,
                    initialMetricRaw: destination.metricRawValue,
                    showsDismissButton: true
                )
                .environmentObject(appState)
            }
        }
    }

    @ViewBuilder
    private func systemContent(_ status: SystemStatus) -> some View {
        systemNodeBar(status)
        realtimeHealthSection(status)
        cpuHistorySection
        environmentSection

        // CPU
        if let cpu = status.cpu, cpu.error == nil {
            SystemCard(title: "CPU", icon: "cpu", color: .blue) {
                Group {
                    if isCompactLayout {
                        VStack(alignment: .leading, spacing: 16) {
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
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                if let l1 = cpu.load1min, let l5 = cpu.load5min,
                                    let l15 = cpu.load15min
                                {
                                    Text("Load Avg")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.2f  %.2f  %.2f", l1, l5, l15))
                                        .font(.callout.monospacedDigit())
                                }

                                Text("\(cpu.cores ?? 4) cores")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
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
                                if let l1 = cpu.load1min, let l5 = cpu.load5min,
                                    let l15 = cpu.load15min
                                {
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
            }
        }

        // Memory
        if let memory = status.memory, memory.error == nil {
            SystemCard(title: "Memória RAM", icon: "memorychip", color: .purple) {
                if let total = memory.totalMb, let used = memory.usedMb,
                    let available = memory.availableMb
                {
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
                if let total = disk.totalGb, let used = disk.usedGb,
                    let available = disk.availableGb
                {
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
                            Label(
                                String(format: "%.1f GB total", total),
                                systemImage: "square.stack.3d.up")
                            Spacer()
                            Label(
                                String(format: "%.1f GB livre", available),
                                systemImage: "checkmark.circle")
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
                                    FirestickDetailView(
                                        deviceId: item.device.id, deviceName: item.device.name)
                                } label: {
                                    FirestickRowView(item: item)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    snapshotTarget = FirestickSnapshotTarget(
                                        id: item.device.id, name: item.device.name)
                                } label: {
                                    Image(systemName: "camera")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .adaptiveGlassButton()
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

                            Text(
                                "\(formatBytes(partition.usedBytes)) / \(formatBytes(partition.totalBytes))"
                            )
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

    private func loadSystemAnalyticsIfNeeded() async {
        guard systemAnalytics == nil else { return }
        do {
            systemAnalytics = try await APIService.shared.fetchSystemAnalytics(
                period: "24h", interval: "15m")
        } catch {
        }
    }

    // MARK: - Node Picker

    private var nodePickerBar: some View {
        HStack(spacing: 0) {
            ForEach(SystemNode.allCases) { node in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedNode = node
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: node.icon)
                            .font(.system(size: 13, weight: .bold))

                        Text(node.label)
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(selectedNode == node ? .white : SystemTheme.ink.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selectedNode == node {
                            Capsule()
                                .fill(node.tint)
                                .shadow(color: node.tint.opacity(0.3), radius: 8, y: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Mac Mini Content

    @ViewBuilder
    private func macMiniContent(_ status: SystemStatus) -> some View {
        macMiniNodeBar(status)
        realtimeHealthSection(status)
        macMiniCPUHistorySection

        // CPU
        if let cpu = status.cpu, cpu.error == nil {
            SystemCard(title: "CPU", icon: "cpu", color: .blue) {
                VStack(alignment: .leading, spacing: 16) {
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
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        if let l1 = cpu.load1min, let l5 = cpu.load5min, let l15 = cpu.load15min {
                            Text("Load Avg")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.2f  %.2f  %.2f", l1, l5, l15))
                                .font(.callout.monospacedDigit())
                        }

                        Text("\(cpu.cores ?? 8) cores")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        // Memory
        if let memory = status.memory, memory.error == nil {
            SystemCard(title: "Memória RAM", icon: "memorychip", color: .purple) {
                if let total = memory.totalMb, let used = memory.usedMb,
                    let available = memory.availableMb
                {
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
                if let total = disk.totalGb, let used = disk.usedGb,
                    let available = disk.availableGb
                {
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
                            Label(
                                String(format: "%.1f GB total", total),
                                systemImage: "square.stack.3d.up")
                            Spacer()
                            Label(
                                String(format: "%.1f GB livre", available),
                                systemImage: "checkmark.circle")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }

        // Processes
        if !appState.macMiniProcesses.isEmpty {
            SystemCard(title: "Top Processos (CPU)", icon: "list.bullet.rectangle", color: .blue) {
                VStack(spacing: 8) {
                    ForEach(appState.macMiniProcesses.prefix(5)) { process in
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
        if !appState.macMiniPartitions.isEmpty {
            SystemCard(title: "Partições", icon: "externaldrive", color: .orange) {
                VStack(spacing: 12) {
                    ForEach(appState.macMiniPartitions) { partition in
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

                            Text(
                                "\(formatBytes(partition.usedBytes)) / \(formatBytes(partition.totalBytes))"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }

        // Network
        if !appState.macMiniNetwork.isEmpty {
            let activeInterfaces = appState.macMiniNetwork.filter {
                $0.rxBytes > 0 || $0.txBytes > 0
            }
            if !activeInterfaces.isEmpty {
                SystemCard(title: "Rede", icon: "arrow.left.and.right", color: .green) {
                    VStack(spacing: 10) {
                        ForEach(activeInterfaces) { iface in
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
    }

    private func macMiniNodeBar(_ status: SystemStatus) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Label("Nó monitorado", systemImage: "desktopcomputer")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SystemTheme.ink.opacity(0.82))

                        Text("ONLINE")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1.0)
                            .foregroundStyle(SystemTheme.piBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(SystemTheme.piBlue.opacity(0.14), in: Capsule())
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(SystemTheme.piBlue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mac Mini")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(SystemTheme.ink)

                            Text(status.location)
                                .font(.subheadline)
                                .foregroundStyle(SystemTheme.ink.opacity(0.62))
                        }
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        SystemTheme.piBlue.opacity(0.16), Color.cyan.opacity(0.10),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)

                        Circle()
                            .stroke(SystemTheme.piBlue.opacity(0.22), lineWidth: 1.2)
                            .frame(width: 64, height: 64)

                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(SystemTheme.piBlue)
                    }

                    Text(statusUpdateText(status))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SystemTheme.ink.opacity(0.62))
                        .multilineTextAlignment(.trailing)
                }
            }

            Text("Telemetria ao vivo do Mac Mini e seus serviços.")
                .font(.callout)
                .foregroundStyle(SystemTheme.ink.opacity(0.62))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let uptime = status.uptime {
                        SystemInfoChip(
                            title: "Uptime",
                            value: uptime.formatted,
                            tint: SystemTheme.piBlue,
                            icon: "clock"
                        )
                    }

                    SystemInfoChip(
                        title: "Plataforma",
                        value: "macOS ARM64",
                        tint: .cyan,
                        icon: "apple.logo"
                    )

                    if let cores = status.cpu?.cores {
                        SystemInfoChip(
                            title: "Cores",
                            value: "\(cores)",
                            tint: .blue,
                            icon: "cpu"
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(20)
        .systemPanel(cornerRadius: 24, highlight: SystemTheme.piBlue)
    }

    @ViewBuilder
    private var macMiniCPUHistorySection: some View {
        if let cpuMetrics = appState.macMiniAnalytics?.cpu {
            let points = cpuChartPoints(cpuMetrics)
            if !points.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CPU")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(SystemTheme.ink)

                            Text("Histórico das últimas 24 horas")
                                .font(.subheadline)
                                .foregroundStyle(SystemTheme.ink.opacity(0.58))
                        }

                        Spacer()

                        Text(
                            String(
                                format: "%.1f%% agora",
                                cpuMetrics.dataPoints.last?.usage ?? cpuMetrics.average)
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SystemTheme.piBlue)
                        .monospacedDigit()
                    }

                    SystemCPUInteractiveChart(
                        points: points,
                        selectedPointID: $macMiniCPUPointID
                    )
                    .frame(height: isCompactLayout ? 230 : 240)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    HStack(spacing: 12) {
                        SystemTrendStat(
                            title: "Média", value: String(format: "%.1f%%", cpuMetrics.average),
                            tint: .blue)
                        SystemTrendStat(
                            title: "Pico", value: String(format: "%.1f%%", cpuMetrics.peak),
                            tint: .orange)
                        SystemTrendStat(
                            title: "Mínimo", value: String(format: "%.1f%%", cpuMetrics.minimum),
                            tint: .green)
                    }
                }
                .padding(20)
                .systemPanel(cornerRadius: 24, highlight: SystemTheme.piBlue)
            }
        }
    }

    private func systemNodeBar(_ status: SystemStatus) -> some View {
        Group {
            if isCompactLayout {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Label("Nó monitorado", systemImage: "desktopcomputer")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(SystemTheme.ink.opacity(0.82))

                                Text("ONLINE")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .tracking(1.0)
                                    .foregroundStyle(SystemTheme.piGreen)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(SystemTheme.piGreen.opacity(0.14), in: Capsule())
                            }

                            HStack(spacing: 10) {
                                RaspberryPiGlyph(size: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(status.hostname)
                                        .font(.system(size: 28, weight: .black, design: .rounded))
                                        .foregroundStyle(SystemTheme.ink)

                                    Text(status.location)
                                        .font(.subheadline)
                                        .foregroundStyle(SystemTheme.ink.opacity(0.62))
                                }
                            }
                        }

                        Spacer(minLength: 12)

                        VStack(alignment: .trailing, spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                SystemTheme.piGreen.opacity(0.16),
                                                SystemTheme.piBlue.opacity(0.10),
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 64, height: 64)

                                Circle()
                                    .stroke(SystemTheme.piGreen.opacity(0.22), lineWidth: 1.2)
                                    .frame(width: 64, height: 64)

                                RaspberryPiGlyph(size: 30)
                            }

                            Text(statusUpdateText(status))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(SystemTheme.ink.opacity(0.62))
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Text("Telemetria ao vivo do Raspberry Pi e dos dispositivos conectados.")
                        .font(.callout)
                        .foregroundStyle(SystemTheme.ink.opacity(0.62))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            if let uptime = status.uptime {
                                SystemInfoChip(
                                    title: "Uptime",
                                    value: uptime.formatted,
                                    tint: SystemTheme.piGreen,
                                    icon: "clock"
                                )
                            }

                            SystemInfoChip(
                                title: "Rede",
                                value: status.wifi?.ssid ?? "sem Wi-Fi",
                                tint: SystemTheme.piBlue,
                                icon: "wifi"
                            )
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Label("Nó monitorado", systemImage: "desktopcomputer")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SystemTheme.ink.opacity(0.82))

                            Text("ONLINE")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .tracking(1.0)
                                .foregroundStyle(SystemTheme.piGreen)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(SystemTheme.piGreen.opacity(0.14), in: Capsule())
                        }

                        HStack(spacing: 10) {
                            RaspberryPiGlyph(size: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(status.hostname)
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(SystemTheme.ink)

                                Text(status.location)
                                    .font(.subheadline)
                                    .foregroundStyle(SystemTheme.ink.opacity(0.62))
                            }
                        }

                        Text("Telemetria ao vivo do Raspberry Pi e dos dispositivos conectados.")
                            .font(.caption)
                            .foregroundStyle(SystemTheme.ink.opacity(0.56))

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                SystemInfoChip(
                                    title: "Host",
                                    value: status.hostname,
                                    tint: SystemTheme.piRed,
                                    showsPi: true
                                )

                                if let uptime = status.uptime {
                                    SystemInfoChip(
                                        title: "Uptime",
                                        value: uptime.formatted,
                                        tint: SystemTheme.piGreen,
                                        icon: "clock"
                                    )
                                }

                                SystemInfoChip(
                                    title: "Rede",
                                    value: status.wifi?.ssid ?? "sem Wi-Fi",
                                    tint: SystemTheme.piBlue,
                                    icon: "wifi"
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                SystemInfoChip(
                                    title: "Host",
                                    value: status.hostname,
                                    tint: SystemTheme.piRed,
                                    showsPi: true
                                )

                                if let uptime = status.uptime {
                                    SystemInfoChip(
                                        title: "Uptime",
                                        value: uptime.formatted,
                                        tint: SystemTheme.piGreen,
                                        icon: "clock"
                                    )
                                }

                                SystemInfoChip(
                                    title: "Rede",
                                    value: status.wifi?.ssid ?? "sem Wi-Fi",
                                    tint: SystemTheme.piBlue,
                                    icon: "wifi"
                                )
                            }
                        }
                    }

                    Spacer(minLength: 16)

                    VStack(alignment: .trailing, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            SystemTheme.piGreen.opacity(0.16),
                                            SystemTheme.piBlue.opacity(0.10),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 78, height: 78)

                            Circle()
                                .stroke(SystemTheme.piGreen.opacity(0.22), lineWidth: 1.2)
                                .frame(width: 78, height: 78)

                            RaspberryPiGlyph(size: 36)
                        }

                        Text(statusUpdateText(status))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SystemTheme.ink.opacity(0.62))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        .padding(20)
        .systemPanel(cornerRadius: 24, highlight: SystemTheme.piGreen)
    }

    private func systemOverviewHeader(_ status: SystemStatus) -> some View {
        Group {
            if isCompactLayout {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Visão geral")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SystemTheme.piBlue.opacity(0.72))
                            .textCase(.uppercase)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(cpuUsageHeadline(status))
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(SystemTheme.ink)

                            if let temp = status.cpu?.temperatureC {
                                Text("\(Int(temp))°C")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.fromName(status.cpu?.temperatureColor))
                            }
                        }

                        Text("uso do processador")
                            .font(.subheadline)
                            .foregroundStyle(SystemTheme.ink.opacity(0.62))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if let memory = status.memory?.usedPercent {
                                SystemQuickMetric(
                                    icon: "memorychip",
                                    value: String(format: "%.1f%%", memory),
                                    label: "RAM",
                                    tint: .purple
                                )
                            }

                            if let disk = status.disk?.usedPercent {
                                SystemQuickMetric(
                                    icon: "internaldrive",
                                    value: String(format: "%.1f%%", disk),
                                    label: "Disco",
                                    tint: .orange
                                )
                            }

                            if let wifi = status.wifi?.qualityPercent {
                                SystemQuickMetric(
                                    icon: "wifi",
                                    value: "\(wifi)%",
                                    label: "Wi-Fi",
                                    tint: wifi > 60 ? SystemTheme.piGreen : SystemTheme.amber
                                )
                            }
                        }
                    }
                }
            } else {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Visão geral")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SystemTheme.piBlue.opacity(0.72))
                            .textCase(.uppercase)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(cpuUsageHeadline(status))
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(SystemTheme.ink)

                            if let temp = status.cpu?.temperatureC {
                                Text("\(Int(temp))°C")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Color.fromName(status.cpu?.temperatureColor))
                            }
                        }

                        Text("uso do processador")
                            .font(.subheadline)
                            .foregroundStyle(SystemTheme.ink.opacity(0.62))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 10) {
                        if let memory = status.memory?.usedPercent {
                            SystemQuickMetric(
                                icon: "memorychip",
                                value: String(format: "%.1f%%", memory),
                                label: "RAM",
                                tint: .purple
                            )
                        }

                        if let disk = status.disk?.usedPercent {
                            SystemQuickMetric(
                                icon: "internaldrive",
                                value: String(format: "%.1f%%", disk),
                                label: "Disco",
                                tint: .orange
                            )
                        }

                        if let wifi = status.wifi?.qualityPercent {
                            SystemQuickMetric(
                                icon: "wifi",
                                value: "\(wifi)%",
                                label: "Wi-Fi",
                                tint: wifi > 60 ? SystemTheme.piGreen : SystemTheme.amber
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .systemPanel(cornerRadius: 24, highlight: SystemTheme.piBlue)
    }

    private func realtimeHealthSection(_ status: SystemStatus) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Saúde em Tempo Real")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SystemTheme.ink)

                    Text("CPU, RAM e temperatura do nó monitorado")
                        .font(.subheadline)
                        .foregroundStyle(SystemTheme.ink.opacity(0.58))
                }

                Spacer()
            }

            HStack(spacing: isCompactLayout ? 10 : 20) {
                RealtimeGaugeCard(
                    title: "CPU",
                    value: status.cpu?.usagePercent ?? 0,
                    maxValue: 100,
                    tint: .blue,
                    symbol: "cpu",
                    valueLabel: String(format: "%.0f%%", status.cpu?.usagePercent ?? 0)
                )

                RealtimeGaugeCard(
                    title: "RAM",
                    value: status.memory?.usedPercent ?? 0,
                    maxValue: 100,
                    tint: .purple,
                    symbol: "memorychip",
                    valueLabel: String(format: "%.0f%%", status.memory?.usedPercent ?? 0)
                )

                RealtimeGaugeCard(
                    title: "Temp",
                    value: status.cpu?.temperatureC ?? 0,
                    maxValue: 100,
                    tint: temperatureGradient,
                    symbol: "thermometer.medium",
                    valueLabel: status.cpu?.temperatureC.map { String(format: "%.0f°C", $0) }
                        ?? "--"
                )
            }
        }
        .padding(20)
        .systemPanel(cornerRadius: 24, highlight: SystemTheme.piBlue)
    }

    @ViewBuilder
    private var cpuHistorySection: some View {
        if let cpuMetrics = systemAnalytics?.cpu {
            let points = cpuChartPoints(cpuMetrics)
            if !points.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CPU")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(SystemTheme.ink)

                            Text("Histórico das últimas 24 horas")
                                .font(.subheadline)
                                .foregroundStyle(SystemTheme.ink.opacity(0.58))
                        }

                        Spacer()

                        Text(
                            String(
                                format: "%.1f%% agora",
                                cpuMetrics.dataPoints.last?.usage ?? cpuMetrics.average)
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SystemTheme.piBlue)
                        .monospacedDigit()
                    }

                    SystemCPUInteractiveChart(
                        points: points,
                        selectedPointID: $selectedCPUPointID
                    )
                    .frame(height: isCompactLayout ? 230 : 240)
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    HStack(spacing: 12) {
                        SystemTrendStat(
                            title: "Média", value: String(format: "%.1f%%", cpuMetrics.average),
                            tint: .blue)
                        SystemTrendStat(
                            title: "Pico", value: String(format: "%.1f%%", cpuMetrics.peak),
                            tint: .orange)
                        SystemTrendStat(
                            title: "Mínimo", value: String(format: "%.1f%%", cpuMetrics.minimum),
                            tint: .green)
                    }
                }
                .padding(20)
                .systemPanel(cornerRadius: 24, highlight: SystemTheme.piBlue)
            }
        }
    }

    private var temperatureGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .green, location: 0.50),
                .init(color: .orange, location: 0.70),
                .init(color: .red, location: 0.85),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func cpuChartPoints(_ metrics: CPUMetrics) -> [SystemCPUChartPoint] {
        metrics.dataPoints.compactMap { point in
            guard let date = systemParseDate(point.timestamp) else { return nil }
            let timestampText = date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
            return SystemCPUChartPoint(
                date: date,
                usage: point.usage,
                valueText: String(format: "%.1f%%", point.usage),
                timestampText: timestampText,
                loadText: formattedLoadAverage(point)
            )
        }
    }

    private func formattedLoadAverage(_ point: CPUDataPoint) -> String? {
        guard
            let load1 = point.load1min,
            let load5 = point.load5min,
            let load15 = point.load15min
        else { return nil }

        return String(format: "Load %.2f / %.2f / %.2f", load1, load5, load15)
    }

    private func cpuUsageHeadline(_ status: SystemStatus) -> String {
        guard let cpu = status.cpu?.usagePercent else { return "--%" }
        return String(format: "%.0f%%", cpu)
    }

    @ViewBuilder
    private var analyticsLauncherSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Históricos e Análises")
                    .font(.headline)
                    .foregroundStyle(SystemTheme.ink)

                Spacer()

                Text("fullscreen")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SystemTheme.ink.opacity(0.48))
            }

            let columns =
                isCompactLayout
                ? [GridItem(.flexible()), GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(SystemAnalyticsDestination.allCases) { destination in
                    Button {
                        analyticsDestination = destination
                    } label: {
                        SystemAnalyticsLaunchTile(destination: destination)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .systemPanel(cornerRadius: 24, highlight: SystemTheme.piBlue)
    }

    @ViewBuilder
    private var environmentSection: some View {
        if let sensor = appState.tuyaSensor, let current = sensor.current {
            SystemCard(title: "Sensor Casa", icon: "humidity.fill", color: .cyan) {
                VStack(alignment: .leading, spacing: 12) {
                    TuyaSensorCard(sensor: sensor, current: current)
                    Button {
                        analyticsDestination = .environment
                    } label: {
                        Label("Abrir histórico do sensor", systemImage: "arrow.up.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.cyan.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if let message = appState.tuyaSensorError {
            SystemCard(title: "Sensor Casa", icon: "humidity.fill", color: .cyan) {
                TuyaSensorStatusCard(message: message)
            }
        }
    }

    private func statusUpdateText(_ status: SystemStatus) -> String {
        guard
            let date = Formatters.isoDate.date(from: status.timestamp)
                ?? Formatters.isoDateNoFrac.date(from: status.timestamp)
        else {
            return "Atualização indisponível"
        }
        return
            "Atualizado \(Formatters.relativeDate.localizedString(for: date, relativeTo: Date()))"
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.body.weight(.semibold))
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(SystemTheme.ink)

                Spacer()
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .systemPanel(cornerRadius: 22, highlight: color)
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

                Text(
                    suffix == "°C"
                        ? String(format: "%.0f%@", value, suffix)
                        : String(format: "%.0f%@", value, suffix)
                )
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(SystemTheme.ink)
            }
            .frame(width: 60, height: 60)

            Text(title)
                .font(.caption2)
                .foregroundStyle(SystemTheme.ink.opacity(0.56))
        }
    }
}

private struct RealtimeGaugeCard: View {
    let title: String
    let value: Double
    let maxValue: Double
    let tint: AnyShapeStyle
    let symbol: String
    let valueLabel: String

    init<S: ShapeStyle>(
        title: String, value: Double, maxValue: Double, tint: S, symbol: String, valueLabel: String
    ) {
        self.title = title
        self.value = value
        self.maxValue = maxValue
        self.tint = AnyShapeStyle(tint)
        self.symbol = symbol
        self.valueLabel = valueLabel
    }

    var body: some View {
        VStack(spacing: 10) {
            Gauge(value: value, in: 0...maxValue) {
                EmptyView()
            } currentValueLabel: {
                Text(valueLabel)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(SystemTheme.ink)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(tint)
            .scaleEffect(1.12)

            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SystemTheme.ink.opacity(0.68))
                .labelStyle(.titleAndIcon)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SystemCPUChartPoint: Identifiable {
    let date: Date
    let usage: Double
    let valueText: String
    let timestampText: String
    let loadText: String?

    var id: Date { date }
}

private struct SystemCPUInteractiveChart: View {
    let points: [SystemCPUChartPoint]
    @Binding var selectedPointID: Date?

    private var selectedPoint: SystemCPUChartPoint? {
        guard let selectedPointID else { return nil }
        return points.first(where: { $0.id == selectedPointID })
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Horário", point.date),
                    y: .value("CPU", point.usage)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [SystemTheme.piBlue.opacity(0.28), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Horário", point.date),
                    y: .value("CPU", point.usage)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(SystemTheme.piBlue)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                if selectedPoint?.id == point.id {
                    PointMark(
                        x: .value("Horário", point.date),
                        y: .value("CPU", point.usage)
                    )
                    .foregroundStyle(SystemTheme.piBlue)
                    .symbolSize(70)
                }
            }

            if let selectedPoint {
                RuleMark(x: .value("Horário", selectedPoint.date))
                    .foregroundStyle(SystemTheme.piBlue.opacity(0.36))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text("\(Int(number.rounded()))")
                            .foregroundStyle(SystemTheme.ink.opacity(0.58))
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(Color(.systemBackground).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrameAnchor = proxy.plotFrame {
                    let plotFrame = geometry[plotFrameAnchor]

                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateSelection(
                                            at: value.location, proxy: proxy, geometry: geometry)
                                    }
                                    .onEnded { value in
                                        updateSelection(
                                            at: value.location, proxy: proxy, geometry: geometry)
                                    }
                            )

                        if let selectedPoint,
                            let plotX = proxy.position(forX: selectedPoint.date),
                            let plotY = proxy.position(forY: selectedPoint.usage)
                        {
                            SystemChartTooltip(point: selectedPoint)
                                .frame(width: 188, alignment: .leading)
                                .position(
                                    x: tooltipXPosition(
                                        plotX: plotFrame.minX + plotX, plotFrame: plotFrame),
                                    y: tooltipYPosition(
                                        plotY: plotFrame.minY + plotY, plotFrame: plotFrame)
                                )
                        }
                    }
                }
            }
        }
        .onChange(of: points.map(\.id)) { _, newIDs in
            if let selectedPointID, !newIDs.contains(selectedPointID) {
                self.selectedPointID = nil
            }
        }
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else {
            selectedPointID = nil
            return
        }

        let relativeX = location.x - plotFrame.origin.x
        guard let selectedDate = proxy.value(atX: relativeX, as: Date.self) else { return }

        selectedPointID =
            points.min {
                abs($0.date.timeIntervalSince(selectedDate))
                    < abs($1.date.timeIntervalSince(selectedDate))
            }?.id
    }

    private func tooltipXPosition(plotX: CGFloat, plotFrame: CGRect) -> CGFloat {
        let width: CGFloat = 188
        let half = width / 2
        return min(max(plotX, plotFrame.minX + half + 8), plotFrame.maxX - half - 8)
    }

    private func tooltipYPosition(plotY: CGFloat, plotFrame: CGRect) -> CGFloat {
        let height: CGFloat = selectedPoint?.loadText == nil ? 84 : 102
        let half = height / 2
        let above = plotY - half - 18
        let minY = plotFrame.minY + half + 8
        if above >= minY {
            return above
        }
        return min(plotFrame.maxY - half - 8, plotY + half + 18)
    }
}

private struct SystemChartTooltip: View {
    let point: SystemCPUChartPoint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(SystemTheme.piBlue)
                    .frame(width: 8, height: 8)

                Text(point.valueText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SystemTheme.ink)
                    .monospacedDigit()
            }

            Text("CPU")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SystemTheme.ink)

            Text(point.timestampText)
                .font(.caption2)
                .foregroundStyle(SystemTheme.ink.opacity(0.58))

            if let loadText = point.loadText {
                Text(loadText)
                    .font(.caption2)
                    .foregroundStyle(SystemTheme.ink.opacity(0.58))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SystemTheme.piBlue.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: SystemTheme.shadow.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

private struct SystemTrendStat: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SystemTheme.ink.opacity(0.56))

            Text(value)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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

    private func subtitle(tvOn: Bool?, showing: Bool?, adbState: String, package: String?) -> String
    {
        var parts: [String] = []
        if let tvOn {
            parts.append(tvOn ? "Ligada" : "Desligada")
        } else {
            parts.append("Estado: ?")
        }
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
                    Text(
                        "Atualizado \(Formatters.relativeDate.localizedString(for: lastUpdated, relativeTo: Date()))"
                    )
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
            let raw = key.publicUrl ?? (NetworkEnvironment.shared.apiBaseURL + key.url)
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
