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

// MARK: - GPS Globe

struct GPSGlobeState: Codable, Equatable {
    let generatedAt: String
    let tzOffsetMinutes: Int?
    let tzName: String?
    let receiver: GPSGlobeReceiver
    let gpsd: GPSGlobeGPSD
    let sky: GPSGlobeSky
    let tle: GPSGlobeTLE?
    let satellitesVisible: [GPSGlobeSatellite]

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case tzOffsetMinutes = "tz_offset_minutes"
        case tzName = "tz_name"
        case receiver, gpsd, sky, tle
        case satellitesVisible = "satellites_visible"
    }

    var generatedDate: Date? {
        Formatters.isoDate.date(from: generatedAt)
            ?? Formatters.isoDateNoFrac.date(from: generatedAt)
    }
}

struct GPSGlobeReceiver: Codable, Equatable {
    let lat: Double
    let lon: Double
    let altitudeM: Double?
    let mode: Int?
    let speedMS: Double?
    let trackDeg: Double?
    let horizontalErrorM: Double?
    let verticalErrorM: Double?
    let timestamp: String?
    let ageSeconds: Double?
    let lastMessageAgeSeconds: Double?

    enum CodingKeys: String, CodingKey {
        case lat, lon, mode, timestamp
        case altitudeM = "altitude_m"
        case speedMS = "speed_ms"
        case trackDeg = "track_deg"
        case horizontalErrorM = "horizontal_error_m"
        case verticalErrorM = "vertical_error_m"
        case ageSeconds = "age_seconds"
        case lastMessageAgeSeconds = "last_message_age_seconds"
    }
}

struct GPSGlobeGPSD: Codable, Equatable {
    let device: GPSGlobeDevice?
    let lastMessageAt: Double?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case device, error
        case lastMessageAt = "last_message_at"
    }
}

struct GPSGlobeDevice: Codable, Equatable {
    let path: String?
    let driver: String?
    let subtype: String?
    let subtype1: String?
    let cycle: Double?
}

struct GPSGlobeSky: Codable, Equatable {
    let hdop: Double?
    let pdop: Double?
    let vdop: Double?
    let nSatellites: Int?
    let usedSatellites: Int?
    let gpsVisible: Int?
    let gpsUsed: Int?

    enum CodingKeys: String, CodingKey {
        case hdop, pdop, vdop
        case nSatellites = "n_satellites"
        case usedSatellites = "used_satellites"
        case gpsVisible = "gps_visible"
        case gpsUsed = "gps_used"
    }
}

struct GPSGlobeTLE: Codable, Equatable {
    let count: Int?
    let lastFetchAt: Double?
    let lastFetchISO: String?
    let lastError: String?

    enum CodingKeys: String, CodingKey {
        case count
        case lastFetchAt = "last_fetch_at"
        case lastFetchISO = "last_fetch_iso"
        case lastError = "last_error"
    }
}

struct GPSGlobeSatellite: Codable, Equatable, Identifiable {
    let prn: Int
    let azimuthDeg: Double?
    let elevationDeg: Double?
    let signalDBHz: Double?
    let used: Bool
    let health: Int?
    let name: String?
    let noradID: Int?
    let intlDesignator: String?
    let imageURL: String?
    let block: String?
    let launch: GPSGlobeLaunch?
    let orbit: GPSGlobeOrbit?
    let subpoint: GPSGlobeSubpoint?

    enum CodingKeys: String, CodingKey {
        case prn, used, health, name, block, launch, orbit, subpoint
        case azimuthDeg = "azimuth_deg"
        case elevationDeg = "elevation_deg"
        case signalDBHz = "signal_dbhz"
        case noradID = "norad_id"
        case intlDesignator = "intl_designator"
        case imageURL = "image_url"
    }

    var id: Int { prn }

    var displayName: String {
        name ?? "PRN \(prn)"
    }
}

struct GPSGlobeLaunch: Codable, Equatable {
    let dateLocalized: String?
    let timeUTC: String?
    let site: String?
    let vehicle: String?

    enum CodingKeys: String, CodingKey {
        case site, vehicle
        case dateLocalized = "date_localized"
        case timeUTC = "time_utc"
    }
}

struct GPSGlobeOrbit: Codable, Equatable {
    let speedKMH: Double?
    let periodMinutes: Double?

    enum CodingKeys: String, CodingKey {
        case speedKMH = "speed_kmh"
        case periodMinutes = "period_minutes"
    }
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
