import AVKit
import SwiftUI
import UniformTypeIdentifiers

// ============================================================
// SÉRIES
// Reproduz arquivos de vídeo colocados na pasta Documentos do app.
// ============================================================

/// One video file found in the app's Documents directory.
struct Episode: Identifiable, Hashable {
    let url: URL
    let season: Int?
    let number: Int?
    let title: String
    let sizeBytes: Int64
    /// Sidecar files sitting beside the video: "<same name>.jpg" and ".txt".
    /// Sidecars rather than a bundled catalogue, so artwork can be added for a
    /// season that arrives later without rebuilding the app.
    let thumbnailURL: URL?
    let synopsis: String?

    var id: String { url.lastPathComponent }

    /// "S03E01" for a parsed name, otherwise the bare file name.
    var code: String {
        guard let season, let number else { return title }
        return String(format: "S%02dE%02d", season, number)
    }

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

/// A season inside a series.
struct Season: Identifiable {
    let number: Int
    let episodes: [Episode]
    let posterURL: URL?
    var id: Int { number }
}

/// A folder under Documents. One folder, one series.
struct Series: Identifiable {
    let name: String
    let folder: URL
    let seasons: [Season]
    let posterURL: URL?
    var id: String { name }

    var episodeCount: Int { seasons.reduce(0) { $0 + $1.episodes.count } }
}

@MainActor
final class EpisodeLibrary: ObservableObject {
    static let shared = EpisodeLibrary()

    @Published private(set) var series: [Series] = []

    /// Documents is what iOS exposes over Finder file sharing, so this is where
    /// files dragged onto the device land.
    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static let playable: Set<String> = ["mp4", "m4v", "mov"]

    /// Bookmark to a folder the user picked anywhere in Files. Stored because a
    /// rebuild from Xcode can hand the app a fresh data container, which orphans
    /// everything copied into Documents; a folder outside the container survives
    /// that, and nothing has to be duplicated.
    private static let bookmarkKey = "series.externalFolder"

    @Published private(set) var externalFolderName: String?
    private var externalFolder: URL?
    private var externalIsScoped = false

    /// Resolves the saved bookmark, if any. Safe to call repeatedly.
    private func resolveExternalFolder() {
        releaseExternal()
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else {
            externalFolder = nil
            externalFolderName = nil
            return
        }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale
        ) else {
            externalFolder = nil
            externalFolderName = nil
            return
        }
        externalIsScoped = url.startAccessingSecurityScopedResource()
        externalFolder = url
        externalFolderName = url.lastPathComponent
        if stale { saveExternalFolder(url) }
    }

    private func releaseExternal() {
        if externalIsScoped, let externalFolder {
            externalFolder.stopAccessingSecurityScopedResource()
        }
        externalIsScoped = false
    }

