import Foundation

// MARK: - Remote Radio API Client

/// HTTP client for the remote radio backend.
/// Reuses the app's existing auth token and base URL from NetworkEnvironment.
actor RemoteRadioAPIClient {
    static let shared = RemoteRadioAPIClient()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    // MARK: - Helpers

    private var baseURL: String {
        get async {
            await MainActor.run { NetworkEnvironment.shared.apiBaseURL }
        }
    }

    private var apiToken: String {
        let token = Secrets.apiToken
        return token.isEmpty ? Secrets.apiTokenAlternative : token
    }

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) async throws
        -> URLRequest
    {
        let base = await baseURL
        guard let url = URL(string: "\(base)\(path)") else {
            throw RemoteRadioError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if !apiToken.isEmpty {
            request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
            request.setValue(apiToken, forHTTPHeaderField: "X-API-Token")
        }
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw RemoteRadioError.networkUnavailable
            case .timedOut:
                throw RemoteRadioError.timeout
            case .cannotConnectToHost, .cannotFindHost:
                throw RemoteRadioError.hostUnreachable
            default:
                throw RemoteRadioError.networkError(urlError.localizedDescription)
            }
        }

        guard let http = response as? HTTPURLResponse else {
            throw RemoteRadioError.unknown
        }

        switch http.statusCode {
        case 200...299:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            throw RemoteRadioError.authFailed
        case 403:
            throw RemoteRadioError.disabled
        case 409:
            throw RemoteRadioError.tunerBusy
        case 404:
            throw RemoteRadioError.sessionNotFound
        case 502:
            throw RemoteRadioError.backendOffline
        case 503:
            // Try to parse error body for specific error codes
            if let body = try? JSONDecoder().decode(RemoteRadioOKResponse.self, from: data) {
                if body.code == "dongle_missing" {
                    throw RemoteRadioError.dongleMissing
                }
                if let msg = body.error ?? body.message {
                    throw RemoteRadioError.serviceUnavailable(msg)
                }
            }
            // 503 with HTML body = likely Cloudflare or reverse proxy
            if let bodyStr = String(data: data, encoding: .utf8),
                bodyStr.contains("<html") || bodyStr.contains("cloudflare")
            {
                throw RemoteRadioError.backendOffline
            }
            throw RemoteRadioError.serviceUnavailable(nil)
        case 504:
            throw RemoteRadioError.backendOffline
        default:
            throw RemoteRadioError.serverError(http.statusCode)
        }
    }

    // MARK: - Endpoints

    /// GET /api/remote-radio/status
    func fetchStatus() async throws -> RemoteRadioStatus {
        let request = try await makeRequest(path: "/api/remote-radio/status")
        return try await perform(request)
    }

    /// POST /api/remote-radio/session
    func createSession() async throws -> RemoteRadioSession {
        let body = try JSONEncoder().encode(["clientName": "ios-app"])
        let request = try await makeRequest(
            path: "/api/remote-radio/session", method: "POST", body: body)
        return try await perform(request)
    }

    /// GET /api/remote-radio/session/{id}
    func getSession(id: String) async throws -> RemoteRadioSession {
        let request = try await makeRequest(path: "/api/remote-radio/session/\(id)")
        return try await perform(request)
    }

    /// DELETE /api/remote-radio/session/{id}
    func deleteSession(id: String) async throws {
        let request = try await makeRequest(
            path: "/api/remote-radio/session/\(id)", method: "DELETE")
        let _: RemoteRadioOKResponse = try await perform(request)
    }

    /// POST /api/remote-radio/session/{id}/offer
    func sendOffer(sessionId: String, sdp: String) async throws -> RemoteRadioAnswer {
        let payload = SDPPayload(type: "offer", sdp: sdp)
        let body = try JSONEncoder().encode(payload)
        let request = try await makeRequest(
            path: "/api/remote-radio/session/\(sessionId)/offer", method: "POST", body: body)
        return try await perform(request)
    }

    /// POST /api/remote-radio/session/{id}/ice
    func sendICECandidate(sessionId: String, candidate: String, sdpMid: String, sdpMLineIndex: Int)
        async throws
    {
        let payload: [String: Any] = [
            "candidate": candidate,
            "sdpMid": sdpMid,
            "sdpMLineIndex": sdpMLineIndex,
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = try await makeRequest(
            path: "/api/remote-radio/session/\(sessionId)/ice", method: "POST", body: body)
        let _: RemoteRadioOKResponse = try await perform(request)
    }

    /// POST /api/remote-radio/session/{id}/tune
    func tune(
        sessionId: String, freqHz: Int, mode: String, gain: TuneRequest.GainValue, squelch: Int
    ) async throws {
        let payload = TuneRequest(freqHz: freqHz, mode: mode, gain: gain, squelch: squelch)
        let body = try JSONEncoder().encode(payload)
        let request = try await makeRequest(
            path: "/api/remote-radio/session/\(sessionId)/tune", method: "POST", body: body)
        let _: RemoteRadioOKResponse = try await perform(request)
    }

    /// POST /api/remote-radio/session/{id}/start
    func startRadio(sessionId: String) async throws {
        let request = try await makeRequest(
            path: "/api/remote-radio/session/\(sessionId)/start", method: "POST")
        let _: RemoteRadioOKResponse = try await perform(request)
    }

    /// POST /api/remote-radio/session/{id}/stop
    func stopRadio(sessionId: String) async throws {
        let request = try await makeRequest(
            path: "/api/remote-radio/session/\(sessionId)/stop", method: "POST")
        let _: RemoteRadioOKResponse = try await perform(request)
    }

    /// Build WebSocket URL for a session
    func wsURL(sessionId: String) async -> URL? {
        let base = await baseURL
        let wsBase =
            base
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        return URL(string: "\(wsBase)/api/remote-radio/session/\(sessionId)/ws")
    }

    // MARK: - OpenWebRX Endpoints

    /// GET /api/openwebrx/status
    func openwebrxStatus() async throws -> OpenWebRXStatusResponse {
        let request = try await makeRequest(path: "/api/openwebrx/status")
        return try await perform(request)
    }

    /// POST /api/openwebrx/connect
    func openwebrxConnect() async throws {
        let request = try await makeRequest(path: "/api/openwebrx/connect", method: "POST")
        let _: RemoteRadioOKResponse = try await perform(request)
    }

    /// POST /api/openwebrx/tune  { "freqHz": int, "mod": "am"|"nfm"|"wfm" }
    func openwebrxTune(freqHz: Int, modulation: String) async throws {
        let payload: [String: Any] = ["freqHz": freqHz, "mod": modulation.lowercased()]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let request = try await makeRequest(path: "/api/openwebrx/tune", method: "POST", body: body)
        let _: RemoteRadioOKResponse = try await perform(request)
    }

    /// Build URL for the WAV audio stream
    func openwebrxAudioWavURL() async -> URL? {
        let base = await baseURL
        return URL(string: "\(base)/api/openwebrx/audio.wav")
    }

    /// Build authenticated URLRequest for the WAV audio stream
    func openwebrxAudioWavRequest() async -> URLRequest? {
        guard let url = await openwebrxAudioWavURL() else { return nil }
        var request = URLRequest(url: url)
        if !apiToken.isEmpty {
            request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
            request.setValue(apiToken, forHTTPHeaderField: "X-API-Token")
        }
        return request
    }
}

