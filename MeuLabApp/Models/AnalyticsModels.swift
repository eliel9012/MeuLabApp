import Foundation

// MARK: - System Analytics

struct SystemAnalytics: Codable, Equatable {
    let period: String
    let interval: String
    let cpu: CPUMetrics
    let memory: MemoryMetrics
    let disk: DiskMetrics
    let temperature: TemperatureMetrics
    let uptime: UptimeMetrics
}

struct CPUMetrics: Codable, Equatable {
    let dataPoints: [CPUDataPoint]
    let average: Double
    let peak: Double
    let minimum: Double
    
    var trend: MetricTrend {
        guard dataPoints.count >= 2 else { return .stable }
        let first = dataPoints.prefix(3).map(\.usage).reduce(0, +) / Double(min(3, dataPoints.count))
        let last = dataPoints.suffix(3).map(\.usage).reduce(0, +) / Double(min(3, dataPoints.count))
        
        if last > first * 1.1 { return .rising }
        if last < first * 0.9 { return .falling }
        return .stable
    }
}

struct CPUDataPoint: Codable, Equatable {
    let timestamp: String
    let usage: Double
    let load1min: Double?
    let load5min: Double?
    let load15min: Double?
}

struct MemoryMetrics: Codable, Equatable {
    let dataPoints: [MemoryDataPoint]
    let averageUsage: Double
    let peakUsage: Double
    let minimumAvailable: Double
    
    var trend: MetricTrend {
        guard dataPoints.count >= 2 else { return .stable }
        let first = dataPoints.prefix(3).map(\.usedPercent).reduce(0, +) / Double(min(3, dataPoints.count))
        let last = dataPoints.suffix(3).map(\.usedPercent).reduce(0, +) / Double(min(3, dataPoints.count))
        
        if last > first * 1.1 { return .rising }
        if last < first * 0.9 { return .falling }
        return .stable
    }
}

struct MemoryDataPoint: Codable, Equatable {
    let timestamp: String
    let usedMb: Int
    let availableMb: Int
    let usedPercent: Double
}

struct DiskMetrics: Codable, Equatable {
    let dataPoints: [DiskDataPoint]
    let averageUsage: Double
    let peakUsage: Double
    let growthRate: Double? // GB per day
    
    var trend: MetricTrend {
        guard dataPoints.count >= 2 else { return .stable }
        let first = dataPoints.prefix(3).map(\.usedPercent).reduce(0, +) / Double(min(3, dataPoints.count))
        let last = dataPoints.suffix(3).map(\.usedPercent).reduce(0, +) / Double(min(3, dataPoints.count))
        
        if last > first * 1.1 { return .rising }
        if last < first * 0.9 { return .falling }
        return .stable
    }
}

struct DiskDataPoint: Codable, Equatable {
    let timestamp: String
    let usedGb: Double
    let availableGb: Double
    let usedPercent: Double
}

struct TemperatureMetrics: Codable, Equatable {
    let dataPoints: [TemperatureDataPoint]
    let average: Double
    let peak: Double
    let minimum: Double
    
    var trend: MetricTrend {
        guard dataPoints.count >= 2 else { return .stable }
        let first = dataPoints.prefix(3).map(\.temperature).reduce(0, +) / Double(min(3, dataPoints.count))
        let last = dataPoints.suffix(3).map(\.temperature).reduce(0, +) / Double(min(3, dataPoints.count))
        
        if last > first * 1.1 { return .rising }
        if last < first * 0.9 { return .falling }
        return .stable
    }
}

struct TemperatureDataPoint: Codable, Equatable {
    let timestamp: String
    let temperature: Double
}

struct UptimeMetrics: Codable, Equatable {
    let current: Int
    let average: Int
    let reboots: Int
}

// MARK: - ADS-B Analytics

struct ADSBAnalytics: Codable, Equatable {
    let period: String
    let totalFlights: Int
    let uniqueAircraft: Int
    let hourlyStats: [HourlyADSBStats]
    let dailyStats: [DailyADSBStats]
    let topAircraftTypes: [AircraftTypeStats]
    let topRoutes: [RouteStats]
    let altitudeDistribution: [AltitudeRange]
}

