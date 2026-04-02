import Foundation

// MARK: - Watch Summary (agregado)

struct WatchSummary {
    let adsb: WatchADSBData
    let acars: WatchACARSData
    let system: WatchSystemData
    let weather: WatchWeatherData
    let infra: WatchInfraData
    let satdump: WatchSatDumpData
    let timestamp: Date
}

// MARK: - ADS-B

struct WatchADSBData: Codable {
    let totalNow: Int
    let withPos: Int
    let above10000: Int?
    let nonCivilNow: Int?

    enum CodingKeys: String, CodingKey {
        case totalNow = "total_now"
        case withPos = "with_pos"
        case above10000 = "above_10000"
        case nonCivilNow = "non_civil_now"
    }
}

struct WatchAircraftList: Codable {
    let count: Int
    let items: [WatchAircraft]
}

struct WatchAircraft: Codable, Identifiable {
    let id: String
    let callsign: String
    let model: String?
    let airline: String?
    let altitudeFt: Int
    let speedKt: Int
    let distanceNm: Double?

    enum CodingKeys: String, CodingKey {
        case id, callsign, model, airline
        case altitudeFt = "altitude_ft"
        case speedKt = "speed_kt"
        case distanceNm = "distance_nm"
    }

    var displayCallsign: String {
        callsign.isEmpty ? id : callsign
    }
}

// MARK: - ACARS

struct WatchACARSData: Codable {
    let messagesTotal: Int
    let messagesLast24h: Int?
    let uniqueFlights: Int?
    let uniqueAircraft: Int?

    enum CodingKeys: String, CodingKey {
        case messagesTotal = "messages_total"
        case messagesLast24h = "messages_last_24h"
        case uniqueFlights = "unique_flights"
        case uniqueAircraft = "unique_aircraft"
    }
}

struct WatchACARSMessageList: Codable {
    let messages: [WatchACARSMessage]
}

struct WatchACARSMessage: Codable, Identifiable {
    let id: String
    let timestamp: String
    let flight: String?
    let registration: String?
    let text: String?
    let label: String?
}

// MARK: - System

struct WatchSystemData: Codable {
    let cpu: WatchCPUData?
    let memory: WatchMemoryData?
    let disk: WatchDiskData?
    let wifi: WatchWiFiData?
    let uptime: WatchUptimeData?

    // Computed helpers for backward compat
    var cpuPercent: Double { cpu?.usagePercent ?? 0 }
    var cpuTemp: Double? { cpu?.temperatureC }
    var memoryPercent: Double { memory?.usedPercent ?? 0 }
    var diskPercent: Double { disk?.usedPercent ?? 0 }
    var wifiSignal: Int? { wifi?.signalDbm }
    var uptimeFormatted: String? { uptime?.formatted }
}

struct WatchCPUData: Codable {
    let usagePercent: Double?
    let temperatureC: Double?
    let cores: Int?

    enum CodingKeys: String, CodingKey {
        case usagePercent = "usage_percent"
        case temperatureC = "temperature_c"
        case cores
    }
}

struct WatchMemoryData: Codable {
    let usedPercent: Double?
    let totalMb: Int?
    let usedMb: Int?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case totalMb = "total_mb"
        case usedMb = "used_mb"
    }
}

struct WatchDiskData: Codable {
    let usedPercent: Double?
    let totalGb: Double?
    let usedGb: Double?

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case totalGb = "total_gb"
        case usedGb = "used_gb"
    }
}

struct WatchWiFiData: Codable {
    let signalDbm: Int?
    let ssid: String?

    enum CodingKeys: String, CodingKey {
        case signalDbm = "signal_dbm"
        case ssid
    }
}

struct WatchUptimeData: Codable {
    let formatted: String?
    let days: Int?
    let hours: Int?
}

// MARK: - Weather

struct WatchWeatherData: Codable {
    let current: WatchCurrentWeather?
    let today: WatchTodayWeather?
    let forecast: [WatchForecastDay]?
}

struct WatchCurrentWeather: Codable {
    let tempC: Int
    let feelsLikeC: Int?
    let humidity: Int?
    let windKmh: Int?
    let windDir: String?
    let description: String
    let precipMm: Double?
    let uvIndex: Int?

