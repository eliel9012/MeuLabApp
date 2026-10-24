import Charts
import SwiftUI

private struct VisionSystemAnalytics: Decodable {
    let cpu: CPU
    let memory: Memory
    let disk: Disk
    let temperature: Temperature
    let uptime: Uptime?

    struct CPU: Decodable {
        let dataPoints: [Point]
        let average: Double
        let peak: Double
        let minimum: Double?
        struct Point: Decodable { let timestamp: String; let usage: Double }
    }
    struct Memory: Decodable {
        let dataPoints: [Point]
        let averageUsage: Double
        let peakUsage: Double
        let minimumAvailable: Double?
        struct Point: Decodable { let timestamp: String; let usedPercent: Double }
    }
    struct Disk: Decodable {
        let dataPoints: [Point]
        let averageUsage: Double
        let peakUsage: Double
        let growthRate: Double?
        struct Point: Decodable { let timestamp: String; let usedPercent: Double }
    }
    struct Temperature: Decodable {
        let dataPoints: [Point]
        let average: Double
        let peak: Double
        let minimum: Double?
        struct Point: Decodable { let timestamp: String; let temperature: Double }
    }
    struct Uptime: Decodable { let current: Int; let average: Int; let reboots: Int }
}

private struct VisionADSBAnalytics: Decodable {
    let totalFlights: Int
    let uniqueAircraft: Int
    let hourlyStats: [Hour]
    let dailyStats: [Day]?
    let topAircraftTypes: [AircraftType]?
    let topRoutes: [Route]?
    let altitudeDistribution: [Altitude]?
    struct Hour: Decodable { let hour: Int; let flightCount: Int }
    struct Day: Decodable { let date: String; let flightCount: Int; let uniqueAircraft: Int }
    struct AircraftType: Decodable { let type: String; let count: Int; let percentage: Double }
    struct Route: Decodable { let origin: String; let destination: String; let count: Int; let percentage: Double }
    struct Altitude: Decodable { let range: String; let count: Int; let percentage: Double }
}

private struct VisionChartPoint: Identifiable {
    let id: Int
    let label: String
    let value: Double
}

private enum VisionAnalyticsMetric: String, CaseIterable, Identifiable {
    case cpu = "CPU", memory = "Memória", disk = "Disco", temperature = "Temperatura"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .cpu: .cyan
        case .memory: .purple
        case .disk: .orange
        case .temperature: .red
        }
    }
    var unit: String { self == .temperature ? "°C" : "%" }
}

