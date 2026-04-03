import SwiftUI

#if canImport(FoundationModels)
    import FoundationModels
#endif

// MARK: - Router view (escolhe moderna ou legada baseado na versão do iOS)

struct IntelligenceView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        IntelligenceViewModern()
            .environmentObject(appState)
    }
}

// MARK: - Chat Session Model

struct ChatSession: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var messages: [ChatMessageData]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(), title: String = "Nova conversa", messages: [ChatMessageData] = [],
        createdAt: Date = Date(), updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ChatMessageData: Identifiable, Codable, Equatable {
    let id: UUID
    let role: ChatRole
    var text: String
    let timestamp: Date
    var structured: IntelligenceStructuredPayload?

    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        timestamp: Date = Date(),
        structured: IntelligenceStructuredPayload? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.structured = structured
    }
}

enum ChatRole: String, Codable, Equatable { case user, assistant, system }

struct IntelligenceActionPayload: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let systemImage: String
    let prompt: String?
    let tab: String?
    let contextIdentifier: String?
    let style: String?

    init(
        id: UUID = UUID(),
        title: String,
        systemImage: String,
        prompt: String? = nil,
        tab: String? = nil,
        contextIdentifier: String? = nil,
        style: String? = nil
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.prompt = prompt
        self.tab = tab
        self.contextIdentifier = contextIdentifier
        self.style = style
    }
}

struct IntelligenceStructuredPayload: Codable, Equatable {
    let title: String
    let summary: String
    let highlights: [String]
    let evidence: [String]
    let actions: [IntelligenceActionPayload]
    let followUpQuestion: String?
    let confidenceNote: String?
    let severity: String?
    let toolTrace: [IntelligenceToolTrace]

