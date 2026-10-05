import Foundation

struct DiskHealthDevice: Decodable, Identifiable, Sendable {
    let device: String
    let model: String?
    let healthPassed: Bool?
    let temperatureC: Double?
    let percentageUsed: Double?
    let availableSparePct: Double?
    let dataWrittenTb: Double?
    let dataReadTb: Double?
    let powerOnHours: Double?
    let unsafeShutdowns: Double?
    let mediaErrors: Double?

    var id: String { device }

    enum CodingKeys: String, CodingKey {
        case device, model
        case healthPassed = "health_passed"
        case temperatureC = "temperature_c"
        case percentageUsed = "percentage_used"
        case availableSparePct = "available_spare_pct"
        case dataWrittenTb = "data_written_tb"
        case dataReadTb = "data_read_tb"
        case powerOnHours = "power_on_hours"
        case unsafeShutdowns = "unsafe_shutdowns"
        case mediaErrors = "media_errors"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        device = (try? c.decode(String.self, forKey: .device)) ?? "?"
        model = try? c.decodeIfPresent(String.self, forKey: .model)
        healthPassed = try? c.decodeIfPresent(Bool.self, forKey: .healthPassed)
        temperatureC = try? c.decodeIfPresent(Double.self, forKey: .temperatureC)
        percentageUsed = try? c.decodeIfPresent(Double.self, forKey: .percentageUsed)
        availableSparePct = try? c.decodeIfPresent(Double.self, forKey: .availableSparePct)
        dataWrittenTb = try? c.decodeIfPresent(Double.self, forKey: .dataWrittenTb)
        dataReadTb = try? c.decodeIfPresent(Double.self, forKey: .dataReadTb)
        powerOnHours = try? c.decodeIfPresent(Double.self, forKey: .powerOnHours)
        unsafeShutdowns = try? c.decodeIfPresent(Double.self, forKey: .unsafeShutdowns)
        mediaErrors = try? c.decodeIfPresent(Double.self, forKey: .mediaErrors)
    }
}

struct DiskHealthResponse: Decodable, Sendable {
    let ok: Bool
    let updatedAt: String?
    let error: String?
    let devices: [DiskHealthDevice]

    enum CodingKeys: String, CodingKey {
        case ok
        case updatedAt = "updated_at"
        case error
        case devices
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = (try? c.decode(Bool.self, forKey: .ok)) ?? false
        updatedAt = try? c.decodeIfPresent(String.self, forKey: .updatedAt)
        error = try? c.decodeIfPresent(String.self, forKey: .error)
        devices = (try? c.decodeIfPresent([DiskHealthDevice].self, forKey: .devices)) ?? []
    }
}

extension APIService {
    func fetchDiskHealth() async throws -> DiskHealthResponse {
        try await fetch("/api/system/disk_health")
    }
}
