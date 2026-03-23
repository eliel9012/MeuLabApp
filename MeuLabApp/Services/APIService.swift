import Foundation
import CoreLocation

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

    private var baseURL = Secrets.apiBaseURL
    private let gpsGlobeBaseURL = "https://gps.meulab.fun"
    private let apiToken = Secrets.apiToken.isEmpty ? Secrets.apiTokenAlternative : Secrets.apiToken

    // AviationStack (Flight Routes)
    private let aviationStackBaseURL = "http://api.aviationstack.com/v1"
    private let aviationStackKey = "SUA_KEY_AQUI"

    private let searchRadiusNm = 250

    private let transientStatusCodes: Set<Int> = [429, 500, 502, 503, 504, 530]

    @MainActor private var receiverLat: Double {
        LocationManager.receiverLocation.coordinate.latitude
    }
    @MainActor private var receiverLon: Double {
        LocationManager.receiverLocation.coordinate.longitude
    }

    private var lastAdsbLolLogTime: Date?
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
        
        #if DEBUG
        Secrets.debugPrintStatus()
        #endif
    }

    /// Called from MainActor when NetworkEnvironment detects a change.
    func updateBaseURL(_ newURL: String) {
        self.baseURL = newURL
    }

    // MARK: - Request Helpers

    private func makeRequest(path: String, requiresAuth: Bool = true) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        if requiresAuth {
            guard !apiToken.isEmpty else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
            request.setValue(apiToken, forHTTPHeaderField: "X-API-Token")
        }
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func performRequest(_ request: URLRequest, retries: Int = 1) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        var lastError: Error?
        let currentRequest = request

        while attempt <= retries {
            do {
                let (data, response) = try await session.data(for: currentRequest)
                guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
                if (200...299).contains(http.statusCode) {
                    return (data, http)
                }
                // Retry for transient server errors
                if transientStatusCodes.contains(http.statusCode) && attempt < retries {
                    attempt += 1
                    let delay = 0.3 + Double.random(in: 0...0.1)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    throw APIError.serverError(http.statusCode)
                }
            } catch {
                // Retry on network errors
                lastError = error
                if attempt < retries {
                    attempt += 1
                    let delay = 0.3 + Double.random(in: 0...0.1)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    throw APIError.networkError(error)
                }
            }
        }

        throw APIError.networkError(lastError ?? APIError.unknown)
    }

    private func fetch<T: Decodable>(_ path: String, requiresAuth: Bool = true) async throws -> T {
        let request = try makeRequest(path: path, requiresAuth: requiresAuth)
        let (data, _) = try await performRequest(request)
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func fetchData(_ path: String, requiresAuth: Bool = true) async throws -> Data {
        let request = try makeRequest(path: path, requiresAuth: requiresAuth)
        let (data, _) = try await performRequest(request)
        return data
    }

    private func fetchFromURL<T: Decodable>(_ urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await performRequest(request)
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - General

    func fetchHealth() async throws -> HealthResponse {
        try await fetch("/health", requiresAuth: false)
    }

    func fetchMetrics() async throws -> MetricsResponse {
        try await fetch("/api/metrics")
    }

    func fetchDashboard() async throws -> DashboardResponse {
        try await fetch("/api/dashboard")
    }

    // MARK: - ADS-B

    func fetchADSBSummary() async throws -> ADSBSummary {
        try await fetch("/api/adsb/summary")
    }

    func fetchAircraftList(limit: Int = 80) async throws -> AircraftList {
        try await fetch("/api/adsb/aircraft?limit=\(limit)")
    }

    func fetchADSBHistory() async throws -> ADSBHistoryResponse {
        try await fetch("/api/adsb/history")
    }

    func fetchADSBAlerts() async throws -> ADSBAlertsResponse {
        try await fetch("/api/adsb/alerts")
    }

    func fetchTuyaTemperatureHumidity(historyLimit: Int = 12) async throws -> TuyaTemperatureHumidityResponse {
        try await fetch("/api/tuya/temperature-humidity?history_limit=\(historyLimit)")
    }

    func fetchADSBLolResponse() async throws -> ADSBLolResponse {
        try await fetch("/api/adsb/adsb_lol")
    }

    func fetchAirlineClassification(
        hex: String? = nil,
        registration: String? = nil,
        callsign: String? = nil,
        model: String? = nil
    ) async throws -> AirlineClassificationLookupResponse {
        var query: [String] = []
        if let hex, !hex.isEmpty {
            let encoded = hex.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? hex
            query.append("hex=\(encoded)")
        }
        if let registration, !registration.isEmpty {
            let encoded = registration.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? registration
            query.append("registration=\(encoded)")
        }
        if let callsign, !callsign.isEmpty {
            let encoded = callsign.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? callsign
            query.append("callsign=\(encoded)")
        }
        if let model, !model.isEmpty {
            let encoded = model.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? model
            query.append("model=\(encoded)")
        }
        let suffix = query.isEmpty ? "" : "?" + query.joined(separator: "&")
        return try await fetch("/api/adsb/airline_classification\(suffix)")
    }

    func saveAirlineClassification(_ payload: AirlineClassificationUpsertRequest) async throws -> AirlineClassificationUpsertResponse {
        var request = try makeRequest(path: "/api/adsb/airline_classification")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(AirlineClassificationUpsertResponse.self, from: data)
    }

    // MARK: - System

    func fetchSystemStatus() async throws -> SystemStatus {
        try await fetch("/api/system/status")
    }

    // MARK: - Fire Stick (ADB monitor)

    func fetchFirestickDevices() async throws -> FirestickDevicesResponse {
        try await fetch("/api/firestick/devices")
    }

    func fetchFirestickStatus(id: String? = nil, force: Bool = false) async throws -> FirestickStatusResponse {
        var path = "/api/firestick/status"
        var query: [String] = []
        if let id, !id.isEmpty {
            let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
            query.append("id=\(encoded)")
        }
        if force {
            query.append("force=1")
        }
        if !query.isEmpty {
            path += "?" + query.joined(separator: "&")
        }
        return try await fetch(path)
    }

    func fetchFirestickScreenshotKey(id: String) async throws -> FirestickScreenshotKeyResponse {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? id
        return try await fetch("/api/firestick/screenshot_key?id=\(encoded)")
    }

    func fetchProcesses(limit: Int = 5) async throws -> ProcessList {
        try await fetch("/api/system/processes?limit=\(limit)")
    }

    func fetchPartitions() async throws -> PartitionList {
        try await fetch("/api/system/partitions")
    }

    func fetchNetworkStats() async throws -> NetworkStats {
        try await fetch("/api/system/network")
    }

    // MARK: - Systemd

    func fetchSystemdStatus(services: [String]? = nil) async throws -> SystemdStatusResponse {
        if let services, !services.isEmpty {
            let joined = services.joined(separator: ",")
            return try await fetch("/api/systemd/status?services=\(joined)")
        }
        return try await fetch("/api/systemd/status")
    }

    // MARK: - Docker

    func fetchDockerVersion() async throws -> DockerVersionResponse {
        try await fetch("/api/docker/version")
    }

    func fetchDockerStatus(health: Bool = true) async throws -> DockerStatusResponse {
        let healthValue = health ? "1" : "0"
        return try await fetch("/api/docker/status?health=\(healthValue)")
    }

    func fetchDockerLogs(container: String, tail: Int = 200, since: Int = 0) async throws -> DockerLogsResponse {
        guard let encoded = container.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }
        return try await fetch("/api/docker/logs?container=\(encoded)&tail=\(tail)&since=\(since)")
    }

    func fetchDockerLogsRaw(container: String, tail: Int = 200, since: Int = 3600) async throws -> String {
        guard let encoded = container.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }
        let path = "/api/docker/logs?container=\(encoded)&tail=\(tail)&since=\(since)"
        let data = try await fetchData(path)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Weather

    func fetchWeather() async throws -> WeatherData {
        try await fetch("/api/weather/current")
    }

    func fetchWeather(lat: Double, lon: Double) async throws -> WeatherData {
        try await fetch("/api/weather/current?lat=\(lat)&lon=\(lon)")
    }

    // MARK: - Radio

    func fetchNowPlaying() async throws -> NowPlaying {
        try await fetch("/api/radio/now-playing")
    }

    func fetchRadioHistory(limit: Int = 50) async throws -> RadioHistoryResponse {
        let clamped = max(1, min(200, limit))
        return try await fetch("/api/radio/history?limit=\(clamped)")
    }

    // MARK: - ACARS

    func fetchACARSSummary() async throws -> ACARSSummary {
        try await fetch("/api/acars/summary")
    }

    func fetchACARSMessages(limit: Int = 20, details: Bool = true, libacars: Bool = true) async throws -> ACARSMessageList {
        let detailsVal = details ? "1" : "0"
        let libacarsVal = libacars ? "1" : "0"
        return try await fetch("/api/acars/messages?limit=\(limit)&details=\(detailsVal)&libacars=\(libacarsVal)")
    }

    func searchACARSMessages(query: String, details: Bool = true, libacars: Bool = true) async throws -> ACARSSearchResult {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }
        let detailsVal = details ? "1" : "0"
        let libacarsVal = libacars ? "1" : "0"
        return try await fetch("/api/acars/search?q=\(encoded)&details=\(detailsVal)&libacars=\(libacarsVal)")
    }

    func fetchACARSMessage(id: Int, libacars: Bool = true) async throws -> ACARSMessageResponse {
        let libacarsVal = libacars ? "1" : "0"
        return try await fetch("/api/acars/message/\(id)?libacars=\(libacarsVal)")
    }

    func fetchACARSHourly() async throws -> ACARSHourlyStats {
        try await fetch("/api/acars/hourly")
    }

    func fetchACARSHistory() async throws -> ACARSHistoryResponse {
        try await fetch("/api/acars/history")
    }

    func fetchACARSAlerts() async throws -> ACARSAlertsResponse {
        try await fetch("/api/acars/alerts")
    }

    // MARK: - Satellite (SatDump)

    func fetchPasses(page: Int = 1, limit: Int = 50) async throws -> PassesListPaginated {
        try await fetch("/api/satdump/passes?page=\(page)&limit=\(limit)")
    }

    func fetchAllPasses(page: Int = 1, limit: Int = 50) async throws -> PassesListPaginated {
        try await fetch("/api/satdump/passes?page=\(page)&limit=\(limit)")
    }

    func fetchLastImages() async throws -> LastImages {
        try await fetch("/api/satdump/last/images")
    }

    func fetchPassImages(passName: String) async throws -> LastImages {
        guard let encoded = passName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }
        return try await fetch("/api/satdump/pass/images?pass=\(encoded)")
    }

    func fetchPassImagesLossless(passName: String) async throws -> LastImages {
        guard let encoded = passName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }
        return try await fetch("/api/satdump/pass/images_lossless?pass=\(encoded)")
    }

    func fetchSatDumpStatus() async throws -> SatDumpStatusResponse {
        try await fetch("/api/satdump/status")
    }

    func cleanupPasses(thresholdMb: Double = 1.0, dryRun: Bool = true) async throws -> PassCleanupResult {
        let path = "/api/satdump/cleanup?threshold_mb=\(thresholdMb)&dry_run=\(dryRun)"
        var request = try makeRequest(path: path)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(PassCleanupResult.self, from: data)
    }

    func fetchSatDumpFFT() async throws -> Data {
        if let cached = BinaryCache.shared.cachedData(forPath: "/api/satdump/fft") { return cached }
        let data = try await fetchData("/api/satdump/fft")
        BinaryCache.shared.store(data, forPath: "/api/satdump/fft")
        return data
    }

    func fetchSatDumpLive() async throws -> SatDumpLiveResponse {
        try await fetch("/api/satdump/live")
    }

    func fetchGPSGlobeState() async throws -> GPSGlobeState {
        try await fetchFromURL("\(gpsGlobeBaseURL)/api/state")
    }

    func fetchSatDumpSchedule() async throws -> Data {
        if let cached = BinaryCache.shared.cachedData(forPath: "/api/satdump/schedule") { return cached }
        let data = try await fetchData("/api/satdump/schedule")
        BinaryCache.shared.store(data, forPath: "/api/satdump/schedule")
        return data
    }

    // MARK: - Meteor Passes

    func fetchMeteorPasses(count: Int = 100, minElevation: Int = 10) async throws -> SatellitePassesResponse {
        try await fetch("/api/satdump/meteor/passes?count=\(count)&min_elevation=\(minElevation)")
    }

    // MARK: - Orbcomm

    func fetchOrbcommPasses(count: Int = 100, minElevation: Int = 10) async throws -> SatellitePassesResponse {
        try await fetch("/api/satdump/orbcomm/passes?count=\(count)&min_elevation=\(minElevation)")
    }

    func fetchOrbcommNextPasses(count: Int = 10, minElevation: Int = 40) async throws -> SatellitePassesResponse {
        try await fetch("/api/satdump/orbcomm/next_passes?count=\(count)&min_elevation=\(minElevation)")
    }

    func fetchOrbcommRuns(limit: Int = 30) async throws -> OrbcommRunsResponse {
        try await fetch("/api/satdump/orbcomm/runs?limit=\(limit)")
    }

    func fetchOrbcommRunsNonempty(limit: Int = 200) async throws -> OrbcommRunsResponse {
        try await fetch("/api/satdump/orbcomm/runs_nonempty?limit=\(limit)")
    }

    func fetchOrbcommDecoded(run: String? = nil, limit: Int = 200) async throws -> OrbcommDecodedResponse {
        var path = "/api/satdump/orbcomm/decoded?limit=\(limit)"
        if let run, !run.isEmpty {
            guard let encoded = run.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw APIError.invalidURL
            }
            path += "&run=\(encoded)"
        }
        return try await fetch(path)
    }

    func fetchOrbcommDecodedFile(run: String? = nil) async throws -> Data {
        var path = "/api/satdump/orbcomm/decoded_file"
        if let run, !run.isEmpty {
            guard let encoded = run.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw APIError.invalidURL
            }
            path += "?run=\(encoded)"
        }
        return try await fetchData(path)
    }

    func fetchOrbcommLogs(run: String? = nil, limit: Int = 500) async throws -> OrbcommLogsResponse {
        var path = "/api/satdump/orbcomm/logs?limit=\(limit)"
        if let run, !run.isEmpty {
            guard let encoded = run.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw APIError.invalidURL
            }
            path += "&run=\(encoded)"
        }
        return try await fetch(path)
    }

    func fetchOrbcommLastEvent(run: String) async throws -> OrbcommLastEventResponse {
        guard let encoded = run.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.invalidURL
        }
        return try await fetch("/api/satdump/orbcomm/last_event?run=\(encoded)")
    }

    // MARK: - Satellite Positions

    func fetchSatellitePositions(minElevation: Int = 0, token: String? = nil) async throws -> SatellitePositionsResponse {
        var path = "/api/satdump/positions?min_elevation=\(minElevation)"
        if let token = token {
            path += "&token=\(token)"
            return try await fetch(path, requiresAuth: false)
        }
        return try await fetch(path)
    }

    func fetchSatelliteStatus(norad: Int? = nil, name: String? = nil, token: String? = nil) async throws -> SatelliteStatusResponse {
        var path = "/api/satdump/satellite_status?"
        if let norad = norad {
            path += "norad=\(norad)"
        } else if let name = name, let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            path += "name=\(encoded)"
        } else {
            throw APIError.invalidURL
        }
        if let token = token {
            path += "&token=\(token)"
            return try await fetch(path, requiresAuth: false)
        }
        return try await fetch(path)
    }

    // MARK: - Image URLs and Data

    func imageURL(passName: String, folderName: String, imageName: String) -> URL? {
        let path = "/api/satdump/image?pass=\(passName)&folder=\(folderName)&image=\(imageName)"
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let components = URLComponents(string: "\(baseURL)\(encodedPath)") else {
            return nil
        }
        return components.url
    }

    func imageLightURL(passName: String, folderName: String, imageName: String, max: Int = 1280, quality: Int = 75, format: String = "webp") -> URL? {
        let path = "/api/satdump/image_light?pass=\(passName)&folder=\(folderName)&image=\(imageName)&max=\(max)&quality=\(quality)&format=\(format)"
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let components = URLComponents(string: "\(baseURL)\(encodedPath)") else {
            return nil
        }
        return components.url
    }

    func imageFastURL(passName: String, folderName: String, imageName: String) -> URL? {
        let path = "/api/satdump/image_fast?pass=\(passName)&folder=\(folderName)&image=\(imageName)"
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let components = URLComponents(string: "\(baseURL)\(encodedPath)") else {
            return nil
        }
        return components.url
    }

    func imageLosslessURL(passName: String, folderName: String, imageName: String) -> URL? {
        let path = "/api/satdump/image_lossless?pass=\(passName)&folder=\(folderName)&image=\(imageName)"
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let components = URLComponents(string: "\(baseURL)\(encodedPath)") else {
            return nil
        }
        return components.url
    }

    func imageLegendURL(passName: String, folderName: String, imageName: String, format: String = "jpeg", quality: Int = 90) -> URL? {
        let path = "/api/satdump/image_legend?pass=\(passName)&folder=\(folderName)&image=\(imageName)&format=\(format)&quality=\(quality)"
        guard let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let components = URLComponents(string: "\(baseURL)\(encodedPath)") else {
            return nil
        }
        return components.url
    }

    func fetchImageData(passName: String, folderName: String, imageName: String) async throws -> Data {
        let passEncoded = passName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? passName
        let folderEncoded = folderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? folderName
        let imageEncoded = imageName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? imageName
        let path = "/api/satdump/image?pass=\(passEncoded)&folder=\(folderEncoded)&image=\(imageEncoded)"
        if let cached = BinaryCache.shared.cachedData(forPath: path) { return cached }
        let data = try await fetchData(path)
        BinaryCache.shared.store(data, forPath: path)
        return data
    }

    func fetchImageLightData(passName: String, folderName: String, imageName: String, max: Int = 1280) async throws -> Data {
        let passEncoded = passName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? passName
        let folderEncoded = folderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? folderName
        let imageEncoded = imageName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? imageName
        let path = "/api/satdump/image_light?pass=\(passEncoded)&folder=\(folderEncoded)&image=\(imageEncoded)&max=\(max)"
        if let cached = BinaryCache.shared.cachedData(forPath: path) { return cached }
        let data = try await fetchData(path)
        BinaryCache.shared.store(data, forPath: path)
        return data
    }

    func fetchImageLosslessData(passName: String, folderName: String, imageName: String) async throws -> Data {
        let passEncoded = passName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? passName
        let folderEncoded = folderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? folderName
        let imageEncoded = imageName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? imageName
        let path = "/api/satdump/image_lossless?pass=\(passEncoded)&folder=\(folderEncoded)&image=\(imageEncoded)"
        if let cached = BinaryCache.shared.cachedData(forPath: path) { return cached }
        let data = try await fetchData(path)
        BinaryCache.shared.store(data, forPath: path)
        return data
    }

    func fetchImageLightJPEG(passName: String, folderName: String, imageName: String, max: Int = 1280, quality: Int = 85) async throws -> Data {
        let passEncoded = passName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? passName
        let folderEncoded = folderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? folderName
        let imageEncoded = imageName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? imageName
        let path = "/api/satdump/image_light?pass=\(passEncoded)&folder=\(folderEncoded)&image=\(imageEncoded)&max=\(max)&format=jpeg&quality=\(quality)"
        if let cached = BinaryCache.shared.cachedData(forPath: path) { return cached }
        let data = try await fetchData(path)
        BinaryCache.shared.store(data, forPath: path)
        return data
    }

    func fetchImageWithLegend(passName: String, folderName: String, imageName: String, format: String = "jpeg", quality: Int = 90) async throws -> Data {
        let passEncoded = passName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? passName
        let folderEncoded = folderName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? folderName
        let imageEncoded = imageName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? imageName
        let path = "/api/satdump/image_legend?pass=\(passEncoded)&folder=\(folderEncoded)&image=\(imageEncoded)&format=\(format)&quality=\(quality)"
        if let cached = BinaryCache.shared.cachedData(forPath: path) { return cached }
        let data = try await fetchData(path)
        BinaryCache.shared.store(data, forPath: path)
        return data
    }

    // MARK: - Notifications

    func registerDeviceToken(token: String, deviceInfo: [String: Any]) async throws -> NotificationRegisterResponse {
        let path = "/api/notifications/register"
        var request = try makeRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "device_token": token,
            "device_info": deviceInfo
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(NotificationRegisterResponse.self, from: data)
    }

    func unregisterDeviceToken(token: String) async throws -> NotificationUnregisterResponse {
        let path = "/api/notifications/unregister"
        var request = try makeRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["device_token": token]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(NotificationUnregisterResponse.self, from: data)
    }

    func fetchNotifications() async throws -> NotificationListResponse {
        try await fetch("/api/notifications")
    }

    func fetchNotificationFeed(sinceId: Int = 0, limit: Int = 50) async throws -> NotificationFeedResponse {
        try await fetch("/api/notifications/feed?since_id=\(sinceId)&limit=\(limit)")
    }

    func ackNotifications(ids: [Int]) async throws -> NotificationAckResponse {
        let path = "/api/notifications/ack"
        var request = try makeRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["ids": ids])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(NotificationAckResponse.self, from: data)
    }

    // MARK: - Alerts (no auth)

    func fetchAlertRules() async throws -> [AlertRule] {
        try await fetch("/api/alerts/rules", requiresAuth: false)
    }

    func createAlertRule(_ rule: AlertRule) async throws -> AlertRule {
        var request = try makeRequest(path: "/api/alerts/rules", requiresAuth: false)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(rule)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(AlertRule.self, from: data)
    }

    func updateAlertRule(_ rule: AlertRule) async throws -> AlertRule {
        var request = try makeRequest(path: "/api/alerts/rules/\(rule.id)", requiresAuth: false)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(rule)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(AlertRule.self, from: data)
    }

    func deleteAlertRule(id: String) async throws {
        var request = try makeRequest(path: "/api/alerts/rules/\(id)", requiresAuth: false)
        request.httpMethod = "DELETE"

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    func fetchAlertTriggers(limit: Int = 20) async throws -> [AlertTrigger] {
        try await fetch("/api/alerts/triggers?limit=\(limit)", requiresAuth: false)
    }

    func acknowledgeAlertTrigger(id: String) async throws -> AlertTrigger {
        var request = try makeRequest(path: "/api/alerts/triggers/\(id)/ack", requiresAuth: false)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(AlertTrigger.self, from: data)
    }

    /// Alias for acknowledgeAlertTrigger for backward compatibility
    func acknowledgeAlert(id: String) async throws -> AlertTrigger {
        try await acknowledgeAlertTrigger(id: id)
    }

    // MARK: - Analytics (no auth, mock data)

    func fetchSystemAnalytics(period: String = "24h", interval: String = "5m") async throws -> SystemAnalytics {
        try await fetch("/api/analytics/system?period=\(period)&interval=\(interval)", requiresAuth: false)
    }

    func fetchADSBAnalytics(period: String = "24h") async throws -> ADSBAnalytics {
        try await fetch("/api/analytics/adsb?period=\(period)", requiresAuth: false)
    }

    func fetchSatelliteAnalytics(period: String = "7d") async throws -> SatelliteAnalytics {
        try await fetch("/api/analytics/satellite?period=\(period)", requiresAuth: false)
    }

    // MARK: - Flights (no auth, mock data)

    func searchFlights(_ request: FlightSearchRequest) async throws -> FlightSearchResponse {
        var components = URLComponents(string: "\(baseURL)/api/flights/search")
        components?.queryItems = buildQueryItems(from: request)

        guard let url = components?.url else { throw APIError.invalidURL }
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(FlightSearchResponse.self, from: data)
    }

    // MARK: - FlightAware (AeroAPI via MeuLab backend)

    enum FlightAwareBoardKind: String {
        case scheduledDepartures = "scheduled_departures"
        case scheduledArrivals = "scheduled_arrivals"
        case departures = "departures"
        case arrivals = "arrivals"
        case enroute = "enroute"
    }

    enum FlightAwareTrafficType: String {
        case airline = "Airline"
        case generalAviation = "General_Aviation"
    }

    func fetchFlightAwareAirportBoard(
        airport: String,
        kind: FlightAwareBoardKind,
        type: FlightAwareTrafficType = .airline,
        maxPages: Int = 1
    ) async throws -> FlightAwareAirportBoardResponse {
        let airportEncoded = airport.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? airport
        let path = "/api/flightaware/airport/board?airport=\(airportEncoded)&kind=\(kind.rawValue)&type=\(type.rawValue)&max_pages=\(maxPages)"
        return try await fetch(path)
    }

    func fetchFlightAwareFlight(ident: String, maxPages: Int = 1) async throws -> FlightAwareFlightResponse {
        let trimmed = ident.trimmingCharacters(in: .whitespacesAndNewlines)
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return try await fetch("/api/flightaware/flight?ident=\(encoded)&max_pages=\(maxPages)")
    }

    // MARK: - Remote (no auth)

    func executeRemoteCommand(_ command: RemoteCommand) async throws -> RemoteCommand {
        try await executeRemoteCommand(command: command.command, target: command.target ?? "", parameters: command.parameters?.value)
    }

    func executeRemoteCommand(command: CommandType, target: String, parameters: Any? = nil) async throws -> RemoteCommand {
        var request = try makeRequest(path: "/api/remote/execute", requiresAuth: false)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "command": command.rawValue,
            "target": target
        ]
        if let parameters = parameters {
            body["parameters"] = parameters
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 202 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(RemoteCommand.self, from: data)
    }

    func fetchRemoteCommands(limit: Int = 20) async throws -> [RemoteCommand] {
        try await fetch("/api/remote/commands?limit=\(limit)", requiresAuth: false)
    }

    func fetchRemoteCommand(id: String) async throws -> RemoteCommand {
        try await fetch("/api/remote/commands/\(id)", requiresAuth: false)
    }

    func cancelRemoteCommand(id: String) async throws -> RemoteCommand {
        var request = try makeRequest(path: "/api/remote/commands/\(id)/cancel", requiresAuth: false)
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(RemoteCommand.self, from: data)
    }

    // MARK: - Theme (no auth)

    func fetchThemeSettings() async throws -> ThemeSettings {
        try await fetch("/api/user/theme", requiresAuth: false)
    }

    func updateThemeSettings(_ settings: ThemeSettings) async throws -> ThemeSettings {
        var request = try makeRequest(path: "/api/user/theme", requiresAuth: false)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(settings)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(ThemeSettings.self, from: data)
    }

    func postThemeSettings(_ settings: ThemeSettings) async throws -> ThemeSettings {
        var request = try makeRequest(path: "/api/user/theme", requiresAuth: false)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(settings)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(ThemeSettings.self, from: data)
    }

    // MARK: - Open-Meteo Integration

    func fetchWeatherOpenMeteo(lat: Double, lon: Double) async throws -> WeatherData {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,is_day&hourly=temperature_2m,relative_humidity_2m,precipitation_probability,precipitation,weather_code,uv_index,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,uv_index_max,sunrise,sunset&timezone=auto"

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let openMeteo = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return try mapOpenMeteoToWeatherData(openMeteo, lat: lat, lon: lon)
    }

    private func mapOpenMeteoToWeatherData(_ response: OpenMeteoResponse, lat: Double, lon: Double) throws -> WeatherData {
        let current = response.current
        let daily = response.daily
        let hourly = response.hourly

        let locationName = String(format: "%.4f, %.4f", lat, lon)

        let currentWeather = CurrentWeather(
            tempC: Int(round(current.temperature_2m)),
            feelsLikeC: Int(round(current.apparent_temperature ?? current.temperature_2m)),
            humidity: current.relative_humidity_2m,
            windKmh: Int(round(current.wind_speed_10m)),
            windDir: LocationManager.compassDirection(from: Double(current.wind_direction_10m)),
            description: wmoDescription(code: current.weather_code),
            precipMm: current.precipitation,
            uvIndex: Int(round(response.hourly.uv_index.first ?? 0)),
            weatherCode: current.weather_code,
            isDaylight: current.is_day == 1
        )

        let todayWeather = TodayWeather(
            maxTempC: Int(round(daily.temperature_2m_max.first ?? 0)),
            minTempC: Int(round(daily.temperature_2m_min.first ?? 0)),
            rainChance: daily.precipitation_probability_max.first ?? 0,
            rainMm: daily.precipitation_sum.first ?? 0,
            uvIndex: Int(round(daily.uv_index_max.first ?? 0)),
            description: daily.weather_code.first.map { wmoDescription(code: $0) },
            sunrise: daily.sunrise?.first,
            sunset: daily.sunset?.first
        )

        var forecastDays: [ForecastDay] = []
        let count = min(daily.time.count, 11)
        for i in 1..<count {
            let day = ForecastDay(
                date: daily.time[i],
                maxTempC: Int(round(daily.temperature_2m_max[i])),
                minTempC: Int(round(daily.temperature_2m_min[i])),
                rainChance: daily.precipitation_probability_max[i],
                rainMm: daily.precipitation_sum[i],
                uvIndex: Int(round(daily.uv_index_max[i])),
                description: wmoDescription(code: daily.weather_code[i]),
                sunrise: value(daily.sunrise, at: i),
                sunset: value(daily.sunset, at: i)
            )
            forecastDays.append(day)
        }

        var hourlyPoints: [HourlyWeatherPoint] = []
        for i in hourly.time.indices {
            hourlyPoints.append(
                HourlyWeatherPoint(
                    time: hourly.time[i],
                    tempC: Int(round(hourly.temperature_2m[i])),
                    humidity: value(hourly.relative_humidity_2m, at: i),
                    rainChance: value(hourly.precipitation_probability, at: i) ?? 0,
                    rainMm: value(hourly.precipitation, at: i) ?? 0,
                    uvIndex: Int(round(value(hourly.uv_index, at: i) ?? 0)),
                    windKmh: value(hourly.wind_speed_10m, at: i).map { Int(round($0)) },
                    description: value(hourly.weather_code, at: i).map { wmoDescription(code: $0) }
                )
            )
        }

        return WeatherData(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            location: locationName,
            current: currentWeather,
            today: todayWeather,
            forecast: forecastDays,
            hourly: hourlyPoints
        )
    }

    private func value<T>(_ array: [T]?, at index: Int) -> T? {
        guard let array, array.indices.contains(index) else { return nil }
        return array[index]
    }

    private func wmoDescription(code: Int) -> String {
        switch code {
        case 0: return "Céu limpo"
        case 1, 2, 3: return "Parcialmente nublado"
        case 45, 48: return "Nevoeiro"
        case 51, 53, 55: return "Garoa"
        case 56, 57: return "Garoa congelante"
        case 61, 63, 65: return "Chuva"
        case 66, 67: return "Chuva congelante"
        case 71, 73, 75: return "Neve"
        case 77: return "Grãos de neve"
        case 80, 81, 82: return "Pancadas de chuva"
        case 85, 86: return "Pancadas de neve"
        case 95: return "Tempestade"
        case 96, 99: return "Tempestade com granizo"
        default: return "Desconhecido"
        }
    }

    // MARK: - AviationStack (Flight Routes)

    func fetchFlightRoute(flightIATA: String) async throws -> AviationStackFlightData? {
        if aviationStackKey == "SUA_KEY_AQUI" || aviationStackKey.isEmpty { return nil }

        let urlString = "\(aviationStackBaseURL)/flights?access_key=\(aviationStackKey)&flight_iata=\(flightIATA)&limit=1"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoded = try JSONDecoder().decode(AviationStackFlightResponse.self, from: data)
        return decoded.data.first
    }

    // MARK: - Export Data

    func exportData(_ request: ExportRequest) async throws -> Data {
        var components = URLComponents(string: "\(baseURL)/api/export")
        components?.queryItems = [
            URLQueryItem(name: "data_type", value: request.dataType.rawValue),
            URLQueryItem(name: "format", value: request.format.rawValue)
        ]

        if let from = request.dateFrom {
            components?.queryItems?.append(URLQueryItem(name: "date_from", value: from))
        }
        if let to = request.dateTo {
            components?.queryItems?.append(URLQueryItem(name: "date_to", value: to))
        }

        guard let url = components?.url else { throw APIError.invalidURL }
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(apiToken, forHTTPHeaderField: "X-API-Token")

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return data
    }

    // MARK: - Health Checks

    func runHealthCheck() async throws -> HealthCheckReport {
        var request = try makeRequest(path: "/api/health/check")
        request.httpMethod = "POST"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        return try JSONDecoder().decode(HealthCheckReport.self, from: data)
    }

    func fetchHealthReports(limit: Int = 10) async throws -> [HealthCheckReport] {
        try await fetch("/api/health/reports?limit=\(limit)")
    }

    // MARK: - Satellite Passes by Filter

    func fetchSatellitePassesByDateRange(from: String, to: String, page: Int = 1, limit: Int = 50) async throws -> PassesListPaginated {
        try await fetch("/api/satdump/passes_by_date?from=\(from)&to=\(to)&page=\(page)&limit=\(limit)")
    }

    func fetchSatellitePassesBySatellite(satellite: String, page: Int = 1, limit: Int = 50) async throws -> PassesListPaginated {
        try await fetch("/api/satdump/passes_by_satellite?satellite=\(satellite)&page=\(page)&limit=\(limit)")
    }

    // MARK: - Helper Methods

    private func buildQueryItems(from request: FlightSearchRequest) -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        if let query = request.query { items.append(URLQueryItem(name: "query", value: query)) }
        if let flightNumber = request.flightNumber { items.append(URLQueryItem(name: "flightNumber", value: flightNumber)) }
        if let registration = request.registration { items.append(URLQueryItem(name: "registration", value: registration)) }
        if let aircraftType = request.aircraftType { items.append(URLQueryItem(name: "aircraftType", value: aircraftType)) }
        if let origin = request.origin { items.append(URLQueryItem(name: "origin", value: origin)) }
        if let destination = request.destination { items.append(URLQueryItem(name: "destination", value: destination)) }
        if let altitudeMin = request.altitudeMin { items.append(URLQueryItem(name: "altitudeMin", value: "\(altitudeMin)")) }
        if let altitudeMax = request.altitudeMax { items.append(URLQueryItem(name: "altitudeMax", value: "\(altitudeMax)")) }
        if let limit = request.limit { items.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let offset = request.offset { items.append(URLQueryItem(name: "offset", value: "\(offset)")) }

        return items
    }
}
