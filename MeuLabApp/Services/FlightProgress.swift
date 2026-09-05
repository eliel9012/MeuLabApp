import Foundation

// ============================================================
// PROGRESSO DE VOO
// Pareia partida e chegada do roteiro em instantes absolutos e
// deriva quanto já voou e quanto falta.
// ============================================================

/// One flight leg with both ends resolved to absolute instants. The itinerary
/// states local clock times in two different zones, which cannot be compared
/// until both are anchored.
struct FlightLeg: Identifiable, Equatable, Sendable {
    let id: String
    /// "IB 268" — as printed on the ticket.
    let code: String
    let origin: String
    let destination: String
    let departure: Date
    /// From the itinerary. Replaced by AeroAPI's estimate when one is cached.
    let scheduledArrival: Date
    let departureTimeZoneID: String?
    let arrivalTimeZoneID: String?
    /// Itinerary stop this leg came from, for cross-referencing.
    let stopID: String

    var departureTimeZone: TimeZone? { departureTimeZoneID.flatMap(TimeZone.init(identifier:)) }
    var arrivalTimeZone: TimeZone? { arrivalTimeZoneID.flatMap(TimeZone.init(identifier:)) }

    static func == (lhs: FlightLeg, rhs: FlightLeg) -> Bool { lhs.id == rhs.id }
}

/// What the progress card draws.
struct FlightProgress: Equatable, Sendable {
    enum Phase: String, Sendable {
        case beforeDeparture
        case inFlight
        case landed
    }

    let leg: FlightLeg
    /// Arrival actually used — AeroAPI's estimate when available, else the
    /// itinerary's own time.
    let effectiveArrival: Date
    /// True when `effectiveArrival` came from AeroAPI rather than the itinerary.
    let isEstimateLive: Bool
    let phase: Phase
    /// 0...1 along the leg. Clamped, so a late flight sits at 1 rather than
    /// running past the end of the bar.
    let fraction: Double
    let elapsed: TimeInterval
    let remaining: TimeInterval

    static func make(leg: FlightLeg, liveArrival: Date? = nil, now: Date = Date()) -> FlightProgress {
        let arrival = liveArrival ?? leg.scheduledArrival
        let total = arrival.timeIntervalSince(leg.departure)
        let elapsed = now.timeIntervalSince(leg.departure)

        let phase: Phase
        if now < leg.departure {
            phase = .beforeDeparture
        } else if now >= arrival {
            phase = .landed
        } else {
            phase = .inFlight
        }

        let fraction = total > 0 ? min(max(elapsed / total, 0), 1) : (phase == .landed ? 1 : 0)

        return FlightProgress(
            leg: leg,
            effectiveArrival: arrival,
            isEstimateLive: liveArrival != nil,
            phase: phase,
            fraction: fraction,
            elapsed: max(elapsed, 0),
            remaining: max(arrival.timeIntervalSince(now), 0)
        )
    }
}

// MARK: - Pareamento a partir do roteiro

enum FlightLegBuilder {
    /// "Voo IB 268 — Guarulhos → Madrid" -> ("Guarulhos", "Madrid")
    private static func route(in title: String) -> (String, String)? {
        guard let dash = title.range(of: "—") else { return nil }
        let tail = title[dash.upperBound...]
        guard let arrow = tail.range(of: "→") else { return nil }
        let from = tail[..<arrow.lowerBound].trimmingCharacters(in: .whitespaces)
        let to = tail[arrow.upperBound...].trimmingCharacters(in: .whitespaces)
        return from.isEmpty || to.isEmpty ? nil : (from, to)
    }

    /// The itinerary states arrival inside the prose ("chegada em Londrina às
    /// 10:15"), so the first clock time in the description is the arrival.
    private static func arrivalClock(in text: String) -> (hour: Int, minute: Int)? {
        guard let m = text.firstMatch(of: /(\d{1,2}):(\d{2})/),
            let h = Int(m.1), let min = Int(m.2),
            (0...23).contains(h), (0...59).contains(min)
        else { return nil }
        return (h, min)
    }

