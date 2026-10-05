import Foundation

/// Apresentações FDF 2026 servidas pelo serviço `fdf-slides` no Pi5.
enum SlideDeck: String, CaseIterable, Identifiable, Sendable {
    case gt3
    case gt8

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .gt3: return "GT3"
        case .gt8: return "GT8"
        }
    }

    var subtitle: String {
        switch self {
        case .gt3: return "Integridade informacional · IA jurídica"
        case .gt8: return "ODR · Direito Preventivo"
        }
    }

    /// Endereço da tela na rede local (porta do fdf-slides no Pi5).
    var lanURL: String {
        switch self {
        case .gt3: return "http://192.168.100.136:8801"
        case .gt8: return "http://192.168.100.136:8802"
        }
    }
}

enum SlideAction: String, Sendable {
    case next, prev, first, last, reload
}

struct SlidesState: Decodable, Sendable {
    let deck: String
    let slide: Int?
    let total: Int?
    let screens: Int
    let updated: Double?
}

extension APIService {
    func fetchSlidesState(_ deck: SlideDeck) async throws -> SlidesState {
        try await fetch("/api/slides/\(deck.rawValue)")
    }

    func sendSlidesAction(_ action: SlideAction, deck: SlideDeck) async throws -> SlidesState {
        try await postSlides("/api/slides/\(deck.rawValue)/\(action.rawValue)")
    }

    func gotoSlide(_ slide: Int, deck: SlideDeck) async throws -> SlidesState {
        try await postSlides("/api/slides/\(deck.rawValue)/goto?slide=\(slide)")
    }

    private func postSlides(_ path: String) async throws -> SlidesState {
        var request = try makeRequest(path: path)
        request.httpMethod = "POST"
        // Sem retry: repetir um "next" pularia dois slides.
        let (data, _) = try await performRequest(request, retries: 0)
        do {
            return try JSONDecoder().decode(SlidesState.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
