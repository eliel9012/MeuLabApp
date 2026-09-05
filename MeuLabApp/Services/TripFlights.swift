import Foundation

// ============================================================
// VOOS DA VIAGEM NO ADS-B
// Reads the itinerary (TripEngine), pulls the flight numbers out of the
// entries and turns them into ADS-B callsigns, so the radar screen can tell
// "this blip is my own flight" apart from ordinary traffic.
// ============================================================

/// One flight of the traveller's own itinerary, resolved out of a `TripStop`.
struct TripFlight: Identifiable, Equatable, Sendable {
    /// Normalized flight code, e.g. "IB268". Unique per flight.
    let id: String
    /// IATA airline code ("IB", "FR", "G3"…). Nil when the itinerary only had a
    /// bare number and no airline could be inferred.
    let iata: String?
    /// Flight number without the airline code, e.g. "268".
    let number: String
    /// ADS-B callsigns this flight may broadcast, best guess first ("IBE268").
    let callsignCandidates: [String]
    /// Airline name as written in the itinerary, when there was one.
    let airlineName: String?
    /// True when the airline came from a name in the text, not from a code
    /// next to the number ("LATAM · voo 4211").
    let airlineWasInferred: Bool

    // Where in the itinerary this flight came from.
    let stopID: String
    let stopTitle: String
    let dayDate: String
    let time: String
    let date: Date?

    /// "IB 268" — what the ticket calls it.
    var displayCode: String {
        guard let iata else { return "Voo \(number)" }
        return "\(iata) \(number)"
    }

    /// Callsign shown in the UI as the one to look for on the radar.
    var primaryCallsign: String? { callsignCandidates.first }
}

// MARK: - Parser

enum TripFlightParser {
    /// IATA → ADS-B (ICAO) callsign prefixes, for the airlines this trip uses
    /// plus a few neighbours that could show up in a changed booking.
    /// LATAM keeps two prefixes: LAN (group) and TAM (Brazilian domestic).
    static let icaoPrefixes: [String: [String]] = [
        "IB": ["IBE"],
        "FR": ["RYR"],
        "LA": ["LAN", "TAM"],
        "JJ": ["TAM"],
        "G3": ["GLO"],
        "TP": ["TAP"],
        "AD": ["AZU"],
        "AF": ["AFR"],
        "BA": ["BAW"],
        "UX": ["AEA"],
        "VY": ["VLG"],
        "U2": ["EZY", "EJU"],
        "TK": ["THY"],
        "LH": ["DLH"],
        "AZ": ["ITY"],
    ]

    /// Airline names as they appear in the itinerary → IATA code. Used when the
    /// entry gives a bare number ("LATAM · voo 4211").
    static let airlineNameToIATA: [String: String] = [
        "LATAM": "LA",
        "IBERIA": "IB",
        "RYANAIR": "FR",
        "GOL": "G3",
        "TAP": "TP",
        "AZUL": "AD",
        "AIR FRANCE": "AF",
        "BRITISH": "BA",
        "VUELING": "VY",
        "EASYJET": "U2",
        "LUFTHANSA": "LH",
    ]

    /// "IB 268", "IB268", "LA3691", "G3 1209" — the space is optional and the
    /// airline code may be two letters, letter+digit or digit+letter.
    private static let codeRegex = #/\b([A-Z]{2}|[A-Z][0-9]|[0-9][A-Z])\s?([0-9]{2,4})\b/#
    /// "voo 4211" — a number with no airline code beside it.
    private static let bareFlightRegex = #/\bVOO\s+([0-9]{2,4})\b/#

