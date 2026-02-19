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
    let cpuPercent: Double
    let cpuTemp: Double?
    let memoryPercent: Double
    let diskPercent: Double
    let wifiSignal: Int?
    let uptime: String?
    
    enum CodingKeys: String, CodingKey {
        case cpuPercent = "cpu_percent"
        case cpuTemp = "cpu_temp"
        case memoryPercent = "memory_percent"
        case diskPercent = "disk_percent"
        case wifiSignal = "wifi_signal"
        case uptime
    }
}

// MARK: - Weather

struct WatchWeatherData: Codable {
    let current: WatchCurrentWeather?
    let forecast: [WatchForecastDay]?
}

struct WatchCurrentWeather: Codable {
    let temperature: Double
    let condition: String
    let humidity: Int?
    let windSpeed: Double?
    let icon: String?
    
    enum CodingKeys: String, CodingKey {
        case temperature, condition, humidity, icon
        case windSpeed = "wind_speed"
    }
}

struct WatchForecastDay: Codable, Identifiable {
    var id: String { date }
    let date: String
    let tempMin: Double
    let tempMax: Double
    let condition: String
    
    enum CodingKeys: String, CodingKey {
        case date, condition
        case tempMin = "temp_min"
        case tempMax = "temp_max"
    }
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
        "ATLAS AIR": "5Y"
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
             "FDX": "FX", "UPS": "5X", "DHL": "D0", "CLX": "CV", "GTI": "5Y"
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
}