    var transcriptText: String {
        var parts = [title, summary]
        if !highlights.isEmpty {
            parts.append(highlights.map { "• \($0)" }.joined(separator: "\n"))
        }
        if let followUpQuestion, !followUpQuestion.isEmpty {
            parts.append("Próxima pergunta: \(followUpQuestion)")
        }
        return parts.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

#if canImport(FoundationModels)
    extension IntelligenceStructuredPayload {
        init(response: IntelligenceGeneratedResponse, toolTrace: [IntelligenceToolTrace]) {
            self.title = response.title
            self.summary = response.summary
            self.highlights = response.highlights
            self.evidence = response.evidence
            self.actions = response.suggestedActions.map {
                IntelligenceActionPayload(
                    title: $0.title,
                    systemImage: $0.systemImage,
                    prompt: $0.prompt,
                    tab: $0.tab,
                    contextIdentifier: $0.contextIdentifier,
                    style: $0.style
                )
            }
            self.followUpQuestion = response.followUpQuestion
            self.confidenceNote = response.confidenceNote
            self.severity = response.severity
            self.toolTrace = toolTrace
        }
    }
#endif

// MARK: - Chat Persistence

private enum ChatStore {
    private static let key = "intelligence.chat_sessions"
    private static let maxSessions = 50

    static func load() -> [ChatSession] {
        guard let data = UserDefaults.standard.data(forKey: key),
            let sessions = try? JSONDecoder().decode([ChatSession].self, from: data)
        else {
            return []
        }
        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func save(_ sessions: [ChatSession]) {
        let trimmed = Array(sessions.prefix(maxSessions))
        DispatchQueue.global(qos: .utility).async {
            if let data = try? JSONEncoder().encode(trimmed) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}

// MARK: - Modern Intelligence View (iOS 26+ com Foundation Models)

private enum IntelligenceTheme {
    static let accent = Color(red: 0.16, green: 0.42, blue: 0.94)
    static let mint = Color(red: 0.12, green: 0.74, blue: 0.48)
    static let amber = Color(red: 0.96, green: 0.63, blue: 0.19)
    static let panel = Color.white.opacity(0.12)
}

private struct OperationalWorkflowItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let prompt: String
    let priority: Int
}

private struct IntelligenceToolbarTitle: View {
    let statusLabel: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 28, height: 28)
                Image(systemName: "apple.intelligence")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("IA")
                    .font(.headline.weight(.bold))
                HStack(spacing: 4) {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .bold))
                    Text(statusLabel)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

private struct IntelligenceWorkflowCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct IntelligenceActionChip: View {
    let action: IntelligenceActionPayload
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            Label(action.title, systemImage: action.systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

struct IntelligenceViewModern: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var sessions: [ChatSession] = ChatStore.load()
    @State private var activeSessionID: UUID?
    @State private var currentMessages: [ChatMessageData] = []
    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var showHistory = false
    @State private var playbooks: [LabPlaybookSuggestion] = []
    @State private var timelineEvents: [LabTimelineEvent] = []
    @State private var qualityItems: [DataQualityItem] = []
    @State private var comparisons: [ComparisonInsight] = []
    @State private var savePending = false
    @State private var didBootstrap = false
    @FocusState private var isInputFocused: Bool
    @AppStorage("intelligence.incident_mode") private var incidentMode = false
    @State private var scrollProxy: ScrollViewProxy?

    private var isWide: Bool { sizeClass == .regular }
    private var currentMode: IntelligenceSessionMode { incidentMode ? .incident : .assistant }
    private var sessionTitle: String {
        sessions.first(where: { $0.id == activeSessionID })?.title ?? "IA"
    }
    private var workflowItems: [OperationalWorkflowItem] {
        let totalAlerts = appState.adsbAlerts.count + appState.acarsAlerts.count
        let cpu = Int(appState.systemStatus?.cpu?.usagePercent ?? 0)
        let base: [OperationalWorkflowItem] = [
            .init(
                icon: "airplane.departure",
                title: "Briefing Agora",
                subtitle: "Monte a leitura inicial do laboratório com risco, contexto e próxima ação.",
                tint: IntelligenceTheme.mint,
                prompt: "Monte um briefing operacional agora com radar, sistema, clima, alertas e próxima ação.",
                priority: 0
            ),
            .init(
                icon: "bell.badge",
                title: "Triar Alertas",
                subtitle: "Ordene ADS-B e ACARS por impacto, urgência e o que merece atenção primeiro.",
                tint: .orange,
                prompt: "Explique os alertas ativos de ADS-B e ACARS. Ordene por prioridade, impacto e próxima ação.",
                priority: totalAlerts > 0 ? 10 : 2
            ),
            .init(
                icon: "cpu",
                title: "Revisar Sistema",
                subtitle: "Cheque CPU, RAM, disco, Wi-Fi e sinais de degradação operacional.",
                tint: IntelligenceTheme.accent,
                prompt: "Faça um diagnóstico operacional do sistema e da infraestrutura. Aponte risco, evidência e próxima ação.",
                priority: cpu >= 75 ? 9 : 3
            ),
            .init(
                icon: "envelope.badge",
                title: "Ler ACARS",
                subtitle: "Resuma mensagens recentes, voos quentes e qualquer mudança de padrão.",
                tint: IntelligenceTheme.amber,
                prompt: "Resuma as mensagens ACARS recentes, destaque anomalias, voos relevantes e o que mudou agora.",
                priority: appState.acarsMessages.isEmpty ? 1 : 5
            ),
            .init(
                icon: "clock.arrow.circlepath",
                title: "O Que Mudou",
                subtitle: "Compare agora com as últimas horas usando histórico e analytics.",
                tint: .indigo,
                prompt: "O que mudou nas últimas horas em radar, ACARS, sistema e analytics?",
                priority: 4
            ),
            .init(
                icon: "cloud.rain",
                title: "Risco Climático",
                subtitle: "Leia chuva, vento e previsão com foco no impacto operacional.",
                tint: .cyan,
                prompt: "Leia o clima atual e a previsão com foco operacional, chuva, vento e impacto no laboratório.",
                priority: 2
            ),
            .init(
                icon: "point.topleft.down.curvedto.point.bottomright.up",
                title: "Próxima Ação",
                subtitle: "Diga qual tela abrir agora e qual pergunta rende mais valor.",
                tint: .pink,
                prompt: "Com base no estado atual do laboratório, qual é a próxima ação mais útil agora?",
                priority: 6
            ),
        ]
        return base.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.title < rhs.title
            }
            return lhs.priority > rhs.priority
        }
    }

    #if canImport(FoundationModels)
        @StateObject private var modelService = FoundationModelService.shared
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.10),
                        Color.mint.opacity(0.08),
                        Color.orange.opacity(0.07),
                        Color.clear,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 18) {
                                heroSection
                                workflowSection
                                if incidentMode {
                                    incidentBanner
                                }
                                if !currentMessages.isEmpty {
                                    chatSection
                                }
                                copilotOverviewSection
                            }
                            .padding(.horizontal, isWide ? 26 : 16)
                            .padding(.top, isWide ? 18 : 12)
                            .padding(.bottom, 12)
                        }
                        .onAppear { scrollProxy = proxy }
                    }

                    Divider()
                    inputBar
                }
            }
            .navigationTitle(sessionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            showHistory = true
                        } label: {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        }
                        .accessibilityLabel("Histórico de conversas")

                        Menu {
                            Button {
                                incidentMode.toggle()
                            } label: {
                                Label(incidentMode ? "Sair Modo Incidente" : "Modo Incidente", systemImage: "exclamationmark.shield")
                            }

                            Button(role: .destructive) {
                                clearChat()
                            } label: {
                                Label("Limpar conversa", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }

                ToolbarItem(placement: .principal) {
                    #if canImport(FoundationModels)
                        IntelligenceToolbarTitle(
                            statusLabel: modelService.availabilityLabel,
                            symbol: modelService.availabilitySymbol,
                            tint: modelService.availabilityTint
                        )
                    #else
                        IntelligenceToolbarTitle(
                            statusLabel: "Fallback local",
                            symbol: "brain",
                            tint: IntelligenceTheme.accent
                        )
                    #endif
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        startNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Nova conversa")
                }
            }
            .sheet(isPresented: $showHistory) {
                chatHistorySheet
            }
            .onAppear {
                bootstrapIfNeeded()
            }
            .onChange(of: incidentMode) { _, _ in
                setupModel(history: currentMessages)
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Copiloto Operacional")
                        .font(.title2.bold())
                    Text("Uma mesa única para entender o estado do radar, do sistema e dos eventos que pedem decisão.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    statusPill(
                        title: incidentMode ? "INCIDENTE" : "ASSISTENTE",
                        value: incidentMode ? "triagem em curso" : "leitura operacional",
                        tint: incidentMode ? .red : IntelligenceTheme.mint
                    )
                    statusPill(
                        title: "Alertas",
                        value: "\(appState.adsbAlerts.count + appState.acarsAlerts.count) ativos",
                        tint: appState.adsbAlerts.isEmpty && appState.acarsAlerts.isEmpty ? IntelligenceTheme.accent : .orange
                    )
                }
            }

            HStack(spacing: 12) {
                quickMetric(title: "Radar", value: "\(appState.adsbSummary?.totalNow ?? appState.aircraftList.count)", tint: IntelligenceTheme.mint)
                quickMetric(title: "CPU", value: "\(Int(appState.systemStatus?.cpu?.usagePercent ?? 0))%", tint: IntelligenceTheme.accent)
                quickMetric(
                    title: "ACARS",
                    value: appState.acarsSummary == nil && appState.acarsMessages.isEmpty
                        ? "—"
                        : "\(appState.acarsSummary?.today.messages ?? appState.acarsMessages.count)",
                    tint: IntelligenceTheme.amber
                )
                quickMetric(
                    title: "Clima",
                    value: appState.weather.map { "\($0.current.tempC)°C" } ?? "—",
                    tint: .cyan
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fluxos Prioritários")
                .font(.headline.weight(.semibold))
            Text("Comece pelos blocos que reduzem incerteza mais rápido.")
                .font(.caption)
                .foregroundStyle(.secondary)
            let columns = isWide
                ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
                : [GridItem(.flexible()), GridItem(.flexible())]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(workflowItems) { item in
                    IntelligenceWorkflowCard(
                        icon: item.icon,
                        title: item.title,
                        subtitle: item.subtitle,
                        tint: item.tint
                    ) {
                        await sendPrompt(item.prompt)
                    }
                }
            }
        }
    }

    private var copilotOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !playbooks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Abrir Agora")
                        .font(.headline.weight(.semibold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(playbooks) { item in
                                Button {
                                    NotificationCenter.default.post(
                                        name: .meulabNavigateToTab,
                                        object: nil,
                                        userInfo: ["tab": item.targetTab]
                                    )
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(item.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(width: isWide ? 240 : 210, alignment: .leading)
                                    .padding(14)
                                    .background(RoundedRectangle(cornerRadius: 18).fill(.thinMaterial))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if !comparisons.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mudanças Relevantes")
                        .font(.headline.weight(.semibold))
                    ForEach(comparisons.prefix(3)) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.metric)
                                    .font(.subheadline.weight(.semibold))
                                Text("Hoje \(item.current) • Ref \(item.previous)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.delta)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(item.delta.hasPrefix("+") ? .green : .orange)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.thinMaterial))
                    }
                }
            }

            if !qualityItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Qualidade das Leituras")
                        .font(.headline.weight(.semibold))
                    FlexibleChipStack(data: qualityItems) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.status == "OK" ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(item.source)
                                .font(.caption.weight(.semibold))
                            Text(item.status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.thinMaterial))
                    }
                }
            }

            if !timelineEvents.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Eventos Recentes")
                        .font(.headline.weight(.semibold))
                    ForEach(timelineEvents.prefix(5)) { event in
                        HStack(alignment: .top, spacing: 10) {
                            Text(event.timeLabel)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(event.category) • \(event.title)")
                                    .font(.caption.weight(.semibold))
                                Text(event.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.thinMaterial))
                    }
                }
            }
        }
    }

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Conversa")
                .font(.headline.weight(.semibold))
            ForEach(currentMessages) { message in
                chatBubble(for: message)
                    .id(message.id)
            }
            if isStreaming {
                streamingBubble
                    .id("streaming")
            }
        }
    }

    private var incidentBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.red)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Modo Incidente Ativo")
                    .font(.caption.bold())
                    .foregroundStyle(.red)
                if let sys = appState.systemStatus {
                    Text("CPU \(Int(sys.cpu?.usagePercent ?? 0))% · RAM \(Int(sys.memory?.usedPercent ?? 0))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("ADS-B \(appState.adsbAlerts.count) • ACARS \(appState.acarsAlerts.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.red.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func chatBubble(for message: ChatMessageData) -> some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                Text(message.text)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(IntelligenceTheme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }

        case .assistant:
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "apple.intelligence")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(IntelligenceTheme.accent)
                    .frame(width: 28, height: 28)
                    .background(IntelligenceTheme.accent.opacity(0.14))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 10) {
                    if let structured = message.structured {
                        structuredBubble(structured)
                    } else {
                        Text(LocalizedStringKey(message.text))
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

                Spacer(minLength: 40)
            }

        case .system:
            Text(message.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func structuredBubble(_ payload: IntelligenceStructuredPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(payload.title)
                        .font(.headline.weight(.semibold))
                    Text(payload.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let severity = payload.severity, !severity.isEmpty {
                    Text(severity.uppercased())
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(IntelligenceTheme.amber.opacity(0.16)))
                }
            }

            if !payload.highlights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(payload.highlights, id: \.self) { item in
                        Label(item, systemImage: "arrowtriangle.right.fill")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }

            if !payload.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Evidências")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    ForEach(payload.evidence.prefix(4), id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !payload.toolTrace.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tools consultadas")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    ForEach(payload.toolTrace.prefix(3)) { trace in
                        Text("\(trace.toolName): \(trace.preview)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !payload.actions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(payload.actions) { action in
                            IntelligenceActionChip(action: action) {
                                handle(action: action)
                            }
                        }
                    }
                }
            }

            if let followUpQuestion = payload.followUpQuestion, !followUpQuestion.isEmpty {
                Text(followUpQuestion)
                    .font(.caption)
                    .foregroundStyle(IntelligenceTheme.accent)
            }

            if let confidenceNote = payload.confidenceNote, !confidenceNote.isEmpty {
                Text(confidenceNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var streamingBubble: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "apple.intelligence")
                .font(.caption.weight(.bold))
                .foregroundStyle(IntelligenceTheme.accent)
                .frame(width: 28, height: 28)
                .background(IntelligenceTheme.accent.opacity(0.14))
                .clipShape(Circle())

            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Consultando contexto e organizando a resposta…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 20).fill(.thinMaterial))

            Spacer(minLength: 40)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Pergunte sobre o laboratório…", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial))
                .onSubmit { Task { await sendUserMessage() } }

            Button {
                Task { await sendUserMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(canSend ? IntelligenceTheme.accent : .gray.opacity(0.4))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, isWide ? 22 : 14)
        .padding(.vertical, 12)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    private var chatHistorySheet: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    Text("Nenhuma conversa ainda")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        Button {
                            switchToSession(session.id)
                            showHistory = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(session.updatedAt.formatted(.relative(presentation: .named)))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if let lastMessage = session.messages.last(where: { $0.role != .system }) {
                                        Text(lastMessage.text)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                if session.id == activeSessionID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(IntelligenceTheme.accent)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Conversas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fechar") { showHistory = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        startNewChat()
                        showHistory = false
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }

    private func statusPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(tint.opacity(0.12)))
    }

    private func quickMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(.thinMaterial))
    }

    private func bootstrapIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true
        if activeSessionID == nil {
            if let first = sessions.first {
                activeSessionID = first.id
                currentMessages = first.messages
            } else {
                startNewChat()
            }
        }
        setupModel(history: currentMessages)
        Task {
            await refreshInsights()
        }
        #if canImport(FoundationModels)
            modelService.prewarm(promptPrefix: "Briefing operacional do laboratório")
        #endif
    }

    private func ensureActiveSession() {
        if activeSessionID == nil || sessions.isEmpty {
            startNewChat()
        }
    }

    private func startNewChat() {
        let session = ChatSession()
        sessions.insert(session, at: 0)
        activeSessionID = session.id
        currentMessages = []
        persistSessions()
        setupModel(history: [])
    }

    private func switchToSession(_ id: UUID) {
        persistCurrentSession()
        activeSessionID = id
        currentMessages = sessions.first(where: { $0.id == id })?.messages ?? []
        setupModel(history: currentMessages)
    }

    private func deleteSessions(at offsets: IndexSet) {
        let idsToDelete = offsets.map { sessions[$0].id }
        sessions.remove(atOffsets: offsets)
        persistSessions()
        if let activeID = activeSessionID, idsToDelete.contains(activeID) {
            activeSessionID = sessions.first?.id
            currentMessages = sessions.first?.messages ?? []
            setupModel(history: currentMessages)
        }
    }

    private func appendMessage(_ message: ChatMessageData) {
        currentMessages.append(message)
        if let idx = sessions.firstIndex(where: { $0.id == activeSessionID }) {
            if sessions[idx].messages.filter({ $0.role == .user }).isEmpty, message.role == .user {
                let title = String(message.text.prefix(44))
                sessions[idx].title = title.count < message.text.count ? title + "…" : title
            }
            sessions[idx].messages = currentMessages
            sessions[idx].updatedAt = Date()
        }
        scheduleSave()
    }

    private func scheduleSave() {
        guard !savePending else { return }
        savePending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            savePending = false
            persistSessions()
        }
    }

    private func persistCurrentSession() {
        if let idx = sessions.firstIndex(where: { $0.id == activeSessionID }) {
            sessions[idx].messages = currentMessages
            sessions[idx].updatedAt = Date()
        }
        persistSessions()
    }

    private func persistSessions() {
        ChatStore.save(sessions)
    }

    @MainActor
    private func setupModel(history: [ChatMessageData]) {
        #if canImport(FoundationModels)
            let snapshot = LabIntelligenceSnapshot(state: appState)
            let nowPlaying = appState.nowPlaying
            modelService.createSession(
                history: history,
                snapshotProvider: { @Sendable in snapshot },
                nowPlayingProvider: { @Sendable in nowPlaying },
                mode: currentMode
            )
        #endif
    }

    @MainActor
    private func sendUserMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        isInputFocused = false
        ensureActiveSession()
        await sendPrompt(text)
    }

    @MainActor
    private func sendPrompt(_ text: String) async {
        ensureActiveSession()
        let historyBeforePrompt = currentMessages
        appendMessage(ChatMessageData(role: .user, text: text))
        scrollToBottom()
        isStreaming = true

        #if canImport(FoundationModels)
            let snapshot = LabIntelligenceSnapshot(state: appState)
            let nowPlaying = appState.nowPlaying
            modelService.updateConversation(
                history: historyBeforePrompt,
                snapshotProvider: { @Sendable in snapshot },
                nowPlayingProvider: { @Sendable in nowPlaying },
                mode: currentMode
            )
            modelService.checkAvailability()

            if modelService.isAvailable {
                do {
                    let result = try await modelService.respondStructured(to: text)
                    let structured = IntelligenceStructuredPayload(
                        response: result.response,
                        toolTrace: result.toolTrace
                    )
                    isStreaming = false
                    appendMessage(
                        ChatMessageData(
                            role: .assistant,
                            text: structured.transcriptText,
                            structured: structured
                        )
                    )
                    await refreshInsights()
                    scrollToBottom()
                    return
                } catch {
                    // Falls through to legacy heuristics.
                }
            }
        #endif

        let fallbackText = await legacyResponse(for: text)
        isStreaming = false
        appendMessage(ChatMessageData(role: .assistant, text: fallbackText))
        await refreshInsights()
        scrollToBottom()
    }

    @MainActor
    private func legacyResponse(for query: String) async -> String {
        let snapshot = LabIntelligenceSnapshot(state: appState)
        return await LabIntelligenceService.shared.ask(query, snapshot: snapshot)
    }

    @MainActor
    private func refreshInsights() async {
        let snapshot = LabIntelligenceSnapshot(state: appState)
        let timeline = await LabIntelligenceService.shared.timeline(from: snapshot)
        let playbookItems = await LabIntelligenceService.shared.playbooks(from: snapshot)
        let quality = await LabIntelligenceService.shared.dataQuality(from: snapshot)
        let comparisonItems = await LabIntelligenceService.shared.comparisons(from: snapshot)
        timelineEvents = timeline
        playbooks = playbookItems
        qualityItems = quality
        comparisons = comparisonItems
    }

    @MainActor
    private func clearChat() {
        guard let idx = sessions.firstIndex(where: { $0.id == activeSessionID }) else { return }
        sessions[idx].messages.removeAll()
        sessions[idx].updatedAt = Date()
        currentMessages = []
        persistSessions()
        setupModel(history: [])
    }

    @MainActor
    private func handle(action: IntelligenceActionPayload) {
        if let tab = action.tab, !tab.isEmpty, let contextIdentifier = action.contextIdentifier,
            !contextIdentifier.isEmpty
        {
            let kind: String? = switch tab {
            case ContentView.Tab.map.rawValue, ContentView.Tab.adsb.rawValue:
                "aircraft"
            case ContentView.Tab.satellite.rawValue:
                "satellite_pass"
            case ContentView.Tab.acars.rawValue:
                "acars"
            case ContentView.Tab.weather.rawValue:
                "weather_day"
            case ContentView.Tab.alerts.rawValue:
                "alert"
            case ContentView.Tab.system.rawValue:
                "system"
            default:
                nil
            }
            var userInfo: [String: String] = [
                "tab": tab,
                "identifier": contextIdentifier,
            ]
            if let kind {
                userInfo["kind"] = kind
            }
            NotificationCenter.default.post(
                name: .meulabOpenContext,
                object: nil,
                userInfo: userInfo
            )
        }

        if let tab = action.tab, !tab.isEmpty {
            if tab == ContentView.Tab.map.rawValue || tab == ContentView.Tab.adsb.rawValue,
                let contextIdentifier = action.contextIdentifier
            {
                if let focused = appState.aircraftList.first(where: {
                    let values = [$0.callsign, $0.registration, $0.hex].compactMap { $0?.lowercased() }
                    return values.contains(contextIdentifier.lowercased())
                }) {
                    appState.mapFocusAircraft = focused
                }
            }
            NotificationCenter.default.post(
                name: .meulabNavigateToTab,
                object: nil,
                userInfo: ["tab": tab]
            )
            return
        }

        if let prompt = action.prompt, !prompt.isEmpty {
            Task { await sendPrompt(prompt) }
        }
    }

    @MainActor
    private func scrollToBottom() {
        if let last = currentMessages.last {
            if isStreaming {
                scrollProxy?.scrollTo("streaming", anchor: .bottom)
            } else {
                withAnimation(.easeOut(duration: 0.2)) {
                    scrollProxy?.scrollTo(last.id, anchor: .bottom)
                }
            }
        } else if isStreaming {
            scrollProxy?.scrollTo("streaming", anchor: .bottom)
        }
    }
}

