import SwiftUI

struct WatchRadioView: View {
    @StateObject private var audioPlayer = WatchAudioPlayer.shared
    @State private var nowPlaying: NowPlaying?
    @State private var isLoading = true
    @State private var error: String?
    @State private var refreshTimer: Timer?

    var body: some View {
        WatchLabScreen(
            title: "Rádio", icon: "dot.radiowaves.left.and.right", tint: WatchLabTheme.red
        ) {
            if isLoading && nowPlaying == nil {
                WatchLabPanel(tint: WatchLabTheme.red) {
                    WatchLabStateView(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Atualizando",
                        subtitle: "Buscando informações da rádio.",
                        tint: WatchLabTheme.red,
                        actionTitle: nil,
                        action: nil
                    )
                }
            } else if let error, nowPlaying == nil {
                WatchLabPanel(tint: WatchLabTheme.red) {
                    WatchLabStateView(
                        icon: "wifi.exclamationmark",
                        title: "Falha",
                        subtitle: error,
                        tint: WatchLabTheme.red,
                        actionTitle: "Tentar",
                        action: { Task { await loadData() } }
                    )
                }
            } else {
                // Now Playing Card
                WatchLabPanel(tint: WatchLabTheme.red) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Diário FM")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WatchLabTheme.ink)
                            Text("Franca, SP")
                                .font(.system(size: 10))
                                .foregroundStyle(WatchLabTheme.secondary)
                        }
                        Spacer()
                        Circle()
                            .fill(
                                audioPlayer.isPlaying
                                    ? WatchLabTheme.green : WatchLabTheme.red.opacity(0.5)
                            )
                            .frame(width: 8, height: 8)
                    }
                }

                // Track Info
                if let np = nowPlaying {
                    WatchLabPanel(tint: WatchLabTheme.violet) {
                        if let artworkUrl = np.artworkUrl, let url = URL(string: artworkUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(WatchLabTheme.panel)
                                    .frame(height: 60)
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .foregroundStyle(WatchLabTheme.secondary)
                                    }
                            }
                        }

                        Text(np.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(WatchLabTheme.ink)
                            .lineLimit(2)

                        if np.artist != "Desconhecido" {
                            Text(np.artist)
                                .font(.caption2)
                                .foregroundStyle(WatchLabTheme.secondary)
                                .lineLimit(1)
                        }

                        if let album = np.album, !album.isEmpty {
                            Text(album)
                                .font(.system(size: 9))
                                .foregroundStyle(WatchLabTheme.tertiary)
                                .lineLimit(1)
                        }
                    }
                }

                // Playback Controls
                WatchLabPanel(tint: WatchLabTheme.blue) {
                    HStack(spacing: 16) {
                        Spacer()

                        Button {
                            audioPlayer.togglePlayPause()
                        } label: {
                            Circle()
                                .fill(
                                    audioPlayer.isPlaying ? WatchLabTheme.red : WatchLabTheme.green
                                )
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if audioPlayer.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(
                                            systemName: audioPlayer.isPlaying
                                                ? "pause.fill" : "play.fill"
                                        )
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)

                        if audioPlayer.isPlaying {
                            Button {
                                audioPlayer.stop()
                            } label: {
                                Circle()
                                    .fill(WatchLabTheme.panelStrong)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(WatchLabTheme.red)
                                    }
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()
                    }

                    if let playerError = audioPlayer.error {
                        Text(playerError)
                            .font(.system(size: 9))
                            .foregroundStyle(WatchLabTheme.red)
                            .lineLimit(2)
                    }
                }
            }
        }
        .task {
            await loadData()
            startAutoRefresh()
        }
        .refreshable { await loadData() }
        .onDisappear { stopAutoRefresh() }
    }

    private func loadData() async {
        if nowPlaying == nil { isLoading = true }
        error = nil
        do {
            nowPlaying = try await WatchAPIService.shared.fetchNowPlaying()
        } catch {
            if nowPlaying == nil {
                self.error = error.localizedDescription
            }
        }
        isLoading = false
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { await loadData() }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

#Preview {
    WatchRadioView()
}
