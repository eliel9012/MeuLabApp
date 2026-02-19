import Foundation

// MARK: - Satellite Pass

struct SatellitePass: Codable, Identifiable, Equatable {
    let name: String
    let imageFolder: String
    let imageCount: Int

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case imageFolder = "image_folder"
        case imageCount = "image_count"
    }

    var formattedDate: String {
        // Format: 2026-01-07_04-53_meteor_m2-x_lrpt_137.9 MHz
        let components = name.split(separator: "_")
        guard components.count >= 2 else { return name }

        let dateStr = String(components[0])
        let timeStr = String(components[1]).replacingOccurrences(of: "-", with: ":")

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        guard let date = inputFormatter.date(from: dateStr) else {
            return "\(dateStr) \(timeStr)"
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "pt_BR")
        outputFormatter.dateFormat = "dd/MM/yyyy"

        return "\(outputFormatter.string(from: date)) \(timeStr)"
    }

    var satelliteName: String {
        if name.contains("meteor_m2-x") {
            return "Meteor M2-x"
        } else if name.contains("meteor_m2-4") {
            return "Meteor M2-4"
        } else if name.contains("noaa") {
            return "NOAA"
        }
        return "Satélite"
    }

    var iconName: String {
        let n = name.lowercased()
        if n.contains("meteor") { return "satellite.fill" }
        if n.contains("noaa") { return "antenna.radiowaves.left.and.right" }
        if n.contains("orbcomm") { return "antenna.radiowaves.left.and.right" }
        return "satellite"
    }
}

// MARK: - Satellite Image

struct SatelliteImage: Codable, Identifiable, Equatable {
    let name: String
    let legend: String
    let passName: String
    let folderName: String
    let imageLightUrl: String?
    let imageFastUrl: String?
    let imageLosslessUrl: String?
    let imageLegendUrl: String?

    var id: String { "\(passName)/\(folderName)/\(name)" }

    enum CodingKeys: String, CodingKey {
        case name, legend
        case passName = "pass_name"
        case folderName = "folder_name"
        case imageLightUrl = "image_light_url"
        case imageFastUrl = "image_fast_url"
        case imageLosslessUrl = "image_lossless_url"
        case imageLegendUrl = "image_legend_url"
    }

    var cleanLegend: String {
        legend
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    var shortName: String {
        name
            .replacingOccurrences(of: "msu_mr_", with: "")
            .replacingOccurrences(of: "_corrected_map.png", with: "")
            .replacingOccurrences(of: "_corrected.png", with: "")
            .replacingOccurrences(of: ".png", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }
}

// MARK: - Last Images Response

struct LastImages: Codable, Equatable {
    let timestamp: String
    let passName: String
    let images: [SatelliteImage]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case passName = "pass_name"
        case images
    }

    var iconName: String {
        let n = passName.lowercased()
        if n.contains("meteor") { return "satellite.fill" }
        if n.contains("noaa") || n.contains("orbcomm") { return "antenna.radiowaves.left.and.right" }
        return "satellite"
    }
}

// MARK: - Passes List

struct PassesList: Codable {
    let timestamp: String
    let count: Int
    let passes: [SatellitePass]
}

struct PassesListPaginated: Codable {
    let timestamp: String
    let count: Int
    let totalCount: Int
    let page: Int
    let limit: Int
    let totalPages: Int
    let passes: [SatellitePassExtended]

    enum CodingKeys: String, CodingKey {
        case timestamp, count, page, limit, passes
        case totalCount = "total_count"
        case totalPages = "total_pages"
    }
}

struct SatellitePassExtended: Codable, Identifiable, Equatable {
    let name: String
    let imageFolder: String
    let imageCount: Int
    let sizeMb: Double
    let qualityStars: Int

    var id: String { name }

    var toSatellitePass: SatellitePass {
        SatellitePass(name: name, imageFolder: imageFolder, imageCount: imageCount)
    }

    enum CodingKeys: String, CodingKey {
        case name
        case imageFolder = "image_folder"
        case imageCount = "image_count"
        case sizeMb = "size_mb"
        case qualityStars = "quality_stars"
    }

