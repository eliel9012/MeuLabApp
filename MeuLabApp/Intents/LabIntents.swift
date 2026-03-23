import AppIntents
import CoreSpotlight
import SwiftUI
import UniformTypeIdentifiers

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

// MARK: - Indexed Entities for Spotlight / Apple Intelligence

@available(iOS 18.0, *)
struct LabAircraftEntity: IndexedEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Aeronave")
    static var defaultQuery = LabAircraftQuery()

    let id: String
    let callsign: String
    let registration: String?
    let hex: String?
    let model: String?
    let airline: String?
    let subtitle: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: callsign.isEmpty ? (registration ?? id) : callsign),
            subtitle: LocalizedStringResource(stringLiteral: subtitle)
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.text.identifier)
        attributes.title = callsign.isEmpty ? (registration ?? id) : callsign
        attributes.displayName = callsign.isEmpty ? (registration ?? id) : callsign
        attributes.contentDescription = [registration, model, airline, hex]
            .compactMap { $0 }
            .joined(separator: " • ")
        attributes.keywords = [callsign, registration, hex, model, airline].compactMap { $0 }
        return attributes
    }

    init(aircraft: Aircraft) {
        id = aircraft.id
        callsign = aircraft.displayCallsign
        registration = aircraft.registration
        hex = aircraft.hex
        model = aircraft.model
        airline = aircraft.airline
        subtitle = [aircraft.registration, aircraft.model, aircraft.airline].compactMap { $0 }.joined(separator: " • ")
    }
}

@available(iOS 18.0, *)
struct LabAircraftQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [LabAircraftEntity] {
        let aircraft = try await APIService.shared.fetchAircraftList(limit: 120).items
        return aircraft
            .filter { identifiers.contains($0.id) }
            .map(LabAircraftEntity.init)
    }

    func suggestedEntities() async throws -> [LabAircraftEntity] {
        let aircraft = try await APIService.shared.fetchAircraftList(limit: 24).items
        return aircraft.map(LabAircraftEntity.init)
    }

    func entities(matching string: String) async throws -> [LabAircraftEntity] {
        let needle = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let aircraft = try await APIService.shared.fetchAircraftList(limit: 120).items
        return aircraft.filter { aircraft in
            let haystack = [
                aircraft.displayCallsign,
                aircraft.registration ?? "",
                aircraft.hex ?? "",
                aircraft.model ?? "",
                aircraft.airline ?? "",
            ]
            .map { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) }
            .joined(separator: " ")
            return haystack.contains(needle)
        }
        .map(LabAircraftEntity.init)
    }
}

@available(iOS 18.0, *)
struct LabAlertEntity: IndexedEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Alerta")
    static var defaultQuery = LabAlertQuery()

    let id: String
    let source: String
    let title: String
    let detail: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: "\(source) • \(title)"),
            subtitle: LocalizedStringResource(stringLiteral: detail)
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.text.identifier)
        attributes.title = "\(source) • \(title)"
        attributes.displayName = title
        attributes.contentDescription = detail
        attributes.keywords = [source, title, detail]
        return attributes
    }
}

@available(iOS 18.0, *)
struct LabAlertQuery: EntityStringQuery {
    private func fetchAll() async throws -> [LabAlertEntity] {
        async let adsbAlerts = APIService.shared.fetchADSBAlerts()
        async let acarsAlerts = APIService.shared.fetchACARSAlerts()
        let adsb = try await adsbAlerts.alerts.map {
            LabAlertEntity(
                id: "adsb_\($0.id)",
                source: "ADS-B",
                title: $0.callsign ?? $0.registration ?? $0.aircraft,
                detail: $0.timestamp
            )
        }
        let acars = try await acarsAlerts.alerts.map {
            LabAlertEntity(
                id: "acars_\($0.id)",
                source: "ACARS",
                title: $0.id,
                detail: $0.timestamp.toDisplayHHMM() ?? "agora"
            )
        }
        return adsb + acars
    }

    func entities(for identifiers: [String]) async throws -> [LabAlertEntity] {
        try await fetchAll().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [LabAlertEntity] {
        try await Array(fetchAll().prefix(24))
    }

    func entities(matching string: String) async throws -> [LabAlertEntity] {
        let needle = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return try await fetchAll().filter {
            "\($0.source) \($0.title) \($0.detail)"
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(needle)
        }
    }
}

@available(iOS 18.0, *)
struct LabSatellitePassEntity: IndexedEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Passe de satélite")
    static var defaultQuery = LabSatellitePassQuery()