struct HourlyADSBStats: Codable, Equatable {
    let hour: Int
    let flightCount: Int
    let averageAltitude: Double?
    let averageSpeed: Double?
}

struct DailyADSBStats: Codable, Equatable {
    let date: String
    let flightCount: Int
    let uniqueAircraft: Int
    let peakHour: Int
    let averageFlightDuration: Double?
}

struct AircraftTypeStats: Codable, Equatable {
    let type: String
    let count: Int
    let percentage: Double
}

struct RouteStats: Codable, Equatable {
    let origin: String
    let destination: String
    let count: Int
    let percentage: Double
}

struct AltitudeRange: Codable, Equatable {
    let range: String
    let count: Int
    let percentage: Double
}

// MARK: - Satellite Analytics

struct SatelliteAnalytics: Codable, Equatable {
    let period: String
    let totalPasses: Int
    let successfulPasses: Int
    let failedPasses: Int
    let averageDuration: Double
    let satelliteStats: [SatelliteStats]
    let imageStats: ImageStats
    let passTimeline: [PassTimelineEntry]
}

struct SatelliteStats: Codable, Equatable {
    let satellite: String
    let passes: Int
    let successRate: Double
    let averageElevation: Double
    let averageDuration: Double
}

struct ImageStats: Codable, Equatable {
    let totalImages: Int
    let averageSize: Double
    let totalSize: Double
    let formats: [ImageFormatStats]
}

struct ImageFormatStats: Codable, Equatable {
    let format: String
    let count: Int
    let percentage: Double
}

struct PassTimelineEntry: Codable, Equatable {
    let timestamp: String
    let satellite: String
    let duration: Double
    let maxElevation: Double
    let success: Bool
    let imageCount: Int
}

// MARK: - Alert System

struct AlertRule: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let type: AlertType
    let condition: AlertCondition
    let threshold: Double
    let alertOperator: AlertOperator
    var enabled: Bool
    let notificationChannels: [NotificationChannel]
    let cooldownMinutes: Int
    let createdAt: String
    let lastTriggered: String?
}

enum AlertType: String, Codable, CaseIterable {
    case cpuUsage = "cpu_usage"
    case memoryUsage = "memory_usage"
    case diskUsage = "disk_usage"
    case temperature = "temperature"
    case aircraftCount = "aircraft_count"
    case satellitePass = "satellite_pass"
    case systemUptime = "system_uptime"
    case dockerContainer = "docker_container"
}

enum AlertCondition: String, Codable, CaseIterable {
    case greaterThan = "greater_than"
    case lessThan = "less_than"
    case equals = "equals"
    case notEquals = "not_equals"
}

enum AlertOperator: String, Codable, CaseIterable {
    case and = "and"
    case or = "or"
}

enum NotificationChannel: String, Codable, CaseIterable {
    case push = "push"
    case email = "email"
    case webhook = "webhook"
}

struct AlertTrigger: Codable, Equatable, Identifiable {
    let id: String
    let ruleId: String
    let ruleName: String
    let triggeredAt: String
    let value: Double
    let threshold: Double
    let message: String
    var acknowledged: Bool
    var acknowledgedBy: String?
    var acknowledgedAt: String?
}

// MARK: - Search & Filters

struct FlightSearchRequest: Codable {
    var query: String?
    var flightNumber: String?
    var registration: String?
    var aircraftType: String?
    var origin: String?
    var destination: String?
    var altitudeMin: Int?
    var altitudeMax: Int?
    var speedMin: Int?
    var speedMax: Int?
    var timeFrom: String?
    var timeTo: String?
    var limit: Int?
    var offset: Int?

