// MARK: - Distance Calculation Helper
import CoreLocation
// Internal PlaneSpottersView removed in favor of global AircraftPhotoView component.
import Foundation
import MapKit
import SwiftUI
import UIKit

private func adsbAdaptiveColor(light: UIColor, dark: UIColor) -> Color {
    Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    )
}

private func adsbRGBA(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1)
    -> UIColor
{
    UIColor(red: red, green: green, blue: blue, alpha: alpha)
}

private enum ADSBTheme {
    static let radarBlue = Color(red: 0.11, green: 0.31, blue: 0.82)
    static let radarBlueDeep = Color(red: 0.05, green: 0.13, blue: 0.38)
    static let radarGreen = Color(red: 0.31, green: 0.90, blue: 0.35)
    static let radarMint = Color(red: 0.73, green: 0.98, blue: 0.62)
    static let ink = adsbAdaptiveColor(
        light: adsbRGBA(0.08, 0.11, 0.20),
        dark: adsbRGBA(0.92, 0.95, 1.00)
    )
    static let secondaryInk = adsbAdaptiveColor(
        light: adsbRGBA(0.26, 0.31, 0.42),
        dark: adsbRGBA(0.76, 0.82, 0.92)
    )
    static let tertiaryInk = adsbAdaptiveColor(
        light: adsbRGBA(0.43, 0.48, 0.58),
        dark: adsbRGBA(0.61, 0.68, 0.79)
    )
    static let sectionInk = adsbAdaptiveColor(
        light: adsbRGBA(0.05, 0.13, 0.38),
        dark: adsbRGBA(0.34, 0.52, 0.98)
    )
    static let mist = adsbAdaptiveColor(
        light: adsbRGBA(0.94, 0.97, 1.00),
        dark: adsbRGBA(0.09, 0.11, 0.18)
    )
    static let cloud = adsbAdaptiveColor(
        light: adsbRGBA(0.97, 0.99, 1.00),
        dark: adsbRGBA(0.04, 0.06, 0.12)
    )
    static let canvasMid = adsbAdaptiveColor(
        light: adsbRGBA(1.00, 1.00, 1.00),
        dark: adsbRGBA(0.06, 0.08, 0.15)
    )
    static let canvasEnd = adsbAdaptiveColor(
        light: adsbRGBA(0.96, 0.99, 0.98),
        dark: adsbRGBA(0.08, 0.10, 0.17)
    )
    static let surfaceTop = adsbAdaptiveColor(
        light: adsbRGBA(1.00, 1.00, 1.00, 0.98),
        dark: adsbRGBA(0.13, 0.16, 0.24, 0.98)
    )
    static let surfaceStroke = adsbAdaptiveColor(
        light: adsbRGBA(1.00, 1.00, 1.00, 0.92),
        dark: adsbRGBA(0.26, 0.31, 0.42, 0.88)
    )
    static let toolbarBubble = adsbAdaptiveColor(
        light: adsbRGBA(1.00, 1.00, 1.00, 0.78),
        dark: adsbRGBA(0.16, 0.20, 0.28, 0.94)
    )
    static let shadow = adsbAdaptiveColor(
        light: adsbRGBA(0.06, 0.13, 0.34),
        dark: adsbRGBA(0.00, 0.00, 0.00)
    )
}

private struct ADSBPanelBackground: View {
    let cornerRadius: CGFloat
    let highlight: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [ADSBTheme.surfaceTop, ADSBTheme.mist],
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
                            colors: [highlight.opacity(0.28), ADSBTheme.surfaceStroke],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            }
            .shadow(color: ADSBTheme.shadow.opacity(0.10), radius: 22, x: 0, y: 12)
            .shadow(color: highlight.opacity(0.08), radius: 14, x: 0, y: 6)
    }
}

private extension View {
    func adsbPanel(cornerRadius: CGFloat = 18, highlight: Color = ADSBTheme.radarBlue) -> some View {
        background(ADSBPanelBackground(cornerRadius: cornerRadius, highlight: highlight))
    }
}

private struct ADSBToolbarTitle: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ADSBTheme.radarGreen.opacity(0.22), ADSBTheme.radarBlue.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Circle()
                    .stroke(ADSBTheme.radarGreen.opacity(0.45), lineWidth: 1.2)
                    .frame(width: 28, height: 28)

                Circle()
                    .fill(ADSBTheme.radarGreen)
                    .frame(width: 6, height: 6)
                    .shadow(color: ADSBTheme.radarGreen.opacity(0.45), radius: 6, x: 0, y: 0)
            }

            Text("ADS-B")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(
                    LinearGradient(
                        colors: [ADSBTheme.radarBlueDeep, ADSBTheme.radarBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("ADS-B")
    }
}

private struct ADSBSourceChip: View {
    let title: String
    let value: String
    let tint: Color
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ADSBTheme.secondaryInk)

            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)

                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ADSBTheme.ink)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(tint.opacity(isActive ? 0.16 : 0.08))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(isActive ? 0.28 : 0.12), lineWidth: 1)
        )
    }
}

