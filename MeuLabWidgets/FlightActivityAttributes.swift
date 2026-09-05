import Foundation

// ============================================================
// ATRIBUTOS DA LIVE ACTIVITY DE VOO
// Compilado nos DOIS targets: MeuLabApp (que dirige a Activity)
// e MeuLabWidgetsExtension (que desenha). Por isso o arquivo não
// pode depender de nada que exista só de um lado — FlightLeg,
// TripEngine e afins ficam de fora de propósito.
// ============================================================

#if canImport(ActivityKit)
import ActivityKit

struct FlightActivityAttributes: ActivityAttributes {

    /// Everything that can move while the Activity is alive. Kept deliberately
    /// small: the countdown and the bar are animated by the system from these
    /// two instants, so nothing here needs a per-minute refresh.
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case beforeDeparture
            case inFlight
            case landed
        }

        /// Departure in force right now — the itinerary's time, or a revised
        /// one once a delay is known.
        var departure: Date
        /// Arrival in force right now — the live estimate when we have one,
        /// otherwise the itinerary's own time.
        var arrival: Date
        /// True when `arrival` came from a tracking service rather than the
        /// itinerary. Drives the "ao vivo" marker.
        var isEstimateLive: Bool
        var phase: Phase
        /// Short note already written in Portuguese ("Atrasado 25 min").
        var note: String?

        /// Guarded range for `ProgressView(timerInterval:)` / `Text(timerInterval:)`,
        /// which trap on an empty or inverted range.
        var flightRange: ClosedRange<Date> {
            let lower = departure
            let upper = max(arrival, departure.addingTimeInterval(60))
            return lower...upper
        }
    }

    // MARK: Static for the whole Activity

    /// "IB 268", as printed on the ticket.
    var flightCode: String
    /// City names as the itinerary writes them ("Guarulhos", "Madrid").
    var origin: String
    var destination: String
    var departureTimeZoneID: String?
    var arrivalTimeZoneID: String?
    /// Kept so the UI can show "previsto 05:35" next to a revised time.
    var scheduledDeparture: Date
    var scheduledArrival: Date

    var originCode: String { FlightActivityFormat.airportCode(for: origin) }
    var destinationCode: String { FlightActivityFormat.airportCode(for: destination) }

    var departureTimeZone: TimeZone? { departureTimeZoneID.flatMap(TimeZone.init(identifier:)) }
    var arrivalTimeZone: TimeZone? { arrivalTimeZoneID.flatMap(TimeZone.init(identifier:)) }
}

// MARK: - Formatação compartilhada

enum FlightActivityFormat {

    /// Clock time rendered in the airport's own zone, not the phone's. A
    /// traveller still on São Paulo time must read the Madrid arrival as
    /// Madrid states it.
    static func clock(_ date: Date, timeZoneID: String?) -> String {
        var calendar = Calendar(identifier: .gregorian)
        let zone = timeZoneID.flatMap(TimeZone.init(identifier:)) ?? .current
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Short zone marker for the arrival line ("CEST", "GMT-3").
    static func zoneAbbreviation(_ timeZoneID: String?, at date: Date) -> String? {
        guard let id = timeZoneID, let zone = TimeZone(identifier: id) else { return nil }
        return zone.abbreviation(for: date)
    }

    /// "2h 14min" / "45min". Used only for text the system does not animate.
    static func shortDuration(_ interval: TimeInterval) -> String {
        let total = max(Int(interval.rounded()), 0) / 60
        let hours = total / 60
        let minutes = total % 60
        if hours == 0 { return "\(minutes)min" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)min"
    }

    /// The itinerary names cities, not airports. Map the ones this trip uses and
    /// fall back to the first three letters, which still reads as a code.
    private static let cityToAirport: [String: String] = [
        "guarulhos": "GRU",
        "sao paulo": "GRU",
        "são paulo": "GRU",
        "congonhas": "CGH",
        "viracopos": "VCP",
        "campinas": "VCP",
        "londrina": "LDB",
        "curitiba": "CWB",
        "rio de janeiro": "GIG",
        "galeao": "GIG",
        "galeão": "GIG",
        "madrid": "MAD",
        "barcelona": "BCN",
        "lisboa": "LIS",
        "porto": "OPO",
        "paris": "CDG",
        "londres": "LHR",
        "roma": "FCO",
        "milao": "MXP",
        "milão": "MXP",
        "amsterda": "AMS",
        "amsterdã": "AMS",
        "frankfurt": "FRA",
        "munique": "MUC",
        "zurique": "ZRH",
        "veneza": "VCE",
        "florenca": "FLR",
        "florença": "FLR",
        "napoles": "NAP",
        "nápoles": "NAP",
        "atenas": "ATH",
        "istambul": "IST",
        "dublin": "DUB",
        "bruxelas": "BRU",
        "viena": "VIE",
        "praga": "PRG",
        "budapeste": "BUD",
        "berlim": "BER",
        "sevilha": "SVQ",
        "valencia": "VLC",
        "valência": "VLC",
        "malaga": "AGP",
        "málaga": "AGP",
    ]

    static func airportCode(for city: String) -> String {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "---" }

        let key = trimmed.lowercased()
        if let hit = cityToAirport[key] { return hit }
        // "Aeroporto de Madrid" and friends: try the last word too.
        if let tail = key.split(separator: " ").last.map(String.init), let hit = cityToAirport[tail] {
            return hit
        }
        // A three-letter city name is very likely already a code.
        let letters = trimmed.uppercased().filter { $0.isLetter }
        guard !letters.isEmpty else { return "---" }
        return String(letters.prefix(3))
    }
}
#endif
