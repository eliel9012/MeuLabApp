import AVKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

private struct VisionEpisode: Identifiable, Hashable {
    let url: URL
    let season: Int?
    let number: Int?
    let title: String
    let size: Int64
    let artwork: URL?
    let synopsis: String?
    var id: String { url.path }
    var code: String {
        guard let season, let number else { return url.deletingPathExtension().lastPathComponent }
        return String(format: "S%02dE%02d", season, number)
    }
}

private struct VisionSeason: Identifiable {
    let number: Int
    let episodes: [VisionEpisode]
    let artwork: URL?
    var id: Int { number }
}

private struct VisionSeries: Identifiable {
    let name: String
    let seasons: [VisionSeason]
    let artwork: URL?
    var id: String { name }
    var episodeCount: Int { seasons.reduce(0) { $0 + $1.episodes.count } }
}

@MainActor @Observable
private final class VisionSeriesLibrary {
    var series: [VisionSeries] = []
    var selectedFolderName: String?
    var error: String?
    private var externalFolder: URL?
    private var scoped = false
    private let bookmarkKey = "vision.series.externalFolder"
    private let extensions: Set<String> = ["mp4", "m4v", "mov"]

    private var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    func selectFolder(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            reload()
        } catch { self.error = error.localizedDescription }
    }

    func clearFolder() {
        releaseFolder()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        reload()
    }

    func reload() {
        releaseFolder()
        if let data = UserDefaults.standard.data(forKey: bookmarkKey) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                scoped = url.startAccessingSecurityScopedResource()
                externalFolder = url
                selectedFolderName = url.lastPathComponent
                if stale, let refreshed = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
                }
            }
        }
        let roots = [documents, externalFolder].compactMap { $0 }
        let fm = FileManager.default
        var byFolder: [URL: [URL]] = [:]
        for root in roots {
            guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                                             options: [.skipsHiddenFiles]) else { continue }
            for case let file as URL in walker where extensions.contains(file.pathExtension.lowercased()) {
                byFolder[file.deletingLastPathComponent(), default: []].append(file)
            }
        }
        series = byFolder.map { folder, files in
            let episodes: [VisionEpisode] = files.map { file in
                let base = file.deletingPathExtension()
                let parsed = Self.parse(base.lastPathComponent)
                let thumbnail = base.appendingPathExtension("jpg")
                let text = base.appendingPathExtension("txt")
                return .init(url: file, season: parsed.0, number: parsed.1, title: parsed.2,
                             size: Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0),
                             artwork: fm.fileExists(atPath: thumbnail.path) ? thumbnail : nil,
                             synopsis: try? String(contentsOf: text, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))
            }
            let groups = Dictionary(grouping: episodes) { $0.season ?? 0 }
            let seasons = groups.keys.sorted().map { number in
                VisionSeason(number: number,
                             episodes: (groups[number] ?? []).sorted { ($0.number ?? .max, $0.title) < ($1.number ?? .max, $1.title) },
                             artwork: Self.existing(folder.appendingPathComponent("Temporada\(number).jpg")))
            }
            return VisionSeries(name: roots.contains(folder) ? "Outros vídeos" : folder.lastPathComponent,
                                seasons: seasons, artwork: Self.existing(folder.appendingPathComponent("poster.jpg")))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        error = nil
    }

    private func releaseFolder() {
        if scoped { externalFolder?.stopAccessingSecurityScopedResource() }
        scoped = false
        externalFolder = nil
        selectedFolderName = nil
    }

    private static func existing(_ url: URL) -> URL? { FileManager.default.fileExists(atPath: url.path) ? url : nil }

    private static func parse(_ name: String) -> (Int?, Int?, String) {
        guard let range = name.range(of: #"[Ss][0-9]{1,2}[Ee][0-9]{1,3}"#, options: .regularExpression) else {
            return (nil, nil, name)
        }
        let code = String(name[range]).uppercased().split(separator: "E")
        let season = Int(code.first?.dropFirst() ?? "")
        let number = Int(code.last ?? "")
        let title = name[range.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: " -–—_."))
        return (season, number, title.isEmpty ? name : title)
    }
}

private enum VisionPlaybackProgress {
    static func seconds(for episode: VisionEpisode) -> Double? {
        let progress = UserDefaults.standard.dictionary(forKey: "vision.series.progress") as? [String: Double] ?? [:]
        guard let seconds = progress[episode.url.lastPathComponent], seconds >= 30 else { return nil }
        return seconds
    }