    enum CodingKeys: String, CodingKey {
        case tempC = "temp_c"
        case feelsLikeC = "feels_like_c"
        case humidity
        case windKmh = "wind_kmh"
        case windDir = "wind_dir"
        case description
        case precipMm = "precip_mm"
        case uvIndex = "uv_index"
    }

    // Compat helpers
    var temperature: Double { Double(tempC) }
    var condition: String { description }
}

struct WatchTodayWeather: Codable {
    let maxTempC: Int?
    let minTempC: Int?
    let rainChance: Int?

    enum CodingKeys: String, CodingKey {
        case maxTempC = "max_temp_c"
        case minTempC = "min_temp_c"
        case rainChance = "rain_chance"
    }
}

struct WatchForecastDay: Codable, Identifiable {
    var id: String { date }
    let date: String
    let maxTempC: Int?
    let minTempC: Int?
    let rainChance: Int?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case date, description
        case maxTempC = "max_temp_c"
        case minTempC = "min_temp_c"
        case rainChance = "rain_chance"
    }

    // Compat helpers
    var tempMin: Double { Double(minTempC ?? 0) }
    var tempMax: Double { Double(maxTempC ?? 0) }
    var condition: String { description ?? "" }
}

// MARK: - Infra

struct WatchInfraData {
    let metrics: WatchMetricsData
    let docker: WatchDockerData
}

struct WatchMetricsData: Codable {
    let uptime: String?
    let requestsTotal: Int?
    let avgLatencyMs: Double?

    enum CodingKeys: String, CodingKey {
        case uptime
        case requestsTotal = "requests_total"
        case avgLatencyMs = "avg_latency_ms"
    }
}

struct WatchDockerData: Codable {
    let containers: [WatchContainer]
}

struct WatchContainer: Codable, Identifiable {
    var id: String { name }
    let name: String
    let state: String
    let health: String?
}

// MARK: - SatDump

struct WatchSatDumpData: Codable {
    let status: WatchSatDumpStatus?
}

struct WatchSatDumpStatus: Codable {
    let running: Bool?
    let currentPass: String?
    let lastPass: WatchLastPass?

    enum CodingKeys: String, CodingKey {
        case running
        case currentPass = "current_pass"
        case lastPass = "last_pass"
    }
}

struct WatchLastPass: Codable {
    let satellite: String?
    let timestamp: String?
}

struct WatchPassesList: Codable {
    let passes: [WatchPass]
}

struct WatchPass: Codable, Identifiable {
    var id: String { name }
    let name: String
    let satellite: String
    let timestamp: String
}

// MARK: - Alerts/Notifications

struct WatchNotificationResponse: Codable {
    let items: [WatchAlert]
}

struct WatchAlert: Codable, Identifiable {
    let id: Int
    let type: String
    let title: String
    let message: String?
    let timestamp: String
    let category: String?
}

