import AVFoundation
import Combine
import Foundation

// MARK: - WS Audio Player (S16LE PCM → AVAudioEngine)

private final class WSAudioPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let pcmFormat: AVAudioFormat

    init() {
        pcmFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48_000,
            channels: 1,
            interleaved: false)!
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: pcmFormat)
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
        try engine.start()
        playerNode.play()
    }

    /// Feed raw S16LE mono PCM data from WebSocket
    func feedPCM(_ data: Data) {
        let sampleCount = data.count / 2  // 16-bit = 2 bytes per sample
        guard sampleCount > 0,
            let buffer = AVAudioPCMBuffer(
                pcmFormat: pcmFormat,
                frameCapacity: AVAudioFrameCount(sampleCount))
        else { return }

        buffer.frameLength = AVAudioFrameCount(sampleCount)
        let floatPtr = buffer.floatChannelData![0]

        data.withUnsafeBytes { raw in
            let s16 = raw.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                floatPtr[i] = Float(s16[i]) / 32768.0
            }
        }

        playerNode.scheduleBuffer(buffer)
    }

    func stop() {
        playerNode.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - OpenWebRX WAV Stream Player

/// Streams audio from /api/openwebrx/audio.wav (infinite WAV over HTTP).
/// Parses the 44-byte WAV header to discover sample rate, then feeds S16LE
/// PCM chunks to AVAudioEngine identically to WSAudioPlayer.
private final class OpenWebRXAudioStreamer: NSObject, URLSessionDataDelegate {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var pcmFormat: AVAudioFormat
    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var headerBuffer = Data()
    private var headerParsed = false
    private var wavSampleRate: Double = 12_000  // default, overridden by WAV header

    var onFrameReceived: (() -> Void)?

    override init() {
        pcmFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 12_000,
            channels: 1,
            interleaved: false)!
        super.init()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: pcmFormat)
    }

    func start(request: URLRequest) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)

        headerBuffer = Data()
        headerParsed = false

        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        dataTask = session?.dataTask(with: request)
        dataTask?.resume()
    }

    func stop() {
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
        playerNode.stop()
        engine.stop()
        headerParsed = false
        headerBuffer = Data()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if !headerParsed {
            headerBuffer.append(data)
            guard headerBuffer.count >= 44 else { return }

            // Parse WAV header: bytes 24-27 = sample rate (UInt32 LE)
            let sr = headerBuffer.withUnsafeBytes { raw -> UInt32 in
                raw.load(fromByteOffset: 24, as: UInt32.self)
            }
            wavSampleRate = Double(sr)

            // Reconfigure engine with actual sample rate
            engine.disconnectNodeOutput(playerNode)
            pcmFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: wavSampleRate,
                channels: 1,
                interleaved: false)!
            engine.connect(playerNode, to: engine.mainMixerNode, format: pcmFormat)
            do {
                try engine.start()
                playerNode.play()
            } catch {
                return
            }

            // Feed remaining bytes after header as PCM
            headerParsed = true
            let remaining = headerBuffer.suffix(from: 44)
            if !remaining.isEmpty {
                feedS16LE(remaining)
            }
            headerBuffer = Data()
        } else {
            feedS16LE(data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
    {
        // Stream ended or errored — caller handles reconnect logic if needed
    }

    // MARK: - PCM conversion

    private func feedS16LE(_ data: Data) {
        let sampleCount = data.count / 2
        guard sampleCount > 0,
            let buffer = AVAudioPCMBuffer(
                pcmFormat: pcmFormat,
                frameCapacity: AVAudioFrameCount(sampleCount))
        else { return }

        buffer.frameLength = AVAudioFrameCount(sampleCount)
        let floatPtr = buffer.floatChannelData![0]

        data.withUnsafeBytes { raw in
            let s16 = raw.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                floatPtr[i] = Float(s16[i]) / 32768.0
            }
        }

        playerNode.scheduleBuffer(buffer)
        onFrameReceived?()
    }
}

// MARK: - Remote Radio ViewModel

@MainActor
final class RemoteRadioViewModel: ObservableObject {

    // MARK: - Published State

    @Published var connectionState: RemoteRadioConnectionState = .disconnected
    @Published var freqHz: Int = 118_300_000  // default: Aviation 118.3 MHz
    @Published var mode: RadioMode = .am
    @Published var gain: TuneRequest.GainValue = .auto
    @Published var squelch: Int = 0
    @Published var backendType: String = ""
    @Published var rtlSerial: String = ""
    @Published var errorMessage: String?
    @Published var statusText: String = "Idle"
    @Published var isAudioPlaying: Bool = false
    @Published var audioFrameCount: Int = 0
    @Published var serverStatus: RemoteRadioStatus?
    @Published var backendAvailable: Bool? = nil  // nil = unknown, true/false = checked
    @Published var donglePresent: Bool? = nil

    // MARK: - Frequency display helpers

