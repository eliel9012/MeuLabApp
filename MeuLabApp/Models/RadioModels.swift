import Foundation

struct NowPlaying: Codable, Equatable {
    let timestamp: String
    let streamUrl: String
    let radioName: String
    let rawMetadata: String?
    let artist: String
    let title: String
    let album: String?
    let artworkUrl: String?
    let itunesUrl: String?
    let genre: String?
    let hasItunes: Bool

    enum CodingKeys: String, CodingKey {
        case timestamp
        case streamUrl = "stream_url"
        case radioName = "radio_name"
        case rawMetadata = "raw_metadata"
        case artist, title, album
        case artworkUrl = "artwork_url"
        case itunesUrl = "itunes_url"
        case genre
        case hasItunes = "has_itunes"
    }

    var displayTitle: String {
        if artist == "Desconhecido" {
            return title
        }
        return "\(artist) - \(title)"
    }

    var artworkURL: URL? {
        guard let urlString = artworkUrl else { return nil }
        return URL(string: urlString)
    }

    // Backends frequentemente mudam `timestamp` mesmo quando a musica/metadata
    // continuam as mesmas. Ignorar `timestamp` evita recomposicoes e trabalho
    // desnecessario (ex.: reload de artwork) a cada polling.
    static func == (lhs: NowPlaying, rhs: NowPlaying) -> Bool {
        lhs.streamUrl == rhs.streamUrl && lhs.radioName == rhs.radioName
            && lhs.rawMetadata == rhs.rawMetadata && lhs.artist == rhs.artist
            && lhs.title == rhs.title && lhs.album == rhs.album && lhs.artworkUrl == rhs.artworkUrl
            && lhs.itunesUrl == rhs.itunesUrl && lhs.genre == rhs.genre
            && lhs.hasItunes == rhs.hasItunes
    }
}

struct RadioHistoryResponse: Codable {
    let ok: Bool?
    let items: [NowPlaying]
    let count: Int?
}

// MARK: - Radio Status (API2)

struct RadioTopSong: Codable {
    let artist: String
    let title: String
    let plays: Int
}

struct RadioStatsData: Codable {
    let total: Int
    let today: Int
    let topSongs: [RadioTopSong]

    enum CodingKeys: String, CodingKey {
        case total, today
        case topSongs = "top_songs"
    }
}

struct RadioStatusResponse: Codable {
    let service: String
    let radioName: String
    let running: Bool
    let dbPath: String?
    let dbExists: Bool?
    let pollIntervalSeconds: Int?
    let duplicateWindowMinutes: Int?
    let retentionDays: Int?
    let lastPollAt: String?
    let lastError: String?
    let stats: RadioStatsData?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case service
        case radioName = "radio_name"
        case running
        case dbPath = "db_path"
        case dbExists = "db_exists"
        case pollIntervalSeconds = "poll_interval_seconds"
        case duplicateWindowMinutes = "duplicate_window_minutes"
        case retentionDays = "retention_days"
        case lastPollAt = "last_poll_at"
        case lastError = "last_error"
        case stats
        case displayName = "display_name"
    }
}

struct RadioStatsResponse: Codable {
    let radioName: String
    let total: Int
    let today: Int
    let topSongs: [RadioTopSong]

    enum CodingKeys: String, CodingKey {
        case radioName = "radio_name"
        case total, today
        case topSongs = "top_songs"
    }
}