    var iconName: String {
        let n = name.lowercased()
        if n.contains("meteor") { return "satellite.fill" }
        if n.contains("noaa") || n.contains("orbcomm") { return "antenna.radiowaves.left.and.right" }
        return "satellite"
    }

    var formattedDate: String {
        let components = name.split(separator: "_")
        guard components.count >= 2 else { return name }

        let dateStr = String(components[0])
        let timeStr = String(components[1]).replacingOccurrences(of: "-", with: ":")

        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        guard let date = inputFormatter.date(from: dateStr) else {
            return "\(dateStr) \(timeStr)"
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "pt_BR")
        outputFormatter.dateFormat = "dd/MM/yyyy"

        return "\(outputFormatter.string(from: date)) \(timeStr)"
    }

    var satelliteName: String {
        if name.contains("meteor_m2-x") {
            return "Meteor M2-x"
        } else if name.contains("meteor_m2-4") {
            return "Meteor M2-4"
        } else if name.contains("noaa") {
            return "NOAA"
        }
        return "Satelite"
    }

    var qualityStarsDisplay: String {
        String(repeating: "\u{2B50}", count: qualityStars)
    }
}

// MARK: - Pass Cleanup

struct PassCleanupResult: Codable {
    let timestamp: String
    let dryRun: Bool
    let thresholdMb: Double
    let totalFound: Int
    let totalRemoved: Int
    let freedMb: Double
    let passes: [CleanupPassInfo]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case dryRun = "dry_run"
        case thresholdMb = "threshold_mb"
        case totalFound = "total_found"
        case totalRemoved = "total_removed"
        case freedMb = "freed_mb"
        case passes
    }
}

struct CleanupPassInfo: Codable, Identifiable {
    let name: String
    let sizeMb: Double
    let imageCount: Int

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case sizeMb = "size_mb"
        case imageCount = "image_count"
    }
}

// MARK: - SatDump Status

struct SatDumpStatusResponse: Codable, Equatable {
    let timestamp: String
    let status: SatDumpStatus

    // Custom decoder to handle status that can be object or error
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(String.self, forKey: .timestamp)

        // Try to decode status as SatDumpStatus
        if let statusObj = try? container.decode(SatDumpStatus.self, forKey: .status) {
            status = statusObj
        } else {
            // If it fails, create a placeholder status (could be error response)
            status = SatDumpStatus(
                passName: "Unknown",
                sizeBytes: 0,
                sizeMb: 0,
                imageCount: 0,
                lastModified: "",
                ageMinutes: 0,
                isRecent: false
            )
        }
    }

    enum CodingKeys: String, CodingKey {
        case timestamp, status
    }
}

struct SatDumpStatus: Codable, Equatable {
    let passName: String
    let sizeBytes: Int64
    let sizeMb: Double
    let imageCount: Int
    let lastModified: String
    let ageMinutes: Double
    let isRecent: Bool

    enum CodingKeys: String, CodingKey {
        case passName = "pass_name"
        case sizeBytes = "size_bytes"
        case sizeMb = "size_mb"
        case imageCount = "image_count"
        case lastModified = "last_modified"
        case ageMinutes = "age_minutes"
        case isRecent = "is_recent"
    }

    var iconName: String {
        let n = passName.lowercased()
        if n.contains("meteor") { return "satellite.fill" }
        if n.contains("noaa") { return "antenna.radiowaves.left.and.right" }
        if n.contains("orbcomm") { return "antenna.radiowaves.left.and.right" }
        return "satellite"
    }
}

// MARK: - SatDump Live

struct SatDumpLiveResponse: Codable, Equatable {
    let timestamp: String
    let satdump: AnyCodable?
}

// MARK: - Meteor/Orbcomm Passes (API Response)

struct SatellitePassesResponse: Codable {
    let timestamp: String
    let count: Int
    let minElevation: Int?
    let stationLocation: String?
    let stationCoords: String?
    let passes: [APIPassPrediction]

    enum CodingKeys: String, CodingKey {
        case timestamp, count, passes
        case minElevation = "min_elevation"
        case stationLocation = "station_location"
        case stationCoords = "station_coords"
    }
}

