import CoreLocation
import Foundation

// MARK: - Aircraft Source
enum AircraftSource: String, Codable {
    case local = "local"  // Detectado pelo seu radar
    case network = "network"  // Via API ADSB.lol
    case opensky = "opensky"  // Via OpenSky Network

    var displayName: String {
        switch self {
        case .local: return "Meu Radar"
        case .network: return "Rede ADSB.lol"
        case .opensky: return "OpenSky Network"
        }
    }

    var iconName: String {
        switch self {
        case .local: return "antenna.radiowaves.left.and.right"
        case .network: return "globe"
        case .opensky: return "network"
        }
    }
}

// MARK: - ADS-B Summary
struct ADSBSummary: Codable, Equatable {
    let timestamp: String
    let totalNow: Int
    let withPos: Int
    let above10000: Int
    let nonCivilNow: Int
    let movement: Movement
    let averages: Averages
    let highlights: Highlights
    let airlines: [Airline]
    let topModels: [TopModel]
    let stats24h: Stats24h

    enum CodingKeys: String, CodingKey {
        case timestamp
        case totalNow = "total_now"
        case withPos = "with_pos"
        case above10000 = "above_10000"
        case nonCivilNow = "non_civil_now"
        case movement, averages, highlights, airlines
        case topModels = "top_models"
        case stats24h = "stats_24h"
    }
}

struct Movement: Codable, Equatable {
    let climbing: Int
    let descending: Int
    let cruising: Int
}

struct Averages: Codable, Equatable {
    let altitudeFt: Int
    let speedKt: Int

    enum CodingKeys: String, CodingKey {
        case altitudeFt = "altitude_ft"
        case speedKt = "speed_kt"
    }
}

struct Highlights: Codable, Equatable {
    let highest: HighlightItem?
    let fastest: HighlightItem?
    let closest: ClosestItem?
}

struct HighlightItem: Codable, Equatable {
    let callsign: String?
    let model: String?
    let altitudeFt: Int?
    let speedKt: Int?

    enum CodingKeys: String, CodingKey {
        case callsign, model
        case altitudeFt = "altitude_ft"
        case speedKt = "speed_kt"
    }
}

struct ClosestItem: Codable, Equatable {
    let callsign: String?
    let model: String?
    let distanceNm: Double?

    enum CodingKeys: String, CodingKey {
        case callsign, model
        case distanceNm = "distance_nm"
    }
}

struct Airline: Codable, Identifiable, Equatable {
    let name: String
    let count: Int

    var id: String { name }

    var logoURL: URL? {
        AirlineLogo.url(for: name)
    }
}

