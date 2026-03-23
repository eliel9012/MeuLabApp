import Foundation
import Network
import Combine

/// Detects whether the device is on the local network and provides
/// the fastest base URLs (local IP vs Cloudflare tunnel).
@MainActor
final class NetworkEnvironment: ObservableObject {
    static let shared = NetworkEnvironment()

    // MARK: - Published URLs

    @Published private(set) var apiBaseURL: String = "https://app.meulab.fun"

    /// True when using direct local IP (fast path)
    @Published private(set) var isLocal: Bool = false

    // MARK: - Constants

    private let localAPIBase = "http://10.0.1.50:8090"
    private let remoteAPIBase = "https://app.meulab.fun"

    // MARK: - Private

    private let monitor = NWPathMonitor()
    private let probeSession: URLSession
    private var monitorStarted = false

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.5
        config.timeoutIntervalForResource = 2
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.probeSession = URLSession(configuration: config)

        startMonitoring()
    }

    // MARK: - Network Monitoring

    private func startMonitoring() {
        guard !monitorStarted else { return }
        monitorStarted = true

        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in
                await self?.probeLocal()
            }
        }
        monitor.start(queue: .global(qos: .utility))

        // Also probe immediately on launch
        Task {
            await probeLocal()
        }
    }

    /// Quickly probe whether the local API is reachable.
    private func probeLocal() async {
        let probeURL = URL(string: "\(localAPIBase)/api/adsb/summary")!
        var request = URLRequest(url: probeURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.5
        // Add auth token
        let token = Secrets.apiToken.isEmpty ? Secrets.apiTokenAlternative : Secrets.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await probeSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                switchToLocal()
                return
            }
        } catch {
            // probe failed – not on local network
        }
        switchToRemote()
    }

    private func switchToLocal() {
        guard !isLocal else { return }
        isLocal = true
        apiBaseURL = localAPIBase
        pushChanges()
    }

    private func switchToRemote() {
        guard isLocal || apiBaseURL == remoteAPIBase else {
            // Already remote on first launch
            isLocal = false
            return
        }
        isLocal = false
        apiBaseURL = remoteAPIBase
        pushChanges()
    }

    /// Push current URL to APIService.
    private func pushChanges() {
        let url = apiBaseURL
        Task {
            await APIService.shared.updateBaseURL(url)
        }
    }
}
