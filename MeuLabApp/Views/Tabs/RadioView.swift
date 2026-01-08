import SwiftUI

struct RadioView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var player = AudioPlayer.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Artwork
                    artworkSection

                    // Track Info
                    if let nowPlaying = appState.nowPlaying {
                        trackInfoSection(nowPlaying)
                    }

                    // Player Controls
                    controlsSection

                    // Error message
                    if let error = player.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Rádio")
        }
    }

    @ViewBuilder
    private var artworkSection: some View {
        Group {
            if let artworkURL = appState.nowPlaying?.artworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .empty:
                        placeholderArtwork
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderArtwork
                    @unknown default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 280, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: player.isPlaying ? 20 : 8)
        .animation(.easeInOut, value: player.isPlaying)
    }

    private var placeholderArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Image(systemName: "radio")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Diário FM")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private func trackInfoSection(_ nowPlaying: NowPlaying) -> some View {
        VStack(spacing: 8) {
            Text(nowPlaying.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(nowPlaying.artist)
                .font(.title3)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let album = nowPlaying.album, !album.isEmpty {
                Text(album)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let genre = nowPlaying.genre {
                Text(genre)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var controlsSection: some View {
        VStack(spacing: 20) {
            // Live indicator
            HStack {
                Circle()
                    .fill(player.isPlaying ? Color.red : Color.gray)
                    .frame(width: 8, height: 8)

                Text(player.isPlaying ? "AO VIVO" : "PAUSADO")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(player.isPlaying ? .red : .secondary)
            }

            // Play/Pause button
            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 80, height: 80)
                        .shadow(color: .blue.opacity(0.4), radius: player.isPlaying ? 12 : 4)

                    if player.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .offset(x: player.isPlaying ? 0 : 3)
                    }
                }
            }
            .buttonStyle(.plain)
            .animation(.easeInOut, value: player.isPlaying)
            .animation(.easeInOut, value: player.isLoading)

            // Radio name
            VStack(spacing: 4) {
                Text(appState.nowPlaying?.radioName ?? "Diário FM")
                    .font(.headline)

                Text("Franca, SP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    RadioView()
        .environmentObject(AppState())
}
