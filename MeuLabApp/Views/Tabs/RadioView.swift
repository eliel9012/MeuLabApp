import Foundation
import SwiftUI
import UIKit

private func radioAdaptiveColor(light: UIColor, dark: UIColor) -> Color {
    Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    )
}

private func radioRGBA(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1)
    -> UIColor
{
    UIColor(red: red, green: green, blue: blue, alpha: alpha)
}

private enum RadioTheme {
    static let blue = Color(red: 0.14, green: 0.38, blue: 0.84)
    static let cyan = Color(red: 0.18, green: 0.70, blue: 0.86)
    static let green = Color(red: 0.27, green: 0.78, blue: 0.37)
    static let red = Color(red: 0.92, green: 0.25, blue: 0.31)
    static let amber = Color(red: 0.95, green: 0.57, blue: 0.15)
    static let ink = radioAdaptiveColor(
        light: radioRGBA(0.08, 0.11, 0.20),
        dark: radioRGBA(0.92, 0.95, 1.00)
    )
    static let mist = radioAdaptiveColor(
        light: radioRGBA(0.94, 0.97, 1.00),
        dark: radioRGBA(0.09, 0.11, 0.18)
    )
    static let surfaceTop = radioAdaptiveColor(
        light: radioRGBA(1.00, 1.00, 1.00, 0.98),
        dark: radioRGBA(0.13, 0.16, 0.24, 0.98)
    )
    static let surfaceStroke = radioAdaptiveColor(
        light: radioRGBA(1.00, 1.00, 1.00, 0.92),
        dark: radioRGBA(0.26, 0.31, 0.42, 0.88)
    )
    static let canvasMid = radioAdaptiveColor(
        light: radioRGBA(1.00, 1.00, 1.00),
        dark: radioRGBA(0.06, 0.08, 0.15)
    )
    static let canvasEnd = radioAdaptiveColor(
        light: radioRGBA(0.98, 0.99, 0.97),
        dark: radioRGBA(0.08, 0.10, 0.17)
    )
    static let shadow = radioAdaptiveColor(
        light: radioRGBA(0.05, 0.12, 0.26),
        dark: radioRGBA(0.00, 0.00, 0.00)
    )
    static let toolbarBubble = radioAdaptiveColor(
        light: radioRGBA(1.00, 1.00, 1.00, 0.78),
        dark: radioRGBA(0.16, 0.20, 0.28, 0.94)
    )
}

private struct RadioPanelBackground: View {
    let cornerRadius: CGFloat
    let highlight: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [RadioTheme.surfaceTop, RadioTheme.mist],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [highlight.opacity(0.12), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [highlight.opacity(0.28), RadioTheme.surfaceStroke],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            }
            .shadow(color: RadioTheme.shadow.opacity(0.08), radius: 22, x: 0, y: 12)
            .shadow(color: highlight.opacity(0.07), radius: 14, x: 0, y: 6)
    }
}

private extension View {
    func radioPanel(cornerRadius: CGFloat = 20, highlight: Color = RadioTheme.blue) -> some View {
        background(RadioPanelBackground(cornerRadius: cornerRadius, highlight: highlight))
    }
}

private struct RadioToolbarTitle: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [RadioTheme.green.opacity(0.18), RadioTheme.blue.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(RadioTheme.blue)
            }

            Text("Rádio")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(
                    LinearGradient(
                        colors: [RadioTheme.green, RadioTheme.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rádio")
    }
}

private struct RadioInfoChip: View {
    let title: String
    let value: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(RadioTheme.ink.opacity(0.56))

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)

                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RadioTheme.ink)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Capsule().fill(tint.opacity(0.10)))
        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 1))
    }
}