    let id: String
    let satelliteName: String
    let passName: String
    let detail: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: satelliteName),
            subtitle: LocalizedStringResource(stringLiteral: detail)
        )
    }

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(itemContentType: UTType.text.identifier)
        attributes.title = satelliteName
        attributes.displayName = satelliteName
        attributes.contentDescription = detail
        attributes.keywords = [satelliteName, passName, detail]
        return attributes
    }

    init(pass: SatellitePassExtended) {
        id = pass.id
        satelliteName = pass.name.replacingOccurrences(of: "_", with: " ")
        passName = pass.name
        detail = "\(pass.imageCount) imagens • \(String(format: "%.1f", pass.sizeMb)) MB • qualidade \(pass.qualityStars)/5"
    }
}

@available(iOS 18.0, *)
struct LabSatellitePassQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [LabSatellitePassEntity] {
        let passes = try await APIService.shared.fetchPasses(limit: 80).passes
        return passes.filter { identifiers.contains($0.id) }.map(LabSatellitePassEntity.init)
    }

    func suggestedEntities() async throws -> [LabSatellitePassEntity] {
        let passes = try await APIService.shared.fetchPasses(limit: 24).passes
        return passes.map(LabSatellitePassEntity.init)
    }

    func entities(matching string: String) async throws -> [LabSatellitePassEntity] {
        let needle = string.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let passes = try await APIService.shared.fetchPasses(limit: 80).passes
        return passes.filter {
            "\($0.name) \($0.imageFolder)"
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(needle)
        }
        .map(LabSatellitePassEntity.init)
    }
}

// MARK: - Open Intents

@available(iOS 18.0, *)
struct OpenAircraftInMeuLabIntent: OpenIntent {
    static var title: LocalizedStringResource = "Abrir aeronave no MeuLab"

    @Parameter(title: "Aeronave")
    var target: LabAircraftEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .meulabNavigateToTab,
            object: nil,
            userInfo: ["tab": ContentView.Tab.map.rawValue]
        )
        NotificationCenter.default.post(
            name: .meulabOpenContext,
            object: nil,
            userInfo: [
                "tab": ContentView.Tab.map.rawValue,
                "kind": "aircraft",
                "identifier": target.id,
                "callsign": target.callsign,
            ]
        )
        return .result()
    }
}

@available(iOS 18.0, *)
struct OpenAlertInMeuLabIntent: OpenIntent {
    static var title: LocalizedStringResource = "Abrir alerta no MeuLab"

    @Parameter(title: "Alerta")
    var target: LabAlertEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .meulabNavigateToTab,
            object: nil,
            userInfo: ["tab": ContentView.Tab.alerts.rawValue]
        )
        NotificationCenter.default.post(
            name: .meulabOpenContext,
            object: nil,
            userInfo: [
                "tab": ContentView.Tab.alerts.rawValue,
                "kind": "alert",
                "identifier": target.id,
            ]
        )
        return .result()
    }
}

@available(iOS 18.0, *)
struct OpenSatellitePassInMeuLabIntent: OpenIntent {
    static var title: LocalizedStringResource = "Abrir passe de satélite no MeuLab"

    @Parameter(title: "Passe")
    var target: LabSatellitePassEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .meulabNavigateToTab,
            object: nil,
            userInfo: ["tab": ContentView.Tab.satellite.rawValue]
        )
        NotificationCenter.default.post(
            name: .meulabOpenContext,
            object: nil,
            userInfo: [
                "tab": ContentView.Tab.satellite.rawValue,
                "kind": "satellite_pass",
                "identifier": target.id,
            ]
        )
        return .result()
    }
}

// MARK: - Spotlight Indexing

@available(iOS 18.0, *)
actor LabEntityIndexer {
    static let shared = LabEntityIndexer()
    private var lastIndexedAt: Date?

    func reindexIfNeeded() async {
        let now = Date()
        if let lastIndexedAt, now.timeIntervalSince(lastIndexedAt) < 900 {
            return
        }
        await reindexNow()
    }

    func reindexNow() async {
        do {
            let aircraft = try await LabAircraftQuery().suggestedEntities()
            let alerts = try await LabAlertQuery().suggestedEntities()
            let passes = try await LabSatellitePassQuery().suggestedEntities()
            let index = CSSearchableIndex.default()
            try await index.indexAppEntities(aircraft)
            try await index.indexAppEntities(alerts)
            try await index.indexAppEntities(passes)
            lastIndexedAt = Date()
        } catch {
            #if DEBUG
                print("[LabEntityIndexer] index error:", error.localizedDescription)
            #endif
        }
    }
}
