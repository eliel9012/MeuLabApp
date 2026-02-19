import AppIntents
import SwiftUI

// MARK: - Aeronaves no Radar

struct AircraftCountIntent: AppIntent {
    static var title: LocalizedStringResource = "Quantas aeronaves no radar?"
    static var description = IntentDescription("Verifica o número de aeronaves sendo rastreadas pelo radar do laboratório.")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        do {
            let summary = try await APIService.shared.fetchADSBSummary()
            let count = summary.totalNow
            
            return .result(
                value: count,
                dialog: "O radar está rastreando \(count) aeronaves no momento."
            )
        } catch {
            return .result(
                value: 0,
                dialog: "Não foi possível conectar ao radar no momento."
            )
        }
    }
}

// MARK: - Status do Laboratório

struct SystemStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Status do laboratório"
    static var description = IntentDescription("Verifica o status e o uptime do servidor do laboratório.")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let status = try await APIService.shared.fetchSystemStatus()
            let uptime = status.uptime?.formatted ?? "Indisponível"
            let cpu = Int(status.cpu?.usagePercent ?? 0)
            
            return .result(
                dialog: "Tudo certo no laboratório. Uptime de \(uptime) e uso de CPU em \(cpu)%."
            )
        } catch {
            return .result(
                dialog: "Não consegui verificar o status do laboratório. Verifique sua conexão."
            )
        }
    }
}

// MARK: - Tocar Rádio

struct PlayRadioIntent: AppIntent {
    static var title: LocalizedStringResource = "Tocar Rádio do Laboratório"
    static var description = IntentDescription("Inicia a reprodução da rádio Diário FM do laboratório.")

    static var openAppWhenRun: Bool = false // Audio playback in background

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        AudioPlayer.shared.play()

        // Fetch metadata if possible for a better response
        var responseText = "Tocando rádio Diário FM."
        if let nowPlaying = try? await APIService.shared.fetchNowPlaying() {
            responseText = "Tocando \(nowPlaying.title) de \(nowPlaying.artist) na Diário FM."
        }

        return .result(
            dialog: IntentDialog(stringLiteral: responseText)
        )
    }
}

// MARK: - Briefing Inteligente

struct IntelligentBriefingIntent: AppIntent {
    static var title: LocalizedStringResource = "Briefing inteligente do laboratório"
    static var description = IntentDescription("Gera um resumo inteligente com radar, satélite, ACARS e sistema.")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        async let adsbTask = APIService.shared.fetchADSBSummary()
        async let systemTask = APIService.shared.fetchSystemStatus()
        async let satTask = APIService.shared.fetchLastImages()
        async let acarsTask = APIService.shared.fetchACARSSummary()

        var parts: [String] = []

        if let adsb = try? await adsbTask {
            parts.append("Radar: \(adsb.totalNow) aeronaves.")
        }
        if let sat = try? await satTask {
            parts.append("Satélite: \(sat.images.count) imagens no último passe.")
        }
        if let acars = try? await acarsTask {
            parts.append("ACARS: \(acars.today.messages) mensagens hoje.")
        }
        if let system = try? await systemTask {
            let cpu = Int(system.cpu?.usagePercent ?? 0)
            parts.append("Sistema: CPU em \(cpu)%.")
        }

        if parts.isEmpty {
            return .result(dialog: "Não consegui montar o briefing agora.")
        }
        return .result(dialog: IntentDialog(stringLiteral: parts.joined(separator: " ")))
    }
}

// MARK: - Perguntar ao Laboratório

struct AskLabIntent: AppIntent {
    static var title: LocalizedStringResource = "Perguntar ao laboratório"
    static var description = IntentDescription("Responde perguntas rápidas sobre radar, sistema, satélite e alertas.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Pergunta")
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let q = question.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()

        if q.contains("alerta") {
            async let adsb = APIService.shared.fetchADSBAlerts()
            async let acars = APIService.shared.fetchACARSAlerts()
            let adsbCount = (try? await adsb.alerts.count) ?? 0
            let acarsCount = (try? await acars.alerts.count) ?? 0
            return .result(dialog: "Alertas recentes: ADS-B \(adsbCount), ACARS \(acarsCount).")
        }

        if q.contains("satel") || q.contains("meteor") || q.contains("passe") {
            if let sat = try? await APIService.shared.fetchLastImages() {
                return .result(dialog: "Último passe com \(sat.images.count) imagens.")
            }
            return .result(dialog: "Não consegui consultar satélite agora.")
        }

        if q.contains("sistema") || q.contains("cpu") || q.contains("temperatura") {
            if let system = try? await APIService.shared.fetchSystemStatus() {
                let cpu = Int(system.cpu?.usagePercent ?? 0)
                let mem = Int(system.memory?.usedPercent ?? 0)
                return .result(dialog: "Sistema agora: CPU \(cpu)% e RAM \(mem)%.")
            }
            return .result(dialog: "Não consegui consultar o sistema agora.")
        }

        if let adsb = try? await APIService.shared.fetchADSBSummary() {
            return .result(dialog: "Radar agora com \(adsb.totalNow) aeronaves.")
        }

        return .result(dialog: "Não consegui responder no momento.")
    }
}