    func saveExternalFolder(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        }
        reload()
    }

    func clearExternalFolder() {
        releaseExternal()
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        externalFolder = nil
        externalFolderName = nil
        reload()
    }

    private init() {}

    func reload() {
        resolveExternalFolder()
        let fm = FileManager.default
        let root = Self.documentsURL
        let roots = [root, externalFolder].compactMap { $0 }

        // Walk the whole tree rather than the root plus one level. Dragging a
        // folder in through Finder often brings its wrapper along, which buried
        // the videos two levels down and made the library look empty.
        var byFolder: [URL: [URL]] = [:]
        for base in roots {
            guard let walker = fm.enumerator(
                at: base,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in walker {
                guard Self.playable.contains(url.pathExtension.lowercased()) else { continue }
                byFolder[url.deletingLastPathComponent(), default: []].append(url)
            }
        }

        // A series is named after the folder its episodes sit in; files dropped
        // straight into Documents have no such folder.
        let out = byFolder.map { folder, files -> Series in
            makeSeries(
                name: roots.contains(folder) ? "Outros vídeos" : folder.lastPathComponent,
                folder: folder,
                files: files
            )
        }

        series = out.sorted { $0.name < $1.name }
    }

    private func makeSeries(name: String, folder: URL, files: [URL]) -> Series {
        let fm = FileManager.default

        let episodes = files
            .map { url -> Episode in
                let base = url.deletingPathExtension()
                let (season, number, title) = Self.parse(base.lastPathComponent)
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                let jpg = base.appendingPathExtension("jpg")
                let txt = base.appendingPathExtension("txt")
                return Episode(
                    url: url, season: season, number: number, title: title,
                    sizeBytes: Int64(size),
                    thumbnailURL: fm.fileExists(atPath: jpg.path) ? jpg : nil,
                    synopsis: try? String(contentsOf: txt, encoding: .utf8)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }

        let grouped = Dictionary(grouping: episodes) { $0.season ?? 0 }
        let seasons = grouped.keys.sorted().map { number in
            Season(
                number: number,
                episodes: (grouped[number] ?? []).sorted {
                    ($0.number ?? .max, $0.title) < ($1.number ?? .max, $1.title)
                },
                posterURL: existing(folder.appendingPathComponent("Temporada\(number).jpg"))
            )
        }

        return Series(
            name: name,
            folder: folder,
            seasons: seasons,
            posterURL: existing(folder.appendingPathComponent("poster.jpg"))
        )
    }

    /// What is actually on disk under Documents, listed verbatim. When the library
    /// comes up empty the question is always "did the files land where the app
    /// looks?", and only the app can answer that.
    func diagnostics() -> [String] {
        let fm = FileManager.default
        let root = Self.documentsURL
        var lines: [String] = []
        lines.append(root.path)

        guard let entries = try? fm.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey], options: []
        ) else {
            lines.append("— não foi possível ler a pasta —")
            return lines
        }
        if entries.isEmpty {
            lines.append("— pasta vazia —")
            return lines
        }
        for e in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let vals = try? e.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            if vals?.isDirectory == true {
                let inner = (try? fm.contentsOfDirectory(atPath: e.path))?.count ?? 0
                lines.append("📁 \(e.lastPathComponent) — \(inner) itens")
                let mp4 = (try? fm.contentsOfDirectory(atPath: e.path))?
                    .filter { $0.lowercased().hasSuffix(".mp4") }.count ?? 0
                lines.append("    \(mp4) .mp4")
            } else {
                let size = Int64(vals?.fileSize ?? 0)
                lines.append("📄 \(e.lastPathComponent) — \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
            }
        }
        return lines
    }

    private func existing(_ url: URL) -> URL? {
        FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// "S03E01 - Suzie, Do You Copy" -> (3, 1, "Suzie, Do You Copy").
    /// Anything unparseable keeps its whole name as the title rather than being
    /// hidden, so a file the user dropped in is never silently missing.
    private static func parse(_ name: String) -> (Int?, Int?, String) {
        guard let m = name.firstMatch(of: /[Ss](\d{1,2})[Ee](\d{1,3})/) else {
            return (nil, nil, name)
        }
        var title = name
        if let range = name.range(of: m.0) {
            title = String(name[range.upperBound...])
        }
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: " -–—_."))
        return (Int(m.1), Int(m.2), title.isEmpty ? name : title)
    }
}

// MARK: - Retomada

/// Where each file was last left off. Keyed by file name so moving the app or
/// re-importing the same episode keeps the position.
enum PlaybackProgress {
    private static let key = "series.progress"
    /// Below this, treat it as "not really started" and play from the top.
    private static let minimumToRemember: Double = 30
    /// Within this of the end, the episode counts as watched and restarts.
    private static let endThreshold: Double = 60

    static func seconds(for episode: Episode) -> Double? {
        let map = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        guard let value = map[episode.id], value >= minimumToRemember else { return nil }
        return value
    }

    static func save(_ seconds: Double, duration: Double, for episode: Episode) {
        var map = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        if duration > 0, seconds >= duration - endThreshold {
            map.removeValue(forKey: episode.id)
        } else if seconds >= minimumToRemember {
            map[episode.id] = seconds
        } else {
            map.removeValue(forKey: episode.id)
        }
        UserDefaults.standard.set(map, forKey: key)
    }

    static func fraction(for episode: Episode, duration: Double) -> Double? {
        guard duration > 0, let s = seconds(for: episode) else { return nil }
        return min(max(s / duration, 0), 1)
    }

    static func clear(_ episode: Episode) {
        var map = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        map.removeValue(forKey: episode.id)
        UserDefaults.standard.set(map, forKey: key)
    }
}

// MARK: - Player

