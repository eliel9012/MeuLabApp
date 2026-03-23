import Charts
import SwiftUI
import UIKit

private func analyticsAdaptiveColor(light: UIColor, dark: UIColor) -> Color {
    Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    )
}

private func analyticsRGBA(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1)
    -> UIColor
{
    UIColor(red: red, green: green, blue: blue, alpha: alpha)
}

private enum AnalyticsTheme {
    static let blue = Color(red: 0.14, green: 0.38, blue: 0.84)
    static let green = Color(red: 0.27, green: 0.78, blue: 0.37)
    static let cyan = Color(red: 0.18, green: 0.70, blue: 0.86)
    static let orange = Color(red: 0.95, green: 0.57, blue: 0.15)
    static let red = Color(red: 0.82, green: 0.21, blue: 0.32)
    static let violet = Color(red: 0.52, green: 0.34, blue: 0.88)
    static let ink = analyticsAdaptiveColor(
        light: analyticsRGBA(0.08, 0.11, 0.20),
        dark: analyticsRGBA(0.92, 0.95, 1.00)
    )
    static let mist = analyticsAdaptiveColor(
        light: analyticsRGBA(0.94, 0.97, 1.00),
        dark: analyticsRGBA(0.09, 0.11, 0.18)
    )
    static let cloud = analyticsAdaptiveColor(
        light: analyticsRGBA(0.98, 0.99, 1.00),
        dark: analyticsRGBA(0.04, 0.06, 0.12)
    )
    static let canvasMid = analyticsAdaptiveColor(
        light: analyticsRGBA(1.00, 1.00, 1.00),
        dark: analyticsRGBA(0.06, 0.08, 0.15)
    )
    static let canvasEnd = analyticsAdaptiveColor(
        light: analyticsRGBA(0.98, 0.99, 0.97),
        dark: analyticsRGBA(0.08, 0.10, 0.17)
    )
    static let surfaceTop = analyticsAdaptiveColor(
        light: analyticsRGBA(1.00, 1.00, 1.00, 0.98),
        dark: analyticsRGBA(0.13, 0.16, 0.24, 0.98)
    )
    static let insetSurface = analyticsAdaptiveColor(
        light: analyticsRGBA(1.00, 1.00, 1.00, 0.72),
        dark: analyticsRGBA(0.12, 0.15, 0.23, 0.92)
    )
    static let surfaceStroke = analyticsAdaptiveColor(
        light: analyticsRGBA(1.00, 1.00, 1.00, 0.92),
        dark: analyticsRGBA(0.26, 0.31, 0.42, 0.88)
    )
    static let toolbarBubble = analyticsAdaptiveColor(
        light: analyticsRGBA(1.00, 1.00, 1.00, 0.78),
        dark: analyticsRGBA(0.16, 0.20, 0.28, 0.94)
    )
    static let plotSurface = analyticsAdaptiveColor(
        light: analyticsRGBA(1.00, 1.00, 1.00, 0.52),
        dark: analyticsRGBA(0.10, 0.13, 0.20, 0.78)
    )
    static let shadow = analyticsAdaptiveColor(
        light: analyticsRGBA(0.05, 0.12, 0.26),
        dark: analyticsRGBA(0.00, 0.00, 0.00)
    )
}

private struct AnalyticsPanelBackground: View {
    let cornerRadius: CGFloat
    let highlight: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [AnalyticsTheme.surfaceTop, AnalyticsTheme.mist],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [highlight.opacity(0.12), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [highlight.opacity(0.26), AnalyticsTheme.surfaceStroke],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            }
            .shadow(color: AnalyticsTheme.shadow.opacity(0.08), radius: 22, x: 0, y: 12)
            .shadow(color: highlight.opacity(0.06), radius: 16, x: 0, y: 6)
    }
}

private struct AnalyticsInsetBackground: View {
    let cornerRadius: CGFloat
    let highlight: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AnalyticsTheme.insetSurface)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [highlight.opacity(0.08), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(highlight.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: AnalyticsTheme.shadow.opacity(0.05), radius: 14, x: 0, y: 8)
    }
}

private extension View {
    func analyticsPanel(cornerRadius: CGFloat = 20, highlight: Color = AnalyticsTheme.blue)
        -> some View
    {
        background(AnalyticsPanelBackground(cornerRadius: cornerRadius, highlight: highlight))
    }

    func analyticsInsetPanel(cornerRadius: CGFloat = 18, highlight: Color = AnalyticsTheme.blue)
        -> some View
    {
        background(AnalyticsInsetBackground(cornerRadius: cornerRadius, highlight: highlight))
    }
}

private struct AnalyticsToolbarTitle: View {
    let title: String

    init(title: String = "Analytics") {
        self.title = title
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AnalyticsTheme.green.opacity(0.18), AnalyticsTheme.blue.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AnalyticsTheme.blue)
            }

            Text(title)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(
                    LinearGradient(
                        colors: [AnalyticsTheme.green, AnalyticsTheme.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analytics")
    }
}

private struct AnalyticsInfoChip: View {
    let title: String
    let value: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AnalyticsTheme.ink.opacity(0.56))

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)

                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AnalyticsTheme.ink)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(tint.opacity(0.10))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct AnalyticsFilterChip: View {
    let title: String
    let isSelected: Bool
    let tint: Color

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [tint, tint.opacity(0.84)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [AnalyticsTheme.surfaceTop.opacity(0.92), AnalyticsTheme.mist],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
            )
            .foregroundStyle(isSelected ? Color.white : AnalyticsTheme.ink)
            .overlay(
                Capsule()
                    .stroke(isSelected ? tint.opacity(0.2) : tint.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: isSelected ? tint.opacity(0.18) : .clear, radius: 10, x: 0, y: 4)
    }
}

private struct AnalyticsSectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 38, height: 38)

                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AnalyticsTheme.ink)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AnalyticsTheme.ink.opacity(0.56))
            }
        }
    }
}

