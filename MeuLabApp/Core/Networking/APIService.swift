import Foundation

/// Implementação do serviço de API
actor APIService: APIServiceProtocol {
    static let shared = APIService()

    private var baseURL = "https://app.meulab.fun"
    private let radarBaseURL = "https://radar.meulab.fun"
    private let apiToken: String

    private let session: URLSession

    private init() {
        self.apiToken = APIService.loadAPIToken()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)

        Logger.info("APIService inicializado com baseURL: \(baseURL)")
    }

    private static func loadAPIToken() -> String {
        if let token = Bundle.main.infoDictionary?["API_TOKEN"] as? String,
            !token.isEmpty
        {
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
            !token.isEmpty
        else {
            Logger.warning("API_TOKEN não encontrado em Info.plist ou Secrets.plist")
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

        Logger.logRequest(method: request.httpMethod ?? "GET", url: url.absoluteString)
        return request
    }

    private func fetch<T: Decodable>(_ path: String) async throws -> T {
        let startTime = Date()
        let request = try makeRequest(path: path)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let apiError = APIError.from(error)
            Logger.logError(apiError, context: "URLSession.data(\(path))")
            throw apiError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.error("Response não é HTTPURLResponse")
            throw APIError.unknown("Response inválida")
        }

        let duration = Date().timeIntervalSince(startTime)
        Logger.logResponse(statusCode: httpResponse.statusCode, url: path, duration: duration)

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            let decodingError = APIError.decodingError(error.localizedDescription)
            Logger.logError(decodingError, context: "JSONDecoder(\(path))")
            throw decodingError
        }
    }

    // MARK: - ADS-B

    func fetchADSBSummary() async throws -> ADSBSummary {
        try await fetch("/api/adsb/summary")
    }

    func fetchAircraftList(limit: Int = 100) async throws -> AircraftList {
        try await fetch("/api/adsb/aircraft?limit=\(limit)")
    }

    // MARK: - Radar direto (radar.meulab.fun)

    /// Busca aeronaves ao vivo diretamente do receptor ADS-B local (sem autenticação)
    func fetchADSBLolAircraft() async throws -> [Aircraft] {
        let urlString = "\(radarBaseURL)/data/aircraft.json"

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        Logger.logRequest(method: "GET", url: urlString)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let apiError = APIError.from(error)
            Logger.logError(apiError, context: "Radar Aircraft")
            throw apiError
        }

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.serverError(statusCode)
        }

        do {
            let decoder = JSONDecoder()
            let radarResponse = try decoder.decode(RadarAircraftResponse.self, from: data)

            // Converte para Aircraft, filtrando apenas os com posição
            let aircraft = radarResponse.aircraft.compactMap { $0.toAircraft() }
            Logger.info(
                "Radar retornou \(aircraft.count) aeronaves (total: \(radarResponse.aircraft.count))"
            )
            return aircraft
        } catch {
            let decodingError = APIError.decodingError(error.localizedDescription)
            Logger.logError(decodingError, context: "Radar Decoding")
            throw decodingError
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
            var components = URLComponents(string: "\(baseURL)\(encodedPath)")
        else {
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
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else {
            throw APIError.invalidURL
        }
        return try await fetch("/api/acars/search?q=\(encoded)")
    }

    // MARK: - Image Loading with Auth

    func fetchImageData(passName: String, folderName: String, imageName: String) async throws
        -> Data
    {
        let path =
            "/api/satdump/image?pass=\(passName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? passName)&folder=\(folderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? folderName)&image=\(imageName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? imageName)"

        let request = try makeRequest(path: path)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return data
    }
}
