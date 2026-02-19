import SwiftUI
import Charts

struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPeriod: AnalyticsPeriod = .last24h
    @State private var selectedMetric: AnalyticsMetric = .cpu
    @State private var systemAnalytics: SystemAnalytics?
    @State private var adsbAnalytics: ADSBAnalytics?
    @State private var satelliteAnalytics: SatelliteAnalytics?
    @State private var isLoading = false
    @State private var error: String?
    
    enum AnalyticsPeriod: String, CaseIterable {
        case last1h = "1h"
        case last6h = "6h"
        case last24h = "24h"
        case last7d = "7d"
        case last30d = "30d"
        
        var displayName: String {
            switch self {
            case .last1h: return "Última hora"
            case .last6h: return "Últimas 6h"
            case .last24h: return "Últimas 24h"
            case .last7d: return "Últimos 7 dias"
            case .last30d: return "Últimos 30 dias"
            }
        }
        
        var interval: String {
            switch self {
            case .last1h: return "1m"
            case .last6h: return "5m"
            case .last24h: return "15m"
            case .last7d: return "1h"
            case .last30d: return "6h"
            }
        }
    }
    
    enum AnalyticsMetric: String, CaseIterable {
        case cpu = "cpu"
        case memory = "memory"
        case disk = "disk"
        case temperature = "temperature"
        
        var displayName: String {
            switch self {
            case .cpu: return "CPU"
            case .memory: return "Memória"
            case .disk: return "Disco"
            case .temperature: return "Temperatura"
            }
        }
        
        var color: Color {
            switch self {
            case .cpu: return .blue
            case .memory: return .purple
            case .disk: return .orange
            case .temperature: return .red
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period and Metric Selection
                    controlSection
                    
                    // System Metrics Chart
                    if let analytics = systemAnalytics {
                        systemMetricsSection(analytics)
                    }
                    
                    // ADSB Analytics
                    if let adsb = adsbAnalytics {
                        adsbAnalyticsSection(adsb)
                    }
                    
                    // Satellite Analytics
                    if let satellite = satelliteAnalytics {
                        satelliteAnalyticsSection(satellite)
                    }
                    
                    if isLoading {
                        ProgressView("Carregando analytics...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    
                    if let error = error {
                        ErrorCard(message: error)
                            .onTapGesture {
                                loadAnalytics()
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button {
                            loadAnalytics()
                        } label: {
                            Label("Atualizar", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .onAppear {
            loadAnalytics()
        }
        .onChange(of: selectedPeriod) { _, _ in
            loadAnalytics()
        }
    }
    
    @ViewBuilder
    private var controlSection: some View {
        VStack(spacing: 16) {
            // Period Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Período")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                            Button {
                                withAnimation(.spring()) {
                                    selectedPeriod = period
                                }
                            } label: {
                                Text(period.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedPeriod == period ? Color.blue : Color(.systemGray6))
                                    )
                                    .foregroundStyle(selectedPeriod == period ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Metric Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Métrica do Sistema")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AnalyticsMetric.allCases, id: \.self) { metric in
                            Button {
                                withAnimation(.spring()) {
                                    selectedMetric = metric
                                }
                            } label: {
                                Text(metric.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedMetric == metric ? metric.color.opacity(0.2) : Color(.systemGray6))
                                    )
                                    .foregroundStyle(selectedMetric == metric ? metric.color : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func systemMetricsSection(_ analytics: SystemAnalytics) -> some View {
        VStack(spacing: 16) {
            // Main Chart
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedMetric.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    trendIndicator(for: selectedMetric, in: analytics)
                }
                
                Chart {
                    switch selectedMetric {
                    case .cpu:
                        ForEach(analytics.cpu.dataPoints, id: \.timestamp) { point in
                            LineMark(
                                x: .value("Tempo", parseDate(point.timestamp)),
                                y: .value("Uso %", point.usage)
                            )
                            .foregroundStyle(.blue)
                            .symbol(.circle)
                        }
                    case .memory:
                        ForEach(analytics.memory.dataPoints, id: \.timestamp) { point in
                            LineMark(
                                x: .value("Tempo", parseDate(point.timestamp)),
                                y: .value("Uso %", point.usedPercent)
                            )
                            .foregroundStyle(.purple)
                            .symbol(.square)
                        }
                    case .disk:
                        ForEach(analytics.disk.dataPoints, id: \.timestamp) { point in
                            LineMark(
                                x: .value("Tempo", parseDate(point.timestamp)),
                                y: .value("Uso %", point.usedPercent)
                            )
                            .foregroundStyle(.orange)
                            .symbol(.triangle)
                        }
                    case .temperature:
                        ForEach(analytics.temperature.dataPoints, id: \.timestamp) { point in
                            LineMark(
                                x: .value("Tempo", parseDate(point.timestamp)),
                                y: .value("Temp °C", point.temperature)
                            )
                            .foregroundStyle(.red)
                            .symbol(.diamond)
                        }
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel("\(value.as(Double.self) ?? 0, specifier: "%.0f")%")
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            // Stats Cards
            HStack(spacing: 12) {
                ForEach(statCards(for: selectedMetric, in: analytics), id: \.title) { card in
                    StatCardMini(title: card.title, value: card.value, color: card.color, trend: card.trend)
                }
            }
        }
    }
    
    @ViewBuilder
    private func adsbAnalyticsSection(_ adsb: ADSBAnalytics) -> some View {
        VStack(spacing: 16) {
            Text("Tráfego Aéreo")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Hourly Chart
            VStack(alignment: .leading, spacing: 12) {
                Text("Voos por Hora")
                    .font(.headline)
                
                Chart {
                    ForEach(adsb.hourlyStats, id: \.hour) { stat in
                        BarMark(
                            x: .value("Hora", stat.hour),
                            y: .value("Voos", stat.flightCount)
                        )
                        .foregroundStyle(.blue)
                        .opacity(0.8)
                    }
                }
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        AxisGridLine()
                        AxisValueLabel("\(value.as(Int.self) ?? 0)h")
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            
            // Top Aircraft Types
            VStack(alignment: .leading, spacing: 12) {
                Text("Tipos de Aeronave")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    ForEach(adsb.topAircraftTypes.prefix(5), id: \.type) { type in
                        HStack {
                            Text(type.type)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("\(type.count)")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            
                            Text(String(format: "%.1f%%", type.percentage))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.blue)
                        }
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    @ViewBuilder
    private func satelliteAnalyticsSection(_ satellite: SatelliteAnalytics) -> some View {
        VStack(spacing: 16) {
            Text("Satélite")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Success Rate
            HStack(spacing: 12) {
                VStack {
                    Text("\(satellite.successfulPasses)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    Text("Sucesso")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text("\(satellite.failedPasses)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                    Text("Falha")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    Text(String(format: "%.1f%%", 
                        Double(satellite.successfulPasses) / Double(satellite.totalPasses) * 100))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.blue)
                    Text("Taxa")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            
            // Satellite Stats
            VStack(spacing: 8) {
                ForEach(satellite.satelliteStats.prefix(3), id: \.satellite) { stat in
                    HStack {
                        Text(stat.satellite)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("\(stat.passes) passes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(String(format: "%.1f%%", stat.successRate))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.green)
                    }
                    Divider()
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    private func trendIndicator(for metric: AnalyticsMetric, in analytics: SystemAnalytics) -> some View {
        let trend: MetricTrend
        let color: Color

        switch metric {
        case .cpu:
            trend = analytics.cpu.trend
            color = .blue
        case .memory:
            trend = analytics.memory.trend
            color = .purple
        case .disk:
            trend = analytics.disk.trend
            color = .orange
        case .temperature:
            trend = analytics.temperature.trend
            color = .red
        }

        return HStack(spacing: 4) {
            Image(systemName: trend.iconName)
                .font(.caption)
                .foregroundStyle(color)

            Text(trend.displayName)
                .font(.caption)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func statCards(for metric: AnalyticsMetric, in analytics: SystemAnalytics) -> [(title: String, value: String, color: Color, trend: MetricTrend)] {
        switch metric {
        case .cpu:
            return [
                ("Média", String(format: "%.1f%%", analytics.cpu.average), .blue, analytics.cpu.trend),
                ("Pico", String(format: "%.1f%%", analytics.cpu.peak), .red, .stable),
                ("Mínima", String(format: "%.1f%%", analytics.cpu.minimum), .green, .stable)
            ]
        case .memory:
            return [
                ("Média", String(format: "%.1f%%", analytics.memory.averageUsage), .purple, analytics.memory.trend),
                ("Pico", String(format: "%.1f%%", analytics.memory.peakUsage), .red, .stable),
                ("Mínima", String(format: "%.0f MB", analytics.memory.minimumAvailable), .green, .stable)
            ]
        case .disk:
            return [
                ("Média", String(format: "%.1f%%", analytics.disk.averageUsage), .orange, analytics.disk.trend),
                ("Pico", String(format: "%.1f%%", analytics.disk.peakUsage), .red, .stable),
                ("Crescimento", analytics.disk.growthRate != nil ? String(format: "%.2f GB/dia", analytics.disk.growthRate!) : "N/A", .blue, .stable)
            ]
        case .temperature:
            return [
                ("Média", String(format: "%.1f°C", analytics.temperature.average), .red, analytics.temperature.trend),
                ("Pico", String(format: "%.1f°C", analytics.temperature.peak), .red, .stable),
                ("Mínima", String(format: "%.1f°C", analytics.temperature.minimum), .blue, .stable)
            ]
        }
    }
    
    private func loadAnalytics() {
        isLoading = true
        error = nil
        
        Task {
            do {
                async let systemTask = APIService.shared.fetchSystemAnalytics(period: selectedPeriod.rawValue, interval: selectedPeriod.interval)
                async let adsbTask = APIService.shared.fetchADSBAnalytics(period: selectedPeriod.rawValue)
                async let satelliteTask = APIService.shared.fetchSatelliteAnalytics(period: selectedPeriod.rawValue)
                
                let (system, adsb, satellite) = try await (systemTask, adsbTask, satelliteTask)
                
                await MainActor.run {
                    self.systemAnalytics = system
                    self.adsbAnalytics = adsb
                    self.satelliteAnalytics = satellite
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

    private func parseDate(_ timestamp: String) -> Date {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            return date
        }
        // Fallback
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return dateFormatter.date(from: timestamp) ?? Date()
    }
}

// MARK: - Supporting Views

struct StatCardMini: View {
    let title: String
    let value: String
    let color: Color
    let trend: MetricTrend
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            HStack(spacing: 2) {
                Image(systemName: trend.iconName)
                    .font(.caption2)
                Text(trend.displayName)
                    .font(.caption2)
            }
            .foregroundStyle(trend.color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Extensions

extension MetricTrend {
    var displayName: String {
        switch self {
        case .rising: return "Subindo"
        case .falling: return "Descendo"
        case .stable: return "Estável"
        }
    }
    
    var iconName: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .rising: return .red
        case .falling: return .green
        case .stable: return .gray
        }
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(AppState())
}
