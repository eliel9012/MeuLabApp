import Foundation

/// API Service minimalista para watchOS
/// Chama a API diretamente sem dependências de iOS
actor WatchAPIService {
    static let shared = WatchAPIService()
    
    private let baseURL = "https://app.meulab.fun"
    private let apiToken = WatchSecrets.apiToken.isEmpty ? WatchSecrets.apiTokenAlternative : WatchSecrets.apiToken
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // Sincronizado com App principal
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        #if DEBUG
        print("🔐 watchOS Secrets: Token configured = \(WatchSecrets.isConfigured)")
        #endif
    }
    
    private func makeRequest(path: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw WatchAPIError.invalidURL
        }
        guard !apiToken.isEmpty else {
            throw WatchAPIError.unauthorized
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue(apiToken, forHTTPHeaderField: "X-API-Token")
        request.setValue("MeuLabWatch/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }
    
    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        let request = try makeRequest(path: path)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WatchAPIError.unknown
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw WatchAPIError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Endpoints
    
    func fetchSummary() async throws -> WatchSummary {
        // Busca todos os dados em paralelo
        async let adsb = fetchADSBSummary()
        async let acars = fetchACARSSummary()
        async let system = fetchSystemStatus()
        async let weather = fetchWeather()
        async let infra = fetchInfraSummary()
        async let satdump = fetchSatDumpStatus()
        
        return try await WatchSummary(
            adsb: adsb,
            acars: acars,
            system: system,
            weather: weather,
            infra: infra,
            satdump: satdump,
            timestamp: Date()
        )
    }
    
    func fetchADSBSummary() async throws -> WatchADSBData {
        try await fetch("/api/adsb/summary")
    }
    
    func fetchACARSSummary() async throws -> WatchACARSData {
        try await fetch("/api/acars/summary")
    }
    
    func fetchSystemStatus() async throws -> WatchSystemData {
        try await fetch("/api/system/status")
    }
    
    func fetchWeather() async throws -> WatchWeatherData {
        try await fetch("/api/weather/current")
    }
    
    func fetchInfraSummary() async throws -> WatchInfraData {
        // Combina métricas e docker status
        async let metrics: WatchMetricsData = fetch("/api/metrics")
        async let docker: WatchDockerData = fetch("/api/docker/status?health=1")
        
        return try await WatchInfraData(metrics: metrics, docker: docker)
    }
    
    func fetchSatDumpStatus() async throws -> WatchSatDumpData {
        try await fetch("/api/satdump/status")
    }
    
    func fetchAlerts() async throws -> [WatchAlert] {
        let response: WatchNotificationResponse = try await fetch("/api/notifications/feed?limit=20")
        return response.items
    }
    
    func fetchAircraftList() async throws -> WatchAircraftList {
        try await fetch("/api/adsb/aircraft?limit=10")
    }
    
    func fetchACARSMessages() async throws -> WatchACARSMessageList {
        try await fetch("/api/acars/messages?limit=10")
    }
    
    func fetchPasses() async throws -> WatchPassesList {
        try await fetch("/api/satdump/passes")
    }
    func fetchNowPlaying() async throws -> NowPlaying {
        try await fetch("/api/radio/now-playing")
    }
}

// MARK: - Error

enum WatchAPIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(Int)
    case unauthorized
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL inválida"
        case .networkError(let e): return "Rede: \(e.localizedDescription)"
        case .serverError(let code): return "Servidor: \(code)"
        case .unauthorized: return "Token de API não configurado"
        case .unknown: return "Erro desconhecido"
        }
    }
}