/// `AVPlayerViewController` rather than hand-rolled controls: it brings the
/// subtitle picker (which is what surfaces the embedded pt-BR track), AirPlay,
/// Picture in Picture and the scrubber for free.
struct EpisodePlayer: UIViewControllerRepresentable {
    let episode: Episode
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let item = AVPlayerItem(url: episode.url)
        let player = AVPlayer(playerItem: item)
        player.allowsExternalPlayback = true

        if let resume = PlaybackProgress.seconds(for: episode) {
            player.seek(to: CMTime(seconds: resume, preferredTimescale: 600))
        }

        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        context.coordinator.observe(player: player, item: item, episode: episode)
        player.play()
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Coordinator) {
        coordinator.persist()
        controller.player?.pause()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var player: AVPlayer?
        private var episode: Episode?
        private var timeObserver: Any?

        func observe(player: AVPlayer, item: AVPlayerItem, episode: Episode) {
            self.player = player
            self.episode = episode
            // Every five seconds is frequent enough to survive a crash and rare
            // enough to be free.
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 5, preferredTimescale: 1),
                queue: .main
            ) { [weak self] _ in
                self?.persist()
            }
        }

        func persist() {
            guard let player, let episode,
                let item = player.currentItem,
                item.duration.isNumeric
            else { return }
            PlaybackProgress.save(
                player.currentTime().seconds,
                duration: item.duration.seconds,
                for: episode
            )
        }

        deinit {
            if let timeObserver, let player {
                player.removeTimeObserver(timeObserver)
            }
        }
    }
}

// MARK: - Peças reutilizadas

/// Artwork loaded straight off disk. These are local files a few dozen KB each,
/// so there is nothing to cache or fetch.
private struct DiskImage: View {
    let url: URL?
    /// nil means "fill the available width" — passing .infinity to frame(width:)
    /// makes the frame genuinely infinite and drags the surrounding layout off
    /// the leading edge.
    var width: CGFloat?
    let height: CGFloat
    var corner: CGFloat = 8
    var placeholder: String = "film"

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.accentColor.opacity(0.15)
                    Image(systemName: placeholder)
                        .font(.system(size: min(width ?? height, height) * 0.32))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .frame(maxWidth: width == nil ? .infinity : width, maxHeight: height)
        .frame(height: height)
        // clipShape only masks the drawing; clipped() is what stops the oversized
        // image from aspectRatio(.fill) reporting its own width to the layout.
        .clipped()
        .clipShape(shape)
    }
}

private func timeText(_ seconds: Double) -> String {
    let total = Int(seconds)
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0
        ? String(format: "%d:%02d:%02d", h, m, s)
        : String(format: "%d:%02d", m, s)
}

// MARK: - Nível 1: séries

struct SeriesView: View {
    @StateObject private var library = EpisodeLibrary.shared
    @State private var pickingFolder = false
    @State private var pickError: String?

