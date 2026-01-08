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
}
