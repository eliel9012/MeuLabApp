import AVFoundation
import Foundation

@MainActor
class WatchAudioPlayer: ObservableObject {
    static let shared = WatchAudioPlayer()

    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var error: String?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?

    private let streamURL = URL(string: "https://rrdns-megasistema.webnow.com.br/diario.aac")!

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Watch audio session error: \(error)")
        }
    }

    func play() {
        guard !isPlaying else { return }
        isLoading = true
        error = nil

        statusObservation?.invalidate()

        playerItem = AVPlayerItem(url: streamURL)

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        statusObservation = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                self?.isLoading = false
                switch item.status {
                case .failed:
                    self?.error = item.error?.localizedDescription ?? "Erro ao reproduzir"
                    self?.isPlaying = false
                case .readyToPlay:
                    self?.error = nil
                default:
                    break
                }
            }
        }

        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        statusObservation?.invalidate()
        isPlaying = false
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }
}
