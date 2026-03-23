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
        case alerts
        case flightSearch
        case export
        case remote
        case remoteRadio
        case intelligence
        case bible

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
            case .remoteRadio: return "SDR"
            case .intelligence: return "IA"
            case .bible: return "Bíblia"
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
            case .remoteRadio: return "antenna.radiowaves.left.and.right.circle"
            case .intelligence: return "brain.head.profile"
            case .bible: return "book.closed"
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
            case .remoteRadio: return "antenna.radiowaves.left.and.right.circle.fill"
            case .intelligence: return "brain.head.profile"
            case .bible: return "book.closed.fill"
            }
        }

        /// Tabs principais que aparecem na barra inferior do iPhone
        static var primaryTabs: [Tab] {
            [.adsb, .satellite, .system, .radio]
        }

        /// Tabs secundárias acessíveis via menu "Mais"
        static var secondaryTabs: [Tab] {
            [
                .map, .acars, .infra, .weather, .analytics, .alerts, .flightSearch, .export,
                .remote, .remoteRadio, .intelligence, .bible,
            ]
        }

        /// Verifica se é uma tab principal
        var isPrimary: Bool {
            Tab.primaryTabs.contains(self)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // -- Tabs Primárias --
            SwiftUI.Tab(value: Tab.adsb) {
                tabView(for: .adsb)
            } label: {
                Label(Tab.adsb.title, systemImage: Tab.adsb.icon)
            }

            SwiftUI.Tab(value: Tab.satellite) {
                tabView(for: .satellite)
            } label: {
                Label(Tab.satellite.title, systemImage: Tab.satellite.icon)
            }

            SwiftUI.Tab(value: Tab.system) {
                tabView(for: .system)
            } label: {
                Label(Tab.system.title, systemImage: Tab.system.icon)
            }

            SwiftUI.Tab(value: Tab.radio) {
                tabView(for: .radio)
            } label: {
                Label(Tab.radio.title, systemImage: Tab.radio.icon)
            }

            // -- Tabs Secundárias agrupadas em "Mais" --
            TabSection("Mais") {
                Group {
                    SwiftUI.Tab(value: Tab.map) {
                        tabView(for: .map)
                    } label: {
                        Label(Tab.map.title, systemImage: Tab.map.icon)
                    }

                    SwiftUI.Tab(value: Tab.acars) {
                        tabView(for: .acars)
                    } label: {
                        Label(Tab.acars.title, systemImage: Tab.acars.icon)
                    }

                    SwiftUI.Tab(value: Tab.infra) {
                        tabView(for: .infra)
                    } label: {
                        Label(Tab.infra.title, systemImage: Tab.infra.icon)
                    }

                    SwiftUI.Tab(value: Tab.weather) {
                        tabView(for: .weather)
                    } label: {
                        Label(Tab.weather.title, systemImage: Tab.weather.icon)
                    }

                    SwiftUI.Tab(value: Tab.analytics) {
                        tabView(for: .analytics)
                    } label: {
                        Label(Tab.analytics.title, systemImage: Tab.analytics.icon)
                    }

                    SwiftUI.Tab(value: Tab.alerts) {
                        tabView(for: .alerts)
                    } label: {
                        Label(Tab.alerts.title, systemImage: Tab.alerts.icon)
                    }
                }

                Group {
                    SwiftUI.Tab(value: Tab.flightSearch) {
                        tabView(for: .flightSearch)
                    } label: {
                        Label(Tab.flightSearch.title, systemImage: Tab.flightSearch.icon)
                    }

                    SwiftUI.Tab(value: Tab.export) {
                        tabView(for: .export)
                    } label: {
                        Label(Tab.export.title, systemImage: Tab.export.icon)
                    }

                    SwiftUI.Tab(value: Tab.remote) {
                        tabView(for: .remote)
                    } label: {
                        Label(Tab.remote.title, systemImage: Tab.remote.icon)
                    }

                    SwiftUI.Tab(value: Tab.remoteRadio) {
                        tabView(for: .remoteRadio)
                    } label: {
                        Label(Tab.remoteRadio.title, systemImage: Tab.remoteRadio.icon)
                    }

                    SwiftUI.Tab(value: Tab.intelligence) {
                        tabView(for: .intelligence)
                    } label: {
                        Label(Tab.intelligence.title, systemImage: Tab.intelligence.icon)
                    }

                    SwiftUI.Tab(value: Tab.bible) {
                        tabView(for: .bible)
                    } label: {
                        Label(Tab.bible.title, systemImage: Tab.bible.icon)
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.blue)
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
            selectedTab = tab
            appState.setActiveTab(tab.rawValue)
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
                selectedTab = tab
                appState.setActiveTab(tab.rawValue)
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
        case .analytics: AnalyticsView()
        case .alerts: AlertsView()
        case .flightSearch: FlightSearchView()
        case .export: DataExportView()
        case .remote: RemoteControlView()
        case .remoteRadio: RemoteRadioView()
        case .intelligence: IntelligenceView()
        case .bible: BibleView()
        }
    }

}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(PushNotificationManager.shared)
        .environmentObject(NotificationFeedManager.shared)
}
