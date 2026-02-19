import SwiftUI
import MapKit

struct ADSBView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAircraftList = false
    @State private var movementSheet: MovementFilter?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if let summary = appState.adsbSummary {
                        // Global Mode Toggle (OpenSky)
                        HStack {
                            Label("Tráfego Global (OpenSky)", systemImage: "globe")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Toggle("", isOn: $appState.isOpenSkyEnabled)
                                .labelsHidden()
                                .tint(.blue)
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 8)

                        // Live Stats Header
                        liveStatsHeader(summary, countOverride: appState.isOpenSkyEnabled ? appState.aircraftList.count : nil)

                        // Quick Stats Grid
                        statsGridSection(summary)

                        // Highlights Section
                        if summary.highlights.highest != nil || summary.highlights.fastest != nil || summary.highlights.closest != nil {
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

                    // Aircraft List Preview
                    if !appState.aircraftList.isEmpty {
                        aircraftPreviewSection
                    }

                    // History Chart
                    if let history = appState.adsbHistory {
                        historyChartSection(history)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("ADS-B")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        NotificationCenter.default.post(
                            name: Notification.Name("meulab.navigateToTab"),
                            object: nil,
                            userInfo: ["tab": ContentView.Tab.flightSearch.rawValue]
                        )
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                     Menu {
                         Toggle(isOn: $appState.isOpenSkyEnabled) {
                             Label("Tráfego Global (OpenSky)", systemImage: "globe")
                         }
                     } label: {
                         Image(systemName: "slider.horizontal.3")
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
        }
    }

    private var airlinesForSection: [Airline] {
        // Prefer current aircraft list so manual classifications are reflected immediately.
        if !appState.aircraftList.isEmpty {
            var grouped: [String: (displayName: String, count: Int)] = [:]

            for aircraft in appState.aircraftList {
                let effectiveName = appState.manualAirlineOverride(for: aircraft) ?? aircraft.airline
                guard let cleaned = normalizedAirlineDisplayName(effectiveName) else { continue }
                let key = cleaned.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).uppercased()

                if var current = grouped[key] {
                    current.count += 1
                    grouped[key] = current
                } else {
                    grouped[key] = (displayName: cleaned, count: 1)
                }
            }

            let aggregated = grouped.values
                .map { Airline(name: $0.displayName, count: $0.count) }
                .sorted {
                    if $0.count == $1.count {
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    return $0.count > $1.count
                }

            if !aggregated.isEmpty {
                return aggregated
            }
        }

        return appState.adsbSummary?.airlines ?? []
    }

    private func normalizedAirlineDisplayName(_ value: String?) -> String? {
        guard let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines), !cleaned.isEmpty else {
            return nil
        }
        return cleaned
    }

    // MARK: - Live Stats Header

    @ViewBuilder
    private func liveStatsHeader(_ summary: ADSBSummary, countOverride: Int? = nil) -> some View {
        HStack(spacing: 16) {
            // Main count with pulse animation
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(.green.opacity(0.4), lineWidth: 8)
                                .scaleEffect(1.5)
                        )

                    Text("\(countOverride ?? summary.totalNow)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                Text("aeronaves no ar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini stats
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("\(summary.withPos)")
                        .font(.callout.bold())
                        .monospacedDigit()
                    Text("rastreadas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "shield.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                    Text("\(summary.nonCivilNow)")
                        .font(.callout.bold())
                        .monospacedDigit()
                    Text("Não Civil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
    }

    // MARK: - Stats Grid

    @ViewBuilder
    private func statsGridSection(_ summary: ADSBSummary) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
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
                    HighlightRowApple(
                        icon: "arrow.up.to.line.circle.fill",
                        iconColor: .blue,
                        title: "Mais Alto",
                        callsign: highest.callsign ?? "",
                        value: Formatters.altitudeDual(highest.altitudeFt ?? 0).aviation,
                        subtitle: Formatters.altitudeDual(highest.altitudeFt ?? 0).metric
                    )
                }

                if let fastest = highlights.fastest, fastest.callsign != nil {
                    Divider().padding(.leading, 56)
                    HighlightRowApple(
                        icon: "hare.fill",
                        iconColor: .orange,
                        title: "Mais Rápido",
                        callsign: fastest.callsign ?? "",
                        value: Formatters.speedDual(fastest.speedKt ?? 0).aviation,
                        subtitle: Formatters.speedDual(fastest.speedKt ?? 0).metric
                    )
                }

                if let closest = highlights.closest, closest.callsign != nil {
                    Divider().padding(.leading, 56)
                    HighlightRowApple(
                        icon: "location.circle.fill",
                        iconColor: .green,
                        title: "Mais Perto",
                        callsign: closest.callsign ?? "",
                        value: Formatters.distanceDual(closest.distanceNm ?? 0).aviation,
                        subtitle: Formatters.distanceDual(closest.distanceNm ?? 0).metric
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
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
                        .foregroundStyle(.blue)
                }
            }

            VStack(spacing: 0) {
                // Filter and sort by distance (using computed fallback if needed)
                let nearbyAircraft = appState.aircraftList
                    .filter { $0.computedDistanceNm < 100000 } // Must have valid distance (less than arbitrary max)
                    .sorted { $0.computedDistanceNm < $1.computedDistanceNm }
                    .prefix(5)
                
                ForEach(Array(nearbyAircraft.enumerated()), id: \.offset) { index, aircraft in
                    Button {
                        selectedNearbyAircraft = aircraft
                    } label: {
                        AircraftRowApple(aircraft: aircraft)
                            .contentShape(Rectangle()) // Ensure tap area covers the row
                    }
                    .buttonStyle(.plain)

                    if index < nearbyAircraft.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
                
                if nearbyAircraft.isEmpty {
                   ContentUnavailableView("Nenhuma aeronave próxima", systemImage: "location.slash")
                       .padding()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
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
                                            colors: [.blue, .cyan],
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
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )

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
                    subtitle: Formatters.altitudeDual(Int(history.records.maxAltitude.value)).metric,
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
            print("[ADSBView]   First aircraft: \(first.callsign) - VR: \(first.verticalRateFpm) fpm")
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

    var body: some View {
        NavigationStack {
            List(aircraft) { ac in
                NavigationLink(destination: AircraftDetailView(ac: ac)) {
                    MovementAircraftRow(ac: ac)
                }
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
    }
}

private struct MovementAircraftRow: View {
    let ac: Aircraft

    var body: some View {
        HStack(spacing: 12) {
            // Airline logo
            if let logoURL = ac.airlineLogoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    default:
                        Circle()
                            .fill(.blue.opacity(0.1))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "airplane")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            )
                    }
                }
            } else {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "airplane")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(ac.displayCallsign)
                        .font(.headline)
                    if let reg = ac.registration, !reg.isEmpty {
                        Text(reg)
                            .font(.caption)
                            .foregroundColor(Color.secondary)
                    }
                    Spacer()
                    Text("\(ac.altitudeFt) ft")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Color.secondary)
                }
                HStack(spacing: 12) {
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
                    Text("\(abs(ac.verticalRateFpm)) fpm")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(ac.verticalRateFpm == 0 ? Color.secondary : (ac.verticalRateFpm > 0 ? Color.green : Color.orange))
                    Text("\(ac.speedKt) kt")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(Color.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
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
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())
                .monospacedDigit()

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

struct AverageStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
                    .monospacedDigit()

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
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
                            .fill(.blue.opacity(0.1))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Text(String(airline.name.prefix(1)))
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                            )
                    }
                }
            } else {
                Circle()
                    .fill(.blue.opacity(0.1))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(airline.name.prefix(1)))
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                    )
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(airline.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text("\(airline.count) voos")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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
                    Text(aircraft.isDualTracked ? "DUAL" : (aircraft.source == .local ? "LOCAL" : "REDE"))
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
                        .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                        
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
                        .foregroundStyle(.secondary)
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
                    .foregroundStyle(.blue)
                Text(value)
                    .font(.caption.bold())
                    .monospacedDigit()
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
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
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
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

// Internal PlaneSpottersView removed in favor of global AircraftPhotoView component.
import Foundation

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
                   let reg = extractRegistration(from: first) {
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
               let reg = extractRegistration(from: aircraftObj) {
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
            json["tail_number"] as? String
        ]

        for value in candidates {
            if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
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
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            guard let place = placemarks.first else { return nil }

            let city = place.locality ?? place.subAdministrativeArea
            let state = place.administrativeArea
            let country = place.country

            let resolved: String?
            if let city, let state {
                resolved = "\(city), \(state)"
            } else if let city {
                resolved = city
            } else if let state {
                resolved = state
            } else {
                resolved = country
            }

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

// MARK: - Distance Calculation Helper
import CoreLocation

// MARK: - Consolidated Detail Views (Moved from AircraftDetailView.swift)

struct AircraftDetailView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Premium Header with Airline Logo and Main Info
                HStack(spacing: 20) {
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
                        .frame(width: 70, height: 70)
                        .padding(8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 4)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ac.displayCallsign)
                            .font(.system(size: 34, weight: .black, design: .monospaced))
                            .tracking(1)
                        if let airline = classifiedAirlineName ?? ac.airline {
                            Text(airline)
                                .font(.headline)
                                .foregroundStyle(.blue)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(24)
                
                // Route Visualizer (FlightAware)
                if let faFlight {
                    AircraftRouteView(flight: faFlight)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                }
                
                // Aircraft Photo (PlaneSpotters with OpenSky Fallback)
                AircraftPhotoView(aircraft: ac)
                    .frame(height: 250)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                
                // Flight Data Grid
                VStack(spacing: 16) {
                    // Classification Section
                    Button {
                        showClassificationSheet = true
                    } label: {
                        HStack {
                            Label("Classificar empresa aérea", systemImage: "building.2.crop.circle")
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
                    DetailRow_Legacy(icon: "number", title: "Matrícula", value: registration ?? ac.registration ?? "N/A")
                    DetailRow_Legacy(icon: "arrow.up.forward", title: "Altitude", value: "\(ac.altitudeFt) ft")
                    DetailRow_Legacy(icon: "speedometer", title: "Velocidade", value: "\(ac.speedKt) kt (\(ac.speedKmh) km/h)")
                    DetailRow_Legacy(icon: "arrow.up.and.down", title: "Razão Vertical", value: "\(ac.verticalRateFpm) fpm")
                    if let track = ac.track {
                        DetailRow_Legacy(icon: "compass.drawing", title: "Proa", value: String(format: "%.0f°", track))
                    }
                    if let lat = ac.lat, let lon = ac.lon {
                        let coordinates = String(format: "%.4f, %.4f", lat, lon)
                        let locationValue = nearbyCity.map { "\(coordinates) • próximo a \($0)" } ?? coordinates
                        DetailRow_Legacy(icon: "location.fill", title: "Coordenadas", value: locationValue)
                    }
                    if let dist = ac.distanceNm {
                        DetailRow_Legacy(icon: "location.fill", title: "Distância", value: String(format: "%.1f nm", dist))
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
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(24)

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
                                Text(FlightAwareTime.short(faFlight.actualOut)
                                     ?? FlightAwareTime.short(faFlight.estimatedOut)
                                     ?? FlightAwareTime.short(faFlight.scheduledOut)
                                     ?? "-")
                                    .font(.headline.monospacedDigit())
                                Text("T\(faFlight.terminalOrigin ?? "-") • G\(faFlight.gateOrigin ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Chegada")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(FlightAwareTime.short(faFlight.actualIn)
                                     ?? FlightAwareTime.short(faFlight.estimatedIn)
                                     ?? FlightAwareTime.short(faFlight.scheduledIn)
                                     ?? "-")
                                    .font(.headline.monospacedDigit())
                                Text("T\(faFlight.terminalDestination ?? "-") • G\(faFlight.gateDestination ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
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
                if let name = response.classification?.airlineName ?? response.message, !name.isEmpty {
                    classifiedAirlineName = response.classification?.airlineName ?? airlineName
                } else {
                    classifiedAirlineName = airlineName
                }
                appState.saveManualAirlineOverride(classifiedAirlineName ?? airlineName, for: ac)
                classificationMessage = "Empresa aérea salva com sucesso."
            }
        } catch {
            await MainActor.run {
                classificationMessage = "Não foi possível salvar. Verifique se o backend já tem os endpoints."
            }
        }
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
                .background(Color(.secondarySystemGroupedBackground))

                // Search
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar companhia", text: $search)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                }
                .padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(10)
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
    }
}

struct AirportBlock_Legacy: View {
    let code: String
    let city: String
    let alignment: HorizontalAlignment
    
    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(code)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
            Text(city)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
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
        if !hex.isEmpty, (directReg == nil || directReg?.isEmpty == true) {
            if let lookedUpReg = await HexLookupService.shared.lookup(hex: hex),
               await tryPlaneSpotters(registration: lookedUpReg) {
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
            let encoded = registration.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? registration
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
        let url = URL(string: "https://opensky-network.org/api/metadata/data/aircraft/icao24/\(icao24.lowercased())/image")!
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD" // Verifica apenas se existe
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
