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
        lhs.streamUrl == rhs.streamUrl &&
        lhs.radioName == rhs.radioName &&
        lhs.rawMetadata == rhs.rawMetadata &&
        lhs.artist == rhs.artist &&
        lhs.title == rhs.title &&
        lhs.album == rhs.album &&
        lhs.artworkUrl == rhs.artworkUrl &&
        lhs.itunesUrl == rhs.itunesUrl &&
        lhs.genre == rhs.genre &&
        lhs.hasItunes == rhs.hasItunes
    }
}

struct RadioHistoryResponse: Codable {
    let ok: Bool?
    let items: [NowPlaying]
    let count: Int?
}
