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

/// Response from /api/satdump/last/images (new schema: pass object + root images array).
struct LastImages: Codable, Equatable {
    let timestamp: String
    let pass: SatDumpRecordedPass?
    let count: Int?
    let images: [SatelliteImage]

    enum CodingKeys: String, CodingKey {
        case timestamp, pass, count, images
    }

    /// Derived pass name for display / AI summary (backwards-compat with old `pass_name` field).
    var passName: String { pass?.name ?? pass?.id ?? "" }

    var iconName: String {
        let n = passName.lowercased()
        if n.contains("meteor") { return "satellite.fill" }
        if n.contains("noaa") || n.contains("orbcomm") {
            return "antenna.radiowaves.left.and.right"
        }
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

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try c.decode(String.self, forKey: .timestamp)
        count = try c.decode(Int.self, forKey: .count)
        totalCount = try c.decodeIfPresent(Int.self, forKey: .totalCount) ?? count
        page = try c.decodeIfPresent(Int.self, forKey: .page) ?? 1
        limit = try c.decodeIfPresent(Int.self, forKey: .limit) ?? 50
        totalPages = try c.decodeIfPresent(Int.self, forKey: .totalPages) ?? 1
        passes = try c.decodeIfPresent([SatellitePassExtended].self, forKey: .passes) ?? []
    }
}

struct SatellitePassExtended: Codable, Identifiable, Equatable {
    let name: String
    let imageFolder: String
    let imageCount: Int
    let sizeMb: Double
    let qualityStars: Int
    let satellite: String?
    let passTimestamp: String?
    let products: [String]?

    var id: String { name }

    var toSatellitePass: SatellitePass {
        SatellitePass(name: name, imageFolder: imageFolder, imageCount: imageCount)
    }

    enum CodingKeys: String, CodingKey {
        case name, satellite, products
        case imageFolder = "image_folder"
        case imageCount = "image_count"
        case sizeMb = "size_mb"
        case qualityStars = "quality_stars"
        case passTimestamp = "timestamp"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        imageFolder = try c.decodeIfPresent(String.self, forKey: .imageFolder) ?? ""
        imageCount = try c.decodeIfPresent(Int.self, forKey: .imageCount) ?? 0
        sizeMb = try c.decodeIfPresent(Double.self, forKey: .sizeMb) ?? 0.0
        qualityStars = try c.decodeIfPresent(Int.self, forKey: .qualityStars) ?? 0
        satellite = try c.decodeIfPresent(String.self, forKey: .satellite)
        passTimestamp = try c.decodeIfPresent(String.self, forKey: .passTimestamp)
        products = try c.decodeIfPresent([String].self, forKey: .products)
    }

    var iconName: String {
        let n = name.lowercased()
        if n.contains("meteor") { return "satellite.fill" }
        if n.contains("noaa") || n.contains("orbcomm") {
            return "antenna.radiowaves.left.and.right"
        }
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

// MARK: - SatDump Recorded Pass (new API format)

/// A recorded SatDump pass as returned by /api/satdump/status (last_pass),
/// /api/satdump/passes and /api/satdump/last/images.
struct SatDumpRecordedPass: Codable, Equatable, Identifiable {
    let id: String
    let name: String?
    let satellite: String?
    let timestamp: String?
    let products: [String]?
    let imageCount: Int?
    let images: [AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case id, name, satellite, timestamp, products, images
        case imageCount = "image_count"
    }
}

// MARK: - SatDump Status

/// Response from /api/satdump/status (new schema, 2026-04).
/// Bridges into legacy `SatDumpStatus` for view compatibility.
struct SatDumpStatusResponse: Codable, Equatable {
    let timestamp: String
    let ok: Bool?
    let meteorBaseExists: Bool?
    let orbcommBaseExists: Bool?
    let meteorPassCount: Int?
    let orbcommRunCount: Int?
    let lastPass: SatDumpRecordedPass?
    let stale: Bool?

    enum CodingKeys: String, CodingKey {
        case timestamp, ok, stale
        case meteorBaseExists = "meteor_base_exists"
        case orbcommBaseExists = "orbcomm_base_exists"
        case meteorPassCount = "meteor_pass_count"
        case orbcommRunCount = "orbcomm_run_count"
        case lastPass = "last_pass"
    }

    /// Bridge into the legacy `SatDumpStatus` type consumed by views.
    var status: SatDumpStatus {
        let passName = lastPass?.name ?? lastPass?.id ?? "Desconhecido"
        let imageCount = lastPass?.imageCount ?? 0
        let lastModified = lastPass?.timestamp ?? timestamp

        // Calculate age from lastPass.timestamp (ISO 8601) to now
        let ageMinutes: Double
        if let ts = lastPass?.timestamp,
            let date = ISO8601DateFormatter().date(from: ts)
                ?? {
                    let f = DateFormatter()
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    return f.date(from: ts)
                }()
        {
            ageMinutes = Date().timeIntervalSince(date) / 60.0
        } else {
            ageMinutes = 0
        }

        let isRecent = !(stale ?? true) || ageMinutes < 30

        return SatDumpStatus(
            passName: passName,
            sizeBytes: 0,
            sizeMb: 0.0,
            imageCount: imageCount,
            lastModified: lastModified,
            ageMinutes: ageMinutes,
            isRecent: isRecent
        )
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

/// Response from /api/satdump/orbcomm/decoded (new schema: data nested object).
/// View-bridge properties keep the same interface as the old flat format.
struct OrbcommDecodedResponse: Codable {
    let timestamp: String
    let run: String
    let log: String?
    let jsonl: String?
    let count: Int
    let events: [AnyCodable]
    let groupedBySat: [String: AnyCodable]?

    // MARK: Custom decoder — new API wraps data under "data" key

    private enum RootKeys: String, CodingKey { case timestamp, data }
    private enum DataKeys: String, CodingKey {
        case run, limit, files, winner
    }
    private enum FilesKeys: String, CodingKey { case jsonl, log }
    private enum WinnerKeys: String, CodingKey {
        case totalEvents = "total_events"
        case validSatEvents = "valid_sat_events"
    }

    init(from decoder: Decoder) throws {
        let root = try decoder.container(keyedBy: RootKeys.self)
        timestamp = try root.decode(String.self, forKey: .timestamp)

        if let dataContainer = try? root.nestedContainer(keyedBy: DataKeys.self, forKey: .data) {
            run = (try? dataContainer.decodeIfPresent(String.self, forKey: .run)) ?? ""
            if let filesContainer = try? dataContainer.nestedContainer(
                keyedBy: FilesKeys.self, forKey: .files)
            {
                log = try? filesContainer.decodeIfPresent(String.self, forKey: .log) ?? nil
                jsonl = try? filesContainer.decodeIfPresent(String.self, forKey: .jsonl) ?? nil
            } else {
                log = nil
                jsonl = nil
            }
            if let winnerContainer = try? dataContainer.nestedContainer(
                keyedBy: WinnerKeys.self, forKey: .winner)
            {
                count = (try? winnerContainer.decodeIfPresent(Int.self, forKey: .totalEvents)) ?? 0
            } else {
                count = 0
            }
        } else {
            // Fallback: try flat old format
            let flat = try decoder.container(keyedBy: CodingKeys.self)
            run = (try? flat.decodeIfPresent(String.self, forKey: .run)) ?? ""
            log = try? flat.decodeIfPresent(String.self, forKey: .log) ?? nil
            jsonl = try? flat.decodeIfPresent(String.self, forKey: .jsonl) ?? nil
            count = (try? flat.decodeIfPresent(Int.self, forKey: .count)) ?? 0
        }
        events = []
        groupedBySat = nil
    }

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
    let degraded: Bool?
    let degradedReason: String?

    enum CodingKeys: String, CodingKey {
        case timestamp, station, satellites, degraded
        case degradedReason = "degraded_reason"
    }
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

// MARK: - GPS Globe
// Decodes the new gps.meulab.fun/api/state payload (satellite tracking API).
// Bridge computed properties expose the legacy interface used by views.

struct GPSGlobeState: Codable, Equatable {
    let generatedAt: String
    let observer: GPSGlobeObserver
    let satellites: [GPSGlobeSatellite]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case observer
        case satellites
    }

    var generatedDate: Date? {
        Formatters.isoDate.date(from: generatedAt)
            ?? Formatters.isoDateNoFrac.date(from: generatedAt)
    }

    // MARK: View bridge properties

    var satellitesVisible: [GPSGlobeSatellite] { satellites }

    var receiver: GPSGlobeReceiver {
        GPSGlobeReceiver(lat: observer.lat, lon: observer.lon, altitudeM: observer.altM)
    }

    var gpsd: GPSGlobeGPSD { GPSGlobeGPSD() }

    var sky: GPSGlobeSky {
        let capturable = satellites.filter { $0.capturableNow == true }.count
        return GPSGlobeSky(
            gpsVisible: satellites.isEmpty ? nil : satellites.count,
            gpsUsed: capturable > 0 ? capturable : nil
        )
    }
}

struct GPSGlobeObserver: Codable, Equatable {
    let lat: Double
    let lon: Double
    let altM: Double?
    let qth: String?

    enum CodingKeys: String, CodingKey {
        case lat, lon, qth
        case altM = "alt_m"
    }
}

/// Bridge struct — constructed from GPSGlobeObserver; not Codable.
struct GPSGlobeReceiver: Equatable {
    let lat: Double
    let lon: Double
    let altitudeM: Double?
    var mode: Int? = nil
    var horizontalErrorM: Double? = nil
}

/// Bridge struct — not present in new API; provides nil error to views.
struct GPSGlobeGPSD: Equatable {
    var error: String? = nil
}

/// Bridge struct — derived from satellite array counts; not Codable.
struct GPSGlobeSky: Equatable {
    var hdop: Double? = nil
    var pdop: Double? = nil
    var vdop: Double? = nil
    var nSatellites: Int? = nil
    var usedSatellites: Int? = nil
    var gpsVisible: Int? = nil
    var gpsUsed: Int? = nil
}

/// Represents the next pass info object in gps.meulab.fun/api/state satellites[].next_pass
struct GPSGlobeNextPass: Codable, Equatable {
    let satellite: String?
    let aosUtc: String?
    let losUtc: String?
    let durationSec: Double?
    let maxElevationDeg: Double?
    let centerFrequencyHz: Int?
    let recommendedGain: Int?
    let recommendedDurationSec: Int?

    enum CodingKeys: String, CodingKey {
        case satellite
        case aosUtc = "aos_utc"
        case losUtc = "los_utc"
        case durationSec = "duration_sec"
        case maxElevationDeg = "max_elevation_deg"
        case centerFrequencyHz = "center_frequency_hz"
        case recommendedGain = "recommended_gain"
        case recommendedDurationSec = "recommended_duration_sec"
    }
}

/// Satellite entry from the new API payload.
struct GPSGlobeSatellite: Codable, Equatable, Identifiable {
    // Stored (decoded) properties — id is now a String (e.g. "orbcomm-fm112")
    let id: String
    let satellite: String?
    let family: String?
    let latitudeDeg: Double?
    let longitudeDeg: Double?
    let altitudeKm: Double?
    let speedKmS: Double?
    let speedKmH: Double?
    let elevationDeg: Double?
    let imageURL: String?
    let capturableNow: Bool?
    let nextPass: GPSGlobeNextPass?
    let nextAosInSec: Double?
    let observerQth: String?

    enum CodingKeys: String, CodingKey {
        case id, satellite, family
        case latitudeDeg = "latitude_deg"
        case longitudeDeg = "longitude_deg"
        case altitudeKm = "altitude_km"
        case speedKmS = "speed_km_s"
        case speedKmH = "speed_km_h"
        case elevationDeg = "elevation_deg"
        case imageURL = "image_url"
        case capturableNow = "capturable_now"
        case nextPass = "next_pass"
        case nextAosInSec = "next_aos_in_sec"
        case observerQth = "observer_qth"
    }

    // MARK: View bridge computed properties

    /// Stable Int derived from the String id for SceneKit node keying (session-local only)
    var prn: Int { abs(id.hashValue) }
    var used: Bool { capturableNow ?? false }
    var name: String? { satellite }
    var displayName: String { satellite ?? "SAT \(id)" }
    var azimuthDeg: Double? { nil }
    var signalDBHz: Double? { nil }
    var noradID: Int? { nil }
    var intlDesignator: String? { nil }
    var block: String? { nil }
    var health: Int? { nil }
    var launch: GPSGlobeLaunch? { nil }

    var orbit: GPSGlobeOrbit? {
        guard let speed = speedKmH else { return nil }
        return GPSGlobeOrbit(speedKMH: speed, periodMinutes: nil)
    }

    var subpoint: GPSGlobeSubpoint? {
        guard let lat = latitudeDeg, let lon = longitudeDeg else { return nil }
        return GPSGlobeSubpoint(
            lat: lat, lon: lon, altitudeKM: altitudeKm, displayAltitude: altitudeKm)
    }
}

/// Bridge struct — represents known launch metadata; always nil for new API.
struct GPSGlobeLaunch: Equatable {
    let dateLocalized: String?
    let timeUTC: String?
    let site: String?
    let vehicle: String?
}

/// Bridge struct — orbital parameters; speedKMH sourced from new API.
struct GPSGlobeOrbit: Equatable {
    let speedKMH: Double?
    let periodMinutes: Double?
}

struct GPSGlobeSubpoint: Codable, Equatable {
    let lat: Double
    let lon: Double
    let altitudeKM: Double?
    let displayAltitude: Double?

    enum CodingKeys: String, CodingKey {
        case lat, lon
        case altitudeKM = "altitude_km"
        case displayAltitude = "display_altitude"
    }
}

// MARK: - API2 Models (app2.meulab.fun)

// MARK: Orbcomm Capture (API2)
struct API2OrbcommCapture: Codable, Identifiable, Equatable {
    let name: String
    let family: String
    let path: String
    let modifiedAt: String
    let fileCount: Int
    let files: [API2CaptureFile]?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, family, path, files
        case modifiedAt = "modified_at"
        case fileCount = "file_count"
    }
}

struct API2CaptureFile: Codable, Equatable {
    let name: String
    let sizeBytes: Int
    let modifiedAt: String

    enum CodingKeys: String, CodingKey {
        case name
        case sizeBytes = "size_bytes"
        case modifiedAt = "modified_at"
    }
}

// MARK: Orbcomm Recent (API2)
struct API2OrbcommRecentResponse: Codable {
    let captures: [API2OrbcommCapture]
}

// MARK: Orbcomm Latest (API2)
struct API2OrbcommLatestResponse: Codable {
    let hasCapture: Bool
    let captureCountToday: Int
    let latestCapture: API2OrbcommCapture?

    enum CodingKeys: String, CodingKey {
        case hasCapture = "has_capture"
        case captureCountToday = "capture_count_today"
        case latestCapture = "latest_capture"
    }
}

// MARK: Orbcomm Decoder Status (API2)
struct API2OrbcommDecoderStatusResponse: Codable {
    let service: String
    let ready: API2DecoderReady
    let decoderBusy: Bool
    let meteorWindowActive: Bool
    let meteorWindowReason: String?
    let nextMeteorWindow: API2MeteorWindow?
    let recentRuns: [API2DecoderRun]?

    enum CodingKeys: String, CodingKey {
        case service, ready
        case decoderBusy = "decoder_busy"
        case meteorWindowActive = "meteor_window_active"
        case meteorWindowReason = "meteor_window_reason"
        case nextMeteorWindow = "next_meteor_window"
        case recentRuns = "recent_runs"
    }
}

struct API2DecoderReady: Codable {
    let repoDir: String?
    let repoExists: Bool
    let rtlSdrBin: String?
    let rtlSdrExists: Bool
    let decimatorExists: Bool
    let decoderExists: Bool
    let sessionsDirExists: Bool
    let sgp4Available: Bool

    enum CodingKeys: String, CodingKey {
        case repoDir = "repo_dir"
        case repoExists = "repo_exists"
        case rtlSdrBin = "rtl_sdr_bin"
        case rtlSdrExists = "rtl_sdr_exists"
        case decimatorExists = "decimator_exists"
        case decoderExists = "decoder_exists"
        case sessionsDirExists = "sessions_dir_exists"
        case sgp4Available = "sgp4_available"
    }
}

struct API2MeteorWindow: Codable {
    let satellite: String
    let aosUtc: String
    let losUtc: String
    let durationSec: Int
    let maxElevationDeg: Double
    let bufferedAosUtc: String?
    let bufferedLosUtc: String?
    let startsInSec: Int?
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case satellite
        case aosUtc = "aos_utc"
        case losUtc = "los_utc"
        case durationSec = "duration_sec"
        case maxElevationDeg = "max_elevation_deg"
        case bufferedAosUtc = "buffered_aos_utc"
        case bufferedLosUtc = "buffered_los_utc"
        case startsInSec = "starts_in_sec"
        case active
    }
}

struct API2DecoderRunEvent: Codable, Identifiable {
    let type: String
    let satellite: String?
    let elevationDeg: Double?
    let dopplerHz: Double?
    let unixTimestamp: Int?
    let utc: String?

    var id: String { "\(type)_\(unixTimestamp ?? 0)" }

    enum CodingKeys: String, CodingKey {
        case type, satellite, utc
        case elevationDeg = "elevation_deg"
        case dopplerHz = "doppler_hz"
        case unixTimestamp = "unix_timestamp"
    }
}

struct API2DecoderRunSummary: Codable {
    let numSatsLoaded: Int?
    let satellitesAcquired: [String]?
    let totalPackets: Int?
    let goodPackets: Int?
    let badPackets: Int?
    let packetTypes: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case numSatsLoaded = "num_sats_loaded"
        case satellitesAcquired = "satellites_acquired"
        case totalPackets = "total_packets"
        case goodPackets = "good_packets"
        case badPackets = "bad_packets"
        case packetTypes = "packet_types"
    }
}

struct API2DecoderRun: Codable, Identifiable {
    let runId: String
    let path: String?
    let modifiedAt: String?
    let decoderLogExists: Bool?
    let rtlLogExists: Bool?
    let summary: API2DecoderRunSummary?
    let events: [API2DecoderRunEvent]?
    let recentMessages: [AnyCodable]?

    var id: String { runId }

    enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case path
        case modifiedAt = "modified_at"
        case decoderLogExists = "decoder_log_exists"
        case rtlLogExists = "rtl_log_exists"
        case summary, events
        case recentMessages = "recent_messages"
    }
}

// MARK: Orbcomm Decoder Run (POST response)
struct API2DecoderRunResponse: Codable {
    let status: String
    let runId: String?
    let message: String?
    let durationSec: Int?
    let centerFrequencyHz: Int?
    let gain: Int?

    enum CodingKeys: String, CodingKey {
        case status, message
        case runId = "run_id"
        case durationSec = "duration_sec"
        case centerFrequencyHz = "center_frequency_hz"
        case gain
    }
}

// MARK: Orbcomm Decoder Latest Packets (API2)
struct API2DecoderLatestPacketsResponse: Codable {
    let sessionsReturned: Int
    let sessions: [API2DecoderRun]

    enum CodingKeys: String, CodingKey {
        case sessionsReturned = "sessions_returned"
        case sessions
    }
}

// MARK: Orbcomm Decoder Latest Messages (API2)
struct API2DecoderLatestMessagesResponse: Codable {
    let sessionsReturned: Int
    let sessions: [API2DecoderRun]

    enum CodingKeys: String, CodingKey {
        case sessionsReturned = "sessions_returned"
        case sessions
    }
}

