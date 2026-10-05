import Foundation
import UIKit

/// Radar ao vivo via WebSocket (`/api/ws/aircraft`).
///
/// Protocolo (servidor aiohttp no Pi):
/// - Auth: header `Authorization: Bearer <token>` (401 antes do upgrade se inválido).
/// - Ao conectar: `{"type":"connected","interval_s":5}`.
/// - A cada ~5s: `{"type":"aircraft","count":N,"items":[...]}` — snapshot completo,
///   mesmos itens de `GET /api/adsb/aircraft` (top 100 por distância).
/// - Servidor faz heartbeat de 30s; cliente envia ping próprio a cada 20s.
///
/// Reconecta com backoff exponencial (1s → 30s). Para ao ir para background.
@MainActor
final class AircraftStream {
    /// Chamado a cada snapshot recebido: (itens, total do servidor).
    var onAircraft: (([Aircraft], Int) -> Void)?

    private(set) var isConnected = false
    private(set) var lastMessageAt: Date?

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var backgroundObserver: NSObjectProtocol?

    private var wantsRunning = false
    private var backoff: TimeInterval = 1
    private let maxBackoff: TimeInterval = 30
    private let pingInterval: UInt64 = 20_000_000_000
    /// Incrementa a cada conexão para descartar callbacks de sockets antigos.
    private var generation = 0

    private let token: String = {
        let primary = Secrets.apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
        return primary.isEmpty
            ? Secrets.apiTokenAlternative.trimmingCharacters(in: .whitespacesAndNewlines)
            : primary
    }()

    private static let url: URL? = {
        guard var comps = URLComponents(string: Secrets.apiBaseURL) else { return nil }
        switch comps.scheme?.lowercased() {
        case "https": comps.scheme = "wss"
        case "http": comps.scheme = "ws"
        default: break
        }
        let base = comps.path.hasSuffix("/") ? String(comps.path.dropLast()) : comps.path
        comps.path = base + "/api/ws/aircraft"
        return comps.url
    }()

    init() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stop() }
        }
    }

    /// Saudável = conectado e recebeu mensagem há menos de `maxSilence` segundos.
    func isHealthy(maxSilence: TimeInterval, now: Date = Date()) -> Bool {
        guard isConnected, let lastMessageAt else { return false }
        return now.timeIntervalSince(lastMessageAt) < maxSilence
    }

    func start() {
        guard !wantsRunning else { return }
        guard !token.isEmpty, Self.url != nil else { return }
        wantsRunning = true
        backoff = 1
        connect()
    }

    func stop() {
        wantsRunning = false
        reconnectTask?.cancel()
        reconnectTask = nil
        tearDown()
    }

    // MARK: - Connection

    private func connect() {
        guard wantsRunning, let url = Self.url else { return }
        tearDown()
        generation += 1
        let gen = generation

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        if session == nil {
            let config = URLSessionConfiguration.default
            config.waitsForConnectivity = false
            session = URLSession(configuration: config)
        }
        guard let session else { return }
        let ws = session.webSocketTask(with: request)
        ws.maximumMessageSize = 4 * 1024 * 1024
        task = ws
        ws.resume()

        receiveTask = Task { [weak self] in
            await self?.receiveLoop(ws, generation: gen)
        }
        pingTask = Task { [weak self] in
            await self?.pingLoop(ws, generation: gen)
        }
    }

    private func tearDown() {
        receiveTask?.cancel()
        receiveTask = nil
        pingTask?.cancel()
        pingTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    private func receiveLoop(_ ws: URLSessionWebSocketTask, generation gen: Int) async {
        while !Task.isCancelled {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await ws.receive()
            } catch {
                handleFailure(generation: gen)
                return
            }
            guard gen == generation else { return }

            let data: Data?
            switch message {
            case .data(let d): data = d
            case .string(let s): data = s.data(using: .utf8)
            @unknown default: data = nil
            }
            guard let data else { continue }
            handle(data)
        }
    }

    private func pingLoop(_ ws: URLSessionWebSocketTask, generation gen: Int) async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: pingInterval)
            guard !Task.isCancelled, gen == generation else { return }
            let ok = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                // sendPing can call its handler twice (the pong, then an error when the
                // task is cancelled); resuming a continuation twice crashes the app.
                let once = ResumeOnce()
                ws.sendPing { error in
                    if once.claim() { cont.resume(returning: error == nil) }
                }
            }
            if !ok {
                handleFailure(generation: gen)
                return
            }
        }
    }

    private func handle(_ data: Data) {
        let envelope: StreamMessage
        do {
            envelope = try JSONDecoder().decode(StreamMessage.self, from: data)
        } catch {
            return
        }
        isConnected = true
        lastMessageAt = Date()
        backoff = 1

        if envelope.type == "aircraft", let items = envelope.items {
            onAircraft?(items, envelope.count ?? items.count)
        }
    }

    private func handleFailure(generation gen: Int) {
        guard gen == generation else { return }
        tearDown()
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard wantsRunning, reconnectTask == nil else { return }
        let delay = backoff
        backoff = min(backoff * 2, maxBackoff)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.reconnectTask = nil
            self?.connect()
        }
    }
}

private struct StreamMessage: Decodable {
    let type: String
    let count: Int?
    let items: [Aircraft]?
}

/// Lets exactly one caller through, from any thread.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
