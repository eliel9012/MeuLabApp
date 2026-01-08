import Foundation

struct SystemStatus: Codable, Equatable {
    let timestamp: String
    let hostname: String
    let location: String
    let uptime: Uptime?
    let cpu: CPUStatus?
    let memory: MemoryStatus?
    let disk: DiskStatus?
    let wifi: WiFiStatus?
}

struct Uptime: Codable, Equatable {
    let seconds: Int
    let formatted: String
    let days: Int
    let hours: Int
    let minutes: Int
}

struct CPUStatus: Codable, Equatable {
    let usagePercent: Double?
    let load1min: Double?
    let load5min: Double?
    let load15min: Double?
    let temperatureC: Double?
    let cores: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case usagePercent = "usage_percent"
        case load1min = "load_1min"
        case load5min = "load_5min"
        case load15min = "load_15min"
        case temperatureC = "temperature_c"
        case cores, error
    }

    var temperatureColor: String {
        guard let temp = temperatureC else { return "gray" }
        if temp < 50 { return "green" }
        if temp < 70 { return "orange" }
        return "red"
    }
}

struct MemoryStatus: Codable, Equatable {
    let totalMb: Int?
    let usedMb: Int?
    let availableMb: Int?
    let usedPercent: Double?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case totalMb = "total_mb"
        case usedMb = "used_mb"
        case availableMb = "available_mb"
        case usedPercent = "used_percent"
        case error
    }
}

struct DiskStatus: Codable, Equatable {
    let totalGb: Double?
    let usedGb: Double?
    let availableGb: Double?
    let usedPercent: Double?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case totalGb = "total_gb"
        case usedGb = "used_gb"
        case availableGb = "available_gb"
        case usedPercent = "used_percent"
        case error
    }
}

struct WiFiStatus: Codable, Equatable {
    let ssid: String?
    let qualityPercent: Int?
    let signalDbm: Int?

    enum CodingKeys: String, CodingKey {
        case ssid
        case qualityPercent = "quality_percent"
        case signalDbm = "signal_dbm"
    }
}