    var body: some View {
        Group {
            if library.series.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(library.series) { series in
                        NavigationLink {
                            SeriesDetailView(series: series)
                        } label: {
                            HStack(spacing: 14) {
                                DiskImage(url: series.posterURL, width: 60, height: 88, corner: 8)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(series.name)
                                        .font(.system(size: 17, weight: .semibold))
                                    Text(subtitle(for: series))
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Séries")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { library.reload() }
        .refreshable { library.reload() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        pickingFolder = true
                    } label: {
                        Label("Escolher pasta de vídeos…", systemImage: "folder.badge.plus")
                    }
                    if let name = library.externalFolderName {
                        Button(role: .destructive) {
                            library.clearExternalFolder()
                        } label: {
                            Label("Parar de usar \(name)", systemImage: "folder.badge.minus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fileImporter(
            isPresented: $pickingFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { library.saveExternalFolder(url) }
            case .failure(let error):
                pickError = error.localizedDescription
            }
        }
        .alert("Não foi possível abrir a pasta", isPresented: .constant(pickError != nil)) {
            Button("OK") { pickError = nil }
        } message: {
            Text(pickError ?? "")
        }
    }

    private func subtitle(for series: Series) -> String {
        let s = series.seasons.count
        let e = series.episodeCount
        let seasons = s == 1 ? "1 temporada" : "\(s) temporadas"
        let episodes = e == 1 ? "1 episódio" : "\(e) episódios"
        return "\(seasons) · \(episodes)"
    }

    private var emptyState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Nenhum vídeo", systemImage: "film.stack")
                    .font(.system(size: 20, weight: .semibold))

                Text(
                    "Conecte o iPhone ao Mac, abra o Finder, escolha o aparelho na barra lateral e vá em Arquivos › MeuLab. Crie uma pasta com o nome da série e arraste os .mp4 para dentro."
                )
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

                Divider()

                Text("O QUE O APP ESTÁ VENDO")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 3) {
                    ForEach(library.diagnostics(), id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary.opacity(0.75))
                            .textSelection(.enabled)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        pickingFolder = true
                    } label: {
                        Label("Escolher pasta", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        library.reload()
                    } label: {
                        Label("Procurar de novo", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)

                Text(
                    "Se você copiou os vídeos para o iPhone e eles não aparecem, use \"Escolher pasta\" e aponte para onde eles estão no app Arquivos. O app lê de lá sem copiar nada."
                )
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }
}

// MARK: - Nível 2: temporadas

struct SeriesDetailView: View {
    let series: Series

    var body: some View {
        List {
            if series.posterURL != nil {
                Section {
                    HStack {
                        Spacer()
                        DiskImage(url: series.posterURL, width: 150, height: 220, corner: 12)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            Section("Temporadas") {
                ForEach(series.seasons) { season in
                    NavigationLink {
                        SeasonDetailView(series: series, season: season)
                    } label: {
                        HStack(spacing: 14) {
                            DiskImage(
                                url: season.posterURL ?? series.posterURL,
                                width: 52, height: 76, corner: 6
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(season.number == 0 ? "Sem temporada" : "Temporada \(season.number)")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(watchedText(season))
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle(series.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Counts what is in progress so a half-watched season is visible from here.
    private func watchedText(_ season: Season) -> String {
        let total = season.episodes.count
        let started = season.episodes.filter { PlaybackProgress.seconds(for: $0) != nil }.count
        let base = total == 1 ? "1 episódio" : "\(total) episódios"
        return started > 0 ? "\(base) · \(started) em andamento" : base
    }
}

// MARK: - Nível 3: episódios da temporada

struct SeasonDetailView: View {
    let series: Series
    let season: Season

    var body: some View {
        List {
            ForEach(season.episodes) { episode in
                NavigationLink {
                    EpisodeDetailView(episode: episode)
                } label: {
                    HStack(spacing: 12) {
                        DiskImage(
                            url: episode.thumbnailURL, width: 104, height: 58,
                            corner: 8, placeholder: "play.fill"
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(episode.code)
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(episode.title)
                                .font(.system(size: 15, weight: .semibold))
                                .multilineTextAlignment(.leading)
                            if let seconds = PlaybackProgress.seconds(for: episode) {
                                Text("Continuar de \(timeText(seconds))")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Color.accentColor)
                            } else {
                                Text(episode.sizeText)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .navigationTitle(season.number == 0 ? series.name : "Temporada \(season.number)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Nível 4: episódio

struct EpisodeDetailView: View {
    let episode: Episode
    @State private var playing = false
    @State private var sharing = false
    @State private var resume: Double?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Full-bleed on purpose: putting the padding on the text below
                // instead keeps the column exactly the screen's width. Padding the
                // whole stack made it 36pt wider and clipped both edges.
                DiskImage(
                    url: episode.thumbnailURL, width: nil, height: 210,
                    corner: 0, placeholder: "play.fill"
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(episode.code)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(episode.title)
                        .font(.system(size: 22, weight: .bold))
                    Text(episode.sizeText)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)

                if let synopsis = episode.synopsis, !synopsis.isEmpty {
                    Text(synopsis)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 18)
                }

                VStack(spacing: 10) {
                    Button {
                        playing = true
                    } label: {
                        Label(
                            resume != nil ? "Continuar de \(timeText(resume!))" : "Reproduzir",
                            systemImage: "play.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if resume != nil {
                        Button {
                            PlaybackProgress.clear(episode)
                            resume = nil
                        } label: {
                            Label("Recomeçar do início", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }

                    Button {
                        sharing = true
                    } label: {
                        Label("Enviar via AirDrop", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal, 18)
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(episode.code)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { resume = PlaybackProgress.seconds(for: episode) }
        .fullScreenCover(isPresented: $playing, onDismiss: {
            resume = PlaybackProgress.seconds(for: episode)
        }) {
            EpisodePlayer(episode: episode, isPresented: $playing)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $sharing) {
            ShareSheet(activityItems: [episode.url])
        }
    }
}
