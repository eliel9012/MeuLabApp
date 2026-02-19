import SwiftUI


struct RadioView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var player = AudioPlayer.shared

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height

                // Keep the screen proportional across iPhone sizes and avoid pushing controls under the tab bar.
                let artworkSize = max(220, min(w * 0.78, h * 0.36, 340))

                ScrollView {
                    VStack(spacing: 16) {
                        artworkSection(size: artworkSize)

                        if let nowPlaying = appState.nowPlaying {
                            trackInfoSection(nowPlaying)
                        } else {
                            Text("Sem informação de música no momento")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        controlsSection

                        if let error = player.error {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.top, 6)
                        }

                        Spacer(minLength: 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.top, 14)
                    .padding(.bottom, 44)
                }
            }
            // Title aligned with the toolbar buttons (same visual row).
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Rádio")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        RadioSongsView()
                            .environmentObject(appState)
                    } label: {
                        Image(systemName: "music.note.list")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func artworkSection(size: CGFloat) -> some View {
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
        .frame(width: size, height: size)
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

            Image("DiarioLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
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

                Text(player.isPlaying ? "NO AR" : "Pausado")
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
                            .scaleEffect(1.5)
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .offset(x: player.isPlaying ? 0 : 3)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(player.isLoading)
            .animation(.easeInOut, value: player.isPlaying)
            .animation(.easeInOut, value: player.isLoading)

            // Radio name
            VStack(spacing: 4) {
                Image("DiarioLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)

                Text("Ribeirão Preto, SP")
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

// MARK: - Songs / History

struct RadioSongsView: View {
    @EnvironmentObject var appState: AppState
    @State private var items: [NowPlaying] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        List {
            if let now = appState.nowPlaying {
                Section("Tocando agora") {
                    trackRow(now, isNow: true)
                }
            }

            Section("Histórico") {
                if isLoading && items.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let errorText, items.isEmpty {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if items.isEmpty {
                    Text("Sem histórico ainda.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items.indices, id: \.self) { idx in
                        trackRow(items[idx], isNow: false)
                    }
                }
            }
        }
        .navigationTitle("Músicas")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await load()
        }
        .task {
            await load()
        }
    }

    @ViewBuilder
    private func trackRow(_ track: NowPlaying, isNow: Bool) -> some View {
        HStack(spacing: 12) {
            artwork(track)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let album = track.album, !album.isEmpty {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if isNow {
                    Text("AGORA")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                } else if let rel = relativeTimestamp(track.timestamp) {
                    Text(rel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let urlString = track.itunesUrl, let url = URL(string: urlString) {
                    Link(destination: url) {
                        Image(systemName: "link")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func artwork(_ track: NowPlaying) -> some View {
        let size: CGFloat = 52
        if let url = track.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholderArtwork(size: size)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholderArtwork(size: size)
                @unknown default:
                    placeholderArtwork(size: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            placeholderArtwork(size: size)
        }
    }

    private func placeholderArtwork(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: "music.note")
                .foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
    }

    private func relativeTimestamp(_ iso: String) -> String? {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d1 = df.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date = d1 else { return nil }

        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    private func load() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await APIService.shared.fetchRadioHistory(limit: 80)
            let nowKey = appState.nowPlaying?.displayTitle
            items = resp.items.filter { $0.displayTitle != nowKey }
            errorText = nil
        } catch {
            if items.isEmpty {
                errorText = "Erro ao carregar histórico."
            }
        }
    }
}

// (No Apple Music button here. Links live only in the history screen.)