    static func save(_ seconds: Double, duration: Double, for episode: VisionEpisode) {
        var progress = UserDefaults.standard.dictionary(forKey: "vision.series.progress") as? [String: Double] ?? [:]
        let key = episode.url.lastPathComponent
        if duration > 0 && seconds >= duration - 60 || seconds < 30 { progress.removeValue(forKey: key) }
        else { progress[key] = seconds }
        UserDefaults.standard.set(progress, forKey: "vision.series.progress")
    }
}

struct VisionSeriesView: View {
    @State private var library = VisionSeriesLibrary()
    @State private var importing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Label("Séries", systemImage: "film.stack").font(.largeTitle.bold())
                        Spacer()
                        Button("Escolher pasta", systemImage: "folder.badge.plus") { importing = true }
                        Button("Atualizar", systemImage: "arrow.clockwise") { library.reload() }
                    }
                    if let selected = library.selectedFolderName {
                        HStack {
                            Text("Pasta: \(selected)").foregroundStyle(.secondary)
                            Button("Desconectar") { library.clearFolder() }
                        }
                    }
                    if let error = library.error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                    if library.series.isEmpty {
                        ContentUnavailableView("Nenhum vídeo encontrado", systemImage: "film.stack",
                                               description: Text("Escolha uma pasta no app Arquivos com vídeos .mp4, .m4v ou .mov. Pastas viram séries; nomes S01E01 viram episódios."))
                    } else {
                        ForEach(library.series) { series in
                            NavigationLink {
                                VisionSeriesDetailView(series: series)
                            } label: {
                                HStack(spacing: 18) {
                                    VisionSeriesArtwork(url: series.artwork, width: 90, height: 120)
                                    VStack(alignment: .leading, spacing: 7) {
                                        Text(series.name).font(.title2.bold())
                                        Text("\(series.seasons.count) temporadas · \(series.episodeCount) episódios")
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding(16)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(28)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .onAppear { library.reload() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url): library.selectFolder(url)
            case .failure(let error): library.error = error.localizedDescription
            }
        }
    }
}

private struct VisionSeriesDetailView: View {
    let series: VisionSeries

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(series.name).font(.largeTitle.bold())
                ForEach(series.seasons) { season in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(season.number == 0 ? "Sem temporada" : "Temporada \(season.number)").font(.title2.bold())
                        ForEach(season.episodes) { episode in
                            NavigationLink {
                                VisionEpisodeView(episode: episode)
                            } label: {
                                HStack(spacing: 14) {
                                    VisionSeriesArtwork(url: episode.artwork ?? season.artwork ?? series.artwork, width: 110, height: 70)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(episode.code).font(.caption.monospaced()).foregroundStyle(.secondary)
                                        Text(episode.title).font(.headline)
                                        Text(VisionPlaybackProgress.seconds(for: episode).map { "Continuar de \(Int($0 / 60)) min" }
                                             ?? ByteCountFormatter.string(fromByteCount: episode.size, countStyle: .file))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle")
                                }
                                .padding(12)
                                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(28)
        }
        .navigationTitle(series.name)
    }
}

private struct VisionEpisodeView: View {
    let episode: VisionEpisode
    @State private var player: AVPlayer

    init(episode: VisionEpisode) {
        self.episode = episode
        _player = State(initialValue: AVPlayer(url: episode.url))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(episode.title).font(.largeTitle.bold())
                Text(episode.code).font(.subheadline.monospaced()).foregroundStyle(.secondary)
                VideoPlayer(player: player)
                    .frame(height: 440)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                if let synopsis = episode.synopsis, !synopsis.isEmpty {
                    Text(synopsis).font(.title3).textSelection(.enabled)
                }
                Text(ByteCountFormatter.string(fromByteCount: episode.size, countStyle: .file))
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(28)
        }
        .navigationTitle(episode.code)
        .task {
            if let resume = VisionPlaybackProgress.seconds(for: episode) {
                await player.seek(to: CMTime(seconds: resume, preferredTimescale: 600))
            }
            player.play()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                saveProgress()
            }
        }
        .onDisappear { saveProgress(); player.pause() }
    }

    private func saveProgress() {
        let current = player.currentTime().seconds
        let duration = player.currentItem?.duration.seconds ?? 0
        guard current.isFinite, duration.isFinite else { return }
        VisionPlaybackProgress.save(current, duration: duration, for: episode)
    }
}

private struct VisionSeriesArtwork: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let url, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "film.stack").resizable().scaledToFit().padding(22)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: width, height: height)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