// Reuse AirlineLogo logic for Watch
struct WatchAirlineLogo {
    static let mapping: [String: String] = [
        // Brazilian Airlines
        "LATAM": "LA",
        "TAM": "JJ",
        "GOL": "G3",
        "AZUL": "AD",
        "VOEPASS": "2Z",
        "PASSAREDO": "2Z",
        "SIDERAL": "SD",
        "MODERN": "WD",
        "TOTAL": "L0",
        "AZUL CONECTA": "AD",
        "MAP": "7M",
        "ABSA": "M3",
        "TWO FLEX": "7Y",
        "ITAPEMIRIM": "3H",
        // South American
        "AVIANCA": "AV",
        "AVIANCA BRASIL": "O6",
        "AEROLINEAS ARGENTINAS": "AR",
        "AEROLINEAS": "AR",
        "FLYBONDI": "FO",
        "JETSMART": "JA",
        "SKY AIRLINE": "H2",
        "COPA": "CM",
        "COPA AIRLINES": "CM",
        "BOLIVIANA": "OB",
        "BOA": "OB",
        "BOLIVIANA DE AVIACION": "OB",
        "AEROMEXICO": "AM",
        "VOLARIS": "Y4",
        "INTERJET": "4O",
        "VIVA AIR": "VH",
        "VIVA AEROBUS": "VB",
        "WINGO": "P5",
        "SATENA": "9R",
        "EASYFLY": "VE",
        // European
        "LUFTHANSA": "LH",
        "TAP": "TP",
        "AIR FRANCE": "AF",
        "KLM": "KL",
        "IBERIA": "IB",
        "BRITISH": "BA",
        "AIR EUROPA": "UX",
        "TURKISH": "TK",
        "SWISS": "LX",
        "ITA AIRWAYS": "AZ",
        "ALITALIA": "AZ",
        "VUELING": "VY",
        "RYANAIR": "FR",
        "EASYJET": "U2",
        "NORWEGIAN": "DY",
        "SAS": "SK",
        "FINNAIR": "AY",
        "LOT": "LO",
        "AUSTRIAN": "OS",
        "BRUSSELS": "SN",
        "AEROFLOT": "SU",
        "EUROWINGS": "EW",
        "CONDOR": "DE",
        "WIZZ": "W6",
        "AIR SERBIA": "JU",
        "TRANSAVIA": "HV",
        // North American
        "AMERICAN": "AA",
        "DELTA": "DL",
        "UNITED": "UA",
        "SOUTHWEST": "WN",
        "JETBLUE": "B6",
        "ALASKA": "AS",
        "SPIRIT": "NK",
        "FRONTIER": "F9",
        "AIR CANADA": "AC",
        "WESTJET": "WS",
        // Middle East
        "EMIRATES": "EK",
        "QATAR": "QR",
        "ETIHAD": "EY",
        "SAUDIA": "SV",
        "ROYAL JORDANIAN": "RJ",
        "GULF AIR": "GF",
        "OMAN AIR": "WY",
        "KUWAIT": "KU",
        // Asian
        "SINGAPORE": "SQ",
        "CATHAY": "CX",
        "ANA": "NH",
        "JAL": "JL",
        "JAPAN AIR": "JL",
        "KOREAN AIR": "KE",
        "ASIANA": "OZ",
        "CHINA SOUTHERN": "CZ",
        "CHINA EASTERN": "MU",
        "AIR CHINA": "CA",
        "HAINAN": "HU",
        "THAI": "TG",
        "VIETNAM": "VN",
        "GARUDA": "GA",
        "MALAYSIA": "MH",
        "PHILIPPINE": "PR",
        "EVA AIR": "BR",
        "CHINA AIRLINES": "CI",
        // Oceanian
        "QANTAS": "QF",
        "AIR NEW ZEALAND": "NZ",
        "FIJI AIRWAYS": "FJ",
        // African
        "SOUTH AFRICAN": "SA",
        "ETHIOPIAN": "ET",
        "KENYA AIRWAYS": "KQ",
        "EGYPT AIR": "MS",
        "ROYAL AIR MAROC": "AT",
        "FEDEX": "FX",
        "UPS": "5X",
        "DHL": "D0",
        "CARGOLUX": "CV",
        "ATLAS AIR": "5Y",
    ]

    static func url(for name: String) -> URL? {
        let cleanName = name.uppercased().trimmingCharacters(in: .whitespaces)
        guard let code = mapping[cleanName] else { return nil }
        return URL(string: "https://daisy.airdispatch.cl/logos/\(code).png")
    }