    var freqMHz: Double {
        Double(freqHz) / 1_000_000.0
    }

    var freqkHz: Double {
        Double(freqHz) / 1_000.0
    }

    var freqDisplayString: String {
        if mode == .wfm {
            return String(format: "%.1f", freqMHz)
        } else {
            // AM/NFM: show in kHz (e.g. 118300.0)
            let khz = freqkHz
            if khz.truncatingRemainder(dividingBy: 1.0) == 0 {
                return String(format: "%.0f", khz)
            } else {
                return String(format: "%.1f", khz)
            }
        }
    }

    var freqUnitLabel: String {
        mode == .wfm ? "MHz" : "kHz"
    }

    // MARK: - Private

    private let apiClient = RemoteRadioAPIClient.shared
    private let audioPlayer = WSAudioPlayer()
    private let openwebrxStreamer = OpenWebRXAudioStreamer()
    private var sessionId: String?
    private var wsTask: URLSessionWebSocketTask?
    private var heartbeatTimer: Timer?
    private var isCleaningUp = false
    private var tuneTask: Task<Void, Never>?

    // MARK: - Lifecycle

    /// Connect: auto-detects backend from server status and uses the appropriate flow.
    func connect() async {
        guard connectionState == .disconnected || connectionState.isError else { return }

        connectionState = .connecting
        errorMessage = nil
        statusText = "Conectando…"
        audioFrameCount = 0

        // 1. Fetch status to discover backend type
        do {
            let status = try await apiClient.fetchStatus()
            serverStatus = status
            backendType = status.backend ?? "rtl"
        } catch {
            // If status fetch fails, try RTL-SDR flow as default
            backendType = "rtl"
        }

        if backendType == "openwebrx" {
            await connectOpenWebRX()
        } else {
            await connectRemoteRadio()
        }
    }

    /// RTL-SDR connect flow: create session → start WS → subscribe audio → tune → start radio → play audio
    private func connectRemoteRadio() async {
        do {
            // 1. Create session (with 409 stale-session recovery)
            let session: RemoteRadioSession
            do {
                session = try await apiClient.createSession()
            } catch RemoteRadioError.tunerBusy {
                // Stale session from a previous crash — force-close it and retry once
                if let staleId = try? await apiClient.fetchStatus().activeSessionId {
                    try? await apiClient.deleteSession(id: staleId)
                }
                session = try await apiClient.createSession()
            }
            sessionId = session.sessionId
            backendType = session.backend
            rtlSerial = session.rtlSerial ?? ""

            // 2. Start WebSocket for heartbeat, events, and audio
            await startWebSocket(sessionId: session.sessionId)

            // 3. Subscribe to audio stream over WS
            try await wsTask?.send(.string(#"{"type":"audio_subscribe"}"#))

            // 4. Tune and start the radio
            try await apiClient.tune(
                sessionId: session.sessionId,
                freqHz: freqHz,
                mode: mode.rawValue,
                gain: gain,
                squelch: squelch
            )
            try await apiClient.startRadio(sessionId: session.sessionId)

            // 5. Start audio playback engine
            try audioPlayer.start()
            isAudioPlaying = true

            connectionState = .running
            statusText = "No Ar"

        } catch {
            // Clean up on any failure
            audioPlayer.stop()
            isAudioPlaying = false
            stopWebSocket()
            if let sid = sessionId {
                try? await apiClient.deleteSession(id: sid)
                sessionId = nil
            }
            let msg =
                (error as? RemoteRadioError)?.localizedDescription ?? error.localizedDescription
            connectionState = .error(msg)
            errorMessage = msg
            statusText = "Erro"
        }
    }

    /// OpenWebRX connect flow: tune DSP to start audio, then stream audio.wav
    private func connectOpenWebRX() async {
        do {
            // 1. Tune to start DSP processing (this triggers audio frames from OpenWebRX)
            try await apiClient.openwebrxTune(freqHz: freqHz, modulation: mode.rawValue)

            // 2. Start streaming audio.wav
            guard let request = await apiClient.openwebrxAudioWavRequest() else {
                throw RemoteRadioError.invalidURL
            }

            openwebrxStreamer.onFrameReceived = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.audioFrameCount += 1
                }
            }
            try openwebrxStreamer.start(request: request)
            isAudioPlaying = true

            connectionState = .running
            statusText = "No Ar"

        } catch {
            openwebrxStreamer.stop()
            isAudioPlaying = false
            let msg =
                (error as? RemoteRadioError)?.localizedDescription ?? error.localizedDescription
            connectionState = .error(msg)
            errorMessage = msg
            statusText = "Erro"
        }
    }

