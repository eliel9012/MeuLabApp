import AVFoundation
import Foundation
import MediaPlayer

#if canImport(UIKit)
import UIKit
#endif

@MainActor
class AudioPlayer: NSObject, ObservableObject {
    static let shared = AudioPlayer()

    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentTrack: NowPlaying?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?

    /// Modern KVO tokens. They invalidate themselves on deinit, so there is no
    /// manual `removeObserver` bookkeeping to get wrong.
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?

    private var notificationObservers: [NSObjectProtocol] = []

    /// User intent, kept separate from `isPlaying` (actual output). An interruption
    /// or a dropped stream flips `isPlaying` to false while intent stays true, which
    /// is what allows automatic resume/reconnect.
    private var userWantsPlayback = false

    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 6

    private let streamURL = URL(string: "https://rrdns-megasistema.webnow.com.br/diario.aac")!
    private var lastArtworkURL: URL?
    private var lastArtworkImage: UIImage?

    /// Bundled station logo, used whenever the stream has no per-track artwork
    /// (jingles, ads, station IDs). Built once — `MPMediaItemArtwork` is cheap to
    /// reuse and rebuilding it on every 5s poll is wasted work.
    private lazy var stationArtwork: MPMediaItemArtwork? = {
        guard let image = UIImage(named: "DiarioLogo") else { return nil }
        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }()

    /// SwiftUI Previews run without a usable media stack, so Now Playing and the
    /// remote command center are skipped there. The Simulator handles both fine —
    /// excluding it too would make Control Center artwork impossible to verify
    /// anywhere but a physical device.
    private var isRunningInPreviews: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    override init() {
        super.init()
        configureAudioSessionCategory()
        registerSessionNotifications()
        if !isRunningInPreviews {
            setupRemoteCommandCenter()
            setupNowPlayingInfo()
        }
    }

    // MARK: - Audio session

    /// Category only. Activation is deferred to `play()` so that merely touching
    /// `AudioPlayer.shared` (e.g. to push Now Playing metadata) never steals the
    /// audio focus from whatever the user is already listening to.
    private func configureAudioSessionCategory() {
        do {
            // Use a safe combination to avoid paramErr (-50). Don't combine mutually exclusive options
            // like .allowAirPlay and .allowBluetoothA2DP together with .playback.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        } catch {
            print("Audio session category setup error: \(error)")
        }
    }

    private func activateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session activation error: \(error)")
        }
    }

    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Audio session deactivation error: \(error)")
        }
    }

    // MARK: - Interruption / route / failure handling

    private func registerSessionNotifications() {
        let center = NotificationCenter.default

        let interruption = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { note in
            // Extract Sendable primitives here; the userInfo dictionary itself
            // must not cross the actor boundary.
            let typeRaw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsRaw = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                AudioPlayer.shared.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw)
            }
        }

        let routeChange = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { note in
            let reasonRaw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                AudioPlayer.shared.handleRouteChange(reasonRaw: reasonRaw)
            }
        }

        // Live stream died mid-playback.
        let failed = center.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AudioPlayer.shared.scheduleReconnect(reason: "Transmissão interrompida")
            }
        }

        // Buffer ran dry and the player gave up.
        let stalled = center.addObserver(
            forName: AVPlayerItem.playbackStalledNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AudioPlayer.shared.scheduleReconnect(reason: "Transmissão travou")
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
            // Phone call, Siri, alarm. Keep `userWantsPlayback` so we can resume.
            player?.pause()
            isPlaying = false
            updateNowPlayingPlaybackState()
        case .ended:
            guard userWantsPlayback else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
            if options.contains(.shouldResume) {
                activateSession()
                player?.play()
            } else {
                // System says don't resume automatically; stop lying in the UI.
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

        // Headphones/AirPods pulled out: iOS already paused us. Reflect it.
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
        activateSession()
        startStream()
    }

    /// Builds a fresh `AVPlayerItem` and wires observation. Used by both the initial
    /// play and every reconnect attempt — a live stream cannot be resumed, only reopened.
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
                AudioPlayer.shared.handleItemStatus(status, failure: failure)
            }
        }

        // Drives `isPlaying`/`isLoading` from what the player is actually doing,
        // instead of optimistically assuming playback started.
        timeControlObservation = player?.observe(\.timeControlStatus, options: [.new]) { observedPlayer, _ in
            let status = observedPlayer.timeControlStatus
            Task { @MainActor in
                AudioPlayer.shared.handleTimeControlStatus(status)
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

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            isPlaying = true
            isLoading = false
            error = nil
            reconnectAttempts = 0
        case .waitingToPlayAtSpecifiedRate:
            // Buffering. Only surface it while the user actually wants audio.
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
        deactivateSession()
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
        if isRunningInPreviews { return }
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
        if isRunningInPreviews { return }
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Diário FM"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Franca, SP"
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func updateNowPlayingInfo(track: NowPlaying) {
        if isRunningInPreviews { return }
        currentTrack = track

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album ?? track.radioName
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        // Apply base metadata immediately, then enrich with artwork asynchronously.
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        guard let artworkURL = track.artworkURL else {
            // No per-track cover (jingle, ad, station ID). Returning here would leave
            // the *previous* song's cover on the Lock Screen / Control Center, so
            // fall back to the station logo — same thing the in-app view shows.
            lastArtworkURL = nil
            lastArtworkImage = nil
            if let stationArtwork {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = stationArtwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            }
            return
        }

        // Reuse cached artwork when possible to avoid refetch + decode churn.
        if lastArtworkURL == artworkURL, let image = lastArtworkImage {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            return
        }

        lastArtworkURL = artworkURL
        lastArtworkImage = nil

        // Swift 6: `Task.detached` runs in a concurrent context; don't capture `self` or other
        // non-Sendable values here. Do the network+decode work detached, then hop to MainActor.
        Task.detached(priority: .utility) {
            do {
                let (data, _) = try await URLSession.shared.data(from: artworkURL)
                if Task.isCancelled { return }
                let decoded: UIImage? = UIImage(data: data)
                if Task.isCancelled { return }

                await MainActor.run {
                    // Drop stale result if the track/artwork has already moved on.
                    let player = AudioPlayer.shared
                    guard player.lastArtworkURL == artworkURL else { return }
                    guard let image = decoded else { return }

                    player.lastArtworkImage = image
                    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            } catch {
                // Avoid surfacing noisy errors to UI; this is best-effort metadata.
                // Keep it as a log only, but don't leave a stale cover behind.
                print("Artwork load error: \(error)")
                await MainActor.run {
                    let player = AudioPlayer.shared
                    guard player.lastArtworkURL == artworkURL else { return }
                    guard let stationArtwork = player.stationArtwork else { return }
                    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    info[MPMediaItemPropertyArtwork] = stationArtwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        }
    }

    private func updateNowPlayingPlaybackState() {
        if isRunningInPreviews { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