struct ADSBView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAircraftList = false
    @State private var movementSheet: MovementFilter?
    @State private var selectedHighlightAircraft: Aircraft?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    GlassSection(spacing: 20) {
                        trafficScopeBar

                        if let summary = appState.adsbSummary {
                            // Live Stats Header
                            liveStatsHeader(
                                summary,
                                countOverride: appState.isOpenSkyEnabled
                                    ? appState.aircraftList.count : nil)

                            // Quick Stats Grid
                            statsGridSection(summary)

                            // Highlights Section
                            if summary.highlights.highest != nil
                                || summary.highlights.fastest != nil
                                || summary.highlights.closest != nil
                            {
                                highlightsSection(summary.highlights)
                            }

                            // Airlines Carousel
                            if !airlinesForSection.isEmpty {
                                airlinesSection(airlinesForSection)
                            }
                        } else if let error = appState.adsbError {
                            ErrorCard(message: error)
                        } else if !appState.aircraftList.isEmpty {
                            ErrorCard(message: "Resumo indisponivel. Mostrando aeronaves da rede.")
                        } else {
                            LoadingCard()
                        }

                        tuyaSensorSection

                        // Aircraft List Preview
                        if !appState.aircraftList.isEmpty {
                            aircraftPreviewSection
                        }

                        // History Chart
                        if let history = appState.adsbHistory {
                            historyChartSection(history)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background {
                ZStack {
                    LinearGradient(
                        colors: [ADSBTheme.cloud, ADSBTheme.canvasMid, ADSBTheme.canvasEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [ADSBTheme.radarBlue.opacity(0.12), .clear],
                        center: .topLeading,
                        startRadius: 20,
                        endRadius: 420
                    )

                    RadialGradient(
                        colors: [ADSBTheme.radarGreen.opacity(0.10), .clear],
                        center: .topTrailing,
                        startRadius: 30,
                        endRadius: 360
                    )
                }
                .ignoresSafeArea()
            }
            .navigationTitle("ADS-B")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ADSBToolbarTitle()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        NotificationCenter.default.post(
                            name: Notification.Name("meulab.navigateToTab"),
                            object: nil,
                            userInfo: ["tab": ContentView.Tab.flightSearch.rawValue]
                        )
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ADSBTheme.radarBlue)
                            .padding(8)
                            .background(Circle().fill(ADSBTheme.toolbarBubble))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle(isOn: $appState.isOpenSkyEnabled) {
                            Label("Tráfego Global (OpenSky)", systemImage: "globe")
                        }
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(ADSBTheme.radarBlue)
                                .padding(8)
                                .background(Circle().fill(ADSBTheme.toolbarBubble))
                        }
                }
            }
            .sheet(isPresented: $showAircraftList) {
                AircraftListSheet(aircraft: appState.aircraftList)
            }
            .sheet(item: $movementSheet) { filter in
                MovementAircraftSheet(
                    filter: filter,
                    aircraft: filteredAircraft(for: filter)
                )
            }
            .sheet(item: $selectedHighlightAircraft) { aircraft in
                NavigationStack {
                    AircraftDetailView(ac: aircraft)
                        .navigationTitle(aircraft.displayCallsign)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Fechar") {
                                    selectedHighlightAircraft = nil
                                }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private var trafficScopeBar: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Label("Fonte do Radar", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ADSBTheme.ink.opacity(0.82))

                    Text(appState.isOpenSkyEnabled ? "EXPANDIDO" : "LOCAL")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(
                            appState.isOpenSkyEnabled ? ADSBTheme.radarGreen : ADSBTheme.radarBlue
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            (appState.isOpenSkyEnabled ? ADSBTheme.radarGreen : ADSBTheme.radarBlue)
                                .opacity(0.14),
                            in: Capsule()
                        )
                }

                Text("Controle de cobertura e origem dos dados")
                    .font(.caption)
                    .foregroundStyle(ADSBTheme.secondaryInk)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        ADSBSourceChip(
                            title: "Radar local",
                            value: localSourceDetail,
                            tint: ADSBTheme.radarGreen,
                            isActive: !appState.isOpenSkyEnabled
                        )

                        ADSBSourceChip(
                            title: "OpenSky",
                            value: openSkySourceDetail,
                            tint: ADSBTheme.radarBlue,
                            isActive: appState.isOpenSkyEnabled
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ADSBSourceChip(
                            title: "Radar local",
                            value: localSourceDetail,
                            tint: ADSBTheme.radarGreen,
                            isActive: !appState.isOpenSkyEnabled
                        )

                        ADSBSourceChip(
                            title: "OpenSky",
                            value: openSkySourceDetail,
                            tint: ADSBTheme.radarBlue,
                            isActive: appState.isOpenSkyEnabled
                        )
                    }
                }
            }

            Spacer()

            Toggle("", isOn: $appState.isOpenSkyEnabled)
                .labelsHidden()
                .tint(ADSBTheme.radarGreen)
                .scaleEffect(1.02)
        }
        .padding(18)
        .adsbPanel(
            cornerRadius: 22,
            highlight: appState.isOpenSkyEnabled ? ADSBTheme.radarGreen : ADSBTheme.radarBlue
        )
    }

    private var localSourceDetail: String {
        let count = max(appState.localAircraftCount, 0)
        return count > 0 ? "\(count) ativas" : "aguardando"
    }

    private var openSkySourceDetail: String {
        guard appState.isOpenSkyEnabled else { return "desligado" }
        let count = max(appState.openskyAircraftCount, 0)
        return count > 0 ? "\(count) na rede" : "sincronizando"
    }

    private var airlinesForSection: [Airline] {
        if !appState.adsbAirlines.isEmpty {
            return appState.adsbAirlines
        }
        return appState.adsbSummary?.airlines ?? []
    }

    private func resolveAircraft(for callsign: String?) -> Aircraft? {
        guard let callsign else { return nil }
        let key = callsign.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !key.isEmpty else { return nil }

        return appState.aircraftList.first {
            let c1 = $0.callsign.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let c2 = $0.displayCallsign.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return c1 == key || c2 == key
        }
    }

    // MARK: - Live Stats Header

    @ViewBuilder
    private func liveStatsHeader(_ summary: ADSBSummary, countOverride: Int? = nil) -> some View {
        HStack(spacing: 16) {
            // Main count with pulse animation
            VStack(alignment: .leading, spacing: 6) {
                Text("Radar ao vivo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ADSBTheme.radarBlueDeep.opacity(0.62))
                    .textCase(.uppercase)

                HStack(spacing: 8) {
                    Circle()
                        .fill(ADSBTheme.radarGreen)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(ADSBTheme.radarGreen.opacity(0.35), lineWidth: 10)
                                .scaleEffect(1.5)
                        )

                    Text("\(countOverride ?? summary.totalNow)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ADSBTheme.ink)
                }

                Text("aeronaves no ar")
                    .font(.subheadline)
                    .foregroundStyle(ADSBTheme.ink.opacity(0.65))
            }

            Spacer()

            // Mini stats
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(ADSBTheme.radarGreen)
                    Text("\(summary.withPos)")
                        .font(.callout.bold())
                        .monospacedDigit()
                        .foregroundStyle(ADSBTheme.ink)
                    Text("rastreadas")
                        .font(.caption)
                        .foregroundStyle(ADSBTheme.ink.opacity(0.55))
                }

                HStack(spacing: 4) {
                    Image(systemName: "shield.fill")
                        .font(.caption)
                        .foregroundStyle(ADSBTheme.radarBlue)
                    Text("\(summary.nonCivilNow)")
                        .font(.callout.bold())
                        .monospacedDigit()
                        .foregroundStyle(ADSBTheme.ink)
                    Text("Não Civil")
                        .font(.caption)
                        .foregroundStyle(ADSBTheme.ink.opacity(0.55))
                }
            }
        }
        .padding(20)
        .adsbPanel(cornerRadius: 24, highlight: ADSBTheme.radarGreen)
    }

    // MARK: - Stats Grid

    @ViewBuilder
    private func statsGridSection(_ summary: ADSBSummary) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12),
            ], spacing: 12
        ) {
            Button {
                movementSheet = .climbing
            } label: {
                MiniStatCard(
                    icon: "arrow.up.circle.fill",
                    value: "\(summary.movement.climbing)",
                    label: "Subindo",
                    color: .green
                )
            }
            .buttonStyle(.plain)

            Button {
                movementSheet = .descending
            } label: {
                MiniStatCard(
                    icon: "arrow.down.circle.fill",
                    value: "\(summary.movement.descending)",
                    label: "Descendo",
                    color: .orange
                )
            }
            .buttonStyle(.plain)

            Button {
                movementSheet = .cruising
            } label: {
                MiniStatCard(
                    icon: "arrow.right.circle.fill",
                    value: "\(summary.movement.cruising)",
                    label: "Cruzeiro",
                    color: .blue
                )
            }
            .buttonStyle(.plain)
        }

        // Averages row
        HStack(spacing: 12) {
            AverageStatCard(
                icon: "airplane.departure",
                title: "Altitude Média",
                value: Formatters.altitudeDual(summary.averages.altitudeFt).aviation,
                subtitle: Formatters.altitudeDual(summary.averages.altitudeFt).metric
            )

            AverageStatCard(
                icon: "gauge.with.needle.fill",
                title: "Velocidade Média",
                value: Formatters.speedDual(summary.averages.speedKt).aviation,
                subtitle: Formatters.speedDual(summary.averages.speedKt).metric
            )
        }
    }

    // MARK: - Highlights

    @ViewBuilder
    private func highlightsSection(_ highlights: Highlights) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Destaques", icon: "star.fill")

            VStack(spacing: 0) {
                if let highest = highlights.highest, highest.callsign != nil {
                    Button {
                        selectedHighlightAircraft = resolveAircraft(for: highest.callsign)
                    } label: {
                        HighlightRowApple(
                            icon: "arrow.up.to.line.circle.fill",
                            iconColor: .blue,
                            title: "Mais Alto",
                            callsign: highest.callsign ?? "",
                            value: Formatters.altitudeDual(highest.altitudeFt ?? 0).aviation,
                            subtitle: Formatters.altitudeDual(highest.altitudeFt ?? 0).metric
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let fastest = highlights.fastest, fastest.callsign != nil {
                    Divider().padding(.leading, 56)
                    Button {
                        selectedHighlightAircraft = resolveAircraft(for: fastest.callsign)
                    } label: {
                        HighlightRowApple(
                            icon: "hare.fill",
                            iconColor: .orange,
                            title: "Mais Rápido",
                            callsign: fastest.callsign ?? "",
                            value: Formatters.speedDual(fastest.speedKt ?? 0).aviation,
                            subtitle: Formatters.speedDual(fastest.speedKt ?? 0).metric
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let closest = highlights.closest, closest.callsign != nil {
                    Divider().padding(.leading, 56)
                    Button {
                        selectedHighlightAircraft = resolveAircraft(for: closest.callsign)
                    } label: {
                        HighlightRowApple(
                            icon: "location.circle.fill",
                            iconColor: .green,
                            title: "Mais Perto",
                            callsign: closest.callsign ?? "",
                            value: Formatters.distanceDual(closest.distanceNm ?? 0).aviation,
                            subtitle: Formatters.distanceDual(closest.distanceNm ?? 0).metric
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
    }

    // MARK: - Airlines

    @ViewBuilder
    private func airlinesSection(_ airlines: [Airline]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Companhias Aéreas", icon: "building.2.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(airlines) { airline in
                        AirlineChip(airline: airline)
                    }
                }
            }
        }
    }

    // MARK: - Aircraft Preview

    // MARK: - Aircraft Preview

    @State private var selectedNearbyAircraft: Aircraft?

    private var aircraftPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "Aeronaves Próximas", icon: "airplane")

                Spacer()

                Button {
                    showAircraftList = true
                } label: {
                    Text("Ver Todas")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ADSBTheme.radarBlue)
                }
            }

            VStack(spacing: 0) {
                let nearbyAircraft = appState.adsbNearbyAircraftPreview

                ForEach(Array(nearbyAircraft.enumerated()), id: \.element.id) { index, aircraft in
                    Button {
                        selectedNearbyAircraft = aircraft
                    } label: {
                        AircraftRowApple(aircraft: aircraft)
                            .contentShape(Rectangle())  // Ensure tap area covers the row
                    }
                    .buttonStyle(.plain)

                    if index < nearbyAircraft.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }

                if nearbyAircraft.isEmpty {
                    ContentUnavailableView(
                        "Nenhuma aeronave próxima", systemImage: "location.slash"
                    )
                    .padding()
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)
        }
        .sheet(item: $selectedNearbyAircraft) { aircraft in
            NavigationStack {
                AircraftDetailView(ac: aircraft)
                    .navigationTitle(aircraft.displayCallsign)
                    .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fechar") {
                                selectedNearbyAircraft = nil
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Tuya Sensor

    @ViewBuilder
    private var tuyaSensorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sensor Casa", icon: "humidity.fill")

            if let message = tuyaSensorMessage {
                TuyaSensorStatusCard(message: message)
            } else if let sensor = appState.tuyaSensor, let current = sensor.current {
                TuyaSensorCard(sensor: sensor, current: current)
            } else {
                LoadingCard()
            }
        }
    }

    // MARK: - History Chart

    @ViewBuilder
    private func historyChartSection(_ history: ADSBHistoryResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Histórico 7 Dias", icon: "chart.bar.fill")

            let peaks = history.days.map { day -> (String, Int) in
                let hours = history.dailyPeaks[day] ?? [:]
                let maxValue = hours.values.max() ?? 0
                return (day, maxValue)
            }

            VStack(spacing: 8) {
                ForEach(peaks, id: \.0) { day, value in
                    HStack(spacing: 12) {
                        Text(formatDay(day))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .leading)

                        GeometryReader { geo in
                            let maxPeak = peaks.map(\.1).max() ?? 1
                            let width = CGFloat(value) / CGFloat(max(maxPeak, 1)) * geo.size.width

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [ADSBTheme.radarBlue, ADSBTheme.radarGreen],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(width, 4))
                            }
                        }
                        .frame(height: 8)

                        Text("\(value)")
                            .font(.caption.monospaced().bold())
                            .foregroundStyle(.primary)
                            .frame(width: 32, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 16)

            // Records bubbles
            HStack(spacing: 8) {
                RecordBubble(
                    icon: "airplane.circle.fill",
                    value: "\(Int(history.records.maxSimultaneous.value))",
                    label: "máx aeronaves"
                )
                RecordBubble(
                    icon: "speedometer",
                    value: Formatters.speedDual(Int(history.records.maxSpeed.value)).aviation,
                    subtitle: Formatters.speedDual(Int(history.records.maxSpeed.value)).metric,
                    label: "máx velocidade"
                )
                RecordBubble(
                    icon: "arrow.up.circle.fill",
                    value: Formatters.altitudeDual(Int(history.records.maxAltitude.value)).aviation,
                    subtitle: Formatters.altitudeDual(Int(history.records.maxAltitude.value))
                        .metric,
                    label: "máx altitude"
                )
            }
        }
    }

    // MARK: - Helpers

    private func filteredAircraft(for filter: MovementFilter) -> [Aircraft] {
        print("[ADSBView] 🔍 Filtering aircraft for: \(filter.title)")
        print("[ADSBView]   Total aircraft in list: \(appState.aircraftList.count)")

        let filtered = appState.aircraftList.filter { filter.matches($0) }
        print("[ADSBView]   Filtered count: \(filtered.count)")

        if filtered.count > 0, let first = filtered.first {
            print(
                "[ADSBView]   First aircraft: \(first.callsign) - VR: \(first.verticalRateFpm) fpm")
        }

        switch filter {
        case .climbing:
            return filtered.sorted { $0.verticalRateFpm > $1.verticalRateFpm }
        case .descending:
            return filtered.sorted { $0.verticalRateFpm < $1.verticalRateFpm }
        case .cruising:
            return filtered.sorted { $0.altitudeFt > $1.altitudeFt }
        }
    }

    private func formatDay(_ day: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: day) {
            formatter.dateFormat = "dd/MM"
            return formatter.string(from: date)
        }
        return day
    }

    private var tuyaSensorMessage: String? {
        if let sensor = appState.tuyaSensor, let message = sensor.friendlyErrorMessage {
            return message
        }
        return appState.tuyaSensorError
    }
}