    /// Disconnect and clean up everything
    func disconnect() async {
        guard !isCleaningUp else { return }
        isCleaningUp = true

        // Cancel pending tune
        tuneTask?.cancel()
        tuneTask = nil

        // Stop audio playback
        audioPlayer.stop()
        openwebrxStreamer.stop()
        isAudioPlaying = false

        // RTL-SDR cleanup
        if backendType != "openwebrx" {
            if connectionState == .running, let sid = sessionId {
                try? await apiClient.stopRadio(sessionId: sid)
            }
            try? await wsTask?.send(.string(#"{"type":"audio_unsubscribe"}"#))
            stopWebSocket()
            if let sid = sessionId {
                try? await apiClient.deleteSession(id: sid)
                sessionId = nil
            }
        }

        connectionState = .disconnected
        statusText = "Idle"
        isCleaningUp = false
    }

    // MARK: - Radio Controls

    /// Tune to a new frequency/mode (while running) — debounced 300ms
    func tune() async {
        tuneTask?.cancel()
        let freq = freqHz
        let m = mode.rawValue
        let g = gain
        let sq = squelch
        let backend = backendType
        tuneTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms debounce
            guard !Task.isCancelled else { return }
            do {
                if backend == "openwebrx" {
                    try await apiClient.openwebrxTune(freqHz: freq, modulation: m)
                } else {
                    guard let sid = sessionId else { return }
                    try await apiClient.tune(
                        sessionId: sid,
                        freqHz: freq,
                        mode: m,
                        gain: g,
                        squelch: sq
                    )
                }
            } catch let error as RemoteRadioError {
                errorMessage = error.localizedDescription
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Apply a preset
    func applyPreset(_ preset: RadioPreset) async {
        freqHz = preset.freqHz
        mode = preset.mode
        if connectionState == .running {
            await tune()
        }
    }

    /// Step frequency by delta Hz
    func stepFrequency(by deltaHz: Int) async {
        freqHz = max(24_000_000, min(1_766_000_000, freqHz + deltaHz))
        if connectionState == .running {
            await tune()
        }
    }

    /// Fetch server status and update availability
    func fetchStatus() async {
        do {
            let status = try await apiClient.fetchStatus()
            serverStatus = status
            backendAvailable = true
            donglePresent = status.donglePresent

            // OpenWebRX backend has no dongle concept — treat as available
            if status.backend == "openwebrx" {
                donglePresent = true
                // If OpenWebRX reports enabled == false, mark unavailable
                if status.enabled == false || status.openwebrxEnabled == false {
                    errorMessage = "OpenWebRX desabilitado no servidor"
                    backendAvailable = false
                } else {
                    errorMessage = nil
                }
            } else if status.donglePresent == false {
                errorMessage = "Dongle RTL-SDR não detectado no Raspberry Pi"
            } else if status.enabled == false {
                errorMessage = "Rádio remoto desabilitado no servidor"
                backendAvailable = false
            } else {
                errorMessage = nil
            }
        } catch let error as RemoteRadioError {
            backendAvailable = false
            errorMessage = error.localizedDescription
        } catch {
            backendAvailable = false
            errorMessage = "Backend não responde"
        }
    }

    // MARK: - WebSocket

    private func startWebSocket(sessionId: String) async {
        guard let url = await apiClient.wsURL(sessionId: sessionId) else { return }

        var request = URLRequest(url: url)
        let token = Secrets.apiToken.isEmpty ? Secrets.apiTokenAlternative : Secrets.apiToken
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let session = URLSession(configuration: .default)
        wsTask = session.webSocketTask(with: request)
        wsTask?.resume()

        // Start receiving messages
        receiveWSMessages()

        // Start heartbeat every 15 seconds
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) {
            [weak self] _ in
            Task { [weak self] in
                await self?.sendWSPing()
            }
        }
    }

    private func stopWebSocket() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        wsTask?.cancel(with: .normalClosure, reason: nil)
        wsTask = nil
    }

    private func sendWSPing() async {
        let ping = #"{"type":"ping"}"#
        try? await wsTask?.send(.string(ping))
    }

    private func receiveWSMessages() {
        wsTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.handleWSMessage(text)
                    case .data(let data):
                        // Binary frames = raw PCM audio
                        self.audioFrameCount += 1
                        self.audioPlayer.feedPCM(data)
                    @unknown default:
                        break
                    }
                    // Continue receiving
                    self.receiveWSMessages()
                case .failure:
                    // WebSocket closed or errored
                    break
                }
            }
        }
    }

    private func handleWSMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
            let msg = try? JSONDecoder().decode(WSMessage.self, from: data)
        else { return }

        switch msg.type {
        case "pong":
            break  // Heartbeat acknowledged
        case "audio_config":
            break  // Server confirmed audio stream params — we already know format
        case "event":
            if msg.event == "state_changed", let status = msg.status {
                serverStatus = status
                if let s = status.state ?? status.status {
                    statusText = s
                }
            }
        case "error":
            errorMessage = msg.message ?? msg.code ?? "Erro desconhecido"
        default:
            break
        }
    }
}

// MARK: - Helpers

extension RemoteRadioConnectionState {
    fileprivate var isError: Bool {
        if case .error = self { return true }
        return false
    }
}