struct VisionAnalyticsView: View {
    @State private var period = "24h"
    @State private var metric: VisionAnalyticsMetric = .cpu
    @State private var system: VisionSystemAnalytics?
    @State private var adsb: VisionADSBAnalytics?
    @State private var systemError: String?
    @State private var adsbError: String?
    @State private var loading = false
    @State private var updatedAt: Date?
    @State private var refreshID = UUID()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Label("Analytics", systemImage: "chart.xyaxis.line").font(.largeTitle.bold())
                    Spacer()
                    if loading { ProgressView() }
                    Button("Atualizar", systemImage: "arrow.clockwise") { Task { await refresh() } }
                }
                Picker("Período", selection: $period) {
                    Text("24 horas").tag("24h")
                    Text("7 dias").tag("7d")
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Sistema · dados do servidor").font(.title2.bold())
                    Picker("Métrica", selection: $metric) {
                        ForEach(VisionAnalyticsMetric.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    if let system {
                        let points = points(for: metric, in: system)
                        if points.isEmpty {
                            empty("Sem amostras de \(metric.rawValue.lowercased()) nesse período.")
                        } else {
                            HStack(spacing: 14) {
                                stat("Média", average(for: metric, in: system), unit: metric.unit)
                                stat("Pico", peak(for: metric, in: system), unit: metric.unit)
                                stat("Amostras", Double(points.count), unit: "")
                            }
                            Chart(points) { point in
                                AreaMark(x: .value("Amostra", point.id), y: .value(metric.rawValue, point.value))
                                    .foregroundStyle(metric.color.opacity(0.16))
                                LineMark(x: .value("Amostra", point.id), y: .value(metric.rawValue, point.value))
                                    .foregroundStyle(metric.color)
                                    .interpolationMethod(.catmullRom)
                            }
                            .chartXAxis(.hidden)
                            .frame(height: 195)
                            HStack {
                                Text(points.first?.label ?? "")
                                Spacer()
                                Text(points.last?.label ?? "")
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        if let uptime = system.uptime {
                            HStack(spacing: 14) {
                                stat("Uptime atual", Double(uptime.current) / 86_400, unit: " dias")
                                stat("Uptime médio", Double(uptime.average) / 86_400, unit: " dias")
                                stat("Reinícios", Double(uptime.reboots), unit: "")
                            }
                        }
                        HStack(spacing: 14) {
                            if let minimum = system.cpu.minimum { stat("CPU mínima", minimum, unit: "%") }
                            if let minimum = system.memory.minimumAvailable { stat("RAM livre mínima", minimum, unit: " MB") }
                            if let growth = system.disk.growthRate { stat("Crescimento disco", growth, unit: " GB/dia") }
                        }
                    } else if let systemError {
                        empty(systemError)
                    } else { ProgressView("Carregando sistema…") }
                }
                .padding(20)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 14) {
                    Text("Tráfego ADS-B · histórico do receptor").font(.title2.bold())
                    if let adsb {
                        HStack(spacing: 14) {
                            stat("Observações", Double(adsb.totalFlights), unit: "")
                            stat("Aeronaves únicas", Double(adsb.uniqueAircraft), unit: "")
                        }
                        if adsb.hourlyStats.isEmpty {
                            empty("Sem histórico ADS-B nesse período.")
                        } else {
                            Chart(adsb.hourlyStats, id: \.hour) { hour in
                                BarMark(x: .value("Hora", hour.hour), y: .value("Observações", hour.flightCount))
                                    .foregroundStyle(.cyan.gradient)
                            }
                            .frame(height: 165)
                        }
                        if let daily = adsb.dailyStats, !daily.isEmpty {
                            Text("Por dia").font(.headline)
                            Chart(daily, id: \.date) { day in
                                BarMark(x: .value("Dia", day.date), y: .value("Observações", day.flightCount))
                                    .foregroundStyle(.blue.gradient)
                            }
                            .frame(height: 165)
                            ForEach(daily, id: \.date) { day in
                                HStack {
                                    Text(day.date)
                                    Spacer()
                                    Text("\(day.flightCount) observações · \(day.uniqueAircraft) aeronaves")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        analyticsList("Tipos de aeronave", items: (adsb.topAircraftTypes ?? []).map { ("\($0.type) · \($0.count)", $0.percentage) })
                        analyticsList("Rotas", items: (adsb.topRoutes ?? []).map { ("\($0.origin) → \($0.destination) · \($0.count)", $0.percentage) })
                        analyticsList("Faixas de altitude", items: (adsb.altitudeDistribution ?? []).map { ("\($0.range) · \($0.count)", $0.percentage) })
                    } else if let adsbError {
                        empty(adsbError)
                    } else { ProgressView("Carregando ADS-B…") }
                }
                .padding(20)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                if let updatedAt {
                    Text("Atualizado \(updatedAt.formatted(date: .omitted, time: .standard)) · MeuLab API")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .task(id: period) { await refresh() }
    }

    @ViewBuilder private func empty(_ message: String) -> some View {
        Label(message, systemImage: "info.circle")
            .foregroundStyle(.secondary)
            .padding(12)
    }

    private func analyticsList(_ title: String, items: [(String, Double)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if items.isEmpty {
                Text("Sem dados registrados neste período.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.0)
                        Spacer()
                        Text("\(item.1.formatted(.number.precision(.fractionLength(1))))%")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, 10)
    }

    private func stat(_ title: String, _ value: Double, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(value.formatted(.number.precision(.fractionLength(unit.isEmpty ? 0 : 1))))\(unit)")
                .font(.title3.bold()).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func points(for metric: VisionAnalyticsMetric, in value: VisionSystemAnalytics) -> [VisionChartPoint] {
        let samples: [(String, Double)]
        switch metric {
        case .cpu: samples = value.cpu.dataPoints.map { ($0.timestamp, $0.usage) }
        case .memory: samples = value.memory.dataPoints.map { ($0.timestamp, $0.usedPercent) }
        case .disk: samples = value.disk.dataPoints.map { ($0.timestamp, $0.usedPercent) }
        case .temperature: samples = value.temperature.dataPoints.map { ($0.timestamp, $0.temperature) }
        }
        return samples.enumerated().map { index, sample in
            VisionChartPoint(id: index, label: sample.0.replacingOccurrences(of: "T", with: " "), value: sample.1)
        }
    }

    private func average(for metric: VisionAnalyticsMetric, in value: VisionSystemAnalytics) -> Double {
        switch metric {
        case .cpu: value.cpu.average
        case .memory: value.memory.averageUsage
        case .disk: value.disk.averageUsage
        case .temperature: value.temperature.average
        }
    }

    private func peak(for metric: VisionAnalyticsMetric, in value: VisionSystemAnalytics) -> Double {
        switch metric {
        case .cpu: value.cpu.peak
        case .memory: value.memory.peakUsage
        case .disk: value.disk.peakUsage
        case .temperature: value.temperature.peak
        }
    }

    private func refresh() async {
        let id = UUID()
        let selectedPeriod = period
        refreshID = id
        loading = true
        defer {
            if refreshID == id { loading = false; updatedAt = Date() }
        }
        do {
            let api = try VisionAPIClient()
            do {
                let result: VisionSystemAnalytics = try await api.fetch("api/analytics/system?period=\(selectedPeriod)&interval=15m")
                guard refreshID == id, !Task.isCancelled else { return }
                system = result
                systemError = nil
            } catch {
                guard refreshID == id, !Task.isCancelled else { return }
                system = nil
                systemError = error.localizedDescription
            }
            do {
                let result: VisionADSBAnalytics = try await api.fetch("api/analytics/adsb?period=\(selectedPeriod)")
                guard refreshID == id, !Task.isCancelled else { return }
                adsb = result
                adsbError = nil
            } catch {
                guard refreshID == id, !Task.isCancelled else { return }
                adsb = nil
                adsbError = error.localizedDescription
            }
        } catch {
            guard refreshID == id, !Task.isCancelled else { return }
            systemError = error.localizedDescription
            adsbError = error.localizedDescription
        }
    }
}