struct RadioView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var player = AudioPlayer.shared
    @State private var recentTracks: [NowPlaying] = []
    @State private var loadingRecentTracks = false
    @State private var enrichedNowPlaying: EnrichedTrack?
    @State private var isEnrichingNowPlaying = false
    @State private var artistFact: String?
    @State private var isLoadingArtistFact = false
    @State private var songFact: String?
    @State private var isLoadingSongFact = false
    @State private var artistFactCache: [String: String] = [:]
    @State private var songFactCache: [String: String] = [:]

    private var isWide: Bool { horizontalSizeClass == .regular }
    private var contentMaxWidth: CGFloat { isWide ? 920 : 520 }
    private var sectionPadding: CGFloat { isWide ? 20 : 16 }
    private var sectionRadius: CGFloat { isWide ? 24 : 22 }
    private var blockSpacing: CGFloat { isWide ? 18 : 16 }
    private var nowPlayingFactKey: String {
        guard let now = appState.nowPlaying else { return "" }
        return factKey(title: now.title, artist: now.artist)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeInsets = proxy.safeAreaInsets
                let horizontalInset = isWide ? 24.0 : 16.0
                let availableWidth = proxy.size.width - safeInsets.leading - safeInsets.trailing
                let contentWidth = min(contentMaxWidth, max(availableWidth - (horizontalInset * 2), 280))
                let artworkSize = isWide ? min(contentWidth * 0.56, 420) : min(contentWidth * 0.74, 248)

                ZStack {
                    immersiveBackground

                    if isWide {
                        wideLayout(contentWidth: contentWidth, artworkSize: artworkSize)
                    } else {
                        compactLayout(contentWidth: contentWidth, artworkSize: artworkSize)
                    }
                }
                .frame(width: proxy.size.width) // Garantia extra para o ZStack não escapar horizontalmente
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    RadioToolbarTitle()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        RadioSongsView()
                            .environmentObject(appState)
                    } label: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(RadioTheme.blue)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(RadioTheme.toolbarBubble)
                            )
                    }
                }
            }
            .task {
                await loadRecentTracks()
            }
            .task(id: nowPlayingFactKey) {
                guard let now = appState.nowPlaying else {
                    enrichedNowPlaying = nil
                    artistFact = nil
                    songFact = nil
                    return
                }

                async let enrich: Void = refreshEnrichedNowPlaying()
                async let artist: Void = refreshArtistFact(for: now)
                async let song: Void = refreshSongFact(for: now)
                _ = await (enrich, artist, song)
            }
        }
    }

    @ViewBuilder
    private func wideLayout(contentWidth: CGFloat, artworkSize: CGFloat) -> some View {
        ScrollView {
            LazyVStack(spacing: 22) {
                stationHeroSection(size: artworkSize, contentWidth: contentWidth, compact: false)

                musicFactsScrollSection(contentWidth: contentWidth)

                recentTracksSection(contentWidth: contentWidth)

                if let error = player.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .frame(maxWidth: contentWidth)
                }

                Spacer(minLength: 18)
            }
            .frame(width: contentWidth, alignment: .center)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 44)
        }
    }

    @ViewBuilder
    private func compactLayout(contentWidth: CGFloat, artworkSize: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                stationHeroSection(
                    size: min(artworkSize, contentWidth - 32),
                    contentWidth: contentWidth,
                    compact: true
                )

                musicFactsScrollSection(contentWidth: contentWidth)

                recentTracksSection(contentWidth: contentWidth)

                if let error = player.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                }

                Spacer(minLength: 18)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 128)
        }
    }

    @ViewBuilder
    private var immersiveBackground: some View {
        ZStack {
            if let artworkURL = effectiveArtworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Limita a expansão ao tamanho proposto
        .clipped() // Corta a sobra da imagem gerada pelo aspecto ratio
        .blur(radius: 40)
        .overlay(Color.black.opacity(0.48))
        .overlay(
            LinearGradient(
                colors: [Color.black.opacity(0.28), Color.clear, Color.black.opacity(0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func stationHeroSection(size: CGFloat, contentWidth: CGFloat, compact: Bool) -> some View {
        if compact {
            let compactWidth = contentWidth
            let compactArtworkSize = min(size, 220)

            VStack(spacing: 18) {
                HStack {
                    Spacer(minLength: 0)
                    artworkSection(size: compactArtworkSize)
                    Spacer(minLength: 0)
                }

                VStack(spacing: 8) {
                    Text(effectiveTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                        .frame(width: compactWidth)

                    if !shouldHideArtistLine {
                        Text(effectiveArtist.isEmpty ? "Diário FM" : effectiveArtist)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                            .frame(width: compactWidth)
                    }

                    if let album = effectiveAlbum, !album.isEmpty {
                        Text(album)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                            .frame(width: compactWidth)
                    }
                }

                HStack {
                    Spacer(minLength: 0)
                    playbackControlsRow(compact: true, contentWidth: compactWidth)
                    Spacer(minLength: 0)
                }

                VStack(spacing: 10) {
                    immersiveInfoPill(
                        title: "Estação",
                        value: appState.nowPlaying?.radioName ?? "Diário FM",
                        icon: "music.note.house",
                        tint: RadioTheme.blue
                    )

                    immersiveInfoPill(
                        title: "Status",
                        value: player.isPlaying ? "No ar" : "Em espera",
                        icon: player.isPlaying ? "dot.radiowaves.left.and.right" : "pause.circle",
                        tint: player.isPlaying ? RadioTheme.red : RadioTheme.amber
                    )
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: compactWidth)
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
        } else {
            VStack(spacing: 22) {
                artworkSection(size: size)

                VStack(spacing: 8) {
                    Text(effectiveTitle)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: contentWidth)

                    if !shouldHideArtistLine {
                        Text(effectiveArtist.isEmpty ? "Diário FM" : effectiveArtist)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)
                            .frame(maxWidth: contentWidth)
                    }

                    if let album = effectiveAlbum, !album.isEmpty {
                        Text(album)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.62))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.84)
                            .frame(maxWidth: contentWidth)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                playbackControlsRow(compact: false, contentWidth: contentWidth)

                HStack(spacing: 10) {
                    immersiveInfoPill(
                        title: "Estação",
                        value: appState.nowPlaying?.radioName ?? "Diário FM",
                        icon: "music.note.house",
                        tint: RadioTheme.blue
                    )

                    immersiveInfoPill(
                        title: "Status",
                        value: player.isPlaying ? "No ar" : "Em espera",
                        icon: player.isPlaying ? "dot.radiowaves.left.and.right" : "pause.circle",
                        tint: player.isPlaying ? RadioTheme.red : RadioTheme.amber
                    )
                }
                .frame(width: contentWidth)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 24)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private func artworkSection(size: CGFloat) -> some View {
        Group {
            if let artworkURL = effectiveArtworkURL {
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
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .animation(.easeInOut, value: player.isPlaying)
    }

    private var placeholderArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [RadioTheme.blue, RadioTheme.cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image("DiarioLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200)
        }
    }

    private var effectiveArtworkURL: URL? {
        if let enrichedURL = enrichedNowPlaying?.artworkURL {
            return enrichedURL
        }
        return appState.nowPlaying?.artworkURL
    }

    private var effectiveTitle: String {
        enrichedNowPlaying?.title ?? appState.nowPlaying?.title ?? "Sem título"
    }

    private var effectiveArtist: String {
        enrichedNowPlaying?.artist ?? appState.nowPlaying?.artist ?? ""
    }

    private var effectiveAlbum: String? {
        if let v = enrichedNowPlaying?.album, !v.isEmpty { return v }
        if let v = appState.nowPlaying?.album, !v.isEmpty { return v }
        return nil
    }

    private var effectiveGenre: String? {
        if let v = enrichedNowPlaying?.genre, !v.isEmpty { return v }
        if let v = appState.nowPlaying?.genre, !v.isEmpty { return v }
        return nil
    }

    private var shouldHideArtistLine: Bool {
        guard let np = appState.nowPlaying else { return false }
        // Hide when it's a station promo with unknown artist
        if isStationPromo(np)
            && np.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "desconhecido" {
            return true
        }
        // Also hide when the title already includes the artist to avoid duplication
        let artist = effectiveArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !artist.isEmpty else { return false }
        let title = effectiveTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = title.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        let normalizedArtist = artist.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return normalizedTitle.contains(normalizedArtist)
    }

    @ViewBuilder
    private func musicFactsScrollSection(contentWidth: CGFloat) -> some View {
        Group {
            if isWide {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        factSection(
                            title: "Fato do artista",
                            systemImage: "person.text.rectangle",
                            tint: RadioTheme.green,
                            isLoading: isLoadingArtistFact,
                            text: artistFact ?? "Sem fatos públicos disponíveis para esta faixa."
                        )
                        .frame(width: 320)

                        factSection(
                            title: "Fato da música",
                            systemImage: "music.quarternote.3",
                            tint: RadioTheme.amber,
                            isLoading: isLoadingSongFact,
                            text: songFact ?? "Sem fatos públicos disponíveis para esta música."
                        )
                        .frame(width: 320)
                    }
                    .padding(.horizontal, 2)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    factSection(
                        title: "Fato do artista",
                        systemImage: "person.text.rectangle",
                        tint: RadioTheme.green,
                        isLoading: isLoadingArtistFact,
                        text: artistFact ?? "Sem fatos públicos disponíveis para esta faixa."
                    )

                    factSection(
                        title: "Fato da música",
                        systemImage: "music.quarternote.3",
                        tint: RadioTheme.amber,
                        isLoading: isLoadingSongFact,
                        text: songFact ?? "Sem fatos públicos disponíveis para esta música."
                    )
                }
            }
        }
        .frame(width: contentWidth, alignment: .center)
    }

    private func factSection(title: String, systemImage: String, tint: Color, isLoading: Bool, text: String)
        -> some View
    {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RadioTheme.ink)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.75)
                }
            }

            Text(text)
                .font(.caption)
                .foregroundStyle(RadioTheme.ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .radioPanel(cornerRadius: 22, highlight: tint)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var radioInsightsSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                insightPill(
                    icon: player.isPlaying ? "dot.radiowaves.left.and.right" : "pause.circle",
                    title: "Status",
                    value: player.isPlaying ? "No Ar" : "Pausado",
                    tint: player.isPlaying ? RadioTheme.red : RadioTheme.amber
                )
                insightPill(
                    icon: "music.note",
                    title: "Gênero",
                    value: effectiveGenre ?? (isEnrichingNowPlaying ? "buscando..." : "-"),
                    tint: RadioTheme.blue
                )
                insightPill(
                    icon: "clock",
                    title: "Atualizado",
                    value: relativeTimestamp(appState.nowPlaying?.timestamp) ?? "agora",
                    tint: RadioTheme.green
                )
            }

            VStack(spacing: 10) {
                insightPill(
                    icon: player.isPlaying ? "dot.radiowaves.left.and.right" : "pause.circle",
                    title: "Status",
                    value: player.isPlaying ? "No Ar" : "Pausado",
                    tint: player.isPlaying ? RadioTheme.red : RadioTheme.amber
                )
                insightPill(
                    icon: "music.note",
                    title: "Gênero",
                    value: effectiveGenre ?? (isEnrichingNowPlaying ? "buscando..." : "-"),
                    tint: RadioTheme.blue
                )
                insightPill(
                    icon: "clock",
                    title: "Atualizado",
                    value: relativeTimestamp(appState.nowPlaying?.timestamp) ?? "agora",
                    tint: RadioTheme.green
                )
            }
        }
    }

    private func insightPill(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(RadioTheme.ink.opacity(0.56))
            }
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RadioTheme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .radioPanel(cornerRadius: 16, highlight: tint)
    }

    @ViewBuilder
    private func recentTracksSection(contentWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Últimas tocadas", systemImage: "music.note.list")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(RadioTheme.ink)
                Spacer()
                NavigationLink("Ver histórico") {
                    RadioSongsView()
                        .environmentObject(appState)
                }
                .font(.caption.weight(.semibold))
            }

            if loadingRecentTracks && recentTracks.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 10)
            } else if recentTracks.isEmpty {
                Text("Sem histórico recente disponível.")
                    .font(.caption)
                    .foregroundStyle(RadioTheme.ink.opacity(0.56))
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(recentTracks.prefix(isWide ? 6 : 4).enumerated()), id: \.offset) {
                        idx, track in
                        HStack(spacing: 10) {
                            recentTrackArtwork(track)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RadioTheme.ink)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption2)
                                    .foregroundStyle(RadioTheme.ink.opacity(0.56))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(relativeTimestamp(track.timestamp) ?? "agora")
                                .font(.caption2)
                                .foregroundStyle(RadioTheme.ink.opacity(0.56))
                        }
                        .padding(isWide ? 12 : 10)
                        .radioPanel(cornerRadius: 14, highlight: RadioTheme.blue)

                        if idx < min(recentTracks.count, isWide ? 6 : 4) - 1 {
                            Divider().opacity(0.18)
                        }
                    }
                }
            }
        }
        .padding(sectionPadding)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: sectionRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: sectionRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .frame(width: contentWidth, alignment: .center)
    }

    @ViewBuilder
    private func recentTrackArtwork(_ track: NowPlaying) -> some View {
        let size: CGFloat = 34

        if let url = track.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(RadioTheme.blue.opacity(0.12))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.caption2)
                                .foregroundStyle(RadioTheme.blue)
                        )
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(RadioTheme.blue.opacity(0.12))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.caption2)
                        .foregroundStyle(RadioTheme.blue)
                )
                .frame(width: size, height: size)
        }
    }

    private func playbackControlsRow(compact: Bool, contentWidth: CGFloat) -> some View {
        HStack {
            Spacer()
            playbackIconButton(systemName: "backward.fill", action: {})
                .opacity(0.55)
            Spacer()
            playbackMainButton
            Spacer()
            playbackIconButton(systemName: "forward.fill", action: {})
                .opacity(0.55)
            Spacer()
        }
        .foregroundStyle(.white)
        .frame(width: compact ? min(214, contentWidth - 44) : min(420, contentWidth))
    }

    private var playbackMainButton: some View {
        Button {
            player.togglePlayPause()
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: isWide ? 88 : 78, height: isWide ? 88 : 78)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )

                if player.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                        .offset(x: player.isPlaying ? 0 : 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func playbackIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isWide ? 32 : 26, weight: .semibold))
                .frame(width: isWide ? 54 : 46, height: isWide ? 54 : 46)
        }
        .buttonStyle(.plain)
    }

    private func immersiveInfoPill(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))

                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func relativeTimestamp(_ iso: String?) -> String? {
        guard let iso else { return nil }
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d1 = df.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date = d1 else { return nil }

        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    @MainActor
    private func loadRecentTracks() async {
        if loadingRecentTracks { return }
        loadingRecentTracks = true
        defer { loadingRecentTracks = false }

        do {
            let resp = try await APIService.shared.fetchRadioHistory(limit: 30)
            let nowKey = appState.nowPlaying?.displayTitle
            recentTracks = resp.items.filter { $0.displayTitle != nowKey }
        } catch {
            if recentTracks.isEmpty {
                recentTracks = []
            }
        }
    }

    @MainActor
    private func refreshEnrichedNowPlaying() async {
        guard let now = appState.nowPlaying else {
            enrichedNowPlaying = nil
            return
        }

        if isStationPromo(now) {
            enrichedNowPlaying = nil
            return
        }

        // If backend already has solid metadata + artwork, no need to call external API.
        if now.artworkURL != nil,
            now.artist.lowercased() != "desconhecido",
            now.album != nil,
            now.genre != nil
        {
            enrichedNowPlaying = nil
            return
        }

        isEnrichingNowPlaying = true
        defer { isEnrichingNowPlaying = false }
        enrichedNowPlaying = await fetchItunesMetadata(for: now)
    }

    private func isStationPromo(_ now: NowPlaying) -> Bool {
        let normalizedTitle = now.title.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedMeta = (now.rawMetadata ?? "").uppercased()
        return normalizedTitle.contains("DIÁRIO FM")
            || normalizedTitle.contains("DIARIO FM")
            || normalizedMeta.contains("DIÁRIO FM")
            || normalizedMeta.contains("DIARIO FM")
    }

    private func factKey(title: String, artist: String) -> String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedArtist)|\(normalizedTitle)"
    }

    @MainActor
    private func refreshArtistFact(for now: NowPlaying) async {
        let requestKey = factKey(title: now.title, artist: now.artist)

        guard appState.nowPlaying != nil else {
            artistFact = nil
            return
        }
        guard !isStationPromo(now) else {
            artistFact = nil
            return
        }

        let artist = effectiveArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !artist.isEmpty, artist.lowercased() != "desconhecido" else {
            artistFact = nil
            return
        }

        if let cached = artistFactCache[artist.lowercased()] {
            artistFact = cached
            return
        }

        isLoadingArtistFact = true
        defer { isLoadingArtistFact = false }

        let fetchedFact = await fetchWikipediaMusicArtistSummary(artist: artist)
        guard requestKey == nowPlayingFactKey else { return }
        artistFact = fetchedFact
        if let fetchedFact {
            artistFactCache[artist.lowercased()] = fetchedFact
        }
    }

    private func fetchWikipediaMusicArtistSummary(artist: String) async -> String? {
        let candidates = [
            "\(artist) (cantor)",
            "\(artist) (cantora)",
            "\(artist) (músico)",
            artist,
        ]

        for page in candidates {
            if let summary = await firstMatchingWikipediaSummary(
                page: page, languages: ["pt", "en"]),
                isMusicContext(summary)
            {
                return summary.extract
            }
        }
        return nil
    }

    @MainActor
    private func refreshSongFact(for now: NowPlaying) async {
        let requestKey = factKey(title: now.title, artist: now.artist)

        guard appState.nowPlaying != nil else {
            songFact = nil
            return
        }
        guard !isStationPromo(now) else {
            songFact = nil
            return
        }

        let title = effectiveTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = effectiveArtist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            songFact = nil
            return
        }

        if let cached = songFactCache[requestKey] {
            songFact = cached
            return
        }

        isLoadingSongFact = true
        defer { isLoadingSongFact = false }

        async let wiki = fetchWikipediaSongSummary(title: title, artist: artist)
        async let itunes = fetchItunesSongFact(title: title, artist: artist)
        let wikiFact = await wiki
        let itunesFact = await itunes
        let fetchedFact = wikiFact ?? itunesFact

        guard requestKey == nowPlayingFactKey else { return }
        songFact = fetchedFact
        if let fetchedFact {
            songFactCache[requestKey] = fetchedFact
        }
    }

    private func fetchWikipediaSongSummary(title: String, artist: String) async -> String? {
        let cleanedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = [
            "\(title) (canção)",
            "\(title) (música)",
            "\(title)",
            cleanedArtist.isEmpty ? nil : "\(title) (\(cleanedArtist) song)",
            cleanedArtist.isEmpty ? nil : "\(title)",
        ].compactMap { $0 }

        for page in candidates {
            if let pt = await fetchWikipediaSummary(page: page, languageCode: "pt") {
                return pt
            }
            if let en = await fetchWikipediaSummary(page: page, languageCode: "en") {
                return en
            }
        }
        return nil
    }

    private func fetchWikipediaSummary(page: String, languageCode: String) async -> String? {
        guard let summary = await fetchWikipediaSummaryData(page: page, languageCode: languageCode)
        else {
            return nil
        }
        return summary.extract
    }

    private func fetchWikipediaSummaryData(page: String, languageCode: String)
        async -> WikipediaSummaryResponse?
    {
        let encoded = page.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? page
        guard
            let url = URL(
                string: "https://\(languageCode).wikipedia.org/api/rest_v1/page/summary/\(encoded)")
        else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode)
            else {
                return nil
            }
            let summary = try JSONDecoder().decode(WikipediaSummaryResponse.self, from: data)
            guard let extract = summary.extract?.trimmingCharacters(in: .whitespacesAndNewlines),
                !extract.isEmpty
            else {
                return nil
            }
            return WikipediaSummaryResponse(
                title: summary.title,
                description: summary.description,
                extract: extract
            )
        } catch {
            return nil
        }
    }

    private func firstMatchingWikipediaSummary(page: String, languages: [String]) async
        -> WikipediaSummaryResponse?
    {
        await withTaskGroup(of: WikipediaSummaryResponse?.self) { group in
            for language in languages {
                group.addTask {
                    await fetchWikipediaSummaryData(page: page, languageCode: language)
                }
            }

            for await summary in group {
                if let summary {
                    return summary
                }
            }

            return nil
        }
    }

    private func isMusicContext(_ summary: WikipediaSummaryResponse) -> Bool {
        let source = [summary.title, summary.description, summary.extract]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        let positiveKeywords = [
            "cantor", "cantora", "músico", "musico", "banda", "rapper", "compositor",
            "singer", "musician", "songwriter", "band", "álbum", "album", "pop", "rock",
        ]
        let negativeKeywords = [
            "falconidae", "gênero de aves", "genero de aves", "ave de rapina", "animal", "bird",
            "genus", "falcão", "falcao",
        ]

        let hasPositive = positiveKeywords.contains { source.contains($0) }
        let hasNegative = negativeKeywords.contains { source.contains($0) }
        return hasPositive && !hasNegative
    }

    private func fetchItunesSongFact(title: String, artist: String) async -> String? {
        var terms: [String] = [title]
        if !artist.isEmpty, artist.lowercased() != "desconhecido" {
            terms.insert(artist, at: 0)
        }

        let query = terms.joined(separator: " ")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard
            let url = URL(
                string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=1")
        else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode)
            else {
                return nil
            }
            let decoded = try JSONDecoder().decode(ItunesSearchResponse.self, from: data)
            guard let track = decoded.results.first else { return nil }

            let year = track.releaseDate.flatMap { String($0.prefix(4)) }
            let durationText: String? = {
                guard let ms = track.trackTimeMillis, ms > 0 else { return nil }
                let totalSec = ms / 1000
                return String(format: "%d:%02d", totalSec / 60, totalSec % 60)
            }()

            var parts: [String] = []
            if let album = track.collectionName, !album.isEmpty {
                parts.append("Álbum: \(album)")
            }
            if let genre = track.primaryGenreName, !genre.isEmpty {
                parts.append("Gênero: \(genre)")
            }
            if let year {
                parts.append("Ano: \(year)")
            }
            if let durationText {
                parts.append("Duração: \(durationText)")
            }

            guard !parts.isEmpty else { return nil }
            return parts.joined(separator: " • ")
        } catch {
            return nil
        }
    }

    private func fetchItunesMetadata(for now: NowPlaying) async -> EnrichedTrack? {
        var terms: [String] = []
        let trimmedArtist = now.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = now.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedArtist.isEmpty, trimmedArtist.lowercased() != "desconhecido" {
            terms.append(trimmedArtist)
        }
        if !trimmedTitle.isEmpty {
            terms.append(trimmedTitle)
        }
        guard !terms.isEmpty else { return nil }

        let query = terms.joined(separator: " ")
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=1"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode)
            else {
                return nil
            }
            let decoded = try JSONDecoder().decode(ItunesSearchResponse.self, from: data)
            guard let first = decoded.results.first else { return nil }

            let artwork = first.artworkUrl100.flatMap {
                URL(string: $0.replacingOccurrences(of: "100x100bb", with: "600x600bb"))
            }
            return EnrichedTrack(
                title: first.trackName ?? trimmedTitle,
                artist: first.artistName ?? trimmedArtist,
                album: first.collectionName,
                genre: first.primaryGenreName,
                artworkURL: artwork,
                itunesURL: first.trackViewUrl
            )
        } catch {
            return nil
        }
    }
}

private struct EnrichedTrack: Equatable {
    let title: String
    let artist: String
    let album: String?
    let genre: String?
    let artworkURL: URL?
    let itunesURL: String?
}

private struct ItunesSearchResponse: Decodable {
    let results: [ItunesTrack]
}

private struct ItunesTrack: Decodable {
    let trackName: String?
    let artistName: String?
    let collectionName: String?
    let artworkUrl100: String?
    let primaryGenreName: String?
    let trackViewUrl: String?
    let releaseDate: String?
    let trackTimeMillis: Int?
}

private struct WikipediaSummaryResponse: Decodable {
    let title: String?
    let description: String?
    let extract: String?
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
