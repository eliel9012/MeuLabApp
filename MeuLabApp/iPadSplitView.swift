import SwiftUI

// MARK: - Sidebar Components

struct iPadSidebarRow: View {
    let tab: ContentView.Tab
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tab.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 20)
            
            Text(tab.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
            
            Spacer()
            
            // Status indicators
            if hasActiveAlerts(for: tab) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? .blue : Color.clear)
        )
        .contentShape(Rectangle())
    }
    
    private func hasActiveAlerts(for tab: ContentView.Tab) -> Bool {
        switch tab {
        case .alerts, .system, .remote:
            return true // In real app, check actual alerts
        default:
            return false
        }
    }
}

struct iPadQuickMetric: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Detail Views

struct DetailView: View {
    let detail: DetailItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                detailContent
            }
            .navigationTitle(detail.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var detailContent: some View {
        switch detail {
        case .cpuDetails:
            CPUDetailsView()
        case .memoryDetails:
            MemoryDetailsView()
        case .diskDetails:
            DiskDetailsView()
        case .networkDetails:
            NetworkDetailsView()
        case .alertDetails:
            AlertDetailsView()
        case .flightDetails(let flightId):
            FlightDetailsView(flightId: flightId)
        case .containerDetails(let containerName):
            ContainerDetailsView(containerName: containerName)
        }
    }
}

// MARK: - Detail Item Enum

enum DetailItem: Identifiable, Hashable {
    case cpuDetails
    case memoryDetails
    case diskDetails
    case networkDetails
    case alertDetails
    case flightDetails(String)
    case containerDetails(String)
    
    var id: String {
        switch self {
        case .cpuDetails:
            return "cpu-details"
        case .memoryDetails:
            return "memory-details"
        case .diskDetails:
            return "disk-details"
        case .networkDetails:
            return "network-details"
        case .alertDetails:
            return "alert-details"
        case .flightDetails(let id):
            return "flight-\(id)"
        case .containerDetails(let name):
            return "container-\(name)"
        }
    }
    
    var title: String {
        switch self {
        case .cpuDetails:
            return "Detalhes da CPU"
        case .memoryDetails:
            return "Detalhes da Memória"
        case .diskDetails:
            return "Detalhes do Disco"
        case .networkDetails:
            return "Detalhes da Rede"
        case .alertDetails:
            return "Detalhes dos Alertas"
        case .flightDetails(let id):
            return "Voo \(id)"
        case .containerDetails(let name):
            return "Container \(name)"
        }
    }
}

// MARK: - Specific Detail Views

struct CPUDetailsView: View {
    @EnvironmentObject var appState: AppState
    @State private var detailedData: CPUDetailedData?
    @State private var isLoading = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Current Status
            if let status = appState.systemStatus?.cpu {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Status Atual")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 16) {
                        DetailMetricCard(
                            title: "Uso",
                            value: String(format: "%.1f%%", status.usagePercent ?? 0),
                            color: .blue
                        )
                        
                        if let temp = status.temperatureC {
                            DetailMetricCard(
                                title: "Temperatura",
                                value: String(format: "%.1f°C", temp),
                                color: .red
                            )
                        }
                        
                        if let cores = status.cores {
                            DetailMetricCard(
                                title: "Cores",
                                value: "\(cores)",
                                color: .green
                            )
                        }
                    }
                    
                    // Load Average
                    if let l1 = status.load1min, let l5 = status.load5min, let l15 = status.load15min {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Load Average")
                                .font(.headline)
                            
                            HStack(spacing: 20) {
                                VStack {
                                    Text("1 min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.2f", l1))
                                        .font(.title3)
                                        .fontWeight(.medium)
                                }
                                
                                VStack {
                                    Text("5 min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.2f", l5))
                                        .font(.title3)
                                        .fontWeight(.medium)
                                }
                                
                                VStack {
                                    Text("15 min")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.2f", l15))
                                        .font(.title3)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding()
                        .glassCard(cornerRadius: 12)
                    }
                }
            }
            
            // Historical Data
            if isLoading {
                ProgressView("Carregando dados históricos...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let data = detailedData {
                HistoricalCPUView(data: data)
            }
        }
        .padding()
        .task {
            await loadDetailedData()
        }
    }
    
    private func loadDetailedData() async {
        isLoading = true
        
        // Simulate loading detailed data
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            self.detailedData = CPUDetailedData.sample
            self.isLoading = false
        }
    }
}

struct DetailMetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct HistoricalCPUView: View {
    let data: CPUDetailedData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Histórico (24h)")
                .font(.title2)
                .fontWeight(.bold)
            
            // Chart (placeholder for now)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 200)
                .overlay {
                    Text("Gráfico de CPU")
                        .foregroundStyle(.secondary)
                }
            
            // Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatItem(title: "Média", value: String(format: "%.1f%%", data.averageUsage))
                StatItem(title: "Pico", value: String(format: "%.1f%%", data.peakUsage))
                StatItem(title: "Mínima", value: String(format: "%.1f%%", data.minUsage))
                StatItem(title: "Temp. Média", value: String(format: "%.1f°C", data.averageTemp))
            }
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Data Models

struct CPUDetailedData {
    let averageUsage: Double
    let peakUsage: Double
    let minUsage: Double
    let averageTemp: Double
    let hourlyData: [CPUHourlyData]
    
    static let sample = CPUDetailedData(
        averageUsage: 45.2,
        peakUsage: 89.7,
        minUsage: 12.3,
        averageTemp: 52.1,
        hourlyData: (0..<24).map { hour in
            CPUHourlyData(
                hour: hour,
                usage: Double.random(in: 20...80),
                temperature: Double.random(in: 45...65)
            )
        }
    )
}

struct CPUHourlyData {
    let hour: Int
    let usage: Double
    let temperature: Double
}

// MARK: - Placeholder Detail Views

struct MemoryDetailsView: View {
    var body: some View {
        VStack {
            Text("Detalhes da Memória")
                .font(.title)
            Text("Em desenvolvimento...")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct DiskDetailsView: View {
    var body: some View {
        VStack {
            Text("Detalhes do Disco")
                .font(.title)
            Text("Em desenvolvimento...")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct NetworkDetailsView: View {
    var body: some View {
        VStack {
            Text("Detalhes da Rede")
                .font(.title)
            Text("Em desenvolvimento...")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct AlertDetailsView: View {
    var body: some View {
        VStack {
            Text("Detalhes dos Alertas")
                .font(.title)
            Text("Em desenvolvimento...")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct FlightDetailsView: View {
    let flightId: String
    
    var body: some View {
        VStack {
            Text("Detalhes do Voo")
                .font(.title)
            Text("Voo: \(flightId)")
                .foregroundStyle(.secondary)
            Text("Em desenvolvimento...")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct ContainerDetailsView: View {
    let containerName: String
    
    var body: some View {
        VStack {
            Text("Detalhes do Container")
                .font(.title)
            Text("Container: \(containerName)")
                .foregroundStyle(.secondary)
            Text("Em desenvolvimento...")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(PushNotificationManager.shared)
        .environmentObject(NotificationFeedManager.shared)
}