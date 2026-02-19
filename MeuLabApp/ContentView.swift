import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pushManager: PushNotificationManager
    @State private var selectedTab: Tab = .adsb
    @State private var showMoreMenu = false
    @State private var didApplyLaunchTab = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    enum Tab: String, CaseIterable {
        case adsb
        case map
        case acars
        case satellite
        case system
        case infra
        case radio
        case weather
        case analytics
        case alerts
        case flightSearch
        case export
        case remote
        case intelligence

        var title: String {
            switch self {
            case .adsb: return "ADS-B"
            case .map: return "Radar"
            case .acars: return "ACARS"
            case .satellite: return "Satélite"
            case .system: return "Sistema"
            case .infra: return "Infra"
            case .radio: return "Rádio"
            case .weather: return "Clima"
            case .analytics: return "Analytics"
            case .alerts: return "Alertas"
            case .flightSearch: return "Buscar"
            case .export: return "Exportar"
            case .remote: return "Controle"
            case .intelligence: return "IA"
            }
        }

        var icon: String {
            switch self {
            case .adsb: return "airplane"
            case .map: return "map"
            case .acars: return "envelope.badge"
            case .satellite: return "antenna.radiowaves.left.and.right"
            case .system: return "cpu"
            case .infra: return "server.rack"
            case .radio: return "radio"
            case .weather: return "cloud.sun"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .alerts: return "bell"
            case .flightSearch: return "magnifyingglass"
            case .export: return "square.and.arrow.up"
            case .remote: return "terminal"
            case .intelligence: return "brain.head.profile"
            }
        }

        var filledIcon: String {
            switch self {
            case .adsb: return "airplane"
            case .map: return "map.fill"
            case .acars: return "envelope.badge.fill"
            case .satellite: return "antenna.radiowaves.left.and.right"
            case .system: return "cpu.fill"
            case .infra: return "server.rack"
            case .radio: return "radio.fill"
            case .weather: return "cloud.sun.fill"
            case .analytics: return "chart.line.uptrend.xyaxis"
            case .alerts: return "bell.fill"
            case .flightSearch: return "magnifyingglass"
            case .export: return "square.and.arrow.up"
            case .remote: return "terminal.fill"
            case .intelligence: return "brain.head.profile"
            }
        }

        /// Tabs principais que aparecem na barra inferior do iPhone
        static var primaryTabs: [Tab] {
            [.adsb, .satellite, .system, .radio]
        }

        /// Tabs secundárias acessíveis via menu "Mais"
        static var secondaryTabs: [Tab] {
            [.map, .acars, .infra, .weather, .analytics, .alerts, .flightSearch, .export, .remote, .intelligence]
        }

        /// Verifica se é uma tab principal
        var isPrimary: Bool {
            Tab.primaryTabs.contains(self)
        }
    }

    init() {
        // Pré-aquece o Radar assim que o ContentView é inicializado
        let store = LegacyRadarWebViewStore.shared
        // Carrega HTML do radar imediatamente para reduzir tempo de abertura da aba
        let radarHTMLString = RadarHTML.content
        let baseURL = URL(string: "https://radar.meulab.fun/")
        store.ensureLoaded(html: radarHTMLString, baseURL: baseURL)
    }

    var body: some View {
        tabContent
            // Desabilita animacao implicita na troca de conteudo ao mudar `selectedTab`.
            .animation(nil, value: selectedTab)
        .onAppear {
            if !didApplyLaunchTab {
                didApplyLaunchTab = true
                if let launchTab = Self.launchTabOverride() {
                    selectedTab = launchTab
                }
            }
            // Ensure background refresh is scoped correctly on initial load.
            appState.setActiveTab(selectedTab.rawValue)
        }
        .onChange(of: selectedTab) { _, newTab in
            appState.setActiveTab(newTab.rawValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("meulab.navigateToTab"))) { note in
            guard let raw = note.userInfo?["tab"] as? String,
                  let tab = Tab(rawValue: raw) else { return }
            selectedTab = tab
            appState.setActiveTab(tab.rawValue)
        }
	.frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    tabBar
                }
                .ignoresSafeArea(.keyboard)
                .adaptiveTheme()
    }

    private static func launchTabOverride() -> Tab? {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["MEULAB_INITIAL_TAB"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return Tab(rawValue: raw.lowercased())
    }

    // Renderiza apenas a tab atual. Isso evita recomposicao de varias views "escondidas"
    // quando o AppState publica atualizacoes frequentes (principal fonte de CPU alto).
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .adsb:
            ADSBView()
        case .map:
            MapView()
        case .acars:
            ACARSView()
        case .satellite:
            SatelliteView()
        case .system:
            SystemView()
        case .infra:
            InfraView()
        case .radio:
            RadioView()
        case .weather:
            WeatherView()
        case .analytics:
            AnalyticsView()
        case .alerts:
            AlertsView()
        case .flightSearch:
            FlightSearchView()
        case .export:
            DataExportView()
        case .remote:
            RemoteControlView()
        case .intelligence:
            IntelligenceView()
        }
    }
    
    /// Tabs a serem exibidas na barra (iPhone mostra primárias + Mais, iPad mostra todas)
    private var visibleTabs: [Tab] {
        if horizontalSizeClass == .compact {
            return Tab.primaryTabs
        } else {
            return Tab.allCases
        }
    }

    private var tabBar: some View {
        // Custom Ultimate Liquid Glass TabBar - CRYSTAL EDITION
        HStack(spacing: 0) {
            ForEach(visibleTabs, id: \.self) { tab in
                tabButton(for: tab)
            }

            // Botão "Mais" apenas no iPhone
            if horizontalSizeClass == .compact {
                moreButton
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            ZStack {
                // Main Glass Layer
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 25, x: 0, y: 15)

                // Reflection / Highlight
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.1), .blue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )

                // Inner Glow if dark mode (subtle)
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(0.02))
            }
        }
        .padding(.horizontal, 14)
        .sheet(isPresented: $showMoreMenu) {
            moreMenuSheet
        }
    }

    private func tabButton(for tab: Tab) -> some View {
        Button {
            // Evite animar a troca de tab inteira: `withAnimation` aqui faz o SwiftUI tentar
            // animar a substituicao do conteudo (views grandes), o que gera pico de CPU.
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            selectedTab = tab
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if selectedTab == tab {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.25), .blue.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 40, height: 40)
                            .transition(.scale.combined(with: .opacity))
                    }

                    Image(systemName: selectedTab == tab ? tab.filledIcon : tab.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selectedTab == tab ? .blue : .primary.opacity(0.6))
                }

                Text(tab.title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .bold : .semibold))
                    .foregroundStyle(selectedTab == tab ? .blue : .primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var moreButton: some View {
        let isSecondarySelected = !selectedTab.isPrimary
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showMoreMenu = true
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    if isSecondarySelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.25), .blue.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 40, height: 40)
                    }

                    Image(systemName: isSecondarySelected ? "ellipsis.circle.fill" : "ellipsis.circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSecondarySelected ? .blue : .primary.opacity(0.6))
                }

                Text("Mais")
                    .font(.system(size: 10, weight: isSecondarySelected ? .bold : .semibold))
                    .foregroundStyle(isSecondarySelected ? .blue : .primary.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var moreMenuSheet: some View {
        NavigationStack {
            List {
                ForEach(Tab.secondaryTabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        showMoreMenu = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(selectedTab == tab ? .blue : .primary)
                                .frame(width: 28)

                            Text(tab.title)
                                .font(.body)
                                .foregroundStyle(selectedTab == tab ? .blue : .primary)

                            Spacer()

                            if selectedTab == tab {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Mais Opções")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fechar") {
                        showMoreMenu = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct IntelligenceView: View {
    @EnvironmentObject var appState: AppState

    @State private var query = ""
    @State private var answer = "Toque em “Gerar Briefing” para um resumo inteligente do estado atual."
    @State private var searchResults: [LabSearchResult] = []
    @State private var timelineEvents: [LabTimelineEvent] = []
    @State private var playbooks: [LabPlaybookSuggestion] = []
    @State private var qualityItems: [DataQualityItem] = []
    @State private var comparisons: [ComparisonInsight] = []
    @State private var isBusy = false
    @FocusState private var isQueryFocused: Bool
    @AppStorage("intelligence.incident_mode") private var incidentMode = false

    var body: some View {
        NavigationView {
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
            TextField("Ex.: voo mais próximo, resumo de alertas, status do sistema", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($isQueryFocused)
            HStack {
                Button {
                    isQueryFocused = false
                    Task { await ask() }
                } label: {
                    Label("Perguntar", systemImage: "sparkle.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
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
            Text("Ações rápidas")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                Button("Gerar Briefing") {
                    Task { await generateBriefing() }
                }
                .buttonStyle(.bordered)

                Button("Resumo de Alertas") {
                    Task { await summarizeAlerts() }
                }
                .buttonStyle(.bordered)

                Button("Buscar") {
                    Task { await runSemanticSearch() }
                }
                .buttonStyle(.bordered)
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)

                    Button(incidentMode ? "Sair Incidente" : "Modo Incidente") {
                        incidentMode.toggle()
                    }
                    .buttonStyle(.bordered)

                    Button("Exportar") {
                        NotificationCenter.default.post(
                            name: Notification.Name("meulab.navigateToTab"),
                            object: nil,
                            userInfo: ["tab": ContentView.Tab.export.rawValue]
                        )
                    }
                    .buttonStyle(.bordered)
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
                    Text("CPU \(Int(sys.cpu?.usagePercent ?? 0))% • RAM \(Int(sys.memory?.usedPercent ?? 0))% • Temp \(Int(sys.cpu?.temperatureC ?? 0))°C")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Alertas ativos: ADS-B \(appState.adsbAlerts.count) • ACARS \(appState.acarsAlerts.count)")
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
                    .buttonStyle(.borderedProminent)

                    Button("Abrir Alertas") {
                        NotificationCenter.default.post(
                            name: Notification.Name("meulab.navigateToTab"),
                            object: nil,
                            userInfo: ["tab": ContentView.Tab.alerts.rawValue]
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .background(Color.red.opacity(0.08))
            .cornerRadius(12)
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
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
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
                        Text("\(item.category) • \(item.title)")
                            .font(.subheadline.weight(.semibold))
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(10)
                }
            }
        }
    }

    @ViewBuilder
    private var playbooksSection: some View {
        if !playbooks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Playbooks automáticos")
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
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(10)
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
                Text("Timeline única")
                    .font(.headline)
                ForEach(timelineEvents) { event in
                    HStack(alignment: .top, spacing: 8) {
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
        }
    }

    @ViewBuilder
    private var comparisonsSection: some View {
        if !comparisons.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Comparativos históricos")
                    .font(.headline)
                ForEach(comparisons) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.metric)
                                .font(.caption.weight(.semibold))
                            Text("Hoje: \(item.current) • Ref: \(item.previous)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.delta)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(item.delta.hasPrefix("+") ? .green : .orange)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
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
                            .background((item.status == "OK" ? Color.green : Color.orange).opacity(0.2))
                            .foregroundStyle(item.status == "OK" ? .green : .orange)
                            .cornerRadius(8)
                    }
                    .padding(8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
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
        let text = await LabIntelligenceService.shared.briefing(from: snapshot())
        let timeline = await LabIntelligenceService.shared.timeline(from: snapshot())
        let playbooks = await LabIntelligenceService.shared.playbooks(from: snapshot())
        let quality = await LabIntelligenceService.shared.dataQuality(from: snapshot())
        let comparisons = await LabIntelligenceService.shared.comparisons(from: snapshot())
        await MainActor.run {
            answer = text
            searchResults = []
            timelineEvents = timeline
            self.playbooks = playbooks
            qualityItems = quality
            self.comparisons = comparisons
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
        let matches = await LabIntelligenceService.shared.semanticSearch(query: q, snapshot: snapshot())
        await MainActor.run {
            answer = matches.isEmpty ? "Nenhum resultado semântico para “\(q)”." : "Encontrei \(matches.count) resultado(s) para “\(q)”."
            searchResults = matches
        }
    }

    private func refreshInsights() async {
        let snap = snapshot()
        let timeline = await LabIntelligenceService.shared.timeline(from: snap)
        let playbooks = await LabIntelligenceService.shared.playbooks(from: snap)
        let quality = await LabIntelligenceService.shared.dataQuality(from: snap)
        let comparisons = await LabIntelligenceService.shared.comparisons(from: snap)
        await MainActor.run {
            timelineEvents = timeline
            self.playbooks = playbooks
            qualityItems = quality
            self.comparisons = comparisons
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

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(PushNotificationManager.shared)
        .environmentObject(NotificationFeedManager.shared)
}