enum AnalyticsFocusPanel: String, Identifiable {
    case dashboard
    case system
    case environment
    case traffic
    case satellite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Analytics"
        case .system: return "Histórico do Sistema"
        case .environment: return "Ambiente"
        case .traffic: return "Tráfego Aéreo"
        case .satellite: return "Satélite"
        }
    }

    var headerTitle: String {
        switch self {
        case .dashboard: return "Console analítico"
        case .system: return "Janela do sistema"
        case .environment: return "Janela do ambiente"
        case .traffic: return "Janela do radar"
        case .satellite: return "Janela do satélite"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            return "Sistema, ambiente, ADS-B e satélite dentro da mesma janela de leitura."
        case .system:
            return "CPU, memória, disco e temperatura em leitura histórica."
        case .environment:
            return "Temperatura e umidade do sensor local com histórico recente."
        case .traffic:
            return "Volume horário e composição do tráfego ADS-B."
        case .satellite:
            return "Passes, sucesso de coleta e imagens ao longo da janela."
        }
    }

    var sectionTint: Color {
        switch self {
        case .dashboard: return AnalyticsTheme.blue
        case .system: return AnalyticsTheme.blue
        case .environment: return AnalyticsTheme.cyan
        case .traffic: return AnalyticsTheme.green
        case .satellite: return AnalyticsTheme.violet
        }
    }

    var allowsMetricPicker: Bool {
        self == .dashboard || self == .system
    }
}

