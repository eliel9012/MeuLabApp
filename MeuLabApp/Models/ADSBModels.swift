import Foundation

// MARK: - Aircraft Source
enum AircraftSource: String, Codable {
    case local = "local"      // Detectado pelo seu radar
    case network = "network"  // Via API ADSB.lol

    var displayName: String {
        switch self {
        case .local: return "Meu Radar"
        case .network: return "Rede ADSB.lol"
        }
    }

    var iconName: String {
        switch self {
        case .local: return "antenna.radiowaves.left.and.right"
        case .network: return "globe"
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
    let callsign: String
    let model: String?
    let airline: String?
    let lat: Double?
    let lon: Double?
    let track: Double?
    let altitudeFt: Int
    let speedKt: Int
    let speedKmh: Int
    let distanceNm: Double?
    let verticalRateFpm: Int
    var source: AircraftSource = .local  // Origem dos dados

    enum CodingKeys: String, CodingKey {
        case id, hex, callsign, model, airline, lat, lon, track
        case altitudeFt = "altitude_ft"
        case speedKt = "speed_kt"
        case speedKmh = "speed_kmh"
        case distanceNm = "distance_nm"
        case verticalRateFpm = "vertical_rate_fpm"
        case source
    }

    var displayCallsign: String {
        callsign.isEmpty ? (hex ?? "???") : callsign
    }

    var hasPosition: Bool {
        lat != nil && lon != nil
    }

    var isLocal: Bool {
        source == .local
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
    func with(source: AircraftSource) -> Aircraft {
        var copy = self
        copy.source = source
        return copy
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
    let t: String?           // Tipo de aeronave
    let r: String?           // Registro
    let lat: Double?
    let lon: Double?
    let alt_baro: IntOrString?
    let alt_geom: Int?
    let gs: Double?          // Ground speed
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
            airline: nil,
            lat: lat,
            lon: lon,
            track: track,
            altitudeFt: altFt,
            speedKt: Int(gs ?? 0),
            speedKmh: Int((gs ?? 0) * 1.852),
            distanceNm: nil,
            verticalRateFpm: baro_rate ?? 0,
            source: .network
        )
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
