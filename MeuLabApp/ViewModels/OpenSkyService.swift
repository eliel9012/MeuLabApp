import Foundation
import CoreLocation

enum OpenSkyError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int)
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL inválida"
        case .networkError(let error): return "Erro de rede: \(error.localizedDescription)"
        case .decodingError(let error): return "Erro ao decodificar: \(error.localizedDescription)"
        case .serverError(let code): return "Erro do servidor: \(code)"
        case .rateLimited: return "Limite de requisições excedido"
        }
    }
}

actor OpenSkyService {
    static let shared = OpenSkyService()
    
    private let baseURL = "https://opensky-network.org/api"
    private let authURL = "https://auth.opensky-network.org/auth/realms/opensky-network/protocol/openid-connect/token"
    
    private let clientId = "eliel9012-api-client"
    private var clientSecret: String
    
    private var accessToken: String?
    private var tokenExpiration: Date?
    
    private let session: URLSession
    
    private init() {
        let envSecret = ProcessInfo.processInfo.environment["MEULAB_OPENSKY_CLIENT_SECRET"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plistSecret = (Bundle.main.object(forInfoDictionaryKey: "MEULAB_OPENSKY_CLIENT_SECRET") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.clientSecret = envSecret?.isEmpty == false ? envSecret! : (plistSecret ?? "")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    func setCredentials(secret: String) {
        self.clientSecret = secret
        self.accessToken = nil
        self.tokenExpiration = nil
    }
    
    // MARK: - Token Management
    
    private func getValidToken() async throws -> String? {
        if let token = accessToken, let expiration = tokenExpiration, expiration > Date().addingTimeInterval(60) {
            return token
        }
        
        return try await refreshToken()
    }
    
    private func refreshToken() async throws -> String? {
        guard !clientSecret.isEmpty else { return nil }
        
        print("[OpenSky] 🔑 Requesting new access token...")
        
        guard let url = URL(string: authURL) else { throw OpenSkyError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyItems = [
            "grant_type": "client_credentials",
            "client_id": clientId,
            "client_secret": clientSecret
        ]
        
        request.httpBody = bodyItems
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenSkyError.networkError(NSError(domain: "InvalidResponse", code: 0))
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("[OpenSky] ❌ Auth failed: \(httpResponse.statusCode)")
            return nil
        }
        
        let tokenResponse = try JSONDecoder().decode(OpenSkyTokenResponse.self, from: data)
        self.accessToken = tokenResponse.access_token
        self.tokenExpiration = Date().addingTimeInterval(Double(tokenResponse.expires_in))
        
        print("[OpenSky] ✅ Token received, expires in \(tokenResponse.expires_in)s")
        return tokenResponse.access_token
    }
    
    // MARK: - API Calls
    
    func fetchStates(boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? = nil) async throws -> [Aircraft] {
        let token = try await getValidToken()
        return try await performFetch(boundingBox: boundingBox, token: token)
    }

    private func performFetch(boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)?, token: String?) async throws -> [Aircraft] {
        let path = "/states/all"
        var queryItems: [URLQueryItem] = []
        
        if let box = boundingBox {
            queryItems.append(URLQueryItem(name: "lamin", value: String(box.minLat)))
            queryItems.append(URLQueryItem(name: "lamax", value: String(box.maxLat)))
            queryItems.append(URLQueryItem(name: "lomin", value: String(box.minLon)))
            queryItems.append(URLQueryItem(name: "lomax", value: String(box.maxLon)))
        }
        
        // Construct URL
        guard var components = URLComponents(string: baseURL + path) else {
            throw OpenSkyError.invalidURL
        }
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw OpenSkyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        
        // Add Bearer Token if we have one
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("[OpenSky] 🔐 Using Bearer Token auth")
        } else {
            print("[OpenSky] 👤 Using anonymous request")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenSkyError.networkError(NSError(domain: "InvalidResponse", code: 0))
        }
        
        // Handle token expiration
        if httpResponse.statusCode == 401 && token != nil {
            print("[OpenSky] ❌ Token expired or invalid (401). Retrying with new token...")
            self.accessToken = nil
            let newToken = try await refreshToken()
            return try await performFetch(boundingBox: boundingBox, token: newToken)
        }
        
        if httpResponse.statusCode == 429 {
            print("[OpenSky] ⚠️ Rate limit exceeded (429)")
            throw OpenSkyError.rateLimited
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("[OpenSky] ⚠️ Server error: \(httpResponse.statusCode)")
            throw OpenSkyError.serverError(httpResponse.statusCode)
        }
        
        let decoded = try JSONDecoder().decode(OpenSkyResponse.self, from: data)
        return decoded.states?.compactMap { mapToAircraft($0) } ?? []
    }
    
    // MARK: - Mapping
    
    private func mapToAircraft(_ state: [OpenSkyStateValue]) -> Aircraft? {
        guard state.count >= 13,
              let icao24 = state[0].stringValue else { return nil }
        
        let callsign = state[1].stringValue?.trimmingCharacters(in: .whitespaces) ?? ""
        let lat = state[6].doubleValue
        let lon = state[5].doubleValue
        let track = state[10].doubleValue
        
        let altMeters = state[7].doubleValue ?? state[13].doubleValue ?? 0
        let altFt = Int(altMeters * 3.28084)
        
        let speedMs = state[9].doubleValue ?? 0
        let speedKt = Int(speedMs * 1.94384)
        let speedKmh = Int(speedMs * 3.6)
        
        let vrMs = state[11].doubleValue ?? 0
        let vrFpm = Int(vrMs * 196.85)
        
        return Aircraft(
            id: icao24,
            hex: icao24,
            callsign: callsign,
            model: nil,
            registration: nil,
            airline: nil,
            lat: lat,
            lon: lon,
            track: track,
            altitudeFt: altFt,
            speedKt: speedKt,
            speedKmh: speedKmh,
            distanceNm: nil,
            verticalRateFpm: vrFpm,
            source: .opensky,
            isDualTracked: false
        )
    }
}

// MARK: - Models

struct OpenSkyTokenResponse: Codable {
    let access_token: String
    let expires_in: Int
}

struct OpenSkyResponse: Codable {
    let time: Int
    let states: [[OpenSkyStateValue]]?
}

enum OpenSkyStateValue: Codable {
    case string(String)
    case double(Double)
    case bool(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        if let x = try? container.decode(Double.self) {
            self = .double(x)
            return
        }
        if let x = try? container.decode(Bool.self) {
            self = .bool(x)
            return
        }
        if container.decodeNil() {
            self = .null
            return
        }
        throw DecodingError.typeMismatch(OpenSkyStateValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for OpenSkyStateValue"))
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let x): try container.encode(x)
        case .double(let x): try container.encode(x)
        case .bool(let x): try container.encode(x)
        case .null: try container.encodeNil()
        }
    }
    
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
    
    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        return nil
    }
    
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