// MARK: - Airline Logo Helper
struct AirlineLogo {
    // Comprehensive mapping of airline names to IATA codes
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
        "BOA": "OB",  // Boliviana de Aviación
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
        // Cargo
        "FEDEX": "FX",
        "UPS": "5X",
        "DHL": "D0",
        "CARGOLUX": "CV",
        "ATLAS AIR": "5Y",
    ]

    // ICAO to IATA comprehensive mapping
    static let icaoToIata: [String: String] = [
        // Brazilian
        "TAM": "JJ", "GLO": "G3", "AZU": "AD", "PTB": "2Z", "ONE": "LA",
        "LAN": "LA", "SID": "SD", "ABJ": "M3", "TIB": "L0",
        // South American
        "AVA": "AV", "ARG": "AR", "FBH": "FO", "JAT": "JA", "JES": "JA", "SKU": "H2",
        "CMP": "CM", "BOV": "OB", "AMX": "AM", "VOI": "Y4",
        "VIV": "VH", "VB": "VB", "RPB": "P5", "NSE": "9R",
        // European
        "DLH": "LH", "TAP": "TP", "AFR": "AF", "KLM": "KL", "IBE": "IB",
        "BAW": "BA", "AEA": "UX", "THY": "TK", "SWR": "LX", "ITY": "AZ",
        "AZA": "AZ", "VLG": "VY", "RYR": "FR", "EZY": "U2", "NAX": "DY",
        "SAS": "SK", "FIN": "AY", "LOT": "LO", "AUA": "OS", "BEL": "SN",
        "AFL": "SU", "EWG": "EW", "CFG": "DE", "WZZ": "W6", "ASL": "JU",
        "TRA": "HV",
        // North American
        "AAL": "AA", "DAL": "DL", "UAL": "UA", "SWA": "WN", "JBU": "B6",
        "ASA": "AS", "NKS": "NK", "FFT": "F9", "ACA": "AC", "WJA": "WS",
        // Middle East
        "UAE": "EK", "QTR": "QR", "ETD": "EY", "SVA": "SV", "RJA": "RJ",
        "GFA": "GF", "OMA": "WY", "KAC": "KU",
        // Asian
        "SIA": "SQ", "CPA": "CX", "ANA": "NH", "JAL": "JL", "KAL": "KE",
        "AAR": "OZ", "CSN": "CZ", "CES": "MU", "CCA": "CA", "CHH": "HU",
        "THA": "TG", "HVN": "VN", "GIA": "GA", "MAS": "MH", "PAL": "PR",
        "EVA": "BR", "CAL": "CI",
        // Oceanian
        "QFA": "QF", "ANZ": "NZ", "FJI": "FJ",
        // African
        "SAA": "SA", "ETH": "ET", "KQA": "KQ", "MSR": "MS", "RAM": "AT",
        // Cargo
        "FDX": "FX", "UPS": "5X", "BOX": "D0", "CLX": "CV", "GTI": "5Y",
        // Military/Government (generic icons)
        "FAB": "FB", "BRS": "FB", "RCH": "FB",
    ]

    private static func normalize(_ s: String) -> String {
        // Normalize for matching (handles Aeroméxico/Aviación, etc.).
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let normalizedMapping: [String: String] = Dictionary(
        uniqueKeysWithValues: mapping.map { (normalize($0.key), $0.value) }
    )

    static func url(for name: String) -> URL? {
        let upper = normalize(name)

        // 1. Precise match
        if let iata = normalizedMapping[upper] {
            return URL(string: "https://www.gstatic.com/flights/airline_logos/70px/\(iata).png")
        }

        // 2. Contains match
        for (key, iata) in normalizedMapping {
            if upper.contains(key) {
                return URL(string: "https://www.gstatic.com/flights/airline_logos/70px/\(iata).png")
            }
        }
        return nil
    }

    static func url(fromCallsign callsign: String) -> URL? {
        let trimmed = callsign.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return nil }
        let icao = String(trimmed.prefix(3)).uppercased()

        if let iata = icaoToIata[icao] {
            return URL(string: "https://www.gstatic.com/flights/airline_logos/70px/\(iata).png")
        }

        return nil
    }
}

struct TopModel: Codable, Identifiable, Equatable {
    let model: String
    let count: Int

    var id: String { model }
}

struct Stats24h: Codable, Equatable {
    let positions: Int?
    let unique: Int?
    let nonCivil: Int?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case positions, unique
        case nonCivil = "non_civil"
        case error
    }
}

// MARK: - Aircraft List
struct AircraftList: Codable {
    let timestamp: String
    let count: Int
    let items: [Aircraft]
}

struct Aircraft: Codable, Identifiable, Equatable {
    let id: String
    let hex: String?
    let callsign: String  // Keep required - API always provides
    let model: String?
    var registration: String?  // Changed to var to allow update from ACARS
    var airline: String?
    let lat: Double?
    let lon: Double?
    let track: Double?
    let altitudeFt: Int  // Keep required - API always provides
    let speedKt: Int  // Keep required - API always provides
    let speedKmh: Int  // Keep required - API always provides
    let distanceNm: Double?
    let verticalRateFpm: Int  // Keep required - API always provides
    var source: AircraftSource = .local  // Origem dos dados
    var isDualTracked: Bool = false  // Detectado por ambas as fontes
    let squawk: String?  // Código transponder (e.g. 7700 = emergência)

