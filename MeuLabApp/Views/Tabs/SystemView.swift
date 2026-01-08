import SwiftUI

struct SystemView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
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
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)

        // CPU
        if let cpu = status.cpu, cpu.error == nil {
            cpuSection(cpu)
        }

        // Memory
        if let memory = status.memory, memory.error == nil {
            memorySection(memory)
        }

        // Disk
        if let disk = status.disk, disk.error == nil {
            diskSection(disk)
        }

        // WiFi
        if let wifi = status.wifi {
            wifiSection(wifi)
        }
    }

    @ViewBuilder
    private func cpuSection(_ cpu: CPUStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.blue)
                Text("CPU")
                    .font(.headline)
            }

            HStack(spacing: 16) {
                // Usage gauge
                GaugeView(
                    value: cpu.usagePercent ?? 0,
                    maxValue: 100,
                    title: "Uso",
                    color: .blue
                )

                // Temperature gauge
                if let temp = cpu.temperatureC {
                    GaugeView(
                        value: temp,
                        maxValue: 100,
                        title: "Temp",
                        color: Color(cpu.temperatureColor),
                        suffix: "°C"
                    )
                }
            }

            // Load averages
            HStack {
                Text("Load:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let l1 = cpu.load1min, let l5 = cpu.load5min, let l15 = cpu.load15min {
                    Text(String(format: "%.2f / %.2f / %.2f", l1, l5, l15))
                        .font(.caption)
                        .monospacedDigit()
                }

                Spacer()

                Text("\(cpu.cores ?? 4) cores")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func memorySection(_ memory: MemoryStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "memorychip")
                    .foregroundStyle(.purple)
                Text("Memória RAM")
                    .font(.headline)
            }

            if let total = memory.totalMb, let used = memory.usedMb, let available = memory.availableMb {
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func diskSection(_ disk: DiskStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.orange)
                Text("Armazenamento")
                    .font(.headline)
            }

            if let total = disk.totalGb, let used = disk.usedGb, let available = disk.availableGb {
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    @ViewBuilder
    private func wifiSection(_ wifi: WiFiStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wifi")
                    .foregroundStyle(.green)
                Text("Wi-Fi")
                    .font(.headline)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let ssid = wifi.ssid {
                        Text(ssid)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if let signal = wifi.signalDbm {
                        Text("\(signal) dBm")
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
        .padding()
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

#Preview {
    SystemView()
        .environmentObject(AppState())
}
