import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pushManager: PushNotificationManager
    @State private var selectedTab: Tab = .adsb
    @State private var didApplyLaunchTab = false

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
        case flightSearch
        case export
        case remote
        case intelligence
        case bible
        case tesouroReserva
        case viagem
        case more

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
            case .flightSearch: return "Buscar"
            case .export: return "Exportar"
            case .remote: return "Controle"
            case .intelligence: return "IA"
            case .bible: return "Bíblia"
            case .tesouroReserva: return "Tesouro Reserva"
            case .viagem: return "Viagem"
            case .more: return "Mais"
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
            case .flightSearch: return "magnifyingglass"
            case .export: return "square.and.arrow.up"
            case .remote: return "terminal"
            case .intelligence: return "brain.head.profile"
            case .bible: return "book.closed"
            case .tesouroReserva: return "banknote"
            case .viagem: return "airplane.circle"
            case .more: return "ellipsis"
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
            case .flightSearch: return "magnifyingglass"
            case .export: return "square.and.arrow.up"
            case .remote: return "terminal.fill"
            case .intelligence: return "brain.head.profile"
            case .bible: return "book.closed.fill"
            case .tesouroReserva: return "banknote.fill"
            case .viagem: return "airplane.circle.fill"
            case .more: return "ellipsis"
            }
        }

        /// Tabs principais que aparecem na barra inferior do iPhone
        static var primaryTabs: [Tab] {
            [.adsb, .satellite, .system, .radio]
        }

        /// Tabs secundárias acessíveis via menu "Mais"
        static var secondaryTabs: [Tab] {
            [
                .map, .acars, .infra, .weather, .flightSearch, .export,
                .remote, .intelligence, .bible, .tesouroReserva, .viagem,
            ]
        }

        /// Verifica se é uma tab principal
        var isPrimary: Bool {
            Tab.primaryTabs.contains(self)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            tabView(for: selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 76)

            MacOS9RootTabBar(
                selectedTab: bottomBarSelection,
                tabs: Tab.primaryTabs + [.more]
            ) { tab in
                selectedTab = tab
                appState.setActiveTab(tab.rawValue)
            }
        }
        .tint(MacOS9Colors.selection)
        .background(MacOS9Colors.windowBackground)
        .adaptiveTheme()
        .onAppear {
            if !didApplyLaunchTab {
                didApplyLaunchTab = true
                if let launchTab = Self.launchTabOverride() {
                    selectedTab = launchTab
                }
            }
            appState.setActiveTab(selectedTab.rawValue)
        }
        .onChange(of: selectedTab) { _, newTab in
            appState.setActiveTab(newTab.rawValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .meulabNavigateToTab)) { note in
            guard let raw = note.userInfo?["tab"] as? String,
                let tab = Tab(rawValue: raw)
            else { return }
            let resolvedTab: Tab = tab == .analytics ? .system : tab
            selectedTab = resolvedTab
            appState.setActiveTab(resolvedTab.rawValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .meulabOpenContext)) { note in
            let pairs = (note.userInfo ?? [:]).reduce(into: [String: String]()) { partialResult, item in
                if let key = item.key as? String, let value = item.value as? String {
                    partialResult[key] = value
                }
            }
            guard !pairs.isEmpty else { return }
            appState.intelligenceContext = pairs

            if let tabRaw = pairs["tab"], let tab = Tab(rawValue: tabRaw) {
                let resolvedTab: Tab = tab == .analytics ? .system : tab
                selectedTab = resolvedTab
                appState.setActiveTab(resolvedTab.rawValue)
            }

            if pairs["kind"] == "aircraft" {
                let identifier = pairs["identifier"]?.lowercased()
                let callsign = pairs["callsign"]?.lowercased()
                if let aircraft = appState.aircraftList.first(where: {
                    let values = [$0.id.lowercased(), $0.callsign.lowercased(), $0.hex?.lowercased()].compactMap { $0 }
                    return values.contains(identifier ?? "") || values.contains(callsign ?? "")
                }) {
                    appState.mapFocusAircraft = aircraft
                }
            }
        }
    }

    private var bottomBarSelection: Tab {
        selectedTab.isPrimary ? selectedTab : .more
    }

    private static func launchTabOverride() -> Tab? {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["MEULAB_INITIAL_TAB"]?.trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }
        return Tab(rawValue: raw.lowercased())
    }

    // Renderiza a view de uma tab específica.
    @ViewBuilder
    private func tabView(for tab: Tab) -> some View {
        switch tab {
        case .adsb: ADSBView()
        case .map: MapView()
        case .acars: ACARSView()
        case .satellite: SatelliteView()
        case .system: SystemView()
        case .infra: InfraView()
        case .radio: RadioView()
        case .weather: WeatherView()
        case .analytics: SystemView()
        case .flightSearch: FlightSearchView()
        case .export: DataExportView()
        case .remote: RemoteControlView()
        case .intelligence: IntelligenceView()
        case .bible: BibleView()
        case .tesouroReserva: TesouroReservaView()
        case .viagem: ViagemView()
        case .more: MoreMenuView(tabs: Tab.secondaryTabs) { selectedTab = $0 }
        }
    }

}

private struct MacOS9RootTabBar: View {
    let selectedTab: ContentView.Tab
    let tabs: [ContentView.Tab]
    let select: (ContentView.Tab) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    select(tab)
                } label: {
                    MacOS9RootTabItem(tab: tab, isSelected: isSelected)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(MacOS9Colors.panelBackground)
        .overlay(Mac9BevelBorder(isRaised: true))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

private struct MacOS9RootTabItem: View {
    let tab: ContentView.Tab
    let isSelected: Bool

    private var iconName: String {
        isSelected ? tab.filledIcon : tab.icon
    }

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: iconName)
                .font(MacOS9Typography.bodyBold(20))
                .frame(height: 22)
            Text(tab.title)
                .font(MacOS9Typography.caption(10))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(MacOS9Colors.primaryText)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(isSelected ? MacOS9Colors.labelBadge : MacOS9Colors.panelBackground)
        .overlay(Mac9BevelBorder(isRaised: !isSelected))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
    }
}

private struct MoreMenuView: View {
    let tabs: [ContentView.Tab]
    let select: (ContentView.Tab) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "ellipsis")
                    .font(MacOS9Typography.bodyBold(16))
                    .frame(width: 28, height: 28)
                    .background(MacOS9Colors.labelBadge)
                    .overlay(Mac9BevelBorder(isRaised: true))
                    .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))

                Text("Mais")
                    .font(MacOS9Typography.windowTitle(18))
                    .foregroundStyle(MacOS9Colors.primaryText)

                Spacer()
            }
            .padding(10)
            .background(MacOS9Colors.panelBackground)
            .overlay(Mac9BevelBorder(isRaised: true))
            .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
            .padding(.horizontal, 14)
            .padding(.top, 10)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        Button {
                            select(tab)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: tab.icon)
                                    .font(MacOS9Typography.bodyBold(15))
                                    .frame(width: 22)
                                    .foregroundStyle(MacOS9Colors.selection)
                                Text(tab.title)
                                    .font(MacOS9Typography.bodyBold(14))
                                    .foregroundStyle(MacOS9Colors.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(MacOS9Typography.bodyBold(11))
                                    .foregroundStyle(MacOS9Colors.secondaryText)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 46)
                            .background(MacOS9Colors.contentPanel)
                        }
                        .buttonStyle(.plain)

                        Rectangle()
                            .fill(MacOS9Colors.border.opacity(0.2))
                            .frame(height: 1)
                            .padding(.leading, 44)
                    }
                }
                .mac9Panel()
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(MacOS9Colors.windowBackground.ignoresSafeArea())
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(PushNotificationManager.shared)
        .environmentObject(NotificationFeedManager.shared)
}
