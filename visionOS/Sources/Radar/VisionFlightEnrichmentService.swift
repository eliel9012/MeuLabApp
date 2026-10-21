import Foundation

struct VisionAircraftPhoto {
    let url: URL
    let photographer: String?
    let source: String
}

/// Uses the same public photo sources and MeuLab FlightAware endpoint as the iPhone app.
@MainActor
final class VisionFlightEnrichmentService {
    static let shared = VisionFlightEnrichmentService()

    private struct Cached<Value> {
        let value: Value
        let fetchedAt: Date
        var isFresh: Bool { Date().timeIntervalSince(fetchedAt) < 300 }
    }

    private var photos: [String: Cached<VisionAircraftPhoto?>] = [:]
    private var flights: [String: Cached<FlightAwareFlight?>] = [:]

    func photo(for aircraft: Aircraft) async -> VisionAircraftPhoto? {
        if let cached = photos[aircraft.hex], cached.isFresh { return cached.value }

        let registration = aircraft.registration?.trimmingCharacters(in: .whitespacesAndNewlines)
        var result: VisionAircraftPhoto?
        if let registration, !registration.isEmpty {
            result = await planeSpotters(path: "reg", identifier: registration)
        }
        if result == nil {
            result = await planeSpotters(path: "hex", identifier: aircraft.hex)
        }
        if result == nil {
            result = await openSky(hex: aircraft.hex)
        }
        photos[aircraft.hex] = Cached(value: result, fetchedAt: Date())
        return result
    }

    func flightAware(for aircraft: Aircraft) async throws -> FlightAwareFlight? {
        let ident = aircraft.callsign.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !ident.isEmpty, ident != aircraft.hex.uppercased() else { return nil }
        if let cached = flights[ident], cached.isFresh { return cached.value }

        let encoded = ident.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?"))) ?? ident
        let response: FlightAwareFlightResponse = try await VisionAPIClient().fetch("api/flightaware/flight?ident=\(encoded)&max_pages=1")
        let result = response.data.flights?.first
        flights[ident] = Cached(value: result, fetchedAt: Date())
        return result
    }

    private func planeSpotters(path: String, identifier: String) async -> VisionAircraftPhoto? {
        let encoded = identifier.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?"))) ?? identifier
        guard let url = URL(string: "https://api.planespotters.net/pub/photos/\(path)/\(encoded)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("MeuLabApp/1.0 (+https://meulab.fun/contact)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let first = (result["photos"] as? [[String: Any]])?.first else { return nil }
            let large = (first["thumbnail_large"] as? [String: Any])?["src"] as? String
            let small = (first["thumbnail"] as? [String: Any])?["src"] as? String
            guard let text = large ?? small, let photoURL = URL(string: text), photoURL.scheme == "https" else { return nil }
            return VisionAircraftPhoto(url: photoURL, photographer: first["photographer"] as? String, source: "PlaneSpotters")
        } catch {
            return nil
        }
    }

    private func openSky(hex: String) async -> VisionAircraftPhoto? {
        guard let url = URL(string: "https://opensky-network.org/api/metadata/data/aircraft/icao24/\(hex.lowercased())/image") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        return VisionAircraftPhoto(url: url, photographer: nil, source: "OpenSky")
    }
}
