import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @EnvironmentObject var pushManager: PushNotificationManager
    @State private var selectedTab: Tab = .adsb
    @State private var didApplyLaunchTab = false

    enum Tab: String, CaseIterable {
        case adsb
        case map
        case acars
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
        case series
        case notes
        case apuracao

        var title: String {
            switch self {
            case .adsb: return "ADS-B"
            case .map: return "Radar"
            case .acars: return "ACARS"
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
            case .series: return "Séries"
            case .notes: return "Notas"
            case .apuracao: return "Apuração"
            }
        }

        var icon: String {
            switch self {
            case .adsb: return "airplane"
            case .map: return "map"
            case .acars: return "envelope.badge"
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
            case .series: return "film.stack"
            case .notes: return "note.text"
            case .apuracao: return "checkmark.seal"
            }
        }

        var filledIcon: String {
            switch self {
            case .adsb: return "airplane"
            case .map: return "map.fill"
            case .acars: return "envelope.badge.fill"
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
            case .series: return "film.stack.fill"
            case .notes: return "note.text"
            case .apuracao: return "checkmark.seal"
            }
        }

        /// Tabs principais que aparecem na barra inferior do iPhone
        static var primaryTabs: [Tab] {
            [.adsb, .system, .radio]
        }

        /// Tabs secundárias acessíveis via menu "Mais"
        static var secondaryTabs: [Tab] {
            [
                .map, .acars, .infra, .weather, .flightSearch, .export,
                .apuracao, .remote, .intelligence, .bible, .tesouroReserva, .viagem, .series, .notes,
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

                    SwiftUI.Tab(value: Tab.tesouroReserva) {
                        tabView(for: .tesouroReserva)
                    } label: {
                        Label(Tab.tesouroReserva.title, systemImage: Tab.tesouroReserva.icon)
                    }

                    SwiftUI.Tab(value: Tab.viagem) {
                        tabView(for: .viagem)
                    } label: {
                        Label(Tab.viagem.title, systemImage: Tab.viagem.icon)
                    }

                    SwiftUI.Tab(value: Tab.series) {
                        tabView(for: .series)
                    } label: {
                        Label(Tab.series.title, systemImage: Tab.series.icon)
                    }
                }

                Group {
                    SwiftUI.Tab(value: Tab.notes) {
                        tabView(for: .notes)
                    } label: {
                        Label(Tab.notes.title, systemImage: Tab.notes.icon)
                    }

                    SwiftUI.Tab(value: Tab.apuracao) {
                        tabView(for: .apuracao)
                    } label: {
                        Label(Tab.apuracao.title, systemImage: Tab.apuracao.icon)
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

    private static func launchTabOverride() -> Tab? {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["MEULAB_INITIAL_TAB"]?.trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty
        else {
            return nil
        }
        return Tab.allCases.first { $0.rawValue.lowercased() == raw.lowercased() }
    }

    // Renderiza a view de uma tab específica.
    @ViewBuilder
    // Dense dashboards (card grids with side-by-side metrics) are capped at AX1:
    // beyond it their rows break word by word. Lists and text screens scale fully.
    private func tabView(for tab: Tab) -> some View {
        switch tab {
        case .adsb: ADSBView().dynamicTypeSize(...DynamicTypeSize.accessibility1)
        case .map: MapView()
        case .acars: ACARSView()
        case .system: SystemView().dynamicTypeSize(...DynamicTypeSize.accessibility1)
        case .infra: InfraView().dynamicTypeSize(...DynamicTypeSize.accessibility1)
        case .radio: RadioView()
        case .weather: WeatherView()
        case .analytics: SystemView().dynamicTypeSize(...DynamicTypeSize.accessibility1)
        case .flightSearch: FlightSearchView()
        case .export: DataExportView()
        case .remote: RemoteControlView()
        case .intelligence: IntelligenceView().dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        case .bible: BibleView()
        case .tesouroReserva: TesouroReservaView()
        case .viagem: ViagemView()
        case .series: SeriesView()
        case .notes: NotesView()
        case .apuracao: ApuracaoView()
        }
    }

}

#Preview {
    ContentView()
        .environment(AppState())
        .environmentObject(PushNotificationManager.shared)
        .environmentObject(NotificationFeedManager.shared)
}