struct AnalyticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedPeriod: AnalyticsPeriod = .last24h
    @State private var selectedMetric: AnalyticsMetric = .cpu
    @State private var systemAnalytics: SystemAnalytics?
    @State private var adsbAnalytics: ADSBAnalytics?
    @State private var satelliteAnalytics: SatelliteAnalytics?
    @State private var tuyaSensor: TuyaTemperatureHumidityResponse?
    @State private var isLoading = false
    @State private var error: String?
    @State private var analyticsLoadTask: Task<Void, Never>?
    let focus: AnalyticsFocusPanel
    let showsDismissButton: Bool

    enum AnalyticsPeriod: String, CaseIterable {
        case last5m = "5m"
        case last1h = "1h"
        case last6h = "6h"
        case last24h = "24h"
        case last7d = "7d"

        var displayName: String {
            switch self {
            case .last5m: return "5 min"
            case .last1h: return "Última hora"
            case .last6h: return "Últimas 6h"
            case .last24h: return "Últimas 24h"
            case .last7d: return "Últimos 7 dias"
            }
        }

        var interval: String {
            switch self {
            case .last5m: return "1m"
            case .last1h: return "1m"
            case .last6h: return "5m"
            case .last24h: return "15m"
            case .last7d: return "1h"
            }
        }
    }

    enum AnalyticsMetric: String, CaseIterable {
        case cpu = "cpu"
        case memory = "memory"
        case disk = "disk"
        case temperature = "temperature"

        var displayName: String {
            switch self {
            case .cpu: return "CPU"
            case .memory: return "Memória"
            case .disk: return "Disco"
            case .temperature: return "Temperatura"
            }
        }

        var color: Color {
            switch self {
            case .cpu: return AnalyticsTheme.blue
            case .memory: return AnalyticsTheme.violet
            case .disk: return AnalyticsTheme.orange
            case .temperature: return AnalyticsTheme.red
            }
        }

        var icon: String {
            switch self {
            case .cpu: return "cpu"
            case .memory: return "memorychip"
            case .disk: return "internaldrive"
            case .temperature: return "thermometer.medium"
            }
        }
    }

    init(
        focus: AnalyticsFocusPanel = .dashboard,
        initialMetricRaw: String? = nil,
        showsDismissButton: Bool = false
    ) {
        self.focus = focus
        self.showsDismissButton = showsDismissButton
        if let initialMetricRaw, let metric = AnalyticsMetric(rawValue: initialMetricRaw) {
            _selectedMetric = State(initialValue: metric)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    controlSection

                    if showsEnvironmentSection, let message = tuyaSensorMessage {
                        tuyaSensorSection(message: message)
                    } else if showsEnvironmentSection, let sensor = tuyaSensor, let current = sensor.current {
                        tuyaSensorSection(sensor: sensor, current: current)
                    }

                    if showsSystemSection, let analytics = systemAnalytics {
                        systemMetricsSection(analytics)
                    }

                    if showsTrafficSection, let adsb = adsbAnalytics {
                        adsbAnalyticsSection(adsb)
                    }

                    if showsSatelliteSection, let satellite = satelliteAnalytics {
                        satelliteAnalyticsSection(satellite)
                    }

                    if isLoading {
                        ProgressView("Carregando analytics...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    if let error = error {
                        ErrorCard(message: error)
                            .onTapGesture {
                                loadAnalytics(for: selectedPeriod, clearIfMissingCache: false)
                            }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background {
                ZStack {
                    LinearGradient(
                        colors: [AnalyticsTheme.cloud, AnalyticsTheme.canvasMid, AnalyticsTheme.canvasEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [AnalyticsTheme.green.opacity(0.10), .clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 420
                    )

                    RadialGradient(
                        colors: [AnalyticsTheme.blue.opacity(0.08), .clear],
                        center: .topTrailing,
                        startRadius: 30,
                        endRadius: 380
                    )
                }
                .ignoresSafeArea()
            }
            .navigationTitle(focus.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    AnalyticsToolbarTitle(title: focus.title)
                }
                if showsDismissButton {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Fechar") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(AnalyticsTheme.toolbarBubble)
                            )
                    } else {
                        Button {
                            loadAnalytics(for: selectedPeriod, clearIfMissingCache: false)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AnalyticsTheme.blue)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(AnalyticsTheme.toolbarBubble)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            hydrateAnalyticsFromCache(for: selectedPeriod)
            loadAnalytics(for: selectedPeriod, clearIfMissingCache: false)
        }
        .onChange(of: selectedPeriod) { _, newPeriod in
            hydrateAnalyticsFromCache(for: newPeriod)
            loadAnalytics(for: newPeriod, clearIfMissingCache: true)
        }
        .onDisappear {
            analyticsLoadTask?.cancel()
            analyticsLoadTask = nil
        }
    }

    private var showsSystemSection: Bool {
        focus == .dashboard || focus == .system
    }

    private var showsEnvironmentSection: Bool {
        focus == .dashboard || focus == .environment
    }

    private var showsTrafficSection: Bool {
        focus == .dashboard || focus == .traffic
    }

    private var showsSatelliteSection: Bool {
        focus == .dashboard || focus == .satellite
    }

    @ViewBuilder
    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Label(focus.headerTitle, systemImage: "waveform.path.ecg.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AnalyticsTheme.ink.opacity(0.82))

                        Text(isLoading ? "ATUALIZANDO" : "PRONTO")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(isLoading ? AnalyticsTheme.orange : AnalyticsTheme.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                (isLoading ? AnalyticsTheme.orange : AnalyticsTheme.green).opacity(0.14),
                                in: Capsule()
                            )
                    }

                    Text(focus.subtitle)
                        .font(.caption)
                        .foregroundStyle(AnalyticsTheme.ink.opacity(0.56))
                }

                Spacer(minLength: 12)

                AnalyticsInfoChip(
                    title: "Foco",
                    value: focus.allowsMetricPicker ? selectedMetric.displayName : focus.title,
                    tint: focus.allowsMetricPicker ? selectedMetric.color : focus.sectionTint,
                    icon: focus.allowsMetricPicker ? selectedMetric.icon : "square.stack.3d.up"
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    AnalyticsInfoChip(
                        title: "Janela",
                        value: selectedPeriod.displayName,
                        tint: AnalyticsTheme.blue,
                        icon: "calendar"
                    )

                    AnalyticsInfoChip(
                        title: "Cadência",
                        value: selectedPeriod.interval,
                        tint: AnalyticsTheme.cyan,
                        icon: "timer"
                    )

                    AnalyticsInfoChip(
                        title: "Amostras",
                        value: currentSampleCountText,
                        tint: AnalyticsTheme.green,
                        icon: "waveform.path.ecg"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    AnalyticsInfoChip(
                        title: "Janela",
                        value: selectedPeriod.displayName,
                        tint: AnalyticsTheme.blue,
                        icon: "calendar"
                    )

                    AnalyticsInfoChip(
                        title: "Cadência",
                        value: selectedPeriod.interval,
                        tint: AnalyticsTheme.cyan,
                        icon: "timer"
                    )

                    AnalyticsInfoChip(
                        title: "Amostras",
                        value: currentSampleCountText,
                        tint: AnalyticsTheme.green,
                        icon: "waveform.path.ecg"
                    )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Período", systemImage: "clock.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(AnalyticsTheme.ink)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                    selectedPeriod = period
                                }
                            } label: {
                                AnalyticsFilterChip(
                                    title: period.displayName,
                                    isSelected: selectedPeriod == period,
                                    tint: AnalyticsTheme.blue
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            if focus.allowsMetricPicker {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Métrica do Sistema", systemImage: selectedMetric.icon)
                        .font(.headline)
                        .foregroundStyle(AnalyticsTheme.ink)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(AnalyticsMetric.allCases, id: \.self) { metric in
                                Button {
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                                        selectedMetric = metric
                                    }
                                } label: {
                                    AnalyticsFilterChip(
                                        title: metric.displayName,
                                        isSelected: selectedMetric == metric,
                                        tint: metric.color
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .padding(20)
        .analyticsPanel(cornerRadius: 24, highlight: selectedMetric.color)
    }

    private var currentSampleCountText: String {
        guard let systemAnalytics else { return "--" }
        return "\(systemChartPoints(for: selectedMetric, in: systemAnalytics).count)"
    }

    @ViewBuilder
    private func systemMetricsSection(_ analytics: SystemAnalytics) -> some View {
        let points = systemChartPoints(for: selectedMetric, in: analytics)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                AnalyticsSectionHeader(
                    title: "Sistema",
                    subtitle: "Série principal e leitura operacional",
                    icon: selectedMetric.icon,
                    tint: selectedMetric.color
                )

                Spacer(minLength: 12)

                trendIndicator(for: selectedMetric, in: analytics)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(selectedMetric.displayName)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(AnalyticsTheme.ink)

                    if let lastValue = points.last?.valueText {
                        Text(lastValue)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(selectedMetric.color)
                    }

                    Spacer()
                }

                InteractiveAnalyticsLineChart(
                    points: points,
                    color: selectedMetric.color,
                    axisFormat: systemChartAxisFormat,
                    yAxisLabel: { value in
                        formattedSystemAxisValue(value, for: selectedMetric)
                    }
                )
            }
            .padding(18)
            .analyticsInsetPanel(cornerRadius: 20, highlight: selectedMetric.color)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    ForEach(statCards(for: selectedMetric, in: analytics), id: \.title) { card in
                        StatCardMini(
                            title: card.title,
                            value: card.value,
                            color: card.color,
                            trend: card.trend
                        )
                    }
                }

                VStack(spacing: 12) {
                    ForEach(statCards(for: selectedMetric, in: analytics), id: \.title) { card in
                        StatCardMini(
                            title: card.title,
                            value: card.value,
                            color: card.color,
                            trend: card.trend
                        )
                    }
                }
            }
        }
        .padding(20)
        .analyticsPanel(cornerRadius: 24, highlight: selectedMetric.color)
    }

    @ViewBuilder
    private func adsbAnalyticsSection(_ adsb: ADSBAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                AnalyticsSectionHeader(
                    title: "Tráfego Aéreo",
                    subtitle: "Volume horário e composição da frota",
                    icon: "airplane",
                    tint: AnalyticsTheme.blue
                )

                Spacer(minLength: 12)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        AnalyticsInfoChip(
                            title: "Voos",
                            value: "\(adsb.totalFlights)",
                            tint: AnalyticsTheme.green,
                            icon: "airplane.departure"
                        )
                        AnalyticsInfoChip(
                            title: "Aeronaves",
                            value: "\(adsb.uniqueAircraft)",
                            tint: AnalyticsTheme.blue,
                            icon: "airplane.circle"
                        )
                    }

                    VStack(alignment: .trailing, spacing: 8) {
                        AnalyticsInfoChip(
                            title: "Voos",
                            value: "\(adsb.totalFlights)",
                            tint: AnalyticsTheme.green,
                            icon: "airplane.departure"
                        )
                        AnalyticsInfoChip(
                            title: "Aeronaves",
                            value: "\(adsb.uniqueAircraft)",
                            tint: AnalyticsTheme.blue,
                            icon: "airplane.circle"
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Voos por hora")
                    .font(.headline)
                    .foregroundStyle(AnalyticsTheme.ink)

                InteractiveAnalyticsBarChart(
                    points: adsb.hourlyStats.map {
                        AnalyticsBarPoint(
                            xValue: $0.hour,
                            value: Double($0.flightCount),
                            valueText: "\($0.flightCount) voos",
                            title: "Tráfego Aéreo",
                            timestampText: String(format: "%02d:00 - %02d:59", $0.hour, $0.hour),
                            details: [
                                .init(
                                    label: "Altitude média",
                                    value: $0.averageAltitude.map { String(format: "%.0f ft", $0) }
                                        ?? "N/A"
                                ),
                                .init(
                                    label: "Velocidade média",
                                    value: $0.averageSpeed.map { String(format: "%.0f kt", $0) }
                                        ?? "N/A"
                                ),
                            ]
                        )
                    },
                    color: AnalyticsTheme.blue,
                    xAxisLabel: { value in
                        "\(Int(value))h"
                    }
                )
            }
            .padding(18)
            .analyticsInsetPanel(cornerRadius: 20, highlight: AnalyticsTheme.blue)

            VStack(alignment: .leading, spacing: 12) {
                Text("Tipos de aeronave")
                    .font(.headline)
                    .foregroundStyle(AnalyticsTheme.ink)

                VStack(spacing: 10) {
                    ForEach(adsb.topAircraftTypes.prefix(5), id: \.type) { type in
                        HStack(spacing: 12) {
                            Text(type.type)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AnalyticsTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(type.count)")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(AnalyticsTheme.ink.opacity(0.6))

                            Text(String(format: "%.1f%%", type.percentage))
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(AnalyticsTheme.blue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AnalyticsTheme.blue.opacity(0.10), in: Capsule())
                        }

                        if type.type != adsb.topAircraftTypes.prefix(5).last?.type {
                            Divider()
                        }
                    }
                }
            }
            .padding(18)
            .analyticsInsetPanel(cornerRadius: 20, highlight: AnalyticsTheme.cyan)
        }
        .padding(20)
        .analyticsPanel(cornerRadius: 24, highlight: AnalyticsTheme.blue)
    }

    @ViewBuilder
    private func satelliteAnalyticsSection(_ satellite: SatelliteAnalytics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AnalyticsSectionHeader(
                title: "Satélite",
                subtitle: "Qualidade das passagens e taxa de sucesso",
                icon: "antenna.radiowaves.left.and.right",
                tint: AnalyticsTheme.green
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    satelliteStatCard(
                        title: "Sucesso",
                        value: "\(satellite.successfulPasses)",
                        tint: AnalyticsTheme.green
                    )
                    satelliteStatCard(
                        title: "Falha",
                        value: "\(satellite.failedPasses)",
                        tint: AnalyticsTheme.red
                    )
                    satelliteStatCard(
                        title: "Taxa",
                        value: String(format: "%.1f%%", satelliteSuccessRate(satellite)),
                        tint: AnalyticsTheme.blue
                    )
                }

                VStack(spacing: 12) {
                    satelliteStatCard(
                        title: "Sucesso",
                        value: "\(satellite.successfulPasses)",
                        tint: AnalyticsTheme.green
                    )
                    satelliteStatCard(
                        title: "Falha",
                        value: "\(satellite.failedPasses)",
                        tint: AnalyticsTheme.red
                    )
                    satelliteStatCard(
                        title: "Taxa",
                        value: String(format: "%.1f%%", satelliteSuccessRate(satellite)),
                        tint: AnalyticsTheme.blue
                    )
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Satélites com mais passagens")
                    .font(.headline)
                    .foregroundStyle(AnalyticsTheme.ink)

                VStack(spacing: 10) {
                    ForEach(satellite.satelliteStats.prefix(3), id: \.satellite) { stat in
                        HStack(spacing: 12) {
                            Text(stat.satellite)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AnalyticsTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(stat.passes) passes")
                                .font(.caption)
                                .foregroundStyle(AnalyticsTheme.ink.opacity(0.56))

                            Text(String(format: "%.1f%%", stat.successRate))
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(AnalyticsTheme.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AnalyticsTheme.green.opacity(0.10), in: Capsule())
                        }

                        if stat.satellite != satellite.satelliteStats.prefix(3).last?.satellite {
                            Divider()
                        }
                    }
                }
            }
            .padding(18)
            .analyticsInsetPanel(cornerRadius: 20, highlight: AnalyticsTheme.green)
        }
        .padding(20)
        .analyticsPanel(cornerRadius: 24, highlight: AnalyticsTheme.green)
    }

    private func trendIndicator(for metric: AnalyticsMetric, in analytics: SystemAnalytics)
        -> some View
    {
        let trend: MetricTrend
        let color: Color

        switch metric {
        case .cpu:
            trend = analytics.cpu.trend
            color = .blue
        case .memory:
            trend = analytics.memory.trend
            color = .purple
        case .disk:
            trend = analytics.disk.trend
            color = .orange
        case .temperature:
            trend = analytics.temperature.trend
            color = .red
        }

        return HStack(spacing: 4) {
            Image(systemName: trend.iconName)
                .font(.caption)
                .foregroundStyle(color)

            Text(trend.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1), in: Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.16), lineWidth: 1)
        )
    }

    private func satelliteStatCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AnalyticsTheme.ink.opacity(0.56))

            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .analyticsInsetPanel(cornerRadius: 18, highlight: tint)
    }

    private func satelliteSuccessRate(_ satellite: SatelliteAnalytics) -> Double {
        guard satellite.totalPasses > 0 else { return 0 }
        return Double(satellite.successfulPasses) / Double(satellite.totalPasses) * 100
    }

    private func statCards(for metric: AnalyticsMetric, in analytics: SystemAnalytics) -> [(
        title: String, value: String, color: Color, trend: MetricTrend
    )] {
        switch metric {
        case .cpu:
            return [
                (
                    "Média", String(format: "%.1f%%", analytics.cpu.average), .blue,
                    analytics.cpu.trend
                ),
                ("Pico", String(format: "%.1f%%", analytics.cpu.peak), .red, .stable),
                ("Mínima", String(format: "%.1f%%", analytics.cpu.minimum), .green, .stable),
            ]
        case .memory:
            return [
                (
                    "Média", String(format: "%.1f%%", analytics.memory.averageUsage), .purple,
                    analytics.memory.trend
                ),
                ("Pico", String(format: "%.1f%%", analytics.memory.peakUsage), .red, .stable),
                (
                    "Mínima", String(format: "%.0f MB", analytics.memory.minimumAvailable), .green,
                    .stable
                ),
            ]
        case .disk:
            return [
                (
                    "Média", String(format: "%.1f%%", analytics.disk.averageUsage), .orange,
                    analytics.disk.trend
                ),
                ("Pico", String(format: "%.1f%%", analytics.disk.peakUsage), .red, .stable),
                (
                    "Crescimento",
                    analytics.disk.growthRate != nil
                        ? String(format: "%.2f GB/dia", analytics.disk.growthRate!) : "N/A", .blue,
                    .stable
                ),
            ]
        case .temperature:
            return [
                (
                    "Média", String(format: "%.1f°C", analytics.temperature.average), .red,
                    analytics.temperature.trend
                ),
                ("Pico", String(format: "%.1f°C", analytics.temperature.peak), .red, .stable),
                ("Mínima", String(format: "%.1f°C", analytics.temperature.minimum), .blue, .stable),
            ]
        }
    }

    private func hydrateAnalyticsFromCache(for period: AnalyticsPeriod) {
        guard let cached = AnalyticsScreenCache.entries[period.rawValue] else { return }
        systemAnalytics = cached.system
        adsbAnalytics = cached.adsb
        satelliteAnalytics = cached.satellite
        tuyaSensor = cached.tuya
    }

    private func loadAnalytics(for period: AnalyticsPeriod, clearIfMissingCache: Bool) {
        analyticsLoadTask?.cancel()

        if clearIfMissingCache && AnalyticsScreenCache.entries[period.rawValue] == nil {
            clearAnalyticsContent()
        }
        isLoading = true
        error = nil

        let interval = period.interval
        let historyLimit = tuyaHistoryLimit(for: period)

        analyticsLoadTask = Task {
            do {
                async let systemTask = APIService.shared.fetchSystemAnalytics(
                    period: period.rawValue, interval: interval)
                async let adsbTask = APIService.shared.fetchADSBAnalytics(period: period.rawValue)
                async let satelliteTask = APIService.shared.fetchSatelliteAnalytics(
                    period: period.rawValue)
                async let tuyaTask = APIService.shared.fetchTuyaTemperatureHumidity(
                    historyLimit: historyLimit)

                let (system, adsb, satellite, tuya) = try await (
                    systemTask, adsbTask, satelliteTask, tuyaTask
                )
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard selectedPeriod == period else { return }
                    self.systemAnalytics = system
                    self.adsbAnalytics = adsb
                    self.satelliteAnalytics = satellite
                    self.tuyaSensor = tuya
                    AnalyticsScreenCache.entries[period.rawValue] = .init(
                        system: system,
                        adsb: adsb,
                        satellite: satellite,
                        tuya: tuya
                    )
                    self.error = nil
                    self.isLoading = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard selectedPeriod == period else { return }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    guard selectedPeriod == period else { return }
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func clearAnalyticsContent() {
        systemAnalytics = nil
        adsbAnalytics = nil
        satelliteAnalytics = nil
        tuyaSensor = nil
    }

    private func parseDate(_ timestamp: String) -> Date {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            return date
        }
        // Fallback
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return dateFormatter.date(from: timestamp) ?? Date()
    }

    @ViewBuilder
    private func tuyaSensorSection(
        sensor: TuyaTemperatureHumidityResponse, current: TuyaSensorCurrent
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Ambiente",
                systemImage: "humidity.fill",
                subtitle: "Sensor local e histórico recente"
            )
            TuyaSensorCard(sensor: sensor, current: current)
            if !tuyaHistoryPoints.isEmpty {
                tuyaHistorySection
            }
        }
    }

    private func systemChartPoints(for metric: AnalyticsMetric, in analytics: SystemAnalytics)
        -> [AnalyticsLinePoint]
    {
        switch metric {
        case .cpu:
            return analytics.cpu.dataPoints.map { point in
                let date = parseDate(point.timestamp)
                return AnalyticsLinePoint(
                    date: date,
                    value: point.usage,
                    valueText: String(format: "%.1f%%", point.usage),
                    title: selectedMetric.displayName,
                    timestampText: date.formatted(systemTooltipDateFormat),
                    details: [
                        .init(
                            label: "Load 1m",
                            value: point.load1min.map { String(format: "%.2f", $0) } ?? "N/A"),
                        .init(
                            label: "Load 5m",
                            value: point.load5min.map { String(format: "%.2f", $0) } ?? "N/A"),
                        .init(
                            label: "Load 15m",
                            value: point.load15min.map { String(format: "%.2f", $0) } ?? "N/A"),
                    ]
                )
            }
        case .memory:
            return analytics.memory.dataPoints.map { point in
                let date = parseDate(point.timestamp)
                return AnalyticsLinePoint(
                    date: date,
                    value: point.usedPercent,
                    valueText: String(format: "%.1f%%", point.usedPercent),
                    title: selectedMetric.displayName,
                    timestampText: date.formatted(systemTooltipDateFormat),
                    details: [
                        .init(label: "Usado", value: "\(point.usedMb) MB"),
                        .init(label: "Livre", value: "\(point.availableMb) MB"),
                    ]
                )
            }
        case .disk:
            return analytics.disk.dataPoints.map { point in
                let date = parseDate(point.timestamp)
                return AnalyticsLinePoint(
                    date: date,
                    value: point.usedPercent,
                    valueText: String(format: "%.1f%%", point.usedPercent),
                    title: selectedMetric.displayName,
                    timestampText: date.formatted(systemTooltipDateFormat),
                    details: [
                        .init(label: "Usado", value: String(format: "%.1f GB", point.usedGb)),
                        .init(label: "Livre", value: String(format: "%.1f GB", point.availableGb)),
                    ]
                )
            }
        case .temperature:
            return analytics.temperature.dataPoints.map { point in
                let date = parseDate(point.timestamp)
                return AnalyticsLinePoint(
                    date: date,
                    value: point.temperature,
                    valueText: String(format: "%.1f°C", point.temperature),
                    title: selectedMetric.displayName,
                    timestampText: date.formatted(systemTooltipDateFormat),
                    details: []
                )
            }
        }
    }

    private func formattedSystemAxisValue(_ value: Double, for metric: AnalyticsMetric) -> String {
        switch metric {
        case .temperature:
            return String(format: "%.0f°C", value)
        case .cpu, .memory, .disk:
            return String(format: "%.0f%%", value)
        }
    }

    private var systemChartAxisFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .last5m, .last1h, .last6h, .last24h:
            return .dateTime.hour().minute()
        case .last7d:
            return .dateTime.day().month(.abbreviated)
        }
    }

    private var systemTooltipDateFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .last5m, .last1h, .last6h:
            return .dateTime.hour().minute().second()
        case .last24h:
            return .dateTime.day().month(.abbreviated).hour().minute()
        case .last7d:
            return .dateTime.day().month(.abbreviated).hour().minute()
        }
    }

    @ViewBuilder
    private func tuyaSensorSection(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                "Ambiente",
                systemImage: "humidity.fill",
                subtitle: "Sensor local e histórico recente"
            )
            TuyaSensorStatusCard(message: message)
        }
    }

    @ViewBuilder
    private func sectionTitle(_ title: String, systemImage: String, subtitle: String) -> some View {
        AnalyticsSectionHeader(
            title: title,
            subtitle: subtitle,
            icon: systemImage,
            tint: AnalyticsTheme.cyan
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tuyaSensorMessage: String? {
        guard let sensor = tuyaSensor else { return nil }
        if let message = sensor.friendlyErrorMessage {
            return message
        }
        if sensor.current == nil {
            return "Sensor Tuya indisponível no momento."
        }
        return nil
    }

    private var tuyaHistoryLimit: Int {
        tuyaHistoryLimit(for: selectedPeriod)
    }

    private func tuyaHistoryLimit(for period: AnalyticsPeriod) -> Int {
        switch period {
        case .last5m:
            return 6
        case .last1h:
            return 12
        case .last6h:
            return 72
        case .last24h:
            return 288
        case .last7d:
            return 576
        }
    }

    private var tuyaHistoryPoints: [TuyaSensorHistoryEntry] {
        (tuyaSensor?.history ?? [])
            .filter { $0.date != nil }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    @ViewBuilder
    private var tuyaHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Histórico do Sensor")
                    .font(.headline)
                    .foregroundStyle(AnalyticsTheme.ink)

                Spacer()

                if let interval = tuyaSensor?.historyIntervalSeconds {
                    Text("a cada \(max(interval / 60, 1)) min")
                        .font(.caption)
                        .foregroundStyle(AnalyticsTheme.ink.opacity(0.56))
                }
            }

            tuyaHistoryChart(
                title: "Temperatura",
                unit: "°C",
                color: .orange,
                value: \.temperatureC
            )

            tuyaHistoryChart(
                title: "Umidade",
                unit: "%",
                color: .blue,
                value: \.humidityPct
            )
        }
        .padding(20)
        .analyticsPanel(cornerRadius: 24, highlight: AnalyticsTheme.cyan)
    }

    @ViewBuilder
    private func tuyaHistoryChart(
        title: String,
        unit: String,
        color: Color,
        value: KeyPath<TuyaSensorHistoryEntry, Double?>
    ) -> some View {
        let points = tuyaHistoryPoints.compactMap { entry -> AnalyticsLinePoint? in
            guard let date = entry.date,
                let rawReading = entry[keyPath: value],
                let reading = normalizedTuyaReading(rawReading, unit: unit)
            else { return nil }
            return AnalyticsLinePoint(
                date: date,
                value: reading,
                valueText: String(format: "%.1f%@", reading, unit),
                title: title,
                timestampText: date.formatted(tuyaTooltipDateFormat),
                details: []
            )
        }

        if !points.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(points.last?.valueText ?? "--")
                        .font(.subheadline)
                        .foregroundStyle(color)
                }

                InteractiveAnalyticsLineChart(
                    points: points,
                    color: color,
                    axisFormat: tuyaHistoryAxisFormat,
                    showsArea: true,
                    height: 120,
                    yDomainOverride: tuyaHistoryDomain(for: points, unit: unit),
                    yAxisLabel: { axisValue in
                        String(format: "%.0f%@", axisValue, unit)
                    }
                )
            }
        }
    }

    private func normalizedTuyaReading(_ rawValue: Double, unit: String) -> Double? {
        guard rawValue.isFinite else { return nil }

        var value = rawValue
        if unit == "%" {
            while value > 100 {
                value /= 10
            }
            guard (0...100).contains(value) else { return nil }
            return value
        }

        while abs(value) > 120 {
            value /= 10
        }
        guard (-40...120).contains(value) else { return nil }
        return value
    }

    private func tuyaHistoryDomain(for points: [AnalyticsLinePoint], unit: String) -> ClosedRange<
        Double
    > {
        let values = points.map(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return unit == "%" ? 0...100 : 20...35
        }

        if unit == "%" {
            let span = max(maxValue - minValue, 8)
            let padding = max(4, span * 0.18)
            let lower = max(0, minValue - padding)
            let upper = min(100, maxValue + padding)
            if lower < upper {
                return lower...upper
            }
            return max(0, minValue - 5)...min(100, maxValue + 5)
        }

        let span = max(maxValue - minValue, 1.5)
        let padding = max(1.5, span * 0.22)
        let lower = minValue - padding
        let upper = maxValue + padding
        if lower < upper {
            return lower...upper
        }
        return (minValue - 2)...(maxValue + 2)
    }

    private var tuyaHistoryAxisFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .last5m, .last1h, .last6h, .last24h:
            return .dateTime.hour().minute()
        case .last7d:
            return .dateTime.day().month(.abbreviated)
        }
    }

    private var tuyaTooltipDateFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .last5m, .last1h, .last6h:
            return .dateTime.hour().minute().second()
        case .last24h:
            return .dateTime.day().month(.abbreviated).hour().minute()
        case .last7d:
            return .dateTime.day().month(.abbreviated).hour().minute()
        }
    }
}

