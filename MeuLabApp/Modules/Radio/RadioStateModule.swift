import Foundation
import Combine

/// Módulo de estado para Rádio
@MainActor
class RadioStateModule: ObservableObject {
    @Published var nowPlaying: NowPlaying?
    @Published var error: String?
    @Published var isLoading = false

    private let api: APIServiceProtocol

    init(api: APIServiceProtocol) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let playing = try await api.fetchNowPlaying()

            if self.nowPlaying != playing {
                self.nowPlaying = playing
                // Update Now Playing in Control Center
                AudioPlayer.shared.updateNowPlayingInfo(track: playing)
            }
            self.error = nil
            Logger.info("Radio refresh: \(playing.title) por \(playing.artist)")
        } catch {
            if nowPlaying == nil {
                self.error = error.localizedDescription
                Logger.error("Radio refresh error: \(error.localizedDescription)")
            }
        }
    }
}