// MARK: - Supporting Components

private enum MovementFilter: String, Identifiable {
    case climbing, descending, cruising

    var id: String { rawValue }

    var title: String {
        switch self {
        case .climbing: return "Subindo"
        case .descending: return "Descendo"
        case .cruising: return "Cruzeiro"
        }
    }

    func matches(_ aircraft: Aircraft) -> Bool {
        switch self {
        case .climbing:
            return aircraft.verticalRateFpm > 256
        case .descending:
            return aircraft.verticalRateFpm < -256
        case .cruising:
            return aircraft.verticalRateFpm <= 256 && aircraft.verticalRateFpm >= -256
        }
    }
}

private struct MovementAircraftSheet: View {
    let filter: MovementFilter
    let aircraft: [Aircraft]
    @Environment(\.dismiss) private var dismiss
    @State private var faFlightsByIdent: [String: FlightAwareFlight] = [:]
    @State private var loadingFlightAware = false

    private var sortedAircraft: [Aircraft] {
        aircraft.sorted { abs($0.verticalRateFpm) > abs($1.verticalRateFpm) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Label("\(aircraft.count) aeronaves", systemImage: "airplane")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .materialCard(cornerRadius: 10)

                        if loadingFlightAware {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.75)
                                Text("Buscando FlightAware...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .materialCard(cornerRadius: 10)
                        }
                    }

                    if sortedAircraft.isEmpty {
                        ContentUnavailableView(
                            "Sem aeronaves no momento",
                            systemImage: "airplane.circle"
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 36)
                    } else {
                        GlassSection(spacing: 10) {
                            ForEach(sortedAircraft) { ac in
                                NavigationLink(destination: AircraftDetailView(ac: ac)) {
                                    MovementAircraftRow(
                                        ac: ac,
                                        faFlight: faFlightsByIdent[flightAwareKey(for: ac.callsign)]
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background {
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.08), Color.cyan.opacity(0.05),
                        Color(.systemBackground),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            .navigationTitle(filter.title)
            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            await loadFlightAwareSummaries()
        }
    }

    private func flightAwareKey(for callsign: String) -> String {
        callsign.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    @MainActor
    private func loadFlightAwareSummaries() async {
        guard !loadingFlightAware else { return }
        guard faFlightsByIdent.isEmpty else { return }

        let idents =
            sortedAircraft
            .map { flightAwareKey(for: $0.callsign) }
            .filter { !$0.isEmpty && $0 != "???" }

        guard !idents.isEmpty else { return }

        loadingFlightAware = true
        defer { loadingFlightAware = false }

        for ident in idents.prefix(12) {
            if faFlightsByIdent[ident] != nil { continue }

            do {
                let response = try await APIService.shared.fetchFlightAwareFlight(
                    ident: ident,
                    maxPages: 1
                )
                if let flight = response.data.flights?.first {
                    faFlightsByIdent[ident] = flight
                }
            } catch {
                // Keep UI responsive; individual failures are ignored.
            }
        }
    }
}

private struct MovementAircraftRow: View {
    let ac: Aircraft
    let faFlight: FlightAwareFlight?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let logoURL = ac.airlineLogoURL {
                    AsyncImage(url: logoURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 34, height: 34)
                        default:
                            Circle()
                                .fill(.blue.opacity(0.12))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "airplane")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                )
                        }
                    }
                } else {
                    Circle()
                        .fill(.blue.opacity(0.12))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "airplane")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(ac.displayCallsign)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let reg = ac.registration, !reg.isEmpty {
                            Text(reg)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 8) {
                        if let model = ac.model, !model.isEmpty {
                            Text(model)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let airline = ac.airline {
                            Text(airline)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(ac.altitudeFt) ft")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("\(ac.speedKt) kt")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                Label(
                    ac.verticalRateFpm > 0
                        ? "Subindo" : (ac.verticalRateFpm < 0 ? "Descendo" : "Nivelado"),
                    systemImage: ac.verticalRateFpm > 0
                        ? "arrow.up"
                        : (ac.verticalRateFpm < 0 ? "arrow.down" : "arrow.left.and.right")
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(
                    ac.verticalRateFpm > 0
                        ? .green : (ac.verticalRateFpm < 0 ? .orange : .secondary)
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (ac.verticalRateFpm > 0
                        ? Color.green : (ac.verticalRateFpm < 0 ? Color.orange : Color.gray))
                        .opacity(0.12), in: Capsule())

                Text("\(abs(ac.verticalRateFpm)) fpm")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }

            if let faFlight {
                Divider().opacity(0.35)
                HStack(spacing: 8) {
                    let origin = faFlight.origin?.bestCode ?? "-"
                    let destination = faFlight.destination?.bestCode ?? "-"
                    Text(origin)
                        .font(.caption.weight(.semibold))
                        .monospaced()
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(destination)
                        .font(.caption.weight(.semibold))
                        .monospaced()

                    Spacer()

                    let outTime =
                        FlightAwareTime.short(faFlight.actualOut)
                        ?? FlightAwareTime.short(faFlight.estimatedOut)
                        ?? FlightAwareTime.short(faFlight.scheduledOut)
                    let inTime =
                        FlightAwareTime.short(faFlight.actualIn)
                        ?? FlightAwareTime.short(faFlight.estimatedIn)
                        ?? FlightAwareTime.short(faFlight.scheduledIn)

                    if let outTime, let inTime {
                        Text("\(outTime) • \(inTime)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("FlightAware")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ADSBTheme.sectionInk)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ADSBTheme.sectionInk)
                .textCase(.uppercase)
        }
    }
}

struct MiniStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.14))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(ADSBTheme.ink)

            Text(label)
                .font(.caption)
                .foregroundStyle(ADSBTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .adsbPanel(cornerRadius: 18, highlight: color)
    }
}

struct AverageStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ADSBTheme.radarBlue.opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ADSBTheme.radarBlue)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(ADSBTheme.secondaryInk)