    init(query: String? = nil, flightNumber: String? = nil, registration: String? = nil,
         aircraftType: String? = nil, origin: String? = nil, destination: String? = nil,
         altitudeMin: Int? = nil, altitudeMax: Int? = nil, speedMin: Int? = nil,
         speedMax: Int? = nil, timeFrom: String? = nil, timeTo: String? = nil,
         limit: Int? = nil, offset: Int? = nil) {
        self.query = query
        self.flightNumber = flightNumber
        self.registration = registration
        self.aircraftType = aircraftType
        self.origin = origin
        self.destination = destination
        self.altitudeMin = altitudeMin
        self.altitudeMax = altitudeMax
        self.speedMin = speedMin
        self.speedMax = speedMax
        self.timeFrom = timeFrom
        self.timeTo = timeTo
        self.limit = limit
        self.offset = offset
    }
}

struct FlightSearchResponse: Codable, Equatable {
    var results: [SearchFlightResult]
    let total: Int
    let limit: Int
    let offset: Int
    var hasMore: Bool
}

struct SearchFlightResult: Codable, Equatable {
    let hex: String
    let flight: String?
    let registration: String?
    let aircraftType: String?
    let origin: String?
    let destination: String?
    let altitude: Int?
    let speed: Int?
    let heading: Int?
    let timestamp: String
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Export

struct ExportRequest: Codable {
    let dataType: ExportDataType
    let format: ExportFormat
    let dateFrom: String?
    let dateTo: String?
    let filters: [String: AnyCodable]?
}

enum ExportDataType: String, Codable, CaseIterable {
    case systemMetrics = "system_metrics"
    case flights = "flights"
    case satellitePasses = "satellite_passes"
    case alerts = "alerts"
    case dockerLogs = "docker_logs"
}

enum ExportFormat: String, Codable, CaseIterable {
    case csv = "csv"
    case json = "json"
    case xlsx = "xlsx"
}

// MARK: - Remote Control

struct RemoteCommandRequest: Codable {
    let command: CommandType
    let target: String
    let parameters: AnyCodable?
}

struct RemoteCommand: Codable, Equatable, Identifiable {
    let id: String
    let command: CommandType
    let target: String?
    let parameters: AnyCodable?
    let status: CommandStatus
    let createdAt: String
    let startedAt: String?
    let completedAt: String?
    let output: String?
    let error: String?
}

enum CommandType: String, Codable, CaseIterable {
    case restartService = "restart_service"
    case stopService = "stop_service"
    case startService = "start_service"
    case clearCache = "clear_cache"
    case runHealthCheck = "run_health_check"
    case backupConfig = "backup_config"
    case restoreConfig = "restore_config"
    case cleanupLogs = "cleanup_logs"
    case updateSystem = "update_system"
}

enum CommandStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
}

// MARK: - Alert Triggers Response

struct AlertTriggersResponse: Codable {
    let triggers: [AlertTrigger]
}

struct AlertTriggerAckResponse: Codable {
    let id: String
    let acknowledged: Bool
    let acknowledgedBy: String?
    let acknowledgedAt: String?
}

// MARK: - Health Check

struct HealthCheckReport: Codable, Equatable {
    let timestamp: String
    let overallStatus: HealthStatus
    let checks: [HealthCheck]
    let score: Double
    let recommendations: [String]
}

struct HealthCheck: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let status: HealthStatus
    let message: String
    let details: [String: AnyCodable]?
    let lastChecked: String
}

enum HealthStatus: String, Codable, CaseIterable {
    case healthy = "healthy"
    case warning = "warning"
    case critical = "critical"
    case unknown = "unknown"
}

// MARK: - Common

enum MetricTrend: String, Codable, CaseIterable {
    case rising = "rising"
    case falling = "falling"
    case stable = "stable"
}

// MARK: - Dark Mode

struct ThemeSettings: Codable, Equatable {
    var mode: ThemeMode
    var autoSwitch: Bool
    var switchTime: SwitchTime?
    var followSystem: Bool
}

enum ThemeMode: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
}

struct SwitchTime: Codable, Equatable {
    var lightMode: String
    var darkMode: String
}