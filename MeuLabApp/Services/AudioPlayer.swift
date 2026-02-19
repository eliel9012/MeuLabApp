import Foundation
import AVFoundation
import MediaPlayer

@MainActor
class AudioPlayer: NSObject, ObservableObject {
    static let shared = AudioPlayer()

    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentTrack: NowPlaying?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?

    private let streamURL = URL(string: "https://rrdns-megasistema.webnow.com.br/diario.aac")!
    private var lastArtworkURL: URL?
    private var lastArtworkImage: UIImage?

    private var isInPreviewOrSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #endif
    }

    override init() {
        super.init()
        setupAudioSession()
        if !isInPreviewOrSimulator {
            setupRemoteCommandCenter()
            setupNowPlayingInfo()
        }
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Use a safe combination to avoid paramErr (-50). Don't combine mutually exclusive options
            // like .allowAirPlay and .allowBluetoothA2DP together with .playback.
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session setup error: \(error)")
        }
    }

    private func setupRemoteCommandCenter() {
        if isInPreviewOrSimulator { return }
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
        if isInPreviewOrSimulator { return }
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "Diário FM"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Franca, SP"
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func updateNowPlayingInfo(track: NowPlaying) {
        if isInPreviewOrSimulator { return }
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
            lastArtworkURL = nil
            lastArtworkImage = nil
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
                // Keep it as a log only.
                print("Artwork load error: \(error)")
            }
        }
    }

    func play() {
        guard !isPlaying else { return }

        isLoading = true
        error = nil

        // Remove observer from previous player item to avoid memory leak
        playerItem?.removeObserver(self, forKeyPath: "status")

        // Create new player item for fresh stream
        playerItem = AVPlayerItem(url: streamURL)

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        // Observe player status
        playerItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)

        player?.play()
        isPlaying = true
        isLoading = false

        updateNowPlayingPlaybackState()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingPlaybackState()
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
        updateNowPlayingPlaybackState()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    private func updateNowPlayingPlaybackState() {
        if isInPreviewOrSimulator { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false

                if let status = self?.playerItem?.status {
                    switch status {
                    case .failed:
                        self?.error = self?.playerItem?.error?.localizedDescription ?? "Erro ao reproduzir"
                        self?.isPlaying = false
                    case .readyToPlay:
                        self?.error = nil
                    case .unknown:
                        break
                    @unknown default:
                        break
                    }
                }
            }
        }
    }

    deinit {
        playerItem?.removeObserver(self, forKeyPath: "status")
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
    }
}

// MARK: - UIImage helper for iOS
#if canImport(UIKit)
import UIKit
#endif