    enum CodingKeys: String, CodingKey {
        case id, hex, callsign, model, registration, airline, lat, lon, track
        case altitudeFt = "altitude_ft"
        case speedKt = "speed_kt"
        case speedKmh = "speed_kmh"
        case distanceNm = "distance_nm"
        case verticalRateFpm = "vertical_rate_fpm"
        case squawk
        // Note: source and isDualTracked are NOT in CodingKeys because they're not provided by the API
    }

    // Custom decoder to handle fields not in API response
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        hex = try container.decodeIfPresent(String.self, forKey: .hex)
        callsign = try container.decode(String.self, forKey: .callsign)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        airline = try container.decodeIfPresent(String.self, forKey: .airline)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lon = try container.decodeIfPresent(Double.self, forKey: .lon)
        track = try container.decodeIfPresent(Double.self, forKey: .track)
        altitudeFt = try container.decode(Int.self, forKey: .altitudeFt)
        speedKt = try container.decode(Int.self, forKey: .speedKt)
        speedKmh = try container.decode(Int.self, forKey: .speedKmh)
        distanceNm = try container.decodeIfPresent(Double.self, forKey: .distanceNm)
        verticalRateFpm = try container.decode(Int.self, forKey: .verticalRateFpm)

        registration = try container.decodeIfPresent(String.self, forKey: .registration)
        squawk = try container.decodeIfPresent(String.self, forKey: .squawk)
        source = .local
        isDualTracked = false
    }

    // Memberwise initializer for manual creation
    init(
        id: String,
        hex: String?,
        callsign: String,
        model: String?,
        registration: String?,
        airline: String?,
        lat: Double?,
        lon: Double?,
        track: Double?,
        altitudeFt: Int,
        speedKt: Int,
        speedKmh: Int,
        distanceNm: Double?,
        verticalRateFpm: Int,
        squawk: String? = nil,
        source: AircraftSource = .local,
        isDualTracked: Bool = false
    ) {
        self.id = id
        self.hex = hex
        self.callsign = callsign
        self.model = model
        self.registration = registration
        self.airline = airline
        self.lat = lat
        self.lon = lon
        self.track = track
        self.altitudeFt = altitudeFt
        self.speedKt = speedKt
        self.speedKmh = speedKmh
        self.distanceNm = distanceNm
        self.verticalRateFpm = verticalRateFpm
        self.squawk = squawk
        self.source = source
        self.isDualTracked = isDualTracked
    }

    var displayCallsign: String {
        callsign.isEmpty ? (hex ?? "Sem ID") : callsign
    }

    var hasPosition: Bool {
        lat != nil && lon != nil
    }

    var isLocal: Bool {
        source == .local
    }

    var airlineLogoURL: URL? {
        // 1. Tenta pelo callsign (ICAO)
        if let url = AirlineLogo.url(fromCallsign: callsign) {
            return url
        }

        // 2. Tenta pelo nome da companhia se disponível
        if let airlineName = airline, let url = AirlineLogo.url(for: airlineName) {
            return url
        }

        return nil
    }

    var movementIcon: String {
        if verticalRateFpm > 256 {
            return "arrow.up.circle.fill"
        } else if verticalRateFpm < -256 {
            return "arrow.down.circle.fill"
        } else {
            return "arrow.right.circle.fill"
        }
    }

    var movementColor: String {
        if verticalRateFpm > 256 {
            return "green"
        } else if verticalRateFpm < -256 {
            return "orange"
        } else {
            return "blue"
        }
    }

    // Criar cópia com source diferente
    func with(source: AircraftSource, dualTracked: Bool = false) -> Aircraft {
        var copy = self
        copy.source = source
        copy.isDualTracked = dualTracked
        return copy
    }

    // Calcular distância dinâmica se não vier da API
    @MainActor
    var computedDistanceNm: Double {
        if let d = distanceNm { return d }
        // Calcular baseado na localização do usuário
        if let lat = lat, let lon = lon,
            let userLoc = LocationManager.shared.userLocation
        {
            let acLoc = CLLocation(latitude: lat, longitude: lon)
            return userLoc.distance(from: acLoc) / 1852.0
        }
        return Double.infinity
    }
}