    /// Airport city to time zone. Derived from the flight title, which is the only
    /// field that reliably names both ends of a leg.
    ///
    /// The map pin cannot be trusted for this: nine of the ten flights pin their
    /// origin airport, but "Voo Ryanair FR 520 — Porto → London Stansted" pins
    /// Stansted, its destination. Reading the zone off the pin would have that leg
    /// departing on London time. Walking back to the previous itinerary stop fails
    /// differently — before an onward flight the previous stop is often the earlier
    /// flight's *departure*, which puts the traveller in the wrong country.
    private static let cityZones: [(needle: String, zone: String)] = [
        ("ribeirão preto", "America/Sao_Paulo"),
        ("ribeirao preto", "America/Sao_Paulo"),
        ("guarulhos", "America/Sao_Paulo"),
        ("congonhas", "America/Sao_Paulo"),
        ("são paulo", "America/Sao_Paulo"),
        ("sao paulo", "America/Sao_Paulo"),
        ("londrina", "America/Sao_Paulo"),
        ("madrid", "Europe/Madrid"),
        ("madri", "Europe/Madrid"),
        ("marseille", "Europe/Paris"),
        ("marselha", "Europe/Paris"),
        ("beauvais", "Europe/Paris"),
        ("paris", "Europe/Paris"),
        ("porto", "Europe/Lisbon"),
        ("lisboa", "Europe/Lisbon"),
        ("stansted", "Europe/London"),
        ("gatwick", "Europe/London"),
        ("london", "Europe/London"),
        ("londres", "Europe/London"),
    ]

    /// Longest needle first, so "ribeirão preto" is not shadowed by a shorter match.
    static func zoneID(forAirport text: String) -> String? {
        let lower = text.lowercased()
        return cityZones
            .filter { lower.contains($0.needle) }
            .max(by: { $0.needle.count < $1.needle.count })?
            .zone
    }

    private static func isFlight(_ stop: TripStop) -> Bool {
        let t = stop.title.lowercased()
        return t.hasPrefix("voo ") || t.contains(" voo ") || t.contains("flight")
    }

    static func legs(from stops: [TripStop]) -> [FlightLeg] {
        var out: [FlightLeg] = []

        for (index, stop) in stops.enumerated() {
            guard isFlight(stop),
                let stopDate = stop.date,
                let (from, to) = route(in: stop.title),
                let clock = arrivalClock(in: stop.detail)
            else { continue }

            // Both ends come from the route in the title. Falling back to the
            // stop's own zone only when a city is unrecognised.
            let departureZoneID = zoneID(forAirport: from) ?? stop.timeZoneID
            let arrivalZoneID = zoneID(forAirport: to)
                ?? stops[(index + 1)...].first(where: { $0.timeZoneID != nil })?.timeZoneID
                ?? stop.timeZoneID
            let arrivalZone = arrivalZoneID.flatMap(TimeZone.init(identifier:))
                ?? TimeZone(identifier: "America/Sao_Paulo")!

            // Re-anchor departure in the origin airport's zone: TripStop resolved it
            // with the pin's zone, which is the wrong one for FR 520.
            var depCal = Calendar(identifier: .gregorian)
            depCal.timeZone = departureZoneID.flatMap(TimeZone.init(identifier:))
                ?? TimeZone(identifier: "America/Sao_Paulo")!
            var depComps = depCal.dateComponents([.year, .month, .day], from: stopDate)
            if let c = TripParser.clock(from: stop.time) {
                depComps.hour = c.hour
                depComps.minute = c.minute
            }
            let departure = depCal.date(from: depComps) ?? stopDate

            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = arrivalZone
            var comps = cal.dateComponents([.year, .month, .day], from: departure)
            comps.hour = clock.hour
            comps.minute = clock.minute
            guard var arrival = cal.date(from: comps) else { continue }

            // An arrival clock that lands at or before departure means the leg
            // crossed midnight — GRU 14:10 BRT to Madrid 05:35 CEST, for one.
            if arrival <= departure {
                arrival = cal.date(byAdding: .day, value: 1, to: arrival) ?? arrival
            }

            let code = flightCode(in: stop.title) ?? stop.title

            out.append(
                FlightLeg(
                    id: stop.id,
                    code: code,
                    origin: from,
                    destination: to,
                    departure: departure,
                    scheduledArrival: arrival,
                    departureTimeZoneID: departureZoneID,
                    arrivalTimeZoneID: arrivalZoneID,
                    stopID: stop.id
                )
            )
        }
        return out
    }

    /// "Voo IB 268 — ..." -> "IB 268". Falls back to a bare number ("Voo 4211").
    static func flightCode(in title: String) -> String? {
        if let m = title.firstMatch(of: /\b([A-Z]{2}|[A-Z][0-9]|[0-9][A-Z])\s?([0-9]{2,4})\b/) {
            return "\(m.1) \(m.2)"
        }
        if let m = title.firstMatch(of: /[Vv]oo\s+([0-9]{2,4})\b/) {
            return "Voo \(m.1)"
        }
        return nil
    }
}