                Text(value)
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(ADSBTheme.ink)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(ADSBTheme.tertiaryInk)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .adsbPanel(cornerRadius: 18, highlight: ADSBTheme.radarBlue)
    }
}

struct HighlightRowApple: View {
    let icon: String
    let iconColor: Color
    let title: String
    let callsign: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(ADSBTheme.secondaryInk)
                    .textCase(.uppercase)

                Text(callsign)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(ADSBTheme.secondaryInk)
            }
        }
        .padding(.vertical, 8)
    }
}

struct AirlineChip: View {
    let airline: Airline

    var body: some View {
        HStack(spacing: 8) {
            if let logoURL = airline.logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                    default:
                        Circle()
                            .fill(ADSBTheme.radarBlue.opacity(0.12))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(String(airline.name.prefix(1)))
                                    .font(.caption.bold())
                                    .foregroundStyle(ADSBTheme.radarBlue)
                            )
                    }
                }
            } else {
                Circle()
                    .fill(ADSBTheme.radarBlue.opacity(0.12))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(airline.name.prefix(1)))
                            .font(.caption.bold())
                            .foregroundStyle(ADSBTheme.radarBlue)
                    )
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(airline.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(ADSBTheme.ink)

                Text("\(airline.count) voos")
                    .font(.caption2)
                    .foregroundStyle(ADSBTheme.secondaryInk)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .adsbPanel(cornerRadius: 14, highlight: ADSBTheme.radarBlue)
    }
}

