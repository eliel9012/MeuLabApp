import Foundation
import SwiftUI

#if canImport(FoundationModels)
    import FoundationModels

    enum IntelligenceSessionMode: String, Codable, Sendable {
        case assistant
        case incident
    }

    struct IntelligenceToolTrace: Codable, Equatable, Identifiable, Sendable {
        let id: String
        let toolName: String
        let preview: String

        init(id: String = UUID().uuidString, toolName: String, preview: String) {
            self.id = id
            self.toolName = toolName
            self.preview = preview
        }
    }

    @Generable
    struct IntelligenceGeneratedAction {
        var title: String
        var systemImage: String
        var prompt: String?
        var tab: String?
        var contextIdentifier: String?
        var style: String?
    }

    @Generable
    struct IntelligenceGeneratedResponse {
        var title: String
        var summary: String
        var highlights: [String]
        var evidence: [String]
        var suggestedActions: [IntelligenceGeneratedAction]
        var followUpQuestion: String?
        var confidenceNote: String?
        var severity: String?
    }

    struct IntelligenceStructuredResult {
        let response: IntelligenceGeneratedResponse
        let toolTrace: [IntelligenceToolTrace]
    }

    private func compactPassLabel(_ text: String) -> String {
        text
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "NOAA", with: "NOAA ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedPreview(_ text: String, maxLength: Int = 140) -> String {
        let compact = text
            .replacingOccurrences(of: "\n", with: " • ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > maxLength else { return compact }
        let end = compact.index(compact.startIndex, offsetBy: maxLength)
        return String(compact[..<end]) + "…"
    }

    // MARK: - Tools para o modelo on-device consultar dados do app

    struct ADSBRadarTool: Tool {
        let name = "getADSBRadar"
        let description =
            "Retorna dados do radar ADS-B: aeronaves ao vivo, resumo de tráfego aéreo, alertas, destaques e estatísticas."

        @Generable
        struct Arguments {
            @Guide(
                description:
                    "Filtro opcional: 'resumo', 'alertas', 'mais_rapida', 'mais_proxima', 'companhias', ou vazio para tudo"
            )
            var filtro: String?
        }

        let snapshotProvider: @Sendable () -> LabIntelligenceSnapshot

        func call(arguments: Arguments) async throws -> String {
            let snap = snapshotProvider()
            let total = snap.adsbSummary?.totalNow ?? snap.aircraft.count
            let withPos =
                snap.adsbSummary?.withPos
                ?? snap.aircraft.filter { $0.lat != nil && $0.lon != nil }.count
            let fastest = snap.aircraft.max(by: { $0.speedKt < $1.speedKt })
            let closest = snap.aircraft
                .filter { $0.distanceNm != nil }
                .min(by: { ($0.distanceNm ?? .greatestFiniteMagnitude) < ($1.distanceNm ?? .greatestFiniteMagnitude) })

            var lines: [String] = [
                "Aeronaves ao vivo: \(total)",
                "Com posição: \(withPos)",
                "Alertas ativos: \(snap.adsbAlerts.count)",
            ]

            if let fastest {
                lines.append("Mais rápida: \(fastest.displayCallsign) a \(fastest.speedKt) kt")
            }
            if let closest, let distance = closest.distanceNm {
                lines.append("Mais próxima: \(closest.displayCallsign) a \(String(format: "%.1f", distance)) nm")
            }

            let preview = snap.aircraft
                .sorted { ($0.distanceNm ?? .greatestFiniteMagnitude) < ($1.distanceNm ?? .greatestFiniteMagnitude) }
                .prefix(6)
                .map { ac in
                    let distance = ac.distanceNm.map { String(format: "%.1f nm", $0) } ?? "dist ?"
                    return "\(ac.displayCallsign) • \(ac.speedKt) kt • \(distance) • \(ac.altitudeFt) ft"
                }
            if !preview.isEmpty {
                lines.append("Amostra: \(preview.joined(separator: " | "))")
            }

            let airlines = snap.adsbSummary?.airlines.prefix(4).map { "\($0.name) (\($0.count))" } ?? []
            if !airlines.isEmpty {
                lines.append("Companhias: \(airlines.joined(separator: ", "))")
            }
            return lines.joined(separator: "\n")
        }
    }

    struct SystemStatusTool: Tool {
        let name = "getSystemStatus"
        let description =
            "Retorna métricas do servidor e da infraestrutura: CPU, RAM, temperatura, uptime, disco, Docker, systemd, rede."

        @Generable
        struct Arguments {
            @Guide(
                description:
                    "Tipo de info: 'geral', 'cpu', 'memoria', 'disco', 'docker', 'systemd', 'rede', ou vazio para tudo"
            )
            var tipo: String?
        }

        let snapshotProvider: @Sendable () -> LabIntelligenceSnapshot

        func call(arguments: Arguments) async throws -> String {
            let snap = snapshotProvider()
            guard let sys = snap.system else { return "Sistema indisponível no momento." }

            var lines: [String] = [
                "Host: \(sys.hostname)",
                "CPU: \(String(format: "%.1f", sys.cpu?.usagePercent ?? 0))%",
                "RAM: \(String(format: "%.1f", sys.memory?.usedPercent ?? 0))% usada",
                "Uptime: \(sys.uptime?.formatted ?? "Indisponível")",
            ]
            if let temp = sys.cpu?.temperatureC {
                lines.append("Temperatura: \(String(format: "%.0f", temp))°C")
            }
            if let disk = sys.disk {
                lines.append("Disco: \(String(format: "%.1f", disk.usedPercent ?? 0))% usado")
            }
            if !snap.processes.isEmpty {
                let top = snap.processes.prefix(3).map { "\($0.command) \(String(format: "%.1f", $0.cpuPercent))%" }
                lines.append("Processos: \(top.joined(separator: ", "))")
            }
            if !snap.dockerContainers.isEmpty {
                let unhealthy = snap.dockerContainers.filter { ($0.health?.status.lowercased() ?? "healthy") != "healthy" }
                lines.append("Containers: \(snap.dockerContainers.count) total, \(unhealthy.count) com atenção")
            }
            if !snap.systemdServices.isEmpty {
                let degraded = snap.systemdServices.filter { $0.activeState.lowercased() != "active" }
                lines.append("Systemd: \(degraded.count) serviços fora do estado esperado")
            }
            if !snap.networkInterfaces.isEmpty {
                let preview = snap.networkInterfaces.prefix(2).map { "\($0.iface) RX \($0.rxBytes)B / TX \($0.txBytes)B" }
                lines.append("Rede: \(preview.joined(separator: " | "))")
            }
            if let metrics = snap.metrics {
                lines.append("Latência API média: \(Int(metrics.avgResponseMs)) ms")
            }
            return lines.joined(separator: "\n")
        }
    }

    struct SatelliteTool: Tool {
        let name = "getSatelliteData"
        let description =
            "Retorna dados de satélites: passes recentes, imagens capturadas, previsões e status do pipeline."

        @Generable
        struct Arguments {
            @Guide(description: "Filtro: 'ultimo_passe', 'previsoes', 'status', ou vazio para tudo")
            var filtro: String?
        }

        let snapshotProvider: @Sendable () -> LabIntelligenceSnapshot

        func call(arguments: Arguments) async throws -> String {
            let snap = snapshotProvider()
            var lines: [String] = []

            if let last = snap.lastImages {
                lines.append("Último passe: \(compactPassLabel(last.passName))")
                lines.append("Imagens capturadas: \(last.images.count)")
                lines.append("Horário: \(last.timestamp)")
            } else {
                lines.append("Nenhum passe recente capturado.")
            }

            if !snap.passes.isEmpty {
                let upcoming = snap.passes.prefix(5).map {
                    "\($0.satelliteName) • \(compactPassLabel($0.name)) • \($0.imageCount) imagens"
                }
                lines.append("Próximos/registrados: \(upcoming.joined(separator: " | "))")
            }

            if let satDump = snap.satDumpStatus {
                lines.append("Último artefato SatDump: \(compactPassLabel(satDump.passName))")
                lines.append("Imagens: \(satDump.imageCount) • recente: \(satDump.isRecent ? "sim" : "não")")
            }

            return lines.joined(separator: "\n")
        }
    }

    struct ACARSTool: Tool {
        let name = "getACARSData"
        let description =
            "Retorna mensagens ACARS recentes, resumo de comunicações, histórico horário e alertas ACARS."

        @Generable
        struct Arguments {
            @Guide(description: "Filtro: 'resumo', 'alertas', 'mensagens', 'historico', ou vazio para tudo")
            var filtro: String?
        }

        let snapshotProvider: @Sendable () -> LabIntelligenceSnapshot

        func call(arguments: Arguments) async throws -> String {
            let snap = snapshotProvider()
            var lines: [String] = []

            let todayMsgs = snap.acarsSummary?.today.messages ?? snap.acarsMessages.count
            lines.append("Mensagens ACARS hoje: \(todayMsgs)")
            lines.append("Alertas ACARS: \(snap.acarsAlerts.count)")

            for msg in snap.acarsMessages.prefix(5) {
                let route = msg.displayRoute ?? "-"
                lines.append("• \(msg.displayFlight) [\(msg.label ?? "-")] • \(route)")
            }

            if let history = snap.acarsHistory, let peakDay = history.last7Days.max(by: { $0.messages < $1.messages }) {
                lines.append("Pico recente: \(peakDay.messages) mensagens em \(peakDay.day)")
            }

            return lines.joined(separator: "\n")
        }
    }

    struct RadioTool: Tool {
        let name = "getRadioStatus"
        let description = "Retorna o que está tocando agora na rádio: artista, música, álbum e contexto da faixa."

        @Generable
        struct Arguments {
            @Guide(description: "Não precisa de input")
            var placeholder: String?
        }

        let nowPlayingProvider: @Sendable () -> NowPlaying?

        func call(arguments: Arguments) async throws -> String {
            guard let nowPlaying = nowPlayingProvider() else {
                return "Rádio sem dados de reprodução no momento."
            }
            var lines: [String] = [
                "Artista: \(nowPlaying.artist)",
                "Música: \(nowPlaying.title)",
                "Rádio: \(nowPlaying.radioName)",
            ]
            if let album = nowPlaying.album, !album.isEmpty { lines.append("Álbum: \(album)") }
            if let genre = nowPlaying.genre, !genre.isEmpty { lines.append("Gênero: \(genre)") }
            lines.append("Atualizado: \(nowPlaying.timestamp)")
            return lines.joined(separator: "\n")
        }
    }

    struct AlertsTool: Tool {
        let name = "getAlerts"
        let description = "Retorna todos os alertas ativos: ADS-B (tráfego) e ACARS (mensagens), com contagem e últimos eventos."

        @Generable
        struct Arguments {
            @Guide(description: "Fonte: 'adsb', 'acars', ou vazio para todos")
            var fonte: String?
        }

        let snapshotProvider: @Sendable () -> LabIntelligenceSnapshot

        func call(arguments: Arguments) async throws -> String {
            let snap = snapshotProvider()
            var lines: [String] = []
            let showAdsb = arguments.fonte == nil || arguments.fonte == "adsb"
            let showAcars = arguments.fonte == nil || arguments.fonte == "acars"

            if showAdsb {
                lines.append("Alertas ADS-B: \(snap.adsbAlerts.count)")
                for alert in snap.adsbAlerts.prefix(4) {
                    let ref = alert.callsign ?? alert.registration ?? alert.aircraft
                    lines.append("• \(ref) — \(alert.timestamp)")
                }
            }
            if showAcars {
                lines.append("Alertas ACARS: \(snap.acarsAlerts.count)")
                for alert in snap.acarsAlerts.prefix(4) {
                    lines.append("• \(alert.id) — \(alert.timestamp)")
                }
            }
            if snap.adsbAlerts.isEmpty && snap.acarsAlerts.isEmpty {
                lines.append("Nenhum alerta ativo no momento.")
            }
            return lines.joined(separator: "\n")
        }
    }

    struct WeatherTool: Tool {
        let name = "getWeatherContext"
        let description = "Retorna clima atual e previsão operacional: temperatura, chuva, vento, umidade, UV e tendência."

        @Generable
        struct Arguments {
            @Guide(description: "Escopo: 'agora', 'chuva', 'hoje', 'previsao', ou vazio para tudo")
            var escopo: String?
        }

        let snapshotProvider: @Sendable () -> LabIntelligenceSnapshot

        func call(arguments: Arguments) async throws -> String {
            let snap = snapshotProvider()
            guard let weather = snap.weather else { return "Clima indisponível no momento." }

            var lines: [String] = [
                "Local: \(weather.location)",
                "Agora: \(weather.current.tempC)°C, \(weather.current.description)",
                "Sensação: \(weather.current.feelsLikeC)°C",
                "Umidade: \(weather.current.humidity)%",
                "Vento: \(weather.current.windKmh) km/h \(weather.current.windDir)",
                "UV: \(weather.current.uvIndex)",
            ]

            lines.append("Hoje: mín \(weather.today.minTempC)°C / máx \(weather.today.maxTempC)°C")
            lines.append("Chuva: \(weather.today.rainChance)% • \(String(format: "%.1f", weather.today.rainMm)) mm")

            return lines.joined(separator: "\n")
        }
    }

    struct AnalyticsTool: Tool {
        let name = "getAnalyticsContext"
        let description = "Retorna tendências recentes e comparativos de analytics do laboratório."

        @Generable
        struct Arguments {
            @Guide(description: "Escopo: 'adsb', 'acars', 'sistema', 'comparativo', ou vazio para tudo")
            var escopo: String?
        }

        let snapshotProvider: @Sendable () -> LabIntelligenceSnapshot

        func call(arguments: Arguments) async throws -> String {
            let snap = snapshotProvider()
            var lines: [String] = []

            if let adsbHistory = snap.adsbHistory {
                let todayPeak = adsbHistory.days.first.flatMap { adsbHistory.dailyPeaks[$0]?["peak"] } ?? 0
                lines.append("ADS-B pico do dia: \(todayPeak)")
            }
            if let acarsHistory = snap.acarsHistory {
                let todayMessages = acarsHistory.last24hHours.reduce(0) { $0 + $1.messages }
                lines.append("ACARS 24h: \(todayMessages) mensagens")
            }
            if let metrics = snap.metrics {
                lines.append("API: média \(Int(metrics.avgResponseMs)) ms, última \(Int(metrics.lastResponseMs)) ms")
            }
            if lines.isEmpty {
                lines.append("Sem analytics recentes disponíveis.")
            }
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Foundation Model Service

    @MainActor
    final class FoundationModelService: ObservableObject {
        static let shared = FoundationModelService()

        private var session: LanguageModelSession?
        private let model = SystemLanguageModel(useCase: .general, guardrails: .default)

        @Published private(set) var availability: SystemLanguageModel.Availability = .unavailable(.modelNotReady)
        @Published private(set) var lastWarmupDate: Date?
        @Published private(set) var lastErrorDescription: String?

        var isAvailable: Bool {
            if case .available = availability { return true }
            return false
        }

        var availabilityLabel: String {
            switch availability {
            case .available:
                return "Pronto no dispositivo"
            case .unavailable(.deviceNotEligible):
                return "Hardware incompatível"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "Apple Intelligence desativada"
            case .unavailable(.modelNotReady):
                return "Modelo aquecendo"
            @unknown default:
                return "Disponibilidade indefinida"
            }
        }

        var availabilitySymbol: String {
            switch availability {
            case .available:
                return "apple.intelligence"
            case .unavailable(.modelNotReady):
                return "hourglass.circle"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "apple.intelligence.badge.xmark"
            case .unavailable(.deviceNotEligible):
                return "exclamationmark.triangle"
            @unknown default:
                return "questionmark.circle"
            }
        }

        var availabilityTint: Color {
            switch availability {
            case .available: return .green
            case .unavailable(.modelNotReady): return .orange
            case .unavailable(.appleIntelligenceNotEnabled): return .yellow
            case .unavailable(.deviceNotEligible): return .red
            @unknown default: return .gray
            }
        }

        func checkAvailability() {
            availability = model.availability
        }

        func prewarm(promptPrefix: String? = nil) {
            guard let session else { return }
            if let promptPrefix, !promptPrefix.isEmpty {
                session.prewarm(promptPrefix: Prompt(promptPrefix))
            } else {
                session.prewarm()
            }
            lastWarmupDate = Date()
            checkAvailability()
        }

        func createSession(
            history: [ChatMessageData] = [],
            snapshotProvider: @escaping @Sendable () -> LabIntelligenceSnapshot,
            nowPlayingProvider: @escaping @Sendable () -> NowPlaying?,
            mode: IntelligenceSessionMode = .assistant
        ) {
            session = makeSession(
                history: history,
                snapshotProvider: snapshotProvider,
                nowPlayingProvider: nowPlayingProvider,
                mode: mode
            )
            checkAvailability()
        }

        func resetSession(
            history: [ChatMessageData] = [],
            snapshotProvider: @escaping @Sendable () -> LabIntelligenceSnapshot,
            nowPlayingProvider: @escaping @Sendable () -> NowPlaying?,
            mode: IntelligenceSessionMode = .assistant
        ) {
            session = nil
            createSession(
                history: history,
                snapshotProvider: snapshotProvider,
                nowPlayingProvider: nowPlayingProvider,
                mode: mode
            )
        }

        func updateConversation(
            history: [ChatMessageData],
            snapshotProvider: @escaping @Sendable () -> LabIntelligenceSnapshot,
            nowPlayingProvider: @escaping @Sendable () -> NowPlaying?,
            mode: IntelligenceSessionMode = .assistant
        ) {
            session = makeSession(
                history: history,
                snapshotProvider: snapshotProvider,
                nowPlayingProvider: nowPlayingProvider,
                mode: mode
            )
            checkAvailability()
        }

        func respondStructured(to prompt: String) async throws -> IntelligenceStructuredResult {
            guard let session else { throw FoundationModelError.unavailable }
            do {
                let response = try await session.respond(
                    to: prompt,
                    generating: IntelligenceGeneratedResponse.self,
                    includeSchemaInPrompt: false,
                    options: GenerationOptions(maximumResponseTokens: 900)
                )
                let trace = toolTrace(from: response.transcriptEntries)
                lastErrorDescription = nil
                return IntelligenceStructuredResult(response: response.content, toolTrace: trace)
            } catch {
                lastErrorDescription = error.localizedDescription
                throw error
            }
        }

        func respondText(to prompt: String) async throws -> String {
            guard let session else { throw FoundationModelError.unavailable }
            do {
                let response = try await session.respond(
                    to: prompt,
                    options: GenerationOptions(maximumResponseTokens: 900)
                )
                lastErrorDescription = nil
                return response.content
            } catch {
                lastErrorDescription = error.localizedDescription
                throw error
            }
        }

        private func makeSession(
            history: [ChatMessageData],
            snapshotProvider: @escaping @Sendable () -> LabIntelligenceSnapshot,
            nowPlayingProvider: @escaping @Sendable () -> NowPlaying?,
            mode: IntelligenceSessionMode
        ) -> LanguageModelSession {
            let tools = makeTools(snapshotProvider: snapshotProvider, nowPlayingProvider: nowPlayingProvider)
            let transcript = makeTranscript(history: history, tools: tools, mode: mode)
            return LanguageModelSession(model: model, tools: tools, transcript: transcript)
        }

        private func makeTools(
            snapshotProvider: @escaping @Sendable () -> LabIntelligenceSnapshot,
            nowPlayingProvider: @escaping @Sendable () -> NowPlaying?
        ) -> [any Tool] {
            [
                ADSBRadarTool(snapshotProvider: snapshotProvider),
                SystemStatusTool(snapshotProvider: snapshotProvider),
                SatelliteTool(snapshotProvider: snapshotProvider),
                ACARSTool(snapshotProvider: snapshotProvider),
                RadioTool(nowPlayingProvider: nowPlayingProvider),
                AlertsTool(snapshotProvider: snapshotProvider),
                WeatherTool(snapshotProvider: snapshotProvider),
                AnalyticsTool(snapshotProvider: snapshotProvider),
            ]
        }

        private func makeTranscript(
            history: [ChatMessageData],
            tools: [any Tool],
            mode: IntelligenceSessionMode
        ) -> Transcript {
            var entries: [Transcript.Entry] = [
                .instructions(
                    .init(
                        segments: [.text(.init(content: instructionsText(for: mode)))],
                        toolDefinitions: tools.map { .init(tool: $0) }
                    ))
            ]

            for message in history {
                switch message.role {
                case .user:
                    entries.append(.prompt(.init(segments: [.text(.init(content: message.text))])))
                case .assistant:
                    entries.append(.response(.init(assetIDs: [], segments: [.text(.init(content: message.text))])))
                case .system:
                    continue
                }
            }
            return Transcript(entries: entries)
        }

        private func instructionsText(for mode: IntelligenceSessionMode) -> String {
            var base = """
            Você é o copiloto operacional do MeuLab.
            Objetivo: orientar, resumir, diagnosticar e apontar a próxima ação usando os dados do app antes de responder.

            Fontes disponíveis:
            - ADS-B com aeronaves ao vivo, histórico, alertas e companhias
            - ACARS com mensagens, alertas e histórico
            - Satélite com passes, imagens e pipeline
            - Sistema e infra com CPU, RAM, disco, Docker, systemd e rede
            - Clima com previsão operacional e chuva
            - Analytics com tendências recentes
            - Rádio com now playing

            Regras de resposta:
            - Responda sempre em português brasileiro.
            - Não invente dados.
            - Consulte as tools antes de responder quando a pergunta depender de estado atual.
            - Estruture a resposta para UI: título curto, resumo, destaques, evidências e próximas ações.
            - Próximas ações devem usar apenas tabs válidas: adsb, map, acars, satellite, system, infra, radio, weather, analytics, alerts, flightSearch, export, remote, remoteRadio, intelligence, bible.
            - Quando sugerir abrir ACARS com contexto, use tab 'acars' e contextIdentifier com voo, matrícula ou id da mensagem.
            - Quando sugerir abrir Clima com contexto, use tab 'weather' e contextIdentifier no formato YYYY-MM-DD para o dia previsto.
            - Ações que impliquem risco operacional devem preferir abrir a tela certa em vez de executar algo diretamente.
            - Se houver incerteza, admita claramente.
            """

            if mode == .incident {
                base += """

                Contexto adicional:
                - O usuário está em modo incidente.
                - Priorize gravidade, impacto, evidência e próxima ação.
                - Se houver alertas ou degradação, proponha uma sequência curta e operacional.
                """
            }

            return base
        }

        private func toolTrace(from entries: ArraySlice<Transcript.Entry>) -> [IntelligenceToolTrace] {
            entries.compactMap { entry in
                guard case .toolOutput(let output) = entry else { return nil }
                let joined = output.segments.compactMap { segment -> String? in
                    switch segment {
                    case .text(let text):
                        return text.content
                    case .structure(let structured):
                        return structured.source
                    @unknown default:
                        return nil
                    }
                }.joined(separator: "\n")
                return IntelligenceToolTrace(
                    toolName: output.toolName,
                    preview: normalizedPreview(joined.isEmpty ? "Sem preview" : joined)
                )
            }
        }
    }

    enum FoundationModelError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Apple Intelligence não está disponível neste dispositivo."
            }
        }
    }

#endif
