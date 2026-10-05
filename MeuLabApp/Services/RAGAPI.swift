import Foundation

// MARK: - RAG (POST /api/rag/query)
//
// Contrato (bot2/api/rag_api.py no pi5radar):
//   request:  { question (>=3 chars), source: notes|radio_history|adsb_history (padrão notes),
//               use_llm?, use_embeddings?, top_k? (1...8, padrão 4), include_context? }
//   response: { question, source, answer, answer_mode, sources[], retrieval{}, llm_error? }
//   answer_mode: "ollama" (texto gerado), "extractive" (lista de trechos),
//                "extractive_fallback" (LLM falhou, trechos), "not_found".
// O LLM é o Ollama local do Pi (porta 11434); se cair, a API devolve os trechos mesmo assim.

enum RAGSource: String, CaseIterable, Identifiable, Sendable {
    case adsbHistory = "adsb_history"
    case radioHistory = "radio_history"
    case notes

    var id: String { rawValue }

    var label: String {
        switch self {
        case .adsbHistory: return "Radar"
        case .radioHistory: return "Rádio"
        case .notes: return "Notas"
        }
    }

    var symbol: String {
        switch self {
        case .adsbHistory: return "airplane"
        case .radioHistory: return "radio"
        case .notes: return "note.text"
        }
    }

    var placeholder: String {
        switch self {
        case .adsbHistory: return "Ex.: qual foi a velocidade máxima registrada?"
        case .radioHistory: return "Ex.: quais músicas tocaram hoje?"
        case .notes: return "Ex.: o que anotei sobre LGPD?"
        }
    }
}

struct RAGQueryResponse: Decodable, Sendable {
    let question: String
    let source: String
    let answer: String
    let answerMode: String
    let sources: [RAGSourceItem]
    let retrieval: RAGRetrieval?
    let llmError: String?

    enum CodingKeys: String, CodingKey {
        case question, source, answer, sources, retrieval
        case answerMode = "answer_mode"
        case llmError = "llm_error"
    }

    /// Texto gerado pelo LLM (só existe quando answer_mode == "ollama").
    var generatedAnswer: String? {
        guard answerMode == "ollama" else { return nil }
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Fontes com alguma relevância. Sem embeddings, a API pode devolver trechos com score 0.
    var relevantSources: [RAGSourceItem] {
        sources.filter { ($0.score ?? 0) > 0 }
    }

    var llmUnavailable: Bool { answerMode == "extractive_fallback" }
}

struct RAGSourceItem: Decodable, Identifiable, Sendable {
    let source: String
    let documentId: String
    let title: String
    let tags: [String]?
    let updatedAt: String?
    let chunkIndex: Int?
    let score: Double?
    let excerpt: String

    var id: String { "\(documentId)#\(chunkIndex ?? 0)" }

    var originLabel: String {
        RAGSource(rawValue: source)?.label ?? source
    }

    enum CodingKeys: String, CodingKey {
        case source, title, tags, score, excerpt
        case documentId = "document_id"
        case updatedAt = "updated_at"
        case chunkIndex = "chunk_index"
    }
}

struct RAGRetrieval: Decodable, Sendable {
    let documentsScanned: Int?
    let chunksScanned: Int?
    let embeddingsUsed: Bool?

    enum CodingKeys: String, CodingKey {
        case documentsScanned = "documents_scanned"
        case chunksScanned = "chunks_scanned"
        case embeddingsUsed = "embeddings_used"
    }
}

private struct RAGQueryBody: Encodable {
    let question: String
    let source: String
    let topK: Int

    enum CodingKeys: String, CodingKey {
        case question, source
        case topK = "top_k"
    }
}

extension APIService {
    /// Sessão própria: a sessão padrão do APIService corta recursos em 30 s, e uma
    /// geração pelo LLM do Pi pode passar disso. A busca sem LLM responde em ~0,2 s.
    private static let ragSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 75
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    func queryRAG(question: String, source: RAGSource, topK: Int = 4) async throws -> RAGQueryResponse {
        var request = try makeRequest(path: "/api/rag/query")
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RAGQueryBody(question: question, source: source.rawValue, topK: topK)
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await Self.ragSession.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.unknown }
        switch http.statusCode {
        case 200...299: break
        case 401, 403: throw APIError.unauthorized
        default: throw APIError.serverError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(RAGQueryResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
