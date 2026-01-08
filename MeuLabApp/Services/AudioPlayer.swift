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

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        setupNowPlayingInfo()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Audio session setup error: \(error)")
        }
    }

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

    func updateNowPlayingInfo(track: NowPlaying) {
        currentTrack = track

        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = track.album ?? track.radioName
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

        // Load artwork if available
        if let artworkURL = track.artworkURL {
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: artworkURL)
                    if let image = UIImage(data: data) {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    }
                } catch {
                    print("Artwork load error: \(error)")
                }
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func play() {
        guard !isPlaying else { return }

        isLoading = true
        error = nil

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
