import Foundation

/// Níveis de log
enum LogLevel: String, CaseIterable {
    case debug = "🔍 DEBUG"
    case info = "ℹ️  INFO"
    case warning = "⚠️  WARNING"
    case error = "❌ ERROR"
    case critical = "🚨 CRITICAL"

    var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return self == .error || self == .critical
        #endif
    }
}

/// Logger centralizado para a aplicação
struct Logger {
    static let shared = Logger()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// Registra uma mensagem
    /// - Parameters:
    ///   - message: Mensagem a ser registrada
    ///   - level: Nível do log (padrão: info)
    ///   - file: Arquivo de origem (automático)
    ///   - function: Função de origem (automático)
    ///   - line: Linha de origem (automática)
    func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level.isEnabled else { return }

        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = """
        [\(timestamp)] \(level.rawValue)
        📍 \(fileName):\(line) - \(function)
        💬 \(message)
        """

        #if DEBUG
        print(logMessage)
        #endif

        // Aqui você pode adicionar persistência de logs se necessário
        persistLog(logMessage, level: level)
    }

    /// Log de sucesso para requisições
    func logRequest(method: String, url: String, level: LogLevel = .debug) {
        log("→ \(method) \(url)", level: level)
    }

    /// Log de resposta
    func logResponse(statusCode: Int, url: String, duration: TimeInterval, level: LogLevel = .debug) {
        let status = statusCode >= 200 && statusCode < 300 ? "✅" : "❌"
        log("\(status) \(statusCode) \(url) (\(String(format: "%.3f", duration))s)", level: level)
    }

    /// Log de erro com contexto
    func logError(_ error: Error, context: String, level: LogLevel = .error) {
        log("Erro em \(context): \(error.localizedDescription)", level: level)
    }

    // MARK: - Persistência (Placeholder)

    private func persistLog(_ message: String, level: LogLevel) {
        // TODO: Implementar persistência de logs em arquivo se necessário
        // Por enquanto, apenas imprime no console
    }
}

// Extensão para logging global
extension Logger {
    /// Logger padrão global
    static func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.shared.log(message, level: .debug, file: file, function: function, line: line)
    }

    static func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.shared.log(message, level: .info, file: file, function: function, line: line)
    }

    static func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.shared.log(message, level: .warning, file: file, function: function, line: line)
    }

    static func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.shared.log(message, level: .error, file: file, function: function, line: line)
    }

    static func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        Logger.shared.log(message, level: .critical, file: file, function: function, line: line)
    }
}