// MARK: - Errors

enum RemoteRadioError: Error, LocalizedError {
    case invalidURL
    case authFailed
    case disabled
    case tunerBusy
    case sessionNotFound
    case dongleMissing
    case signalingFailed(String)
    case webrtcFailed(String)
    case serverError(Int)
    case backendOffline
    case serviceUnavailable(String?)
    case networkUnavailable
    case timeout
    case hostUnreachable
    case networkError(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .authFailed:
            return "Autenticação falhou — verifique o token"
        case .disabled:
            return "Rádio remoto desabilitado no servidor"
        case .tunerBusy:
            return "Tuner já em uso por outra sessão"
        case .sessionNotFound:
            return "Sessão não encontrada"
        case .dongleMissing:
            return "Dongle RTL-SDR não detectado — conecte o dongle ao Raspberry Pi"
        case .signalingFailed(let msg):
            return "Signaling: \(msg)"
        case .webrtcFailed(let msg):
            return "WebRTC: \(msg)"
        case .serverError(let code):
            return "Erro do servidor (\(code))"
        case .backendOffline:
            return "Backend indisponível — verifique se o serviço está ativo no Raspberry Pi"
        case .serviceUnavailable(let detail):
            if let detail {
                return "Serviço indisponível: \(detail)"
            }
            return "Serviço SDR indisponível — verifique se o backend está rodando"
        case .networkUnavailable:
            return "Sem conexão de rede"
        case .timeout:
            return "Tempo esgotado — servidor não respondeu"
        case .hostUnreachable:
            return "Servidor inalcançável — verifique a rede"
        case .networkError(let msg):
            return "Erro de rede: \(msg)"
        case .unknown:
            return "Erro desconhecido"
        }
    }

    /// Whether this error indicates the backend is not running/reachable
    var isBackendUnavailable: Bool {
        switch self {
        case .backendOffline, .serviceUnavailable, .hostUnreachable, .timeout:
            return true
        case .serverError(let code) where code >= 500:
            return true
        default:
            return false
        }
    }
}
