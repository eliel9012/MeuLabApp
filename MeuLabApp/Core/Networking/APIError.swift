import Foundation

/// Erros de API com sugestões de recuperação
enum APIError: Error, LocalizedError, Equatable {
    case invalidURL
    case networkError(String)
    case decodingError(String)
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida"
        case .networkError(let message):
            return "Erro de rede: \(message)"
        case .decodingError(let message):
            return "Erro ao processar dados: \(message)"
        case .unauthorized:
            return "Não autorizado - verifique suas credenciais"
        case .forbidden:
            return "Acesso negado"
        case .notFound:
            return "Recurso não encontrado"
        case .serverError(let code):
            return "Erro do servidor: \(code)"
        case .timeout:
            return "Timeout na requisição"
        case .unknown(let message):
            return "Erro desconhecido: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Verifique sua conexão de internet e tente novamente"
        case .unauthorized:
            return "Execute login novamente com suas credenciais"
        case .forbidden:
            return "Você não possui permissão para acessar este recurso"
        case .notFound:
            return "O recurso solicitado não existe mais"
        case .serverError(let code) where code >= 500:
            return "O servidor está com problemas. Tente novamente mais tarde"
        case .timeout:
            return "A requisição demorou muito. Verifique sua conexão"
        default:
            return nil
        }
    }

    var failureReason: String? {
        switch self {
        case .invalidURL:
            return "A URL construída é inválida"
        case .networkError(let message):
            return message
        case .decodingError(let message):
            return message
        case .unauthorized:
            return "Token inválido ou expirado"
        case .serverError(let code):
            return "Servidor retornou status \(code)"
        case .timeout:
            return "Tempo limite de conexão excedido"
        case .unknown(let message):
            return message
        default:
            return nil
        }
    }

    // MARK: - Equatable

    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.timeout, .timeout):
            return true
        case (.networkError(let lMsg), .networkError(let rMsg)):
            return lMsg == rMsg
        case (.decodingError(let lMsg), .decodingError(let rMsg)):
            return lMsg == rMsg
        case (.serverError(let lCode), .serverError(let rCode)):
            return lCode == rCode
        case (.unknown(let lMsg), .unknown(let rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }

    // MARK: - Helper

    /// Converte um erro genérico em APIError
    static func from(_ error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .networkError("Sem conexão de internet")
            default:
                return .networkError(error.localizedDescription)
            }
        }

        return .unknown(error.localizedDescription)
    }
}
