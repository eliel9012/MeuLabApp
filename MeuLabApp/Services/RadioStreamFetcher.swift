import Foundation

enum RadioNowPlayingError: Error {
    case metadataUnavailable
    case invalidResponse
}

struct RadioStreamFetcher {
    private static let streamURL = URL(string: "http://51-222-26-208.webnow.com.br/diario.mp3")!
    private static let displayStreamURL = "https://rrdns-megasistema.webnow.com.br/diario.aac"
    private static let radioName = "Diário FM"

    static func fetch() async throws -> NowPlaying {
        let metadata = try await fetchICYMetadata()
        var artist = "Desconhecido"
        var title = metadata ?? "Sem informação"

        if let meta = metadata, meta.contains(" - ") {
            let parts = meta.split(separator: "-", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                artist = parts[0]
                title = parts[1]
            }
        }

        var album: String?
        var artworkUrl: String?
        var itunesUrl: String?
        var genre: String?
        var hasItunes = false

        if artist != "Desconhecido" {
            if let itunes = try? await searchItunes(artist: artist, title: title) {
                artist = itunes.artistName ?? artist
                title = itunes.trackName ?? title
                album = itunes.collectionName
                artworkUrl = itunes.artworkUrl
                itunesUrl = itunes.trackViewUrl
                genre = itunes.primaryGenreName
                hasItunes = true
            }
        }

        return NowPlaying(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            streamUrl: Self.displayStreamURL,
            radioName: Self.radioName,
            rawMetadata: metadata,
            artist: artist,
            title: title,
            album: album,
            artworkUrl: artworkUrl,
            itunesUrl: itunesUrl,
            genre: genre,
            hasItunes: hasItunes
        )
    }

    private static func fetchICYMetadata() async throws -> String? {
        var request = URLRequest(url: streamURL)
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")

        let session = URLSession(configuration: .ephemeral)
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw RadioNowPlayingError.invalidResponse }
        guard let metaintString = http.value(forHTTPHeaderField: "icy-metaint"), let metaint = Int(metaintString) else {
            return nil
        }

        var iterator = bytes.makeIterator()
        // Skip metaint bytes
        for _ in 0..<metaint {
            guard iterator.next() != nil else { return nil }
        }
        // Meta length byte
        guard let lenByte = iterator.next() else { return nil }
        let metaLength = Int(lenByte) * 16
        if metaLength == 0 { return nil }

        var metaData = [UInt8]()
        for _ in 0..<metaLength {
            guard let b = iterator.next() else { break }
            metaData.append(b)
        }
        let metaString = String(bytes: metaData, encoding: .utf8) ?? ""
        if let range = metaString.range(of: "StreamTitle='"), let end = metaString.range(of: "';", range: range.upperBound..<metaString.endIndex) {
            let titleRange = range.upperBound..<end.lowerBound
            return String(metaString[titleRange])
        }
        return nil
    }

    private struct ITunesResponse: Decodable {
        struct Item: Decodable {
            let artistName: String?
            let trackName: String?
            let collectionName: String?
            let artworkUrl100: String?
            let previewUrl: String?
            let trackViewUrl: String?
            let primaryGenreName: String?
        }
        let resultCount: Int
        let results: [Item]
    }

    private struct ITunesResult {
        let artistName: String?
        let trackName: String?
        let collectionName: String?
        let artworkUrl: String?
        let trackViewUrl: String?
        let primaryGenreName: String?
    }

    private static func searchItunes(artist: String, title: String) async throws -> ITunesResult? {
        let query = "\(artist) \(title)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        var comps = URLComponents(string: "https://itunes.apple.com/search")!
        comps.queryItems = [
            .init(name: "term", value: query),
            .init(name: "media", value: "music"),
            .init(name: "entity", value: "song"),
            .init(name: "limit", value: "1"),
            .init(name: "country", value: "BR"),
        ]
        guard let url = comps.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("MeuLabApp/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let decoded = try JSONDecoder().decode(ITunesResponse.self, from: data)
        guard let first = decoded.results.first else { return nil }
        var artwork: String?
        if let art = first.artworkUrl100 {
            artwork = art.replacingOccurrences(of: "100x100", with: "600x600")
        }
        return ITunesResult(
            artistName: first.artistName,
            trackName: first.trackName,
            collectionName: first.collectionName,
            artworkUrl: artwork,
            trackViewUrl: first.trackViewUrl,
            primaryGenreName: first.primaryGenreName
        )
    }
}
