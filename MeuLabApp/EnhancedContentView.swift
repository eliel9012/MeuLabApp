import SwiftUI

struct EnhancedContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pushManager: PushNotificationManager
    @State private var selectedTab: ContentView.Tab = .adsb
    @State private var selectedDetail: DetailItem?

    private var visibleTabs: [ContentView.Tab] {
        ContentView.Tab.allCases.filter { $0 != .analytics }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 350)
        .environmentObject(appState)
        .environmentObject(pushManager)
        .environmentObject(NotificationFeedManager.shared)
        .onReceive(NotificationCenter.default.publisher(for: .meulabNavigateToTab)) { note in
            guard let raw = note.userInfo?["tab"] as? String,
                let tab = ContentView.Tab(rawValue: raw)
            else { return }
            selectedTab = tab == .analytics ? .system : tab
        }
        .onReceive(NotificationCenter.default.publisher(for: .meulabOpenContext)) { note in
            let pairs = (note.userInfo ?? [:]).reduce(into: [String: String]()) { partialResult, item in
                if let key = item.key as? String, let value = item.value as? String {
                    partialResult[key] = value
                }
            }
            guard !pairs.isEmpty else { return }
            appState.intelligenceContext = pairs
            if let raw = pairs["tab"], let tab = ContentView.Tab(rawValue: raw) {
                selectedTab = tab == .analytics ? .system : tab
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            // App Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(MacOS9Colors.primaryText)

                    Text("MeuLab")
                        .font(MacOS9Typography.editorialTitle(24))
                        .foregroundStyle(MacOS9Colors.primaryText)

                    Spacer()
                }

                // Quick Status
                if let status = appState.systemStatus {
                    HStack(spacing: 8) {
                        EnhancedQuickMetric(
                            title: "CPU",
                            value: "\(Int(status.cpu?.usagePercent ?? 0))%",
                            color: MacOS9Colors.statusBlue
                        )

                        EnhancedQuickMetric(
                            title: "RAM",
                            value: "\(Int(status.memory?.usedPercent ?? 0))%",
                            color: MacOS9Colors.selection
                        )

                        EnhancedQuickMetric(
                            title: "Disco",
                            value: "\(Int(status.disk?.usedPercent ?? 0))%",
                            color: MacOS9Colors.statusOrange
                        )
                    }
                }
            }
            .padding()
            .background(MacOS9Colors.panelBackground)
            .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))

            MacOS9GroovedDivider()

            // Navigation List
            List {
                ForEach(visibleTabs, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        EnhancedSidebarRow(tab: tab, isSelected: selectedTab == tab)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(MacOS9Colors.contentPanel)
        }
        .background(MacOS9Colors.windowBackground)
        .navigationSplitViewColumnWidth(300)
    }

    @ViewBuilder
    private var detailView: some View {
        Group {
            if let selectedDetail = selectedDetail {
                DetailView(detail: selectedDetail)
            } else {
                // Show current tab content
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
                    SystemView()
                case .flightSearch:
                    FlightSearchView()
                case .export:
                    DataExportView()
                case .remote:
                    RemoteControlView()
                case .intelligence:
                    IntelligenceView()
                case .bible:
                    BibleView()
                case .tesouroReserva:
                    TesouroReservaView()
                case .viagem:
                    ViagemView()
                case .more:
                    EmptyView()
                }
            }
        }
        .environmentObject(appState)
        .environmentObject(pushManager)
        .environmentObject(NotificationFeedManager.shared)
    }

    private var tabBar: some View {
        // Tab bar for compact mode (iPhone)
        HStack(spacing: 0) {
            ForEach(visibleTabs, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(MacOS9Colors.selection)
                                    .frame(width: 40, height: 40)
                                    .transition(.scale.combined(with: .opacity))
                            }

                            Image(systemName: selectedTab == tab ? tab.filledIcon : tab.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .symbolEffect(.bounce, value: selectedTab == tab)
                                .foregroundStyle(
                                    selectedTab == tab
                                        ? MacOS9Colors.selectedText : MacOS9Colors.primaryText)
                        }

                        Text(tab.title)
                            .font(MacOS9Typography.caption(10))
                            .foregroundStyle(
                                selectedTab == tab
                                    ? MacOS9Colors.selection : MacOS9Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 0)
        .padding(.horizontal, 14)
    }
}

// MARK: - Sidebar Components

struct EnhancedSidebarRow: View {
    let tab: ContentView.Tab
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tab.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? MacOS9Colors.selectedText : MacOS9Colors.primaryText)
                .frame(width: 20)

            Text(tab.title)
                .font(MacOS9Typography.body())
                .foregroundStyle(isSelected ? MacOS9Colors.selectedText : MacOS9Colors.primaryText)

            Spacer()

            // Status indicators
            if hasActiveAlerts(for: tab) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(MacOS9Colors.statusRed)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(isSelected ? MacOS9Colors.selection : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func hasActiveAlerts(for tab: ContentView.Tab) -> Bool {
        switch tab {
        case .system, .remote:
            return true  // In real app, check actual alerts
        default:
            return false
        }
    }
}

struct EnhancedQuickMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(MacOS9Typography.windowTitle(14))
                .monospacedDigit()
                .foregroundStyle(color)

            Text(title)
                .font(MacOS9Typography.caption(10))
                .foregroundStyle(MacOS9Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .glassCard(tint: color, cornerRadius: 8)
    }
}

#Preview(traits: .landscapeLeft) {
    EnhancedContentView()
        .environmentObject(AppState())
        .environmentObject(PushNotificationManager.shared)
        .environmentObject(NotificationFeedManager.shared)
}