struct AircraftRowApple: View {
    let aircraft: Aircraft

    var body: some View {
        HStack(spacing: 12) {
            // Movement indicator
            ZStack {
                Circle()
                    .fill(movementColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: aircraft.movementIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(movementColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Airline logo
                    if let logoURL = aircraft.airlineLogoURL {
                        AsyncImage(url: logoURL) { phase in
                            if case .success(let image) = phase {
                                image.resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 16)
                            }
                        }
                    }

                    Text(aircraft.displayCallsign)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()

                    // Source badge
                    Text(
                        aircraft.isDualTracked
                            ? "DUAL" : (aircraft.source == .local ? "LOCAL" : "REDE")
                    )
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.15))
                    .foregroundStyle(badgeColor)
                    .clipShape(Capsule())
                }

                if let model = aircraft.model {
                    Text(model)
                        .font(.caption)
                        .foregroundStyle(ADSBTheme.secondaryInk)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                let dist = aircraft.computedDistanceNm
                // Treat > 900000 as invalid/unknown
                if dist < 900000 {
                    // Distance is primary
                    let distFmt = Formatters.distanceDual(dist)
                    Text(distFmt.aviation)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.blue)

                    Text(distFmt.metric)
                        .font(.caption2)
                        .foregroundStyle(ADSBTheme.secondaryInk)

                    // Altitude secondary
                    Text(Formatters.altitudeDual(aircraft.altitudeFt).aviation)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                } else {
                    // Fallback to Altitude (Distance unavailable)
                    let alt = Formatters.altitudeDual(aircraft.altitudeFt)
                    Text(alt.aviation)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()

                    Text(alt.metric)
                        .font(.caption2)
                        .foregroundStyle(ADSBTheme.secondaryInk)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var movementColor: Color {
        Color.fromName(aircraft.movementColor)
    }

    private var badgeColor: Color {
        aircraft.isDualTracked ? .green : (aircraft.source == .local ? .blue : .orange)
    }
}

struct RecordBubble: View {
    let icon: String
    let value: String
    var subtitle: String? = nil
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(ADSBTheme.radarBlue)
                Text(value)
                    .font(.caption.bold())
                    .monospacedDigit()
                    .foregroundStyle(ADSBTheme.ink)
            }

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 8))
                    .foregroundStyle(ADSBTheme.tertiaryInk)
                    .monospacedDigit()
            }

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(ADSBTheme.secondaryInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .adsbPanel(cornerRadius: 12, highlight: ADSBTheme.radarBlue)
    }
}

// Private PlaneSpottersPopover removed - use PlaneSpottersView instead

struct AircraftListSheet: View {
    let aircraft: [Aircraft]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(aircraft, id: \.id) { ac in
                    AircraftRowApple(aircraft: ac)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Aeronaves (\(aircraft.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

struct ErrorCard: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard(tint: .orange, cornerRadius: 16)
    }
}

struct TuyaSensorCard: View {
    let sensor: TuyaTemperatureHumidityResponse
    let current: TuyaSensorCurrent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sensor Casa")
                        .font(.headline)

                    if let source = sensor.source, !source.isEmpty {
                        Text(source.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(lastUpdatedTimeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let date = sensor.lastUpdatedAt {
                        Text(date.timeAgoDisplay())
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            HStack(spacing: 12) {
                TuyaPrimaryMetricCard(
                    title: "Temperatura",
                    value: formattedTemperature,
                    icon: "thermometer.medium",
                    color: .orange
                )

                TuyaPrimaryMetricCard(
                    title: "Umidade",
                    value: formattedHumidity,
                    icon: "humidity.fill",
                    color: .blue
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    TuyaInfoPill(icon: "battery.100", text: batteryText, tint: .green)
                    TuyaInfoPill(
                        icon: "thermometer.sun", text: temperatureAlarmText,
                        tint: alarmTint(for: current.temperatureAlarm))
                    TuyaInfoPill(
                        icon: "humidity", text: humidityAlarmText,
                        tint: alarmTint(for: current.humidityAlarm))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TuyaInfoPill(icon: "battery.100", text: batteryText, tint: .green)
                        TuyaInfoPill(
                            icon: "thermometer.sun", text: temperatureAlarmText,
                            tint: alarmTint(for: current.temperatureAlarm))
                    }

                    TuyaInfoPill(
                        icon: "humidity", text: humidityAlarmText,
                        tint: alarmTint(for: current.humidityAlarm))
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private var formattedTemperature: String {
        guard let value = current.temperatureC else { return "--" }
        return "\(value.formattedBR(decimals: 1)) °C"
    }

    private var formattedHumidity: String {
        guard let value = current.humidityPct else { return "--" }
        return "\(value.formattedBR(decimals: 0))%"
    }

    private var batteryText: String {
        if let battery = current.batteryPct {
            return "Bateria \(battery)%"
        }
        return "Bateria --"
    }

    private var temperatureAlarmText: String {
        "Temp \(alarmLabel(for: current.temperatureAlarm))"
    }

    private var humidityAlarmText: String {
        "Umid \(alarmLabel(for: current.humidityAlarm))"
    }

    private var lastUpdatedTimeText: String {
        guard let date = sensor.lastUpdatedAt else { return "Atualização indisponível" }
        return "Atualizado às \(Formatters.time.string(from: date))"
    }

    private func alarmLabel(for rawValue: String?) -> String {
        switch rawValue?.lowercased() {
        case "cancel", "normal", "none":
            return "normal"
        case "upperalarm":
            return "alto"
        case "loweralarm":
            return "baixo"
        case .some(let value) where !value.isEmpty:
            return value
        default:
            return "--"
        }
    }

    private func alarmTint(for rawValue: String?) -> Color {
        switch rawValue?.lowercased() {
        case "upperalarm", "loweralarm":
            return .orange
        default:
            return .secondary
        }
    }
}

struct TuyaPrimaryMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ADSBTheme.secondaryInk)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .adsbPanel(cornerRadius: 16, highlight: color)
    }
}

struct TuyaInfoPill: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
    }
}

struct TuyaSensorStatusCard: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 16)
    }
}

struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Carregando...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Color Extension

extension Color {
    static func fromName(_ name: String?) -> Color {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return .primary
        }
        switch name.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "mint": return .mint
        case "teal": return .teal
        case "cyan": return .cyan
        case "blue": return .blue
        case "indigo": return .indigo
        case "purple": return .purple
        case "pink": return .pink
        case "brown": return .brown
        case "gray", "grey": return .gray
        case "black": return .black
        case "white": return .white
        default: break
        }
        let hex = name.hasPrefix("#") ? String(name.dropFirst()) : name
        if hex.count == 6, let value = Int(hex, radix: 16) {
            let r = Double((value >> 16) & 0xFF) / 255.0
            let g = Double((value >> 8) & 0xFF) / 255.0
            let b = Double(value & 0xFF) / 255.0
            return Color(red: r, green: g, blue: b)
        }
        return .accentColor
    }
}

