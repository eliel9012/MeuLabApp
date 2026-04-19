import Foundation

// MARK: - Health Check Response

struct HealthResponse: Codable, Equatable {
    let status: String
}

// MARK: - Dashboard Response

struct DashboardResponse: Codable, Equatable {
    let timestamp: String
    let adsb: DashboardADSB
    let system: DashboardSystem
}

struct DashboardADSB: Codable, Equatable {
    let totalAircraft: Int
    let withPosition: Int

    enum CodingKeys: String, CodingKey {
        case totalAircraft = "total_aircraft"
        case withPosition = "with_position"
    }
}

struct DashboardSystem: Codable, Equatable {
    let cpuTemp: Double?
    let load: Double?

    enum CodingKeys: String, CodingKey {
        case cpuTemp = "cpu_temp"
        case load
    }
}

// MARK: - Process List

struct ProcessList: Codable, Equatable {
    let timestamp: String
    let items: [ProcessItem]
}

struct ProcessItem: Codable, Equatable, Identifiable {
    let pid: Int
    let command: String
    let cpuPercent: Double
    let memPercent: Double

    var id: Int { pid }

    enum CodingKeys: String, CodingKey {
        case pid, command
        case cpuPercent = "cpu_percent"
        case memPercent = "mem_percent"
    }
}

// MARK: - Partitions

struct PartitionList: Codable, Equatable {
    let timestamp: String
    let partitions: [Partition]
}

struct Partition: Codable, Equatable, Identifiable {
    let filesystem: String
    let mount: String
    let totalBytes: Int64
    let usedBytes: Int64
    let availableBytes: Int64
    let usedPercent: String

    var id: String { mount }

    enum CodingKeys: String, CodingKey {
        case filesystem, mount
        case totalBytes = "total_bytes"
        case usedBytes = "used_bytes"
        case availableBytes = "available_bytes"
        case usedPercent = "used_percent"
    }
}

// MARK: - Network

struct NetworkStats: Codable, Equatable {
    let timestamp: String
    let interfaces: [NetworkInterface]
}

struct NetworkInterface: Codable, Equatable, Identifiable {
    let iface: String
    let rxBytes: Int64
    let txBytes: Int64

    var id: String { iface }

    enum CodingKeys: String, CodingKey {
        case iface
        case rxBytes = "rx_bytes"
        case txBytes = "tx_bytes"
    }
}

// MARK: - Remote Source

struct APIRemoteSource: Codable, Equatable {
    let type: String?
    let host: String?
}

// MARK: - Docker

struct DockerVersionResponse: Codable, Equatable {
    let timestamp: String
    let version: DockerVersionPayload
    let source: APIRemoteSource?
}

struct DockerVersionPayload: Codable, Equatable {
    let client: DockerVersionClient
    let server: DockerVersionServer

    enum CodingKeys: String, CodingKey {
        case client = "Client"
        case server = "Server"
    }
}

struct DockerVersionClient: Codable, Equatable {
    let platform: DockerPlatform?
    let version: String?
    let apiVersion: String?
    let defaultAPIVersion: String?
    let gitCommit: String?
    let goVersion: String?
    let os: String?
    let arch: String?
    let buildTime: String?
    let context: String?

    enum CodingKeys: String, CodingKey {
        case platform = "Platform"
        case version = "Version"
        case apiVersion = "ApiVersion"
        case defaultAPIVersion = "DefaultAPIVersion"
        case gitCommit = "GitCommit"
        case goVersion = "GoVersion"
        case os = "Os"
        case arch = "Arch"
        case buildTime = "BuildTime"
        case context = "Context"
    }
}

struct DockerVersionServer: Codable, Equatable {
    let platform: DockerPlatform?
    let version: String?
    let apiVersion: String?
    let minAPIVersion: String?
    let os: String?
    let arch: String?
    let components: [DockerComponent]?
    let gitCommit: String?
    let goVersion: String?
    let kernelVersion: String?
    let buildTime: String?

    enum CodingKeys: String, CodingKey {
        case platform = "Platform"
        case version = "Version"
        case apiVersion = "ApiVersion"
        case minAPIVersion = "MinAPIVersion"
        case os = "Os"
        case arch = "Arch"
        case components = "Components"
        case gitCommit = "GitCommit"
        case goVersion = "GoVersion"
        case kernelVersion = "KernelVersion"
        case buildTime = "BuildTime"
    }
}

struct DockerPlatform: Codable, Equatable {
    let name: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
    }
}

struct DockerComponent: Codable, Equatable, Identifiable {
    let name: String
    let version: String
    let details: [String: String]?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case version = "Version"
        case details = "Details"
    }
}

struct DockerStatusResponse: Codable, Equatable {
    let timestamp: String
    let containers: [DockerContainer]
    let source: APIRemoteSource?
}

struct DockerContainer: Codable, Equatable, Identifiable {
    let command: String
    let createdAt: String
    let containerId: String
    let image: String
    let labels: String?
    let localVolumes: String?
    let mounts: String?
    let names: String
    let networks: String?
    let platform: String?
    let ports: String?
    let runningFor: String
    let size: String?
    let state: String
    let status: String
    let health: DockerHealth?

    var id: String { containerId }

    enum CodingKeys: String, CodingKey {
        case command = "Command"
        case createdAt = "CreatedAt"
        case containerId = "ID"
        case image = "Image"
        case labels = "Labels"
        case localVolumes = "LocalVolumes"
        case mounts = "Mounts"
        case names = "Names"
        case networks = "Networks"
        case platform = "Platform"
        case ports = "Ports"
        case runningFor = "RunningFor"
        case size = "Size"
        case state = "State"
        case status = "Status"
        case health = "Health"
    }
}

