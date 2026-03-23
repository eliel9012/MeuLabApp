import SwiftUI

struct EnhancedContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pushManager: PushNotificationManager
    @State private var selectedTab: ContentView.Tab = .adsb
    @State private var selectedDetail: DetailItem?

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
            selectedTab = tab
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
                selectedTab = tab
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
                        .font(.title2)
                        .foregroundStyle(.blue)

                    Text("MeuLab")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()
                }

                // Quick Status
                if let status = appState.systemStatus {
                    HStack(spacing: 8) {
                        EnhancedQuickMetric(
                            title: "CPU",
                            value: "\(Int(status.cpu?.usagePercent ?? 0))%",
                            color: .blue
                        )

                        EnhancedQuickMetric(
                            title: "RAM",
                            value: "\(Int(status.memory?.usedPercent ?? 0))%",
                            color: .purple
                        )

                        EnhancedQuickMetric(
                            title: "Disco",
                            value: "\(Int(status.disk?.usedPercent ?? 0))%",
                            color: .orange
                        )
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))

            Divider()

            // Navigation List
            List {
                ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        EnhancedSidebarRow(tab: tab, isSelected: selectedTab == tab)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.sidebar)
        }
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
                    AnalyticsView()
                case .alerts:
                    AlertsView()
                case .flightSearch:
                    FlightSearchView()
                case .export:
                    DataExportView()
                case .remote:
                    RemoteControlView()
                case .remoteRadio:
                    RemoteRadioView()
                case .intelligence:
                    IntelligenceView()
                case .bible:
                    BibleView()
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
            ForEach(ContentView.Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        selectedTab = tab
                    }
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
                                .symbolEffect(.bounce, value: selectedTab == tab)
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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 32)
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
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 20)

            Text(tab.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)

            Spacer()

            // Status indicators
            if hasActiveAlerts(for: tab) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? .blue : Color.clear)
        )
        .contentShape(Rectangle())
    }

    private func hasActiveAlerts(for tab: ContentView.Tab) -> Bool {
        switch tab {
        case .alerts, .system, .remote:
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
                .font(.system(size: 14, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
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