// MARK: Orbcomm Passes Next (API2)
struct API2OrbcommPassesObserver: Codable {
    let lat: Double
    let lon: Double
    let altM: Int?

    enum CodingKeys: String, CodingKey {
        case lat, lon
        case altM = "alt_m"
    }
}

struct API2OrbcommPass: Codable, Identifiable, Equatable {
    let satellite: String
    let aosUtc: String
    let losUtc: String
    let durationSec: Int
    let maxElevationDeg: Double
    let centerFrequencyHz: Int?
    let recommendedGain: Int?
    let recommendedDurationSec: Int?

    var id: String { "\(satellite)_\(aosUtc)" }

    enum CodingKeys: String, CodingKey {
        case satellite
        case aosUtc = "aos_utc"
        case losUtc = "los_utc"
        case durationSec = "duration_sec"
        case maxElevationDeg = "max_elevation_deg"
        case centerFrequencyHz = "center_frequency_hz"
        case recommendedGain = "recommended_gain"
        case recommendedDurationSec = "recommended_duration_sec"
    }
}

struct API2OrbcommPassesNextResponse: Codable {
    let observer: API2OrbcommPassesObserver?
    let decoderOnly: Bool?
    let decoderSatellites: [String]?
    let passCount: Int
    let passes: [API2OrbcommPass]