private struct FlexibleChipStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content

    init(data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(data)) { item in
                content(item)
            }
        }
    }
}

// MARK: - Legacy Intelligence View (iOS < 26 fallback — mantém a interface antiga)

struct IntelligenceViewLegacy: View {
    @EnvironmentObject var appState: AppState

    @State private var query = ""
    @State private var answer =
        "Toque em \u{201C}Gerar Briefing\u{201D} para um resumo inteligente do estado atual."
    @State private var searchResults: [LabSearchResult] = []
    @State private var timelineEvents: [LabTimelineEvent] = []
    @State private var playbooks: [LabPlaybookSuggestion] = []
    @State private var qualityItems: [DataQualityItem] = []
    @State private var comparisons: [ComparisonInsight] = []
    @State private var isBusy = false
    @FocusState private var isQueryFocused: Bool
    @AppStorage("intelligence.incident_mode") private var incidentMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    inputSection
                    quickActions
                    incidentSection
                    answerSection
                    searchSection
                    playbooksSection
                    timelineSection
                    comparisonsSection
                    dataQualitySection
                }
                .padding()
            }
            .navigationTitle("IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        isQueryFocused = false
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                    .accessibilityLabel("Ocultar teclado")

                    Button("Fechar") {
                        closeIntelligenceView()
                    }
                }
            }
            .onAppear {
                Task { await refreshInsights() }
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assistente")
                .font(.headline)
            TextField(
                "Ex.: voo mais pr\u{00F3}ximo, resumo de alertas, status do sistema", text: $query
            )
            .textFieldStyle(.roundedBorder)
            .focused($isQueryFocused)
            HStack {
                Button {
                    isQueryFocused = false
                    Task { await ask() }
                } label: {
                    Label("Perguntar", systemImage: "sparkle.magnifyingglass")
                }
                .adaptiveGlassProminentButton()
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)

                if isBusy {
                    ProgressView()
                        .scaleEffect(0.9)
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A\u{00E7}\u{00F5}es r\u{00E1}pidas")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("Gerar Briefing") {
                        Task { await generateBriefing() }
                    }
                    .adaptiveGlassButton()

                    Button("Resumo de Alertas") {
                        Task { await summarizeAlerts() }
                    }
                    .adaptiveGlassButton()

                    Button("Buscar") {
                        Task { await runSemanticSearch() }
                    }
                    .adaptiveGlassButton()
                    .disabled(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)

                    Button(incidentMode ? "Sair Incidente" : "Modo Incidente") {
                        incidentMode.toggle()
                    }
                    .adaptiveGlassButton()

                    Button("Exportar") {
                        NotificationCenter.default.post(
                            name: Notification.Name("meulab.navigateToTab"),
                            object: nil,
                            userInfo: ["tab": ContentView.Tab.export.rawValue]
                        )
                    }
                    .adaptiveGlassButton()
                }
            }
        }
    }

    @ViewBuilder
    private var incidentSection: some View {
        if incidentMode {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Modo Incidente", systemImage: "exclamationmark.shield.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Spacer()
                }
                if let sys = appState.systemStatus {
                    Text(
                        "CPU \(Int(sys.cpu?.usagePercent ?? 0))% \u{2022} RAM \(Int(sys.memory?.usedPercent ?? 0))% \u{2022} Temp \(Int(sys.cpu?.temperatureC ?? 0))\u{00B0}C"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Text(
                    "Alertas ativos: ADS-B \(appState.adsbAlerts.count) \u{2022} ACARS \(appState.acarsAlerts.count)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button("Abrir Sistema") {
                        NotificationCenter.default.post(
                            name: Notification.Name("meulab.navigateToTab"),
                            object: nil,
                            userInfo: ["tab": ContentView.Tab.system.rawValue]
                        )
                    }
                    .adaptiveGlassProminentButton()

                    Button("Abrir Alertas") {
                        NotificationCenter.default.post(
                            name: Notification.Name("meulab.navigateToTab"),
                            object: nil,
                            userInfo: ["tab": ContentView.Tab.alerts.rawValue]
                        )
                    }
                    .adaptiveGlassButton()
                }
            }
            .padding(12)
            .glassCard(tint: .red, cornerRadius: 12)
        }
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resposta")
                .font(.headline)
            Text(answer)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .glassCard(cornerRadius: 12)
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        if !searchResults.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Busca global")
                    .font(.headline)
                ForEach(searchResults) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item.category) \u{2022} \(item.title)")
                            .font(.subheadline.weight(.semibold))
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .materialCard(cornerRadius: 10)
                }
            }
        }
    }

    @ViewBuilder
    private var playbooksSection: some View {
        if !playbooks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Playbooks autom\u{00E1}ticos")
                    .font(.headline)
                ForEach(playbooks) { item in
                    Button {
                        NotificationCenter.default.post(
                            name: Notification.Name("meulab.navigateToTab"),
                            object: nil,
                            userInfo: ["tab": item.targetTab]
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .materialCard(cornerRadius: 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var timelineSection: some View {
        if !timelineEvents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Timeline \u{00FA}nica")
                    .font(.headline)
                ForEach(timelineEvents) { event in
                    HStack(alignment: .top, spacing: 8) {
                        Text(event.timeLabel)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(event.category) \u{2022} \(event.title)")
                                .font(.caption.weight(.semibold))
                            Text(event.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .materialCard(cornerRadius: 8)
                }
            }
        }
    }

    @ViewBuilder
    private var comparisonsSection: some View {
        if !comparisons.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Comparativos hist\u{00F3}ricos")
                    .font(.headline)
                ForEach(comparisons) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.metric)
                                .font(.caption.weight(.semibold))
                            Text("Hoje: \(item.current) \u{2022} Ref: \(item.previous)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.delta)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(item.delta.hasPrefix("+") ? .green : .orange)
                    }
                    .padding(8)
                    .materialCard(cornerRadius: 8)
                }
            }
        }
    }

    @ViewBuilder
    private var dataQualitySection: some View {
        if !qualityItems.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Qualidade de dados")
                    .font(.headline)
                ForEach(qualityItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.source)
                                .font(.caption.weight(.semibold))
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.status)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                (item.status == "OK" ? Color.green : Color.orange).opacity(0.2)
                            )
                            .foregroundStyle(item.status == "OK" ? .green : .orange)
                            .cornerRadius(8)
                    }
                    .padding(8)
                    .materialCard(cornerRadius: 8)
                }
            }
        }
    }

    private func snapshot() -> LabIntelligenceSnapshot {
        LabIntelligenceSnapshot(state: appState)
    }

    private func generateBriefing() async {
        isBusy = true
        defer { isBusy = false }
        let snap = snapshot()
        let text = await LabIntelligenceService.shared.briefing(from: snap)
        let timeline = await LabIntelligenceService.shared.timeline(from: snap)
        let pbs = await LabIntelligenceService.shared.playbooks(from: snap)
        let quality = await LabIntelligenceService.shared.dataQuality(from: snap)
        let comps = await LabIntelligenceService.shared.comparisons(from: snap)
        await MainActor.run {
            answer = text
            searchResults = []
            timelineEvents = timeline
            playbooks = pbs
            qualityItems = quality
            comparisons = comps
        }
    }

    private func summarizeAlerts() async {
        isBusy = true
        defer { isBusy = false }
        let text = await LabIntelligenceService.shared.summarizeAlerts(from: snapshot())
        await MainActor.run {
            answer = text
            searchResults = []
        }
    }

    private func ask() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }
        let snap = snapshot()
        let text = await LabIntelligenceService.shared.ask(q, snapshot: snap)
        let matches = await LabIntelligenceService.shared.semanticSearch(query: q, snapshot: snap)
        await MainActor.run {
            answer = text
            searchResults = matches
        }
    }

    private func runSemanticSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }
        let matches = await LabIntelligenceService.shared.semanticSearch(
            query: q, snapshot: snapshot())
        await MainActor.run {
            answer =
                matches.isEmpty
                ? "Nenhum resultado sem\u{00E2}ntico para \u{201C}\(q)\u{201D}."
                : "Encontrei \(matches.count) resultado(s) para \u{201C}\(q)\u{201D}."
            searchResults = matches
        }
    }

    private func refreshInsights() async {
        let snap = snapshot()
        let timeline = await LabIntelligenceService.shared.timeline(from: snap)
        let pbs = await LabIntelligenceService.shared.playbooks(from: snap)
        let quality = await LabIntelligenceService.shared.dataQuality(from: snap)
        let comps = await LabIntelligenceService.shared.comparisons(from: snap)
        await MainActor.run {
            timelineEvents = timeline
            playbooks = pbs
            qualityItems = quality
            comparisons = comps
        }
    }

    private func closeIntelligenceView() {
        isQueryFocused = false
        NotificationCenter.default.post(
            name: Notification.Name("meulab.navigateToTab"),
            object: nil,
            userInfo: ["tab": ContentView.Tab.adsb.rawValue]
        )
    }
}