#Preview {
    ADSBView()
        .environmentObject(AppState())
}

// MARK: - Services & Helpers

/// Service to lookup aircraft registration from ICAO Hex code
actor HexLookupService {
    static let shared = HexLookupService()

    private var cache: [String: String] = [:]

    /// Tries to fetch registration for a given hex code
    func lookup(hex: String) async -> String? {
        let cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanHex.isEmpty else {
            print("[HexLookup] ⚠️ Empty hex provided")
            return nil
        }

        if let cached = cache[cleanHex] {
            return cached
        }

        // Try hexdb.io (Open API)
        // Endpoint: https://hexdb.io/api/v1/aircraft/{hex}
        let urlString = "https://hexdb.io/api/v1/aircraft/\(cleanHex)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let reg = extractRegistration(from: json) {
                    cache[cleanHex] = reg
                    return reg
                }
            }
        } catch {
            print("[HexLookup] ❌ [HexDB] Failed: \(error.localizedDescription)")
        }

        // Fallback: ADSB.one
        if let reg = await lookupADSBOne(hex: cleanHex) {
            cache[cleanHex] = reg
            return reg
        }

        // Fallback 2: ADSBDB
        if let reg = await lookupADSBDB(hex: cleanHex) {
            cache[cleanHex] = reg
            return reg
        }

        return nil
    }

    private func lookupADSBOne(hex: String) async -> String? {
        let urlString = "https://api.adsb.one/v2/hex/\(hex)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let reg = extractRegistration(from: json) {
                    return reg
                }
                if let acArray = json["ac"] as? [[String: Any]],
                    let first = acArray.first,
                    let reg = extractRegistration(from: first)
                {
                    return reg
                }
            }
        } catch {
            print("[HexLookup] ❌ [ADSB.one] Failed: \(error.localizedDescription)")
        }

        return nil
    }

    private func lookupADSBDB(hex: String) async -> String? {
        let urlString = "https://api.adsbdb.com/v0/aircraft/\(hex)"
        guard let url = URL(string: urlString) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                return nil
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let responseObj = json["response"] as? [String: Any],
                let aircraftObj = responseObj["aircraft"] as? [String: Any],
                let reg = extractRegistration(from: aircraftObj)
            {
                return reg
            }
        } catch {
            print("[HexLookup] ❌ [ADSBDB] Failed: \(error.localizedDescription)")
        }

        return nil
    }

    private func extractRegistration(from json: [String: Any]) -> String? {
        let candidates: [String?] = [
            json["registration"] as? String,
            json["Registration"] as? String,
            json["r"] as? String,
            json["tail"] as? String,
            json["tail_number"] as? String,
        ]

        for value in candidates {
            if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                !trimmed.isEmpty
            {
                return trimmed
            }
        }

        return nil
    }
}

actor NearbyCityResolver {
    static let shared = NearbyCityResolver()

    private var cache: [String: String] = [:]

    func lookup(lat: Double, lon: Double) async -> String? {
        let key = String(format: "%.2f,%.2f", lat, lon)
        if let cached = cache[key] {
            return cached
        }

        let location = CLLocation(latitude: lat, longitude: lon)
        do {
            guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else { return nil }

            let resolved =
                mapItem.address?.shortAddress ?? mapItem.address?.fullAddress ?? mapItem.name

            if let resolved, !resolved.isEmpty {
                cache[key] = resolved
                return resolved
            }
        } catch {
            return nil
        }

        return nil
    }
}

// MARK: - Consolidated Detail Views (Moved from AircraftDetailView.swift)