    enum CodingKeys: String, CodingKey {
        case observer
        case decoderOnly = "decoder_only"
        case decoderSatellites = "decoder_satellites"
        case passCount = "pass_count"
        case passes
    }
}

// MARK: Orbcomm Schedule Next (POST response)
struct API2OrbcommScheduleNextResponse: Codable {
    let status: String
    let runId: String?
    let satellite: String?
    let aosUtc: String?
    let losUtc: String?
    let maxElevationDeg: Double?
    let durationSec: Int?
    let gain: Int?
    let firesInSec: Int?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case status, satellite, message
        case runId = "run_id"
        case aosUtc = "aos_utc"
        case losUtc = "los_utc"
        case maxElevationDeg = "max_elevation_deg"
        case durationSec = "duration_sec"
        case gain
        case firesInSec = "fires_in_sec"
    }
}

// MARK: Orbcomm Scheduled Passes (API2)
struct API2OrbcommScheduledPass: Codable, Identifiable {
    let runId: String
    let satellite: String
    let aosUtc: String
    let losUtc: String
    let maxElevationDeg: Double
    let durationSec: Int
    let gain: Int
    let centerFrequencyHz: Int
    let firesInSec: Int?
    let scheduledAt: String?
    let timerAlive: Bool?

    var id: String { runId }