// MARK: - Supporting Views

struct StatCardMini: View {
    let title: String
    let value: String
    let color: Color
    let trend: MetricTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AnalyticsTheme.ink.opacity(0.56))

                Spacer()

                Image(systemName: trend.iconName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(trend.color)
            }

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .monospacedDigit()

            Text(trend.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(trend.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(trend.color.opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .analyticsInsetPanel(cornerRadius: 18, highlight: color)
    }
}

private struct AnalyticsTooltipRow: Equatable {
    let label: String
    let value: String
}

private struct AnalyticsScreenCachePayload {
    let system: SystemAnalytics
    let adsb: ADSBAnalytics
    let satellite: SatelliteAnalytics
    let tuya: TuyaTemperatureHumidityResponse
}

private enum AnalyticsScreenCache {
    static var entries: [String: AnalyticsScreenCachePayload] = [:]
}

private struct AnalyticsLinePoint: Identifiable, Equatable {
    let date: Date
    let value: Double
    let valueText: String
    let title: String
    let timestampText: String
    let details: [AnalyticsTooltipRow]

    var id: Date { date }
}

private struct AnalyticsBarPoint: Identifiable, Equatable {
    let xValue: Int
    let value: Double
    let valueText: String
    let title: String
    let timestampText: String
    let details: [AnalyticsTooltipRow]

    var id: Int { xValue }
}

private struct InteractiveAnalyticsLineChart: View {
    let points: [AnalyticsLinePoint]
    let color: Color
    let axisFormat: Date.FormatStyle
    var showsArea = false
    var height: CGFloat = 200
    var yDomainOverride: ClosedRange<Double>? = nil
    let yAxisLabel: (Double) -> String

    @State private var selectedPoint: AnalyticsLinePoint?

    var body: some View {
        Chart {
            ForEach(points) { point in
                if showsArea {
                    AreaMark(
                        x: .value("Tempo", point.date),
                        y: .value("Valor", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.18), color.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                LineMark(
                    x: .value("Tempo", point.date),
                    y: .value("Valor", point.value)
                )
                .foregroundStyle(color)

                if selectedPoint?.id == point.id {
                    PointMark(
                        x: .value("Tempo", point.date),
                        y: .value("Valor", point.value)
                    )
                    .foregroundStyle(color)
                    .symbolSize(80)
                }
            }

            if let selectedPoint {
                RuleMark(x: .value("Tempo", selectedPoint.date))
                    .foregroundStyle(color.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .frame(height: height)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel(format: axisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { axisValue in
                AxisGridLine()
                AxisValueLabel {
                    if let value = axisValue.as(Double.self) {
                        Text(yAxisLabel(value))
                            .foregroundStyle(AnalyticsTheme.ink.opacity(0.62))
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(AnalyticsTheme.plotSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrameAnchor = proxy.plotFrame {
                    let plotFrame = geometry[plotFrameAnchor]

                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateSelection(
                                            at: value.location,
                                            proxy: proxy,
                                            geometry: geometry
                                        )
                                    }
                                    .onEnded { value in
                                        updateSelection(
                                            at: value.location,
                                            proxy: proxy,
                                            geometry: geometry
                                        )
                                    }
                            )

                        if let selectedPoint,
                            let plotX = proxy.position(forX: selectedPoint.date),
                            let plotY = proxy.position(forY: selectedPoint.value)
                        {
                            AnalyticsChartTooltip(
                                accent: color,
                                value: selectedPoint.valueText,
                                title: selectedPoint.title,
                                timestampText: selectedPoint.timestampText,
                                details: selectedPoint.details
                            )
                            .frame(width: tooltipWidth, alignment: .leading)
                            .position(
                                x: tooltipXPosition(
                                    plotX: plotFrame.minX + plotX,
                                    plotFrame: plotFrame
                                ),
                                y: tooltipYPosition(
                                    plotY: plotFrame.minY + plotY,
                                    tooltipHeight: tooltipHeight(for: selectedPoint),
                                    plotFrame: plotFrame
                                )
                            )
                            .animation(.easeOut(duration: 0.16), value: selectedPoint.id)
                        }
                    }
                }
            }
        }
        .onChange(of: points) { _, newPoints in
            guard let selectedPoint else { return }
            self.selectedPoint = newPoints.first(where: { $0.id == selectedPoint.id })
        }
    }

    private var yDomain: ClosedRange<Double> {
        if let yDomainOverride {
            return yDomainOverride
        }

        let values = points.map(\.value)
        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...1
        }

        let span = max(maxValue - minValue, max(abs(maxValue), 1) * 0.08)
        let padding = span * 0.25
        let lowerBound = minValue - padding
        let upperBound = maxValue + padding

        if minValue >= 0 {
            return max(0, lowerBound)...upperBound
        }
        return lowerBound...upperBound
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else {
            selectedPoint = nil
            return
        }

        let relativeX = location.x - plotFrame.origin.x
        guard let selectedDate = proxy.value(atX: relativeX, as: Date.self) else { return }

        selectedPoint = points.min {
            abs($0.date.timeIntervalSince(selectedDate))
                < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var tooltipWidth: CGFloat { 196 }

    private func tooltipHeight(for point: AnalyticsLinePoint) -> CGFloat {
        82 + CGFloat(point.details.count) * 18
    }

    private func tooltipXPosition(plotX: CGFloat, plotFrame: CGRect) -> CGFloat {
        let halfWidth = tooltipWidth / 2
        let minX = plotFrame.minX + halfWidth + 8
        let maxX = plotFrame.maxX - halfWidth - 8
        return min(max(plotX, minX), maxX)
    }

    private func tooltipYPosition(plotY: CGFloat, tooltipHeight: CGFloat, plotFrame: CGRect)
        -> CGFloat
    {
        let preferredAbove = plotY - (tooltipHeight / 2) - 18
        let minimum = plotFrame.minY + (tooltipHeight / 2) + 8
        if preferredAbove >= minimum {
            return preferredAbove
        }

        let below = plotY + (tooltipHeight / 2) + 18
        let maximum = plotFrame.maxY - (tooltipHeight / 2) - 8
        return min(maximum, max(minimum, below))
    }
}

private struct InteractiveAnalyticsBarChart: View {
    let points: [AnalyticsBarPoint]
    let color: Color
    let xAxisLabel: (Double) -> String

    @State private var selectedPoint: AnalyticsBarPoint?

    var body: some View {
        Chart {
            ForEach(points) { point in
                BarMark(
                    x: .value("Hora", point.xValue),
                    y: .value("Valor", point.value)
                )
                .foregroundStyle(selectedPoint?.id == point.id ? color : color.opacity(0.75))

                if selectedPoint?.id == point.id {
                    RuleMark(x: .value("Hora", point.xValue))
                        .foregroundStyle(color.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
        }
        .frame(height: 150)
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                if let hourValue = value.as(Double.self) {
                    AxisValueLabel(xAxisLabel(hourValue))
                        .foregroundStyle(AnalyticsTheme.ink.opacity(0.62))
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .background(AnalyticsTheme.plotSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let plotFrameAnchor = proxy.plotFrame {
                    let plotFrame = geometry[plotFrameAnchor]

                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        updateSelection(
                                            at: value.location,
                                            proxy: proxy,
                                            geometry: geometry
                                        )
                                    }
                                    .onEnded { value in
                                        updateSelection(
                                            at: value.location,
                                            proxy: proxy,
                                            geometry: geometry
                                        )
                                    }
                            )

                        if let selectedPoint,
                            let plotX = proxy.position(forX: selectedPoint.xValue),
                            let plotY = proxy.position(forY: selectedPoint.value)
                        {
                            AnalyticsChartTooltip(
                                accent: color,
                                value: selectedPoint.valueText,
                                title: selectedPoint.title,
                                timestampText: selectedPoint.timestampText,
                                details: selectedPoint.details
                            )
                            .frame(width: tooltipWidth, alignment: .leading)
                            .position(
                                x: tooltipXPosition(
                                    plotX: plotFrame.minX + plotX,
                                    plotFrame: plotFrame
                                ),
                                y: tooltipYPosition(
                                    plotY: plotFrame.minY + plotY,
                                    tooltipHeight: tooltipHeight(for: selectedPoint),
                                    plotFrame: plotFrame
                                )
                            )
                            .animation(.easeOut(duration: 0.16), value: selectedPoint.id)
                        }
                    }
                }
            }
        }
        .onChange(of: points) { _, newPoints in
            guard let selectedPoint else { return }
            self.selectedPoint = newPoints.first(where: { $0.id == selectedPoint.id })
        }
    }

    private var yDomain: ClosedRange<Double> {
        let maxValue = points.map(\.value).max() ?? 1
        return 0...max(maxValue * 1.2, maxValue + 1)
    }

    private func updateSelection(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrameAnchor = proxy.plotFrame else { return }
        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else {
            selectedPoint = nil
            return
        }

        let relativeX = location.x - plotFrame.origin.x
        guard let rawValue = proxy.value(atX: relativeX, as: Double.self) else { return }

        selectedPoint = points.min {
            abs(Double($0.xValue) - rawValue) < abs(Double($1.xValue) - rawValue)
        }
    }

    private var tooltipWidth: CGFloat { 196 }

    private func tooltipHeight(for point: AnalyticsBarPoint) -> CGFloat {
        82 + CGFloat(point.details.count) * 18
    }

    private func tooltipXPosition(plotX: CGFloat, plotFrame: CGRect) -> CGFloat {
        let halfWidth = tooltipWidth / 2
        let minX = plotFrame.minX + halfWidth + 8
        let maxX = plotFrame.maxX - halfWidth - 8
        return min(max(plotX, minX), maxX)
    }

    private func tooltipYPosition(plotY: CGFloat, tooltipHeight: CGFloat, plotFrame: CGRect)
        -> CGFloat
    {
        let preferredAbove = plotY - (tooltipHeight / 2) - 16
        let minimum = plotFrame.minY + (tooltipHeight / 2) + 8
        if preferredAbove >= minimum {
            return preferredAbove
        }

        let below = plotY + (tooltipHeight / 2) + 16
        let maximum = plotFrame.maxY - (tooltipHeight / 2) - 8
        return min(maximum, max(minimum, below))
    }
}

private struct AnalyticsChartTooltip: View {
    let accent: Color
    let value: String
    let title: String
    let timestampText: String
    let details: [AnalyticsTooltipRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)

                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AnalyticsTheme.ink)
            }

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AnalyticsTheme.ink)
                .lineLimit(1)

            Label(timestampText, systemImage: "clock")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(AnalyticsTheme.ink.opacity(0.58))
                .lineLimit(1)

            if !details.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(details.enumerated()), id: \.offset) { _, detail in
                        HStack(spacing: 10) {
                            Text(detail.label)
                                .font(.caption2)
                                .foregroundStyle(AnalyticsTheme.ink.opacity(0.56))

                            Spacer(minLength: 8)

                            Text(detail.value)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(AnalyticsTheme.ink)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AnalyticsTheme.surfaceTop, AnalyticsTheme.mist],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(accent.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: AnalyticsTheme.shadow.opacity(0.12), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Extensions

extension MetricTrend {
    var displayName: String {
        switch self {
        case .rising: return "Subindo"
        case .falling: return "Descendo"
        case .stable: return "Estável"
        }
    }

    var iconName: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "minus"
        }
    }

    var color: Color {
        switch self {
        case .rising: return .red
        case .falling: return .green
        case .stable: return .gray
        }
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(AppState())
}