    /// Uppercased and stripped of accents, so "Ribeirão" never breaks a match.
    static func normalizedText(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive], locale: .current).uppercased()
    }

    /// Callsign form used for comparisons: letters and digits only, uppercased.
    static func normalizedCallsign(_ callsign: String) -> String {
        normalizedText(callsign).filter { $0.isLetter || $0.isNumber }
    }

    /// Airline name mentioned anywhere in the text, if any.
    static func airlineName(in normalizedText: String) -> (name: String, iata: String)? {
        for (name, iata) in airlineNameToIATA where normalizedText.contains(name) {
            return (name, iata)
        }
        return nil
    }

    /// Every flight number in one piece of text, in the order it appears.
    /// Returns pairs of (IATA code or nil, number).
    static func flightNumbers(in text: String) -> [(iata: String?, number: String)] {
        let upper = normalizedText(text)
        var found: [(String?, String)] = []

        for match in upper.matches(of: codeRegex) {
            let code = String(match.1)
            let number = String(match.2)
            // Only airlines we know how to translate — keeps random pairs like
            // a booking reference from being read as a flight.
            guard icaoPrefixes[code] != nil else { continue }
            found.append((code, number))
        }

        if found.isEmpty {
            for match in upper.matches(of: bareFlightRegex) {
                found.append((nil, String(match.1)))
            }
        }

        return found.map { (iata: $0.0, number: $0.1) }
    }

    /// ADS-B callsigns a flight may broadcast. Best guess first.
    /// Note: some carriers (Ryanair in particular) often fly under an
    /// alphanumeric callsign unrelated to the flight number, so a miss here is
    /// expected rather than exceptional.
    static func callsigns(iata: String?, number: String) -> [String] {
        guard let iata else { return [] }
        var out: [String] = []
        let trimmed = String(number.drop(while: { $0 == "0" }))
        let digits = trimmed.isEmpty ? number : trimmed

        for prefix in icaoPrefixes[iata] ?? [] {
            out.append(prefix + digits)
            if digits.count < 4 {
                out.append(prefix + String(repeating: "0", count: 4 - digits.count) + digits)
            }
        }
        out.append(iata + digits)

        var seen = Set<String>()
        return out.filter { seen.insert($0).inserted }
    }

    /// Flights of the itinerary, chronological, one entry per flight number.
    /// A number that shows up again later (a landing reminder, for instance)
    /// does not create a second flight.
    static func flights(from stops: [TripStop]) -> [TripFlight] {
        var seen = Set<String>()
        var out: [TripFlight] = []

        for stop in stops {
            let raw = [stop.title, stop.ref].compactMap { $0 }.joined(separator: " · ")
            let upper = normalizedText(raw)
            let named = airlineName(in: upper)

            for entry in flightNumbers(in: raw) {
                let iata = entry.iata ?? named?.iata
                let inferred = entry.iata == nil && iata != nil
                let id = (iata ?? "VOO") + entry.number
                guard seen.insert(id).inserted else { continue }

                out.append(
                    TripFlight(
                        id: id,
                        iata: iata,
                        number: entry.number,
                        callsignCandidates: callsigns(iata: iata, number: entry.number),
                        airlineName: named?.name.capitalized,
                        airlineWasInferred: inferred,
                        stopID: stop.id,
                        stopTitle: stop.title,
                        dayDate: stop.dayDate,
                        time: stop.time,
                        date: stop.date
                    )
                )
            }
        }

        return out
    }
}

// MARK: - Service

/// Holds the trip's flights and answers the only question the radar screen
/// asks: "is this aircraft one of mine?".
@MainActor
final class TripFlights: ObservableObject {
    static let shared = TripFlights()

    @Published private(set) var flights: [TripFlight] = []

    /// Callsign (normalized) → flight, for O(1) lookups while drawing rows.
    private var callsignIndex: [String: TripFlight] = [:]

    private init() {}

    /// Builds the list once. The itinerary only reaches `TripEngine` when the
    /// travel screen is opened, so fall back to the itinerary source directly.
    func reloadIfNeeded() {
        guard flights.isEmpty else { return }
        reload()
    }

    func reload() {
        var stops = TripEngine.shared.stops
        if stops.isEmpty {
            stops = ViagemBridge.makeStops()
        }
        let parsed = TripFlightParser.flights(from: stops)

        var index: [String: TripFlight] = [:]
        for flight in parsed {
            for callsign in flight.callsignCandidates {
                index[TripFlightParser.normalizedCallsign(callsign)] = flight
            }
        }

        callsignIndex = index
        if flights != parsed { flights = parsed }
    }

    /// The itinerary flight this aircraft is broadcasting, if any.
    func flight(matching aircraft: Aircraft) -> TripFlight? {
        let key = TripFlightParser.normalizedCallsign(aircraft.callsign)
        guard !key.isEmpty else { return nil }
        return callsignIndex[key]
    }

    /// Convenience for view code that only needs the yes/no.
    func isTripFlight(_ aircraft: Aircraft) -> Bool {
        flight(matching: aircraft) != nil
    }

    /// The aircraft currently on the radar for a given itinerary flight.
    func liveAircraft(for flight: TripFlight, in aircraft: [Aircraft]) -> Aircraft? {
        let wanted = Set(flight.callsignCandidates.map(TripFlightParser.normalizedCallsign))
        return aircraft.first { wanted.contains(TripFlightParser.normalizedCallsign($0.callsign)) }
    }

    /// All itinerary flights visible on the radar right now.
    func liveAircraftByFlightID(in aircraft: [Aircraft]) -> [String: Aircraft] {
        var out: [String: Aircraft] = [:]
        for ac in aircraft {
            guard let flight = flight(matching: ac) else { continue }
            out[flight.id] = ac
        }
        return out
    }
}
