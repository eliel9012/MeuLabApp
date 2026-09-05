import AVFoundation
import Foundation
import MediaPlayer

@MainActor
class WatchAudioPlayer: ObservableObject {
    static let shared = WatchAudioPlayer()

    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?

    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var notificationObservers: [NSObjectProtocol] = []

    /// User intent, kept separate from `isPlaying` (actual output). An interruption
    /// or a dropped stream clears `isPlaying` while intent stays true, which is what
    /// allows automatic resume and reconnection.
    private var userWantsPlayback = false

    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 6

    private let streamURL = URL(string: "https://rrdns-megasistema.webnow.com.br/diario.aac")!

    private init() {
        configureAudioSessionCategory()
        registerSessionNotifications()
        setupRemoteCommandCenter()
        setupNowPlayingInfo()
    }

    // MARK: - Audio session

    /// `.longFormAudio` is what lets a watchOS app keep streaming in the background
    /// and route to Bluetooth output instead of the watch speaker. Category only —
    /// activation is deferred to `play()` so opening the app does not grab audio focus.
    private func configureAudioSessionCategory() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                policy: .longFormAudio
            )
        } catch {
            print("Watch audio session category error: \(error)")
        }
    }

    /// Unlike iOS, watchOS *does* provide the asynchronous activation API, and it is
    /// the required path under `.longFormAudio`: it can present the route picker, and
    /// it legitimately fails when no eligible output is available. That failure has to
    /// surface — starting the stream anyway would leave silent "playback".
    private func activateSession() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().activate(options: []) { activated, error in
                if let error {
                    print("Watch audio session activation error: \(error)")
                }
                continuation.resume(returning: activated)
            }
        }
    }

    /// `setActive(false)` is blocking and has no async counterpart, so keep it off
    /// the main thread.
    private nonisolated static func deactivateSession() async {
        await Task.detached(priority: .userInitiated) {
            do {
                try AVAudioSession.sharedInstance().setActive(
                    false, options: [.notifyOthersOnDeactivation]
                )
            } catch {
                print("Watch audio session deactivation error: \(error)")
            }
        }.value
    }

    // MARK: - Interruption / route / failure handling

    private func registerSessionNotifications() {
        let center = NotificationCenter.default

        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { note in
            let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                WatchAudioPlayer.shared.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw)
            }
        }

        let routeChange = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { note in
            let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                WatchAudioPlayer.shared.handleRouteChange(reasonRaw: reasonRaw)
            }
        }

        let failed = center.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                WatchAudioPlayer.shared.scheduleReconnect(reason: "Transmissão interrompida")
            }
        }

        let stalled = center.addObserver(
            forName: AVPlayerItem.playbackStalledNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                WatchAudioPlayer.shared.scheduleReconnect(reason: "Transmissão travou")
            }
        }

        notificationObservers = [interruption, routeChange, failed, stalled]
    }

    private func handleInterruption(typeRaw: UInt?, optionsRaw: UInt?) {
        guard let raw = typeRaw,
            let type = AVAudioSession.InterruptionType(rawValue: raw)
        else { return }

        switch type {
        case .began:
            player?.pause()
            isPlaying = false
            updateNowPlayingPlaybackState()
        case .ended:
            guard userWantsPlayback else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
            if options.contains(.shouldResume) {
                Task { @MainActor in
                    guard await activateSession(), userWantsPlayback else { return }
                    player?.play()
                }
            } else {
                userWantsPlayback = false
                isPlaying = false
                updateNowPlayingPlaybackState()
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonRaw: UInt?) {
        guard let raw = reasonRaw,
            let reason = AVAudioSession.RouteChangeReason(rawValue: raw)
        else { return }

        // Bluetooth output went away — watchOS has already stopped us. Reflect it
        // instead of leaving the UI claiming playback.
        if reason == .oldDeviceUnavailable {
            userWantsPlayback = false
            player?.pause()
            isPlaying = false
            updateNowPlayingPlaybackState()
        }
    }

    private func scheduleReconnect(reason: String) {
        guard userWantsPlayback else { return }
        guard reconnectTask == nil else { return }

        guard reconnectAttempts < maxReconnectAttempts else {
            userWantsPlayback = false
            isPlaying = false
            isLoading = false
            error = "\(reason). Não foi possível reconectar."
            updateNowPlayingPlaybackState()
            return
        }

        reconnectAttempts += 1
        let delay = min(30.0, pow(2.0, Double(reconnectAttempts - 1)))
        isLoading = true
        error = nil

        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.reconnectTask = nil
            guard self.userWantsPlayback else { return }
            self.startStream()
        }
    }

    // MARK: - Playback

    func play() {
        guard !userWantsPlayback else { return }
        userWantsPlayback = true
        reconnectAttempts = 0
        error = nil
        isLoading = true

        Task { @MainActor in
            let activated = await activateSession()
            // The user may have hit pause during activation (or the route picker).
            guard userWantsPlayback else { return }
            guard activated else {
                userWantsPlayback = false
                isLoading = false
                isPlaying = false
                error = "Não foi possível ativar o áudio. Conecte um fone Bluetooth."
                return
            }
            startStream()
        }
    }

    /// A live stream cannot be resumed, only reopened, so every start and every
    /// reconnect attempt builds a fresh `AVPlayerItem`.
    private func startStream() {
        isLoading = true

        statusObservation?.invalidate()
        timeControlObservation?.invalidate()

        let item = AVPlayerItem(url: streamURL)
        playerItem = item

        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        statusObservation = item.observe(\.status, options: [.new]) { observedItem, _ in
            let status = observedItem.status
            let failure = observedItem.error?.localizedDescription
            Task { @MainActor in
                WatchAudioPlayer.shared.handleItemStatus(status, failure: failure)
            }
        }

        timeControlObservation = player?.observe(\.timeControlStatus, options: [.new]) { observedPlayer, _ in
            let status = observedPlayer.timeControlStatus
            Task { @MainActor in
                WatchAudioPlayer.shared.handleTimeControlStatus(status)
            }
        }

        player?.play()
    }

    private func handleItemStatus(_ status: AVPlayerItem.Status, failure: String?) {
        switch status {
        case .failed:
            scheduleReconnect(reason: failure ?? "Erro ao reproduzir")
        case .readyToPlay:
            error = nil
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    /// Drives the published state from what the player is actually doing, rather
    /// than assuming playback began the moment `play()` was called.
    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            isPlaying = true
            isLoading = false
            error = nil
            reconnectAttempts = 0
        case .waitingToPlayAtSpecifiedRate:
            isPlaying = false
            isLoading = userWantsPlayback
        case .paused:
            isPlaying = false
            if !userWantsPlayback { isLoading = false }
        @unknown default:
            break
        }
        updateNowPlayingPlaybackState()
    }

    func pause() {
        userWantsPlayback = false
        reconnectTask?.cancel()
        reconnectTask = nil
        player?.pause()
        isPlaying = false
        isLoading = false
        updateNowPlayingPlaybackState()
    }

    func stop() {
        userWantsPlayback = false
        reconnectTask?.cancel()
        reconnectTask = nil
        reconnectAttempts = 0

        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil

        player?.pause()
        player?.replaceCurrentItem(with: nil)
        playerItem = nil

        isPlaying = false
        isLoading = false
        updateNowPlayingPlaybackState()
        Task { await Self.deactivateSession() }
    }

    func togglePlayPause() {
        if userWantsPlayback {
            pause()
        } else {
            play()
        }
    }

    // MARK: - Remote command center / Now Playing

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
    }

    private func setupNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Diário FM"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Franca, SP"
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    private func updateNowPlayingPlaybackState() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