    static func url(fromCallsign callsign: String) -> URL? {
        let prefix = String(callsign.prefix(3)).uppercased()

        let mapping: [String: String] = [
            "TAM": "JJ", "GLO": "G3", "AZU": "AD", "PTB": "2Z", "ONE": "LA",
            "LAN": "LA", "SID": "SD", "ABJ": "M3", "TIB": "L0",
            "AVA": "AV", "ARG": "AR", "FBH": "FO", "JAT": "JA", "SKU": "H2",
            "CMP": "CM", "BOV": "OB", "AMX": "AM", "VOI": "Y4",
            "VIV": "VH", "VB": "VB", "RPB": "P5", "NSE": "9R",
            "DLH": "LH", "TAP": "TP", "AFR": "AF", "KLM": "KL", "IBE": "IB",
            "BAW": "BA", "AEA": "UX", "THY": "TK", "SWR": "LX", "ITY": "AZ",
            "AZA": "AZ", "VLG": "VY", "RYR": "FR", "EZY": "U2", "NAX": "DY",
            "SAS": "SK", "FIN": "AY", "LOT": "LO", "AUA": "OS", "BEL": "SN",
            "AFL": "SU", "EWG": "EW", "CFG": "DE", "WZZ": "W6", "ASL": "JU",
            "TRA": "HV",
            "AAL": "AA", "DAL": "DL", "UAL": "UA", "SWA": "WN", "JBU": "B6",
            "ASA": "AS", "NKS": "NK", "FFT": "F9", "ACA": "AC", "WJA": "WS",
            "UAE": "EK", "QTR": "QR", "ETD": "EY", "SVA": "SV", "RJA": "RJ",
            "GFA": "GF", "OMA": "WY", "KAC": "KU",
            "SIA": "SQ", "CPA": "CX", "ANA": "NH", "JAL": "JL", "KAL": "KE",
            "AAR": "OZ", "CSN": "CZ", "CES": "MU", "CCA": "CA", "CHH": "HU",
            "THA": "TG", "HVN": "VN", "GIA": "GA", "MAS": "MH", "PAL": "PR",
            "EVA": "BR", "CAL": "CI",
            "QFA": "QF", "ANZ": "NZ", "FJI": "FJ",
            "SAA": "SA", "ETH": "ET", "KQA": "KQ", "MSR": "MS", "RAM": "AT",
            "FDX": "FX", "UPS": "5X", "DHL": "D0", "CLX": "CV", "GTI": "5Y",
        ]

        guard let code = mapping[prefix] else { return nil }
        return URL(string: "https://daisy.airdispatch.cl/logos/\(code).png")
    }
}
// MARK: - Radio
struct NowPlaying: Codable, Equatable {
    let timestamp: String
    let streamUrl: String
    let radioName: String
    let rawMetadata: String?
    let artist: String
    let title: String
    let album: String?
    let artworkUrl: String?
    let itunesUrl: String?
    let genre: String?
    let hasItunes: Bool

    enum CodingKeys: String, CodingKey {
        case timestamp
        case streamUrl = "stream_url"
        case radioName = "radio_name"
        case rawMetadata = "raw_metadata"
        case artist, title, album
        case artworkUrl = "artwork_url"
        case itunesUrl = "itunes_url"
        case genre
        case hasItunes = "has_itunes"
    }

    var displayTitle: String {
        if artist == "Desconhecido" {
            return title
        }
        return "\(artist) - \(title)"
    }