// MARK: - ADSB.lol API Response
struct ADSBLolResponse: Codable {
    let ac: [ADSBLolAircraft]?
    let now: Double?
    let total: Int?
    let ctime: Double?
    let ptime: Int?
}

struct ADSBLolAircraft: Codable {
    let hex: String?
    let flight: String?
    let t: String?  // Tipo de aeronave
    let r: String?  // Registro
    let lat: Double?
    let lon: Double?
    let alt_baro: IntOrString?
    let alt_geom: Int?
    let gs: Double?  // Ground speed
    let track: Double?
    let baro_rate: Int?
    let squawk: String?
    let category: String?
    let nav_altitude_mcp: Int?
    let nav_heading: Double?
    let nic: Int?
    let rc: Int?
    let seen_pos: Double?
    let version: Int?
    let nic_baro: Int?
    let nac_p: Int?
    let nac_v: Int?
    let sil: Int?
    let sil_type: String?
    let mlat: [String]?
    let tisb: [String]?
    let messages: Int?
    let seen: Double?
    let rssi: Double?

    // Converter para Aircraft
    func toAircraft() -> Aircraft? {
        guard let hex = hex else { return nil }

        let altFt: Int
        if let altBaro = alt_baro {
            altFt = altBaro.intValue ?? alt_geom ?? 0
        } else {
            altFt = alt_geom ?? 0
        }

        return Aircraft(
            id: hex,
            hex: hex,
            callsign: flight?.trimmingCharacters(in: .whitespaces) ?? "",
            model: t,
            registration: r,
            airline: nil,
            lat: lat,
            lon: lon,
            track: track,
            altitudeFt: altFt,
            speedKt: Int(gs ?? 0),
            speedKmh: Int((gs ?? 0) * 1.852),
            distanceNm: nil,
            verticalRateFpm: baro_rate ?? 0,
            squawk: squawk,
            source: .network
        )
    }
}

// MARK: - Tuya Sensor

struct TuyaTemperatureHumidityResponse: Codable, Equatable {
    let ok: Bool
    let timestamp: String
    let source: String?
    let device: TuyaSensorDevice?
    let current: TuyaSensorCurrent?
    let history: [TuyaSensorHistoryEntry]?
    let historyIntervalSeconds: Int?
    let raw: TuyaSensorRaw?
    let degraded: Bool
    let degradedReason: String?
    let localError: String?

    enum CodingKeys: String, CodingKey {
        case ok, timestamp, source, device, current, history, raw, degraded
        case degradedReason = "degraded_reason"
        case historyIntervalSeconds = "history_interval_seconds"
        case localError = "local_error"
    }

    var friendlyErrorMessage: String? {
        guard !ok || degraded else { return nil }

        if let reason = degradedReason?.trimmedNonEmpty {
            return "Leitura parcial do sensor: \(reason)."
        }

        if let localError = localError?.trimmedNonEmpty {
            return "Sensor indisponível no momento: \(localError)."
        }

        return "Sensor Tuya indisponível no momento."
    }

    var lastUpdatedAt: Date? {
        Formatters.isoDate.date(from: timestamp) ?? Formatters.isoDateNoFrac.date(from: timestamp)
    }
}

struct TuyaSensorHistoryEntry: Codable, Equatable, Identifiable {
    let timestamp: String
    let temperatureC: Double?
    let humidityPct: Double?
    let batteryPct: Int?
    let source: String?
    let deviceID: String?
    let deviceName: String?

    var id: String { timestamp }

    enum CodingKeys: String, CodingKey {
        case timestamp, source
        case temperatureC = "temperature_c"
        case humidityPct = "humidity_pct"
        case batteryPct = "battery_pct"
        case deviceID = "device_id"
        case deviceName = "device_name"
    }

