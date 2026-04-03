import Foundation

struct AviationStackFlightResponse: Codable {
    let pagination: AviationStackPagination?
    let data: [AviationStackFlightData]
}

struct AviationStackPagination: Codable {
    let limit: Int
    let offset: Int
    let count: Int
    let total: Int
}

struct AviationStackFlightData: Codable {
    let flightDate: String?
    let flightStatus: String?
    let departure: AviationStackAirport?
    let arrival: AviationStackAirport?
    let airline: AviationStackAirline?
    let flight: AviationStackFlight?
    
    enum CodingKeys: String, CodingKey {
        case flightDate = "flight_date"
        case flightStatus = "flight_status"
        case departure, arrival, airline, flight
    }
}

struct AviationStackAirport: Codable {
    let airport: String?
    let timezone: String?
    let iata: String?
    let icao: String?
    let terminal: String?
    let gate: String?
    let scheduled: String?
    let estimated: String?
    let actual: String?
    let estimatedRunway: String?
    let actualRunway: String?
    
    enum CodingKeys: String, CodingKey {
        case airport, timezone, iata, icao, terminal, gate, scheduled, estimated, actual
        case estimatedRunway = "estimated_runway"
        case actualRunway = "actual_runway"
    }
}

struct AviationStackAirline: Codable {
    let name: String?
    let iata: String?
    let icao: String?
}

struct AviationStackFlight: Codable {
    let number: String?
    let iata: String?
    let icao: String?
    let codeshared: AviationStackCodeshared?
}

struct AviationStackCodeshared: Codable {
    let airlineName: String?
    let airlineIata: String?
    let airlineIcao: String?
    let flightNumber: String?
    let flightIata: String?
    let flightIcao: String?
    
    enum CodingKeys: String, CodingKey {
        case airlineName = "airline_name"
        case airlineIata = "airline_iata"
        case airlineIcao = "airline_icao"
        case flightNumber = "flight_number"
        case flightIata = "flight_iata"
        case flightIcao = "flight_icao"
    }
}

// MARK: - FlightAware (AeroAPI via MeuLab backend)

/// Backend wrapper for `/api/flightaware/airport/board`.
struct FlightAwareAirportBoardResponse: Codable, Equatable {
    let airport: String
    let kind: String
    let data: FlightAwareBoardData
}

/// `data` object contains one of these arrays depending on the "kind".
struct FlightAwareBoardData: Codable, Equatable {
    let scheduledDepartures: [FlightAwareFlight]?
    let scheduledArrivals: [FlightAwareFlight]?
    let departures: [FlightAwareFlight]?
    let arrivals: [FlightAwareFlight]?
    let enroute: [FlightAwareFlight]?

    enum CodingKeys: String, CodingKey {
        case scheduledDepartures = "scheduled_departures"
        case scheduledArrivals = "scheduled_arrivals"
        case departures
        case arrivals
        case enroute
    }
}

/// Backend wrapper for `/api/flightaware/flight`.
struct FlightAwareFlightResponse: Codable, Equatable {
    let ident: String
    let data: FlightAwareFlightData
}

struct FlightAwareFlightData: Codable, Equatable {
    let flights: [FlightAwareFlight]?
}

struct FlightAwareAirportRef: Codable, Equatable {
    let code: String?
    let codeIcao: String?
    let codeIata: String?
    let name: String?
    let city: String?
    let country: String?

    enum CodingKeys: String, CodingKey {
        case code
        case codeIcao = "code_icao"
        case codeIata = "code_iata"
        case name, city, country
    }

    var bestCode: String {
        codeIata ?? code ?? codeIcao ?? "-"
    }
}

struct FlightAwareFlight: Codable, Identifiable, Equatable {
    let faFlightID: String?

    let ident: String?
    let identIcao: String?
    let identIata: String?

    let `operator`: String?
    let operatorIcao: String?
    let operatorIata: String?

    let origin: FlightAwareAirportRef?
    let destination: FlightAwareAirportRef?

    // Times (ISO8601 Z)
    let scheduledOut: String?
    let estimatedOut: String?
    let actualOut: String?
    let scheduledOff: String?
    let estimatedOff: String?
    let actualOff: String?

    let scheduledOn: String?
    let estimatedOn: String?
    let actualOn: String?
    let scheduledIn: String?
    let estimatedIn: String?
    let actualIn: String?

    // Gate/terminal
    let terminalOrigin: String?
    let gateOrigin: String?
    let terminalDestination: String?
    let gateDestination: String?

    enum CodingKeys: String, CodingKey {
        case faFlightID = "fa_flight_id"
        case ident
        case identIcao = "ident_icao"
        case identIata = "ident_iata"
        case `operator`
        case operatorIcao = "operator_icao"
        case operatorIata = "operator_iata"
        case origin, destination
        case scheduledOut = "scheduled_out"
        case estimatedOut = "estimated_out"
        case actualOut = "actual_out"
        case scheduledOff = "scheduled_off"
        case estimatedOff = "estimated_off"
        case actualOff = "actual_off"
        case scheduledOn = "scheduled_on"
        case estimatedOn = "estimated_on"
        case actualOn = "actual_on"
        case scheduledIn = "scheduled_in"
        case estimatedIn = "estimated_in"
        case actualIn = "actual_in"
        case terminalOrigin = "terminal_origin"
        case gateOrigin = "gate_origin"
        case terminalDestination = "terminal_destination"
        case gateDestination = "gate_destination"
    }

    var id: String {
        if let faFlightID, !faFlightID.isEmpty { return faFlightID }
        let parts = [
            identIcao, ident, scheduledOut, estimatedOut, scheduledIn, estimatedIn
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: "|")
    }

    var bestIdent: String {
        identIata ?? identIcao ?? ident ?? "-"
    }
}

enum FlightAwareTime {
    static func parse(_ iso: String?) -> Date? {
        guard let iso, !iso.isEmpty else { return nil }
        return Formatters.isoDateNoFrac.date(from: iso) ?? Formatters.isoDate.date(from: iso)
    }

    static func short(_ iso: String?) -> String? {
        guard let d = parse(iso) else { return nil }
        return Formatters.time.string(from: d)
    }
}