/// Predicted pass data from API (distinct from local PredictedPass in SatellitePassPredictor)
struct APIPassPrediction: Codable, Identifiable, Equatable {
    let satellite: String
    let norad: Int?
    let aosUtc: String
    let aosBrt: String
    let maxUtc: String
    let maxBrt: String
    let losUtc: String
    let losBrt: String
    let durationMinutes: Double
    let maxElevation: Double
    let maxAzimuth: Double
    let aosAzimuth: Double
    let losAzimuth: Double
    let qualityStars: Int

    var id: String { "\(satellite)_\(aosUtc)" }

    enum CodingKeys: String, CodingKey {
        case satellite, norad
        case aosUtc = "aos_utc"
        case aosBrt = "aos_brt"
        case maxUtc = "max_utc"
        case maxBrt = "max_brt"
        case losUtc = "los_utc"
        case losBrt = "los_brt"
        case durationMinutes = "duration_minutes"
        case maxElevation = "max_elevation"
        case maxAzimuth = "max_azimuth"
        case aosAzimuth = "aos_azimuth"
        case losAzimuth = "los_azimuth"
        case qualityStars = "quality_stars"
    }

    var qualityStarsDisplay: String {
        String(repeating: "\u{2B50}", count: qualityStars)
    }
}

// MARK: - Orbcomm Runs

struct OrbcommRunsResponse: Codable {
    let timestamp: String
    let count: Int
    let runs: [OrbcommRun]
}

struct OrbcommRun: Codable, Identifiable, Equatable {
    let name: String
    let logBytes: Int
    let jsonlBytes: Int?
    let files: Int

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case logBytes = "log_bytes"
        case jsonlBytes = "jsonl_bytes"
        case files
    }
}

// MARK: - Orbcomm Decoded

struct OrbcommDecodedResponse: Codable {
    let timestamp: String
    let run: String
    let log: String?
    let jsonl: String?
    let count: Int
    let events: [AnyCodable]
    let groupedBySat: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case timestamp, run, log, jsonl, count, events
        case groupedBySat = "grouped_by_sat"
    }
}

// MARK: - Orbcomm Logs

struct OrbcommLogsResponse: Codable {
    let timestamp: String
    let run: String
    let log: String
    let count: Int
    let lines: [String]
}

// MARK: - Orbcomm Last Event

struct OrbcommLastEventResponse: Codable {
    let timestamp: String
    let run: String
    let log: String?
    let jsonl: String?
    let event: AnyCodable?
}

// MARK: - Satellite Positions

struct SatellitePositionsResponse: Codable {
    let timestamp: String
    let station: StationLocation
    let satellites: [SatellitePosition]
}

struct StationLocation: Codable, Equatable {
    let lat: Double
    let lon: Double
    let altM: Int

    enum CodingKeys: String, CodingKey {
        case lat, lon
        case altM = "alt_m"
    }
}

struct SatellitePosition: Codable, Identifiable, Equatable {
    let satelliteId: String
    let name: String
    let category: SatelliteCategory
    let norad: Int?
    let lat: Double
    let lon: Double
    let altKm: Double
    let elevation: Double
    let azimuth: Double

    var id: String { satelliteId }

    enum CodingKeys: String, CodingKey {
        case satelliteId = "id"
        case name, category, norad, lat, lon
        case altKm = "alt_km"
        case elevation, azimuth
    }
}

enum SatelliteCategory: String, Codable {
    case meteor = "Meteor"
    case orbcomm = "ORBCOMM"
    case unknown = "Unknown"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = SatelliteCategory(rawValue: value) ?? .unknown
    }
}

// MARK: - Satellite Status

struct SatelliteStatusResponse: Codable, Equatable {
    let timestamp: String
    let name: String
    let category: SatelliteCategory
    let norad: Int?
    let lat: Double
    let lon: Double
    let altKm: Double
    let elevation: Double
    let azimuth: Double
    let speedKmS: Double
    let orbitPeriodMin: Double?
    let meanMotionRevPerDay: Double?

    enum CodingKeys: String, CodingKey {
        case timestamp, name, category, norad, lat, lon
        case altKm = "alt_km"
        case elevation, azimuth
        case speedKmS = "speed_km_s"
        case orbitPeriodMin = "orbit_period_min"
        case meanMotionRevPerDay = "mean_motion_rev_per_day"
    }
}
