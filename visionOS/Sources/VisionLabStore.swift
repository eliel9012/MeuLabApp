import AVFoundation
import Foundation
import Observation

enum VisionSection: String, CaseIterable, Identifiable {
    case radar = "ADS-B"
    case trip = "Viagem"
    case analytics = "Analytics"
    case alerts = "Alertas"
    case system = "Sistema"
    case infrastructure = "Infraestrutura"
    case radio = "Rádio"
    case weather = "Clima"
    case acars = "ACARS"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .radar: "airplane"
        case .trip: "suitcase.rolling.fill"
        case .analytics: "chart.xyaxis.line"
        case .alerts: "bell.badge"
        case .system: "cpu"
        case .infrastructure: "server.rack"
        case .radio: "radio"
        case .weather: "cloud.sun"
        case .acars: "waveform.path"
        }
    }
}

private enum VisionAPIError: LocalizedError {
    case missingConfiguration, http(Int)
    var errorDescription: String? {
        switch self {
        case .missingConfiguration: "Configuração da API ausente. Adicione Secrets.plist ao projeto."
        case .http(let code): "API respondeu HTTP \(code)."
        }
    }
}

struct VisionAPIClient {
    let baseURL: URL
    let token: String

    init() throws {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let values = NSDictionary(contentsOfFile: path) as? [String: Any],
              let base = values["API_BASE_URL"] as? String,
              let url = URL(string: base),
              let token = [values["API_TOKEN"] as? String, values["MEULAB_API_TOKEN"] as? String]
                .compactMap({ $0 }).first(where: { !$0.isEmpty }) else { throw VisionAPIError.missingConfiguration }
        baseURL = url
        self.token = token
    }

    func fetch<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        guard let url = URL(string: "/\(path)", relativeTo: baseURL)?.absoluteURL else {
            throw VisionAPIError.missingConfiguration
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(token, forHTTPHeaderField: "X-API-Token")
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw VisionAPIError.http(0) }
        guard (200...299).contains(http.statusCode) else { throw VisionAPIError.http(http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func post<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        guard let url = URL(string: "/\(path)", relativeTo: baseURL)?.absoluteURL else {
            throw VisionAPIError.missingConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(token, forHTTPHeaderField: "X-API-Token")
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw VisionAPIError.http(0) }
        guard (200...299).contains(http.statusCode) else { throw VisionAPIError.http(http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func fetchText(_ path: String, query: [URLQueryItem]) async throws -> String {
        guard let base = URL(string: "/\(path)", relativeTo: baseURL)?.absoluteURL,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw VisionAPIError.missingConfiguration
        }
        components.queryItems = query
        guard let url = components.url else { throw VisionAPIError.missingConfiguration }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(token, forHTTPHeaderField: "X-API-Token")
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw VisionAPIError.http(0) }
        guard (200...299).contains(http.statusCode) else { throw VisionAPIError.http(http.statusCode) }
        return String(decoding: data, as: UTF8.self)
    }
}

struct VisionProcessList: Decodable { let items: [VisionProcess] }
struct VisionProcess: Decodable, Identifiable {
    let pid: Int
    let command: String
    let cpuPercent: Double
    let memPercent: Double
    var id: Int { pid }
    enum CodingKeys: String, CodingKey {
        case pid, command
        case cpuPercent = "cpu_percent", memPercent = "mem_percent"
    }
}
struct VisionPartitionList: Decodable { let partitions: [VisionPartition] }
struct VisionPartition: Decodable, Identifiable {
    let mount: String
    let filesystem: String
    let usedPercent: String
    var id: String { mount }
    enum CodingKeys: String, CodingKey { case mount, filesystem, usedPercent = "used_percent" }
}
struct VisionNetworkStats: Decodable { let interfaces: [VisionNetworkInterface] }
struct VisionNetworkInterface: Decodable, Identifiable {
    let iface: String
    let rxBytes: Int64
    let txBytes: Int64
    var id: String { iface }
    enum CodingKeys: String, CodingKey { case iface, rxBytes = "rx_bytes", txBytes = "tx_bytes" }
}
struct VisionACARSSummary: Decodable {
    let today: Today
    let lastHour: Int
    struct Today: Decodable { let messages: Int; let flights: Int; let aircraft: Int }
    enum CodingKeys: String, CodingKey { case today, lastHour = "last_hour" }
}
struct VisionACARSList: Decodable { let messages: [VisionACARSMessage] }
struct VisionACARSMessage: Decodable, Identifiable {
    let id: Int
    let flight: String?
    let tail: String?
    let label: String?
    let text: String?
    let time: String
}

@MainActor @Observable
final class VisionLabStore {
    var selection: VisionSection = .radar
    var system: SystemStatus?
    var processes: [VisionProcess] = []
    var partitions: [VisionPartition] = []
    var interfaces: [VisionNetworkInterface] = []
    var radio: NowPlaying?
    var radioHistory: [NowPlaying] = []
    var weather: WeatherData?
    var acars: VisionACARSSummary?
    var acarsMessages: [VisionACARSMessage] = []
    var error: String?
    var updatedAt: Date?
    var isLoading = false
    var isPlaying = false

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var player: AVPlayer?

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                do { try await Task.sleep(for: .seconds(self.selection == .weather ? 120 : 20)) }
                catch { break }
            }
        }
    }

    func stop() { pollTask?.cancel(); pollTask = nil }

    func select(_ section: VisionSection) {
        selection = section
        Task { await refresh() }
    }

    func refresh() async {
        guard selection != .radar, selection != .trip, selection != .analytics,
              selection != .alerts else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let api = try VisionAPIClient()
            switch selection {
            case .radar: break
            case .trip: break
            case .analytics: break
            case .alerts: break
            case .system:
                system = try await api.fetch("api/system/status")
            case .infrastructure:
                async let status: SystemStatus = api.fetch("api/system/status")
                async let processList: VisionProcessList = api.fetch("api/system/processes?limit=8")
                async let partitionList: VisionPartitionList = api.fetch("api/system/partitions")
                async let network: VisionNetworkStats = api.fetch("api/system/network")
                (system, processes, partitions, interfaces) = try await (status, processList.items, partitionList.partitions, network.interfaces)
            case .radio:
                async let now: NowPlaying = api.fetch("api/radio/now-playing")
                async let history: RadioHistoryResponse = api.fetch("api/radio/history?limit=40")
                (radio, radioHistory) = try await (now, history.items)
            case .weather:
                weather = try await api.fetch("api/weather/current")
            case .acars:
                async let summary: VisionACARSSummary = api.fetch("api/acars/summary")
                async let messages: VisionACARSList = api.fetch("api/acars/messages?limit=12")
                (acars, acarsMessages) = try await (summary, messages.messages)
            }
            error = nil
            updatedAt = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleRadio() {
        if isPlaying {
            player?.pause()
            isPlaying = false
        } else if let stream = radio?.streamUrl, let url = URL(string: stream) {
            player = AVPlayer(url: url)
            player?.play()
            isPlaying = true
        }
    }
}
