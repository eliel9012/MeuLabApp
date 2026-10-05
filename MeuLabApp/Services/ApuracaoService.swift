import Foundation

/// Busca o JSON oficial do TSE (espelho Cloudflare) com ETag e cache em memória por URL.
actor ApuracaoService {
    static let shared = ApuracaoService()

    enum Falha: LocalizedError {
        case naoEncontrado
        case http(Int)
        case rede

        var errorDescription: String? {
            switch self {
            case .naoEncontrado: "Arquivo ainda não publicado pelo TSE."
            case .http(let code): "Servidor respondeu \(code)."
            case .rede: "Sem conexão com o servidor."
            }
        }
    }

    private struct Entrada {
        let snapshot: ApuracaoSnapshot
        let etag: String?
    }

    private var cache: [URL: Entrada] = [:]
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        // O ETag é tratado aqui; o cache HTTP do sistema só atrapalharia o 304.
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        session = URLSession(configuration: config)
    }

    func cached(_ url: URL) -> ApuracaoSnapshot? {
        cache[url]?.snapshot
    }

    /// Devolve o snapshot atual. 304 devolve o que já está em cache.
    func buscar(_ url: URL) async throws -> ApuracaoSnapshot {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let anterior = cache[url]
        if let etag = anterior?.etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            #if DEBUG
                print("[Apuração] GET \(url.absoluteString) → erro de rede: \(error.localizedDescription)")
            #endif
            throw Falha.rede
        }
        guard let http = response as? HTTPURLResponse else { throw Falha.rede }
        #if DEBUG
            print("[Apuração] GET \(url.absoluteString) → \(http.statusCode) (\(data.count) bytes)")
        #endif

        switch http.statusCode {
        case 304:
            if let anterior { return anterior.snapshot }
            // ETag sem dados em cache não deveria acontecer; refaz sem condição.
            cache[url] = nil
            return try await buscar(url)
        case 200:
            let snapshot = try ApuracaoSnapshot.decodificar(data, url: url)
            cache[url] = Entrada(snapshot: snapshot, etag: http.value(forHTTPHeaderField: "ETag"))
            return snapshot
        case 404:
            throw Falha.naoEncontrado
        default:
            throw Falha.http(http.statusCode)
        }
    }
}