struct DockerHealth: Codable, Equatable {
    let status: String
    let failingStreak: Int?
    let log: [DockerHealthLog]?

    enum CodingKeys: String, CodingKey {
        case status = "Status"
        case failingStreak = "FailingStreak"
        case log = "Log"
    }
}

struct DockerHealthLog: Codable, Equatable, Identifiable {
    let start: String
    let end: String
    let exitCode: Int
    let output: String

    var id: String { start + end }

    enum CodingKeys: String, CodingKey {
        case start = "Start"
        case end = "End"
        case exitCode = "ExitCode"
        case output = "Output"
    }
}

// MARK: - Docker Logs Response

struct DockerLogsResponse: Codable {
    let timestamp: String
    let container: String
    let lines: [String]
}

// MARK: - Systemd

struct SystemdStatusResponse: Codable, Equatable {
    let timestamp: String
    let services: [SystemdService]
    let source: APIRemoteSource?
}

struct SystemdService: Codable, Equatable, Identifiable {
    let service: String
    let activeState: String
    let subState: String
    let activeSince: String
    let description: String

    var id: String { service }

    enum CodingKeys: String, CodingKey {
        case service
        case activeState = "active_state"
        case subState = "sub_state"
        case activeSince = "active_since"
        case description
    }
}

// MARK: - Metrics

struct MetricsResponse: Codable, Equatable {
    let timestamp: String?
    let uptimeSeconds: Int
    let requestCount: Int
    let avgResponseMs: Double
    let lastResponseMs: Double
    let cacheHits: Int
    let cacheMisses: Int

    enum CodingKeys: String, CodingKey {
        case timestamp
        case uptimeSeconds = "uptime_seconds"
        case requestCount = "request_count"
        case avgResponseMs = "avg_response_ms"
        case lastResponseMs = "last_response_ms"
        case cacheHits = "cache_hits"
        case cacheMisses = "cache_misses"
    }
}

// MARK: - ADSB History/Alerts

struct ADSBHistoryResponse: Codable, Equatable {
    let timestamp: String
    let days: [String]
    let dailyPeaks: [String: [String: Int]]
    let records: ADSBRecords

    enum CodingKeys: String, CodingKey {
        case timestamp, days, records
        case dailyPeaks = "daily_peaks"
    }
}

struct ADSBRecords: Codable, Equatable {
    let maxSimultaneous: ADSBRecord
    let maxSpeed: ADSBRecord
    let maxAltitude: ADSBRecord

    enum CodingKeys: String, CodingKey {
        case maxSimultaneous = "max_simultaneous"
        case maxSpeed = "max_speed"
        case maxAltitude = "max_altitude"
    }
}

struct ADSBRecord: Codable, Equatable {
    let value: Double
    let timestamp: String
    let aircraft: String
}

struct ADSBAlertsResponse: Codable, Equatable {
    let timestamp: String
    let alerts: [ADSBAlert]
}

struct ADSBAlert: Codable, Equatable, Identifiable {
    let date: String
    let aircraft: String
    let timestamp: String
    let registration: String?
    let model: String?
    let callsign: String?

    var id: String { timestamp + aircraft }
}

// MARK: - ACARS History/Alerts

struct ACARSHistoryResponse: Codable, Equatable {
    let timestamp: String
    let last7Days: [ACARSDayCount]
    let last24hHours: [ACARSHourCount]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case last7Days = "last_7_days"
        case last24hHours = "last_24h_hours"
    }
}

struct ACARSDayCount: Codable, Equatable, Identifiable {
    let day: String
    let messages: Int

    var id: String { day }
}

struct ACARSHourCount: Codable, Equatable, Identifiable {
    let hour: String
    let messages: Int

    var id: String { hour }
}

// FlexibleTimestamp to accept String or Number for timestamp in ACARSAlert
enum FlexibleTimestamp: Codable, Equatable {
    case string(String)
    case number(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let n = try? container.decode(Double.self) {
            self = .number(n)
        } else if let i = try? container.decode(Int.self) {
            self = .number(Double(i))
        } else {
            self = .string("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s):
            try container.encode(s)
        case .number(let n):
            try container.encode(n)
        }
    }

    // Helper to format to HH:MM for UI when possible
    func toDisplayHHMM() -> String? {
        switch self {
        case .string(let s):
            // Try ISO8601 first
            if let date = ISO8601DateFormatter().date(from: s) {
                return DateFormatter.timeFormatter.string(from: date)
            }
            // Try "YYYY-MM-DD HH:MM:SS" -> take HH:MM
            let parts = s.split(separator: " ")
            if parts.count >= 2 {
                return String(parts[1].prefix(5))
            }
            // If it looks like just HH:MM:SS
            if s.contains(":") { return String(s.prefix(5)) }
            return nil
        case .number(let n):
            let seconds = TimeInterval(n)
            let date = Date(timeIntervalSince1970: seconds)
            return DateFormatter.timeFormatter.string(from: date)
        }
    }
}

extension DateFormatter {
    fileprivate static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

struct ACARSAlertsResponse: Codable, Equatable {
    let timestamp: String
    let alerts: [ACARSAlert]
}

struct ACARSAlert: Codable, Equatable, Identifiable {
    let id: String
    let timestamp: FlexibleTimestamp
}
