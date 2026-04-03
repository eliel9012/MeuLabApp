import Foundation

/// Service to lookup aircraft registration from ICAO Hex code
actor HexLookupService {
    static let shared = HexLookupService()
    
    private var cache: [String: String] = [:]
    
    /// Tries to fetch registration for a given hex code
    func lookup(hex: String) async -> String? {
        // Normalize hex
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanHex.isEmpty else { return nil }
        if let cached = cache[cleanHex] {
            return cached
        }

        // Try hexdb.io (Open API)
        // Endpoint: https://hexdb.io/api/v1/aircraft/{hex}
        let urlString = "https://hexdb.io/api/v1/aircraft/\(cleanHex)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reg = extractRegistration(from: json) {
                cache[cleanHex] = reg
                return reg
            }
        } catch {
            print("Hex lookup failed: \(error.localizedDescription)")
        }

        if let reg = await lookupADSBOne(hex: cleanHex) {
            cache[cleanHex] = reg
            return reg
        }

        if let reg = await lookupADSBDB(hex: cleanHex) {
            cache[cleanHex] = reg
            return reg
        }

        return nil
    }

    private func lookupADSBOne(hex: String) async -> String? {
        let urlString = "https://api.adsb.one/v2/hex/\(hex)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let reg = extractRegistration(from: json) {
                    return reg
                }
                if let acArray = json["ac"] as? [[String: Any]],
                   let first = acArray.first,
                   let reg = extractRegistration(from: first) {
                    return reg
                }
            }
        } catch {
            print("Hex lookup fallback adsb.one failed: \(error.localizedDescription)")
        }

        return nil
    }

    private func lookupADSBDB(hex: String) async -> String? {
        let urlString = "https://api.adsbdb.com/v0/aircraft/\(hex)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseObj = json["response"] as? [String: Any],
               let aircraftObj = responseObj["aircraft"] as? [String: Any],
               let reg = extractRegistration(from: aircraftObj) {
                return reg
            }
        } catch {
            print("Hex lookup fallback adsbdb failed: \(error.localizedDescription)")
        }

        return nil
    }

    private func extractRegistration(from json: [String: Any]) -> String? {
        let candidates: [String?] = [
            json["registration"] as? String,
            json["Registration"] as? String,
            json["r"] as? String,
            json["tail"] as? String,
            json["tail_number"] as? String
        ]

        for value in candidates {
            if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }
}