    var artworkURL: URL? {
        guard let urlString = artworkUrl, !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - Radio Status

struct WatchRadioStatus: Codable {
    let status: String?
    let streamUrl: String?
    let listeners: Int?
    let uptime: String?

    enum CodingKeys: String, CodingKey {
        case status
        case streamUrl = "stream_url"
        case listeners, uptime
    }
}

// MARK: - Satellite Predictions

struct WatchMeteorPassesResponse: Codable {
    let passes: [WatchMeteorPass]?
    let satellite: String?
    let count: Int?
}

struct WatchMeteorPass: Codable, Identifiable {
    var id: String { "\(satellite ?? "sat")_\(aos ?? "unknown")" }
    let satellite: String?
    let aos: String?  // Acquisition of Signal
    let los: String?  // Loss of Signal
    let maxElevation: Double?
    let azimuthAos: Double?
    let azimuthLos: Double?
    let duration: Double?  // seconds

    enum CodingKeys: String, CodingKey {
        case satellite, aos, los, duration
        case maxElevation = "max_elevation"
        case azimuthAos = "azimuth_aos"
        case azimuthLos = "azimuth_los"
    }

    var aosDate: Date? {
        guard let aos else { return nil }
        return ISO8601DateFormatter().date(from: aos)
            ?? DateFormatter.passFormatter.date(from: aos)
    }

    var isUpcoming: Bool {
        guard let date = aosDate else { return false }
        return date > Date()
    }

    var timeUntil: String {
        guard let date = aosDate else { return "--" }
        let interval = date.timeIntervalSince(Date())
        if interval < 0 { return "Em andamento" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 24 {
            return "em \(hours / 24)d"
        } else if hours > 0 {
            return "em \(hours)h \(minutes)m"
        } else {
            return "em \(minutes)m"
        }
    }

    var durationMinutes: String {
        guard let d = duration else { return "--" }
        return String(format: "%.0fm", d / 60.0)
    }

    var qualityStars: Int {
        guard let el = maxElevation else { return 1 }
        if el >= 70 { return 5 }
        if el >= 50 { return 4 }
        if el >= 30 { return 3 }
        if el >= 15 { return 2 }
        return 1
    }
}

extension DateFormatter {
    fileprivate static let passFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

// MARK: - ACARS Search

struct WatchACARSSearchResult: Codable {
    let messages: [WatchACARSMessage]?
    let count: Int?
    let query: String?
}

// MARK: - ADS-B Highlights

struct WatchADSBHighlights: Codable {
    let highlights: [WatchHighlightAircraft]?
    let militaryCount: Int?
    let interestingCount: Int?

    enum CodingKeys: String, CodingKey {
        case highlights
        case militaryCount = "military_count"
        case interestingCount = "interesting_count"
    }
}

struct WatchHighlightAircraft: Codable, Identifiable {
    let id: String
    let callsign: String?
    let registration: String?
    let model: String?
    let airline: String?
    let category: String?
    let reason: String?
    let altitudeFt: Int?
    let distanceNm: Double?

    enum CodingKeys: String, CodingKey {
        case id, callsign, registration, model, airline, category, reason
        case altitudeFt = "altitude_ft"
        case distanceNm = "distance_nm"
    }
}

// MARK: - Remote Control (Watch)

struct WatchRemoteCommand: Codable, Identifiable {
    let id: String
    let command: String
    let target: String?
    let status: String
    let createdAt: String
    let output: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case id, command, target, status, output, error
        case createdAt = "created_at"
    }

    var statusColor: String {
        switch status {
        case "completed": return "green"
        case "failed": return "red"
        case "running": return "orange"
        default: return "secondary"
        }
    }
}

// MARK: - Analytics (Watch simplified)

struct WatchADSBAnalytics: Codable {
    let period: String?
    let totalFlights: Int?
    let uniqueAircraft: Int?
    let topAircraftTypes: [WatchAircraftTypeStats]?
    let hourlyStats: [WatchHourlyStats]?

    enum CodingKeys: String, CodingKey {
        case period
        case totalFlights = "total_flights"
        case uniqueAircraft = "unique_aircraft"
        case topAircraftTypes = "top_aircraft_types"
        case hourlyStats = "hourly_stats"
    }
}

struct WatchAircraftTypeStats: Codable, Identifiable {
    var id: String { type }
    let type: String
    let count: Int
    let percentage: Double?
}

struct WatchHourlyStats: Codable, Identifiable {
    var id: Int { hour }
    let hour: Int
    let flightCount: Int

    enum CodingKeys: String, CodingKey {
        case hour
        case flightCount = "flight_count"
    }
}

// MARK: - Tuya Smart Sensors

struct WatchTuyaResponse: Codable {
    let ok: Bool
    let timestamp: String?
    let current: WatchTuyaCurrent?
    let degraded: Bool?
    let degradedReason: String?

    enum CodingKeys: String, CodingKey {
        case ok, timestamp, current, degraded
        case degradedReason = "degraded_reason"
    }
}

struct WatchTuyaCurrent: Codable {
    let temperatureC: Double?
    let humidityPct: Double?
    let batteryPct: Int?

    enum CodingKeys: String, CodingKey {
        case temperatureC = "temperature_c"
        case humidityPct = "humidity_pct"
        case batteryPct = "battery_pct"
    }
}

// MARK: - Dashboard

struct WatchDashboardResponse: Codable {
    let adsb: WatchDashboardADSB?
    let system: WatchDashboardSystem?
    let uptime: String?
}

struct WatchDashboardADSB: Codable {
    let totalToday: Int?
    let peakHour: Int?
    let topAirline: String?

    enum CodingKeys: String, CodingKey {
        case totalToday = "total_today"
        case peakHour = "peak_hour"
        case topAirline = "top_airline"
    }
}

struct WatchDashboardSystem: Codable {
    let cpuAvg: Double?
    let memoryAvg: Double?
    let diskUsed: Double?

    enum CodingKeys: String, CodingKey {
        case cpuAvg = "cpu_avg"
        case memoryAvg = "memory_avg"
        case diskUsed = "disk_used"
    }
}