struct AircraftDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let ac: Aircraft

    @State private var faFlight: FlightAwareFlight?
    @State private var faLoading = false
    @State private var faError: String?

    @State private var registration: String?
    @State private var isLookingUp = false
    @State private var classifiedAirlineName: String?
    @State private var showClassificationSheet = false
    @State private var classificationMessage: String?
    @State private var isLoadingClassification = false
    @State private var nearbyCity: String?

    private var isWide: Bool { horizontalSizeClass == .regular }
    private var detailSpacing: CGFloat { isWide ? 20 : 16 }
    private var detailMaxWidth: CGFloat { isWide ? 860 : 760 }
    private var photoHeight: CGFloat { isWide ? 300 : 250 }

    var body: some View {
        ScrollView {
            VStack(spacing: detailSpacing) {
                // Premium Header with Airline Logo and Main Info
                HStack(spacing: 16) {
                    if let logoURL = ac.airlineLogoURL {
                        AsyncImage(url: logoURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fit)
                            case .failure, .empty:
                                Image(systemName: "airplane.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.blue.opacity(0.3))
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 60, height: 60)
                        .padding(8)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(ac.displayCallsign)
                            .font(.system(size: 30, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                        if let airline = classifiedAirlineName ?? ac.airline {
                            Text(airline)
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }

                        if let faFlight {
                            HStack(spacing: 6) {
                                Text(faFlight.origin?.bestCode ?? "-")
                                    .font(.caption.weight(.semibold))
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(faFlight.destination?.bestCode ?? "-")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding()
                .glassCard(cornerRadius: 24)

                // Route Visualizer (FlightAware)
                if let faFlight {
                    AircraftRouteView(flight: faFlight)
                        .padding(isWide ? 16 : 14)
                        .glassCard(cornerRadius: 20)
                        .zIndex(2)
                }

                // Aircraft Photo (PlaneSpotters with OpenSky Fallback)
                AircraftPhotoView(aircraft: ac)
                    .frame(height: photoHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .glassCard(cornerRadius: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.top, 2)
                    .zIndex(1)

                // Flight Data Grid
                VStack(spacing: 16) {
                    // Classification Section
                    Button {
                        showClassificationSheet = true
                    } label: {
                        HStack {
                            Label(
                                "Classificar empresa aérea", systemImage: "building.2.crop.circle"
                            )
                            .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)

                    if isLoadingClassification {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.85)
                            Text("Carregando classificação...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }

                    if let message = classificationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    DetailRow_Legacy(icon: "airplane", title: "Modelo", value: ac.model ?? "N/A")
                    DetailRow_Legacy(
                        icon: "number", title: "Matrícula",
                        value: registration ?? ac.registration ?? "N/A")
                    DetailRow_Legacy(
                        icon: "arrow.up.forward", title: "Altitude", value: "\(ac.altitudeFt) ft")
                    DetailRow_Legacy(
                        icon: "speedometer", title: "Velocidade",
                        value: "\(ac.speedKt) kt (\(ac.speedKmh) km/h)")
                    DetailRow_Legacy(
                        icon: "arrow.up.and.down", title: "Razão Vertical",
                        value: "\(ac.verticalRateFpm) fpm")
                    if let track = ac.track {
                        DetailRow_Legacy(
                            icon: "compass.drawing", title: "Proa",
                            value: String(format: "%.0f°", track))
                    }
                    if let lat = ac.lat, let lon = ac.lon {
                        let coordinates = String(format: "%.4f, %.4f", lat, lon)
                        let locationValue =
                            nearbyCity.map { "\(coordinates) • próximo a \($0)" } ?? coordinates
                        DetailRow_Legacy(
                            icon: "location.fill", title: "Coordenadas", value: locationValue)
                    }
                    if let dist = ac.distanceNm {
                        DetailRow_Legacy(
                            icon: "location.fill", title: "Distância",
                            value: String(format: "%.1f nm", dist))
                    }

                    // Open in Map Button
                    Button {
                        appState.mapFocusAircraft = ac
                        NotificationCenter.default.post(
                            name: Notification.Name("meulab.navigateToTab"),
                            object: nil,
                            userInfo: ["tab": "map"]
                        )
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Ver no Mapa")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.primary)
                        .glassInteractive(cornerRadius: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.blue.opacity(0.35), lineWidth: 1.5)
                        )
                    }
                    .padding(.top, 8)
                }
                .padding()
                .glassCard(cornerRadius: 24)

                // FlightAware block (gate/terminal/schedule)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("FlightAware", systemImage: "clock.badge.checkmark")
                            .font(.headline)
                        Spacer()
                        if faLoading {
                            ProgressView().scaleEffect(0.9)
                        }
                    }

                    if let faFlight {
                        let orig = faFlight.origin?.bestCode ?? "-"
                        let dest = faFlight.destination?.bestCode ?? "-"

                        HStack(spacing: 10) {
                            Text(orig)
                                .font(.title3.bold())
                                .monospaced()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                            Text(dest)
                                .font(.title3.bold())
                                .monospaced()
                            Spacer()
                            Text(faFlight.bestIdent)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }

                        Divider()

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Saída")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(
                                    FlightAwareTime.short(faFlight.actualOut)
                                        ?? FlightAwareTime.short(faFlight.estimatedOut)
                                        ?? FlightAwareTime.short(faFlight.scheduledOut)
                                        ?? "-"
                                )
                                .font(.headline.monospacedDigit())
                                Text(
                                    "T\(faFlight.terminalOrigin ?? "-") • G\(faFlight.gateOrigin ?? "-")"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Chegada")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(
                                    FlightAwareTime.short(faFlight.actualIn)
                                        ?? FlightAwareTime.short(faFlight.estimatedIn)
                                        ?? FlightAwareTime.short(faFlight.scheduledIn)
                                        ?? "-"
                                )
                                .font(.headline.monospacedDigit())
                                Text(
                                    "T\(faFlight.terminalDestination ?? "-") • G\(faFlight.gateDestination ?? "-")"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Operadora")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(faFlight.operator ?? faFlight.operatorIcao ?? "-")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Status")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(flightAwareStatus(faFlight))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }
                    } else if let faError {
                        Text(faError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Sem dados de horário/gate para este ident agora.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .glassCard(cornerRadius: 16)
            }
            .frame(maxWidth: detailMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(isWide ? 20 : 16)
        }
        .background {
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.08),
                    Color.blue.opacity(0.05),
                    Color(.systemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .navigationTitle("Detalhes do Voo")
        .sheet(isPresented: $showClassificationSheet) {
            AirlineClassificationSheet(
                aircraft: ac,
                currentAirline: classifiedAirlineName ?? ac.airline,
                suggestions: classificationSuggestions
            ) { selectedName in
                Task {
                    await saveClassification(airlineName: selectedName)
                }
            }
        }
        .task {
            if let reg = ac.registration {
                registration = reg
            }
            await loadNearbyCity()
            await loadFlightAware()
            await loadExistingClassification()
        }
    }

    @MainActor
    private func loadNearbyCity() async {
        guard let lat = ac.lat, let lon = ac.lon else {
            nearbyCity = nil
            return
        }
        nearbyCity = await NearbyCityResolver.shared.lookup(lat: lat, lon: lon)
    }

    @MainActor
    private func loadFlightAware() async {
        let ident = ac.callsign.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ident.isEmpty, ident != "???" else { return }
        if faLoading { return }

        faLoading = true
        faError = nil
        defer { faLoading = false }

        do {
            let resp = try await APIService.shared.fetchFlightAwareFlight(ident: ident, maxPages: 1)
            faFlight = resp.data.flights?.first
        } catch {
            faError = error.localizedDescription
        }
    }

    private var classificationSuggestions: [String] {
        let fromSummary = appState.adsbSummary?.airlines.map(\.name) ?? []
        let merged = Set(fromSummary + AirlineLogo.mapping.keys)
        return merged.sorted()
    }

    private func loadExistingClassification() async {
        isLoadingClassification = true
        defer { isLoadingClassification = false }

        do {
            let result = try await APIService.shared.fetchAirlineClassification(
                hex: ac.hex,
                registration: registration ?? ac.registration,
                callsign: ac.callsign,
                model: ac.model
            )
            if let classified = result.classification?.airlineName, !classified.isEmpty {
                await MainActor.run {
                    classifiedAirlineName = classified
                    appState.saveManualAirlineOverride(classified, for: ac)
                    classificationMessage = "Classificação manual encontrada na API."
                }
            }
        } catch {
            await MainActor.run {
                classificationMessage = "Classificação manual ainda não disponível no servidor."
            }
        }
    }

    private func saveClassification(airlineName: String) async {
        isLoadingClassification = true
        defer { isLoadingClassification = false }

        let payload = AirlineClassificationUpsertRequest(
            hex: ac.hex,
            registration: registration ?? ac.registration,
            callsign: ac.callsign,
            model: ac.model,
            airlineName: airlineName,
            airlineIcao: nil,
            airlineIata: nil,
            source: "manual",
            confidence: 1.0
        )

        do {
            let response = try await APIService.shared.saveAirlineClassification(payload)
            await MainActor.run {
                if let name = response.classification?.airlineName ?? response.message,
                    !name.isEmpty
                {
                    classifiedAirlineName = response.classification?.airlineName ?? airlineName
                } else {
                    classifiedAirlineName = airlineName
                }
                appState.saveManualAirlineOverride(classifiedAirlineName ?? airlineName, for: ac)
                classificationMessage = "Empresa aérea salva com sucesso."
            }
        } catch {
            await MainActor.run {
                classificationMessage =
                    "Não foi possível salvar. Verifique se o backend já tem os endpoints."
            }
        }
    }

    private func flightAwareStatus(_ flight: FlightAwareFlight) -> String {
        if flight.actualIn != nil || flight.actualOn != nil {
            return "Pousado"
        }
        if flight.actualOff != nil || flight.actualOut != nil {
            return "Em voo"
        }
        if flight.estimatedOut != nil || flight.scheduledOut != nil {
            return "Programado"
        }
        return "Sem status"
    }
}

private struct AirlineClassificationSheet: View {
    let aircraft: Aircraft
    let currentAirline: String?
    let suggestions: [String]
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var search: String = ""
    @State private var selected: String? = nil

    private var filtered: [String] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if q.isEmpty { return suggestions }
        return suggestions.filter { $0.uppercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Info Header
                VStack(spacing: 6) {
                    HStack(spacing: 12) {
                        if let logoURL = aircraft.airlineLogoURL {
                            AsyncImage(url: logoURL) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "airplane.circle.fill")
                                        .foregroundStyle(.blue.opacity(0.4))
                                }
                            }
                            .frame(width: 30, height: 30)
                        }
                        Text(aircraft.displayCallsign)
                            .font(.headline)
                        Spacer()
                    }
                }
                .padding()
                .background(.ultraThinMaterial)

                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar companhia", text: $search)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                }
                .padding(10)
                .glassCard(cornerRadius: 10)
                .padding()

                List {
                    ForEach(filtered, id: \.self) { name in
                        Button {
                            selected = name
                        } label: {
                            HStack {
                                Text(name)
                                Spacer()
                                if selected == name {
                                    Image(systemName: "checkmark").foregroundStyle(.blue)
                                }
                            }
                        }
                        .foregroundStyle(selected == name ? .blue : .primary)
                    }
                }
                .scrollContentBackground(.hidden)

                Button {
                    if let selected {
                        onSave(selected)
                        dismiss()
                    }
                } label: {
                    Text("Salvar")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selected != nil ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .disabled(selected == nil)
                .padding()
            }
            .navigationTitle("Classificar Empresa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}

struct AircraftRouteView: View {
    let flight: FlightAwareFlight

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                AirportBlock_Legacy(
                    code: flight.origin?.bestCode ?? "???",
                    city: flight.origin?.city ?? "Origem",
                    alignment: .leading
                )

                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "airplane")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    HStack(spacing: 4) {
                        ForEach(0..<8) { _ in
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 4, height: 4)
                        }
                    }
                }
                .padding(.horizontal, 10)

                Spacer()

                AirportBlock_Legacy(
                    code: flight.destination?.bestCode ?? "???",
                    city: flight.destination?.city ?? "Destino",
                    alignment: .trailing
                )
            }

            VStack(spacing: 10) {
                AirportBlock_Legacy(
                    code: flight.origin?.bestCode ?? "???",
                    city: flight.origin?.city ?? "Origem",
                    alignment: .center
                )

                HStack(spacing: 6) {
                    Image(systemName: "airplane")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    ForEach(0..<8) { _ in
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 3.5, height: 3.5)
                    }
                }

                AirportBlock_Legacy(
                    code: flight.destination?.bestCode ?? "???",
                    city: flight.destination?.city ?? "Destino",
                    alignment: .center
                )
            }
        }
        .frame(minHeight: 98)
    }
}

struct AirportBlock_Legacy: View {
    let code: String
    let city: String
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(code)
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(city)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                .lineLimit(2)
        }
        .frame(minWidth: 80)
    }
}