    var date: Date? {
        Formatters.isoDate.date(from: timestamp) ?? Formatters.isoDateNoFrac.date(from: timestamp)
    }
}

struct TuyaSensorDevice: Codable, Equatable {
    let id: String
    let name: String
    let localIP: String?
    let productID: String?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category
        case localIP = "local_ip"
        case productID = "product_id"
    }
}

struct TuyaSensorCurrent: Codable, Equatable {
    let temperatureC: Double?
    let humidityPct: Double?
    let batteryPct: Int?
    let temperatureUnit: String?
    let temperatureAlarm: String?
    let humidityAlarm: String?

    enum CodingKeys: String, CodingKey {
        case temperatureC = "temperature_c"
        case humidityPct = "humidity_pct"
        case batteryPct = "battery_pct"
        case temperatureUnit = "temperature_unit"
        case temperatureAlarm = "temperature_alarm"
        case humidityAlarm = "humidity_alarm"
    }
}

struct TuyaSensorRaw: Codable, Equatable {
    let status: TuyaSensorStatus?
}

struct TuyaSensorStatus: Codable, Equatable {
    let result: [TuyaSensorStatusEntry]?
    let success: Bool?
}

struct TuyaSensorStatusEntry: Codable, Equatable {
    let code: String
    let value: TuyaSensorStatusValue
}

enum TuyaSensorStatusValue: Codable, Equatable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.typeMismatch(
                TuyaSensorStatusValue.self,
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unsupported Tuya status value")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
}

extension String {
    fileprivate var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Tuya Status (API2)

struct TuyaStatusResponse: Codable {
    let service: String
    let running: Bool
    let deviceId: String?
    let deviceName: String?
    let sourceMode: String?
    let historyPath: String?
    let historyItems: Int?
    let backgroundRefreshSeconds: Int?
    let cacheTtlSeconds: Double?
    let lastRefreshAt: String?
    let lastError: String?
    let hasStalePayload: Bool?

    enum CodingKeys: String, CodingKey {
        case service, running
        case deviceId = "device_id"
        case deviceName = "device_name"
        case sourceMode = "source_mode"
        case historyPath = "history_path"
        case historyItems = "history_items"
        case backgroundRefreshSeconds = "background_refresh_seconds"
        case cacheTtlSeconds = "cache_ttl_seconds"
        case lastRefreshAt = "last_refresh_at"
        case lastError = "last_error"
        case hasStalePayload = "has_stale_payload"
    }
}

// Helper para decodificar alt_baro que pode ser Int ou String ("ground")
enum IntOrString: Codable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            self = .int(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let val): try container.encode(val)
        case .string(let val): try container.encode(val)
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let val): return val
        case .string: return nil
        }
    }
}

// MARK: - Airline Classification (Manual)

struct AirlineClassificationRecord: Codable, Equatable {
    let hex: String?
    let registration: String?
    let callsign: String?
    let model: String?
    let airlineName: String
    let airlineIcao: String?
    let airlineIata: String?
    let source: String?
    let confidence: Double?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case hex, registration, callsign, model, source, confidence
        case airlineName = "airline_name"
        case airlineIcao = "airline_icao"
        case airlineIata = "airline_iata"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AirlineClassificationLookupResponse: Codable {
    let ok: Bool?
    let classification: AirlineClassificationRecord?
    let message: String?
}

struct AirlineClassificationUpsertRequest: Codable {
    let hex: String?
    let registration: String?
    let callsign: String?
    let model: String?
    let airlineName: String
    let airlineIcao: String?
    let airlineIata: String?
    let source: String
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case hex, registration, callsign, model, source, confidence
        case airlineName = "airline_name"
        case airlineIcao = "airline_icao"
        case airlineIata = "airline_iata"
    }
}

struct AirlineClassificationUpsertResponse: Codable {
    let ok: Bool?
    let classification: AirlineClassificationRecord?
    let message: String?
}
