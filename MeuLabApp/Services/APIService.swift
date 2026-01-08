import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case unauthorized
    case serverError(Int)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .networkError(let error):
            return "Erro de rede: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Erro ao processar dados: \(error.localizedDescription)"
        case .unauthorized:
            return "Não autorizado"
        case .serverError(let code):
            return "Erro do servidor: \(code)"
        case .unknown:
            return "Erro desconhecido"
        }
    }
}

actor APIService {
    static let shared = APIService()

    private let baseURL = "https://app.meulab.fun"
    private let adsbLolURL = "https://voa.meulab.fun"
    private let apiToken: String

    // Localização do receptor para buscar aeronaves próximas
    private let receiverLat = -20.512504
    private let receiverLon = -47.400830
    private let searchRadiusNm = 250  // Raio de busca em milhas náuticas

    private let session: URLSession

    private init() {
        self.apiToken = APIService.loadAPIToken()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    private static func loadAPIToken() -> String {
        if let token = Bundle.main.infoDictionary?["API_TOKEN"] as? String,
           !token.isEmpty {
            return token
        }

        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any],
              let token = plist["API_TOKEN"] as? String,
              !token.isEmpty else {
            return ""
        }

        return token
    }

    private func makeRequest(path: String) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        if !apiToken.isEmpty {
            request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        let request = try makeRequest(path: path)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw APIError.unauthorized
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - ADS-B

    func fetchADSBSummary() async throws -> ADSBSummary {
        try await fetch("/api/adsb/summary")
    }

    func fetchAircraftList(limit: Int = 100) async throws -> AircraftList {
        try await fetch("/api/adsb/aircraft?limit=\(limit)")
    }

    // MARK: - ADSB.lol Network API

    /// Busca aeronaves da rede ADSB.lol num raio ao redor do receptor
    func fetchADSBLolAircraft() async throws -> [Aircraft] {
        let urlString = "\(adsbLolURL)/v2/lat/\(receiverLat)/lon/\(receiverLon)/dist/\(searchRadiusNm)"

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        do {
            let decoder = JSONDecoder()
            let adsbLolResponse = try decoder.decode(ADSBLolResponse.self, from: data)

            // Converter para Aircraft com source = .network
            let aircraft = adsbLolResponse.ac?.compactMap { $0.toAircraft() } ?? []
            return aircraft
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - System

    func fetchSystemStatus() async throws -> SystemStatus {
        try await fetch("/api/system/status")
    }

    // MARK: - Radio

    func fetchNowPlaying() async throws -> NowPlaying {
        try await fetch("/api/radio/now-playing")
    }

    // MARK: - Weather

    func fetchWeather() async throws -> WeatherData {
        try await fetch("/api/weather/current")
    }

    // MARK: - Satellite

    func fetchLastImages() async throws -> LastImages {
        try await fetch("/api/satdump/last/images")
    }

    func fetchPasses() async throws -> PassesList {
        try await fetch("/api/satdump/passes")
    }

    func imageURL(passName: String, folderName: String, imageName: String) -> URL? {
        let path = "/api/satdump/image?pass=\(passName)&folder=\(folderName)&image=\(imageName)"
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              var components = URLComponents(string: "\(baseURL)\(encodedPath)") else {
            return nil
        }
        return components.url
    }

    // MARK: - ACARS

    func fetchACARSSummary() async throws -> ACARSSummary {
        try await fetch("/api/acars/summary")
    }

    func fetchACARSMessages(limit: Int = 20) async throws -> ACARSMessageList {
        try await fetch("/api/acars/messages?limit=\(limit)")
    }

    func fetchACARSHourly() async throws -> ACARSHourlyStats {
        try await fetch("/api/acars/hourly")
    }

    func searchACARSMessages(query: String) async throws -> ACARSSearchResult {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }
        return try await fetch("/api/acars/search?q=\(encoded)")
    }
}

// MARK: - Image Loading with Auth

extension APIService {
    func fetchImageData(passName: String, folderName: String, imageName: String) async throws -> Data {
        let path = "/api/satdump/image?pass=\(passName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? passName)&folder=\(folderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? folderName)&image=\(imageName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? imageName)"

        let request = try makeRequest(path: path)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return data
    }
}