// MARK: - AircraftPhotoView (Moved from AircraftPhotoView.swift)

struct AircraftPhotoView: View {
    let aircraft: Aircraft

    @State private var imageURL: URL?
    @State private var isLoading = true
    @State private var photographer: String?
    @State private var sourceName: String?

    var body: some View {
        Group {
            if let imageURL {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipped()
                        case .failure:
                            fallbackView
                        @unknown default:
                            EmptyView()
                        }
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        if let photographer {
                            Text("© \(photographer)")
                                .font(.system(size: 8))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        if let sourceName {
                            Text(sourceName)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    .padding(6)
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                noPhotoView
            }
        }
        .task {
            await loadPhoto()
        }
    }

    private var fallbackView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Erro ao carregar imagem")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noPhotoView: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("Sem foto disponível")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadPhoto() async {
        let directReg = aircraft.registration?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = (aircraft.hex ?? aircraft.id).trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Tenta PlaneSpotters (pela matrícula já disponível)
        if let reg = directReg, !reg.isEmpty {
            if await tryPlaneSpotters(registration: reg) {
                return
            }
        }

        // 2. Se a matrícula não veio no payload, tenta resolver via HEX e buscar no PlaneSpotters
        if !hex.isEmpty, directReg == nil || directReg?.isEmpty == true {
            if let lookedUpReg = await HexLookupService.shared.lookup(hex: hex),
                await tryPlaneSpotters(registration: lookedUpReg)
            {
                return
            }
        }

        // 3. Tenta PlaneSpotters direto pelo HEX
        if !hex.isEmpty, await tryPlaneSpottersByHex(hex: hex) {
            return
        }

        // 4. Tenta OpenSky (pelo ICAO24/Hex)
        if !hex.isEmpty {
            if await tryOpenSky(icao24: hex) {
                return
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }

    private func tryPlaneSpotters(registration: String) async -> Bool {
        do {
            let encoded =
                registration.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                ?? registration
            let url = URL(string: "https://api.planespotters.net/pub/photos/reg/\(encoded)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let photos = json?["photos"] as? [[String: Any]]

            guard let first = photos?.first else { return false }

            let thumbLarge = (first["thumbnail_large"] as? [String: Any])?["src"] as? String
            let thumb = (first["thumbnail"] as? [String: Any])?["src"] as? String
            let photographerName = first["photographer"] as? String

            if let urlString = thumbLarge ?? thumb, let imgURL = URL(string: urlString) {
                await MainActor.run {
                    self.imageURL = imgURL
                    self.photographer = photographerName
                    self.sourceName = "PlaneSpotters"
                    self.isLoading = false
                }
                return true
            }
        } catch {
            print("[Photo] PlaneSpotters error: \(error.localizedDescription)")
        }
        return false
    }

    private func tryPlaneSpottersByHex(hex: String) async -> Bool {
        do {
            let encoded = hex.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? hex
            let url = URL(string: "https://api.planespotters.net/pub/photos/hex/\(encoded)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let photos = json?["photos"] as? [[String: Any]]

            guard let first = photos?.first else { return false }

            let thumbLarge = (first["thumbnail_large"] as? [String: Any])?["src"] as? String
            let thumb = (first["thumbnail"] as? [String: Any])?["src"] as? String
            let photographerName = first["photographer"] as? String

            if let urlString = thumbLarge ?? thumb, let imgURL = URL(string: urlString) {
                await MainActor.run {
                    self.imageURL = imgURL
                    self.photographer = photographerName
                    self.sourceName = "PlaneSpotters"
                    self.isLoading = false
                }
                return true
            }
        } catch {
            print("[Photo] PlaneSpotters HEX error: \(error.localizedDescription)")
        }
        return false
    }

    private func tryOpenSky(icao24: String) async -> Bool {
        // OpenSky API para imagens de aeronaves
        let url = URL(
            string:
                "https://opensky-network.org/api/metadata/data/aircraft/icao24/\(icao24.lowercased())/image"
        )!

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"  // Verifica apenas se existe
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                await MainActor.run {
                    self.imageURL = url
                    self.photographer = nil
                    self.sourceName = "OpenSky"
                    self.isLoading = false
                }
                return true
            }
        } catch {
            print("[Photo] OpenSky error: \(error.localizedDescription)")
        }
        return false
    }
}

struct DetailRow_Legacy: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}