    enum CodingKeys: String, CodingKey {
        case satellite
        case runId = "run_id"
        case aosUtc = "aos_utc"
        case losUtc = "los_utc"
        case maxElevationDeg = "max_elevation_deg"
        case durationSec = "duration_sec"
        case gain
        case centerFrequencyHz = "center_frequency_hz"
        case firesInSec = "fires_in_sec"
        case scheduledAt = "scheduled_at"
        case timerAlive = "timer_alive"
    }
}

struct API2OrbcommScheduledResponse: Codable {
    let scheduledCount: Int
    let scheduled: [API2OrbcommScheduledPass]

    enum CodingKeys: String, CodingKey {
        case scheduledCount = "scheduled_count"
        case scheduled
    }
}

// MARK: Meteor Status (API2)
struct API2MeteorStatusResponse: Codable {
    let windowActive: Bool
    let windowReason: String?
    let nextWindow: API2MeteorWindow?
    let tleFileExists: Bool?
    let tleAge: String?
    let satdumpLaunchagent: API2LaunchAgentInfo?
    let recentCaptures: [API2OrbcommCapture]?

    enum CodingKeys: String, CodingKey {
        case windowActive = "window_active"
        case windowReason = "window_reason"
        case nextWindow = "next_window"
        case tleFileExists = "tle_file_exists"
        case tleAge = "tle_age"
        case satdumpLaunchagent = "satdump_launchagent"
        case recentCaptures = "recent_captures"
    }
}

struct API2LaunchAgentInfo: Codable {
    let label: String?
    let loaded: Bool?
    let state: String?
    let pid: Int?
    let path: String?
}

// MARK: Meteor Passes Next (API2)
struct API2MeteorPassesNextResponse: Codable {
    let observer: API2OrbcommPassesObserver?
    let passCount: Int
    let passes: [API2OrbcommPass]

    enum CodingKeys: String, CodingKey {
        case observer
        case passCount = "pass_count"
        case passes
    }
}

// MARK: SatDump Status (API2)
struct API2SatDumpStatusResponse: Codable {
    let satdumpRunning: Bool?
    let satdumpPid: Int?
    let autotrackRunning: Bool?
    let autotrackPid: Int?
    let recentCaptures: [API2OrbcommCapture]?

    enum CodingKeys: String, CodingKey {
        case satdumpRunning = "satdump_running"
        case satdumpPid = "satdump_pid"
        case autotrackRunning = "autotrack_running"
        case autotrackPid = "autotrack_pid"
        case recentCaptures = "recent_captures"
    }
}

// MARK: TLE Update (API2)
struct API2TLEUpdateResponse: Codable {
    let status: String
    let message: String?
    let updated: Int?
}

// MARK: Orbcomm Cancel Pass (API2)
struct API2CancelPassResponse: Codable {
    let status: String
    let runId: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case status, message
        case runId = "run_id"
    }
}
