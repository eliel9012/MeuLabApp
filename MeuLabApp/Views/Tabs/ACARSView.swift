import SwiftUI
import UIKit

private func acarsAdaptiveColor(light: UIColor, dark: UIColor) -> Color {
    Color(
        uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? dark : light
        }
    )
}

private func acarsRGBA(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1)
    -> UIColor
{
    UIColor(red: red, green: green, blue: blue, alpha: alpha)
}

private enum ACARSTheme {
    static let violet = Color(red: 0.52, green: 0.34, blue: 0.88)
    static let blue = Color(red: 0.14, green: 0.38, blue: 0.84)
    static let cyan = Color(red: 0.18, green: 0.70, blue: 0.86)
    static let green = Color(red: 0.27, green: 0.78, blue: 0.37)
    static let amber = Color(red: 0.95, green: 0.57, blue: 0.15)
    static let ink = acarsAdaptiveColor(
        light: acarsRGBA(0.08, 0.11, 0.20),
        dark: acarsRGBA(0.92, 0.95, 1.00)
    )
    static let mist = acarsAdaptiveColor(
        light: acarsRGBA(0.94, 0.97, 1.00),
        dark: acarsRGBA(0.09, 0.11, 0.18)
    )
    static let surfaceTop = acarsAdaptiveColor(
        light: acarsRGBA(1.00, 1.00, 1.00, 0.98),
        dark: acarsRGBA(0.13, 0.16, 0.24, 0.98)
    )
    static let surfaceStroke = acarsAdaptiveColor(
        light: acarsRGBA(1.00, 1.00, 1.00, 0.92),
        dark: acarsRGBA(0.26, 0.31, 0.42, 0.88)
    )
    static let canvasMid = acarsAdaptiveColor(
        light: acarsRGBA(1.00, 1.00, 1.00),
        dark: acarsRGBA(0.06, 0.08, 0.15)
    )
    static let canvasEnd = acarsAdaptiveColor(
        light: acarsRGBA(0.98, 0.99, 0.97),
        dark: acarsRGBA(0.08, 0.10, 0.17)
    )
    static let shadow = acarsAdaptiveColor(
        light: acarsRGBA(0.05, 0.12, 0.26),
        dark: acarsRGBA(0.00, 0.00, 0.00)
    )
    static let toolbarBubble = acarsAdaptiveColor(
        light: acarsRGBA(1.00, 1.00, 1.00, 0.78),
        dark: acarsRGBA(0.16, 0.20, 0.28, 0.94)
    )
}

private struct ACARSPanelBackground: View {
    let cornerRadius: CGFloat
    let highlight: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [ACARSTheme.surfaceTop, ACARSTheme.mist],
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
                            colors: [highlight.opacity(0.28), ACARSTheme.surfaceStroke],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.1
                    )
            }
            .shadow(color: ACARSTheme.shadow.opacity(0.08), radius: 22, x: 0, y: 12)
            .shadow(color: highlight.opacity(0.07), radius: 14, x: 0, y: 6)
    }
}

private extension View {
    func acarsPanel(cornerRadius: CGFloat = 20, highlight: Color = ACARSTheme.violet) -> some View {
        background(ACARSPanelBackground(cornerRadius: cornerRadius, highlight: highlight))
    }
}

private struct ACARSToolbarTitle: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [ACARSTheme.violet.opacity(0.18), ACARSTheme.blue.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ACARSTheme.violet)
            }

            Text("ACARS")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(
                    LinearGradient(
                        colors: [ACARSTheme.violet, ACARSTheme.blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

private struct ACARSInfoChip: View {
    let title: String
    let value: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ACARSTheme.ink.opacity(0.56))

            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)

                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ACARSTheme.ink)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Capsule().fill(tint.opacity(0.10)))
        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 1))
    }
}

struct ACARSView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showMessagesList = false
    @State private var showSearchResults = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedAircraft: ACARSTopAircraft?
    @State private var aircraftMessages: [ACARSMessage] = []
    @State private var isLoadingAircraftMessages = false
    @State private var searchResults: [ACARSMessage] = []

    private var isWide: Bool { horizontalSizeClass == .regular }
    private var contentMaxWidth: CGFloat { isWide ? 980 : 760 }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Summary Section
                    if let summary = appState.acarsSummary {
                        summarySection(summary)
                        hourlyChartSection
                        topAircraftSection(summary.topAircraft)
                        topLabelsSection(summary.topLabels)
                    } else if let error = appState.acarsError {
                        ErrorCard(message: error)
                    } else {
                        LoadingCard()
                    }

                    // Recent Messages Preview
                    if !appState.acarsMessages.isEmpty {
                        recentMessagesSection
                    }

                    if let history = appState.acarsHistory {
                        acarsHistorySection(history)
                    }

                    // Removed: "Alertas Recentes" card (kept alerts in the dedicated Alertas tab).
                }
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding()
                .padding(.bottom, 44)
            }
            .background {
                ZStack {
                    LinearGradient(
                        colors: [ACARSTheme.canvasMid, ACARSTheme.canvasEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(ACARSTheme.violet.opacity(0.10))
                        .frame(width: isWide ? 520 : 320)
                        .blur(radius: 40)
                        .offset(x: isWide ? -260 : -120, y: -260)

                    Circle()
                        .fill(ACARSTheme.blue.opacity(0.08))
                        .frame(width: isWide ? 420 : 260)
                        .blur(radius: 34)
                        .offset(x: isWide ? 260 : 120, y: -120)

                    Circle()
                        .fill(ACARSTheme.green.opacity(0.08))
                        .frame(width: isWide ? 420 : 260)
                        .blur(radius: 40)
                        .offset(x: isWide ? 220 : 120, y: 280)
                }
                .ignoresSafeArea()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ACARSToolbarTitle()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        print("[ACARSView] 🔄 Manual refresh triggered")
                        Task {
                            await appState.refreshACARS()
                            await appState.refreshACARSHistory()
                            await appState.refreshACARSAlerts()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(ACARSTheme.violet)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(ACARSTheme.toolbarBubble)
                            )
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar voo ou matrícula")
            .onSubmit(of: .search) {
                Task { await searchFlight() }
            }
            .sheet(isPresented: $showMessagesList) {
                ACARSMessagesSheet(messages: appState.acarsMessages)
            }
            .sheet(isPresented: $showSearchResults) {
                ACARSMessagesSheet(messages: searchResults)
            }
            .sheet(item: $selectedAircraft) { aircraft in
                AircraftMessagesSheet(
                    aircraft: aircraft,
                    messages: aircraftMessages,
                    isLoading: isLoadingAircraftMessages
                )
            }
            .onChange(of: appState.intelligenceContext) { _, context in
                guard
                    let context,
                    context["tab"] == ContentView.Tab.acars.rawValue,
                    context["kind"] == "acars",
                    let identifier = context["identifier"],
                    !identifier.isEmpty
                else { return }

                searchText = identifier
                appState.intelligenceContext = nil
                Task { await searchFlight() }
            }
        }
    }

    private func loadMessagesForAircraft(_ aircraft: ACARSTopAircraft) {
        selectedAircraft = aircraft
        isLoadingAircraftMessages = true
        aircraftMessages = []

        Task {
            do {
                let result = try await APIService.shared.searchACARSMessages(query: aircraft.tail)
                await MainActor.run {
                    aircraftMessages = result.messages
                    isLoadingAircraftMessages = false
                }
            } catch {
                await MainActor.run {
                    isLoadingAircraftMessages = false
                }
            }
        }
    }

    // MARK: - Summary Section

    @ViewBuilder
    private func summarySection(_ summary: ACARSSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Label("Link ACARS", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ACARSTheme.ink.opacity(0.82))

                        Text("ATIVO")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(ACARSTheme.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(ACARSTheme.green.opacity(0.14), in: Capsule())
                    }

                    Text("Mensageria aeronáutica, fila recente e leitura de volume na mesma janela.")
                        .font(.caption)
                        .foregroundStyle(ACARSTheme.ink.opacity(0.56))
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 8) {
                    ACARSInfoChip(
                        title: "Pico",
                        value: summary.today.peakHour ?? "--",
                        tint: ACARSTheme.amber,
                        icon: "clock.badge"
                    )
                }
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12
            ) {
                ACARSStatCard(
                    title: "Mensagens",
                    value: "\(summary.today.messages)",
                    icon: "envelope.fill",
                    color: ACARSTheme.violet
                )

                ACARSStatCard(
                    title: "Voos",
                    value: "\(summary.today.flights)",
                    icon: "airplane",
                    color: ACARSTheme.blue
                )

                ACARSStatCard(
                    title: "Aeronaves",
                    value: "\(summary.today.aircraft)",
                    icon: "airplane.circle",
                    color: ACARSTheme.green
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ACARSInfoChip(
                        title: "Janela 24h",
                        value: "\(summary.last24h.messages) msgs",
                        tint: ACARSTheme.blue,
                        icon: "clock"
                    )
                    ACARSInfoChip(
                        title: "Cadência",
                        value: "\(summary.lastHour) msgs/h",
                        tint: ACARSTheme.cyan,
                        icon: "waveform"
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    ACARSInfoChip(
                        title: "Janela 24h",
                        value: "\(summary.last24h.messages) msgs",
                        tint: ACARSTheme.blue,
                        icon: "clock"
                    )
                    ACARSInfoChip(
                        title: "Cadência",
                        value: "\(summary.lastHour) msgs/h",
                        tint: ACARSTheme.cyan,
                        icon: "waveform"
                    )
                }
            }
        }
        .padding(18)
        .acarsPanel(cornerRadius: 24, highlight: ACARSTheme.violet)
    }

    // MARK: - Hourly Chart

    private var hourlyChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(ACARSTheme.blue)
                Text("Últimas 12 Horas")
                    .font(.headline)
                    .foregroundStyle(ACARSTheme.ink)
            }

            if !appState.acarsHourly.isEmpty {
                let maxMessages = appState.acarsHourly.map(\.messages).max() ?? 1

                VStack(spacing: 4) {
                    ForEach(appState.acarsHourly.prefix(8)) { hour in
                        HStack(spacing: 8) {
                            Text(hour.hour)
                                .font(.caption)
                                .monospacedDigit()
                                .frame(width: 45, alignment: .leading)

                            GeometryReader { geo in
                                let width =
                                    CGFloat(hour.messages) / CGFloat(maxMessages) * geo.size.width
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ACARSTheme.violet.opacity(0.8))
                                    .frame(width: max(width, 2))
                            }
                            .frame(height: 20)

                            Text("\(hour.messages)")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(ACARSTheme.ink.opacity(0.56))
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(18)
        .acarsPanel(cornerRadius: 22, highlight: ACARSTheme.blue)
    }

    // MARK: - Top Aircraft

    @ViewBuilder
    private func topAircraftSection(_ aircraft: [ACARSTopAircraft]) -> some View {
        if !aircraft.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(ACARSTheme.amber)
                    Text("Top Aeronaves")
                        .font(.headline)
                        .foregroundStyle(ACARSTheme.ink)
                    Spacer()
                    Text("Toque para ver mensagens")
                        .font(.caption2)
                        .foregroundStyle(ACARSTheme.ink.opacity(0.56))
                }

                ForEach(Array(aircraft.enumerated()), id: \.element.id) { index, ac in
                    Button {
                        loadMessagesForAircraft(ac)
                    } label: {
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(ACARSTheme.ink.opacity(0.56))
                                .frame(width: 20)

                            Text(ac.tail)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .monospacedDigit()

                            if let flight = ac.flight, !flight.isEmpty {
                                Text("(\(flight))")
                                    .font(.caption)
                                    .foregroundStyle(ACARSTheme.ink.opacity(0.56))
                            }

                            Spacer()

                            Text("\(ac.count) msgs")
                                .font(.caption)
                                .foregroundStyle(ACARSTheme.ink.opacity(0.56))

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(ACARSTheme.ink.opacity(0.34))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .acarsPanel(cornerRadius: 14, highlight: ACARSTheme.violet)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .acarsPanel(cornerRadius: 22, highlight: ACARSTheme.amber)
        }
    }

    // MARK: - Top Labels

    @ViewBuilder
    private func topLabelsSection(_ labels: [ACARSTopLabel]) -> some View {
        if !labels.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(ACARSTheme.green)
                    Text("Tipos de Mensagem")
                        .font(.headline)
                        .foregroundStyle(ACARSTheme.ink)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 8
                ) {
                    ForEach(labels) { label in
                        HStack {
                            Text(label.label)
                                .font(.caption)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ACARSTheme.violet.opacity(0.18), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                            if let desc = label.description {
                                Text(desc)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundStyle(ACARSTheme.ink)
                            }

                            Spacer()

                            Text("\(label.count)")
                                .font(.caption)
                                .foregroundStyle(ACARSTheme.ink.opacity(0.56))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .acarsPanel(cornerRadius: 14, highlight: ACARSTheme.green)
                    }
                }
            }
            .padding(18)
            .acarsPanel(cornerRadius: 22, highlight: ACARSTheme.green)
        }
    }

    // MARK: - Recent Messages

    private var recentMessagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "envelope.badge")
                    .foregroundStyle(ACARSTheme.blue)
                Text("Mensagens Recentes")
                    .font(.headline)
                    .foregroundStyle(ACARSTheme.ink)

                Spacer()

                Button {
                    showMessagesList = true
                } label: {
                    Text("Ver Todas")
                        .font(.subheadline)
                }
            }

            VStack(spacing: 8) {
                ForEach(appState.acarsMessages.prefix(5)) { message in
                    ACARSMessageRow(message: message)
                }
            }
        }
        .padding(18)
        .acarsPanel(cornerRadius: 22, highlight: ACARSTheme.blue)
    }

    // MARK: - Search

    private func searchFlight() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }

        do {
            let result = try await APIService.shared.searchACARSMessages(query: searchText)
            await MainActor.run {
                searchResults = result.messages
                showSearchResults = true
            }
        } catch {
            await MainActor.run {
                searchResults = []
                showSearchResults = false
            }
        }
    }

    // MARK: - History

    @ViewBuilder
    private func acarsHistorySection(_ history: ACARSHistoryResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Histórico 7 Dias")
                .font(.headline)
                .foregroundStyle(ACARSTheme.ink.opacity(0.72))

            VStack(spacing: 6) {
                ForEach(history.last7Days) { day in
                    HStack {
                        Text(formatDay(day.day))
                            .font(.caption)
                            .frame(width: 70, alignment: .leading)
                        GeometryReader { geo in
                            let maxValue = history.last7Days.map(\.messages).max() ?? 1
                            let width = CGFloat(day.messages) / CGFloat(maxValue) * geo.size.width
                            RoundedRectangle(cornerRadius: 4)
                                .fill(ACARSTheme.violet.opacity(0.8))
                                .frame(width: max(width, 2))
                        }
                        .frame(height: 16)
                        Text("\(day.messages)")
                            .font(.caption2)
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                            .foregroundStyle(ACARSTheme.ink.opacity(0.56))
                    }
                }
            }
        }
        .padding(18)
        .acarsPanel(cornerRadius: 22, highlight: ACARSTheme.violet)
    }

    @ViewBuilder
    private func acarsAlertsSection(_ alerts: [ACARSAlert]) -> some View {
        EmptyView()
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

    private func formatAlertTime(_ timeString: String) -> String {
        if let date = ISO8601DateFormatter().date(from: timeString) {
            return Formatters.time.string(from: date)
        }
        return formatTime(timeString)
    }

    private func formatTime(_ timeString: String) -> String {
        // Extract HH:MM from formats like "YYYY-MM-DD HH:MM:SS" or return original if not matched
        let parts = timeString.split(separator: " ")
        if parts.count >= 2 {
            let timePart = String(parts[1])
            // Safely take first 5 characters of the time part (HH:MM)
            let end = timePart.index(timePart.startIndex, offsetBy: min(5, timePart.count))
            return String(timePart[..<end])
        }
        // If there's no space, try to take HH:MM from the whole string
        if let colonIndex = timeString.firstIndex(of: ":") {
            // We want 2 digits for minutes after the colon -> total of 5 chars starting at (hour start)
            let startOfHour =
                timeString.index(colonIndex, offsetBy: -2, limitedBy: timeString.startIndex)
                ?? timeString.startIndex
            let end = timeString.index(
                startOfHour,
                offsetBy: min(5, timeString.distance(from: startOfHour, to: timeString.endIndex)))
            let slice = timeString[startOfHour..<end]
            return String(slice)
        }
        return timeString
    }
}

// MARK: - Supporting Views

struct ACARSStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(ACARSTheme.ink)

            Text(title)
                .font(.caption2)
                .foregroundStyle(ACARSTheme.ink.opacity(0.56))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .acarsPanel(cornerRadius: 16, highlight: color)
    }
}

struct ACARSMessageRow: View {
    let message: ACARSMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: message.labelIcon)
                .font(.title3)
                .foregroundStyle(Color.fromName(message.labelColor))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.displayFlight)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(ACARSTheme.ink)

                    if let tail = message.tail, message.flight != nil {
                        Text("(\(tail))")
                            .font(.caption)
                            .foregroundStyle(ACARSTheme.ink.opacity(0.56))
                    }

                    Spacer()

                    Text(formatTime(message.time))
                        .font(.caption)
                        .foregroundStyle(ACARSTheme.ink.opacity(0.56))
                }

                if let route = message.displayRoute {
                    Label(route, systemImage: "airplane.departure")
                        .font(.caption)
                        .foregroundStyle(ACARSTheme.ink.opacity(0.56))
                }

                if let labelDesc = message.labelDesc {
                    Text(labelDesc)
                        .font(.caption)
                        .foregroundStyle(ACARSTheme.violet)
                }

                if let text = message.text, !text.isEmpty {
                    Text(text.prefix(80) + (text.count > 80 ? "..." : ""))
                        .font(.caption)
                        .foregroundStyle(ACARSTheme.ink.opacity(0.62))
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .acarsPanel(cornerRadius: 16, highlight: Color.fromName(message.labelColor))
    }

    private func formatTime(_ timeString: String) -> String {
        // Extract HH:MM from "YYYY-MM-DD HH:MM:SS"
        let parts = timeString.split(separator: " ")
        if parts.count >= 2 {
            let timePart = parts[1]
            return String(timePart.prefix(5))
        }
        return timeString
    }
}

struct ACARSMessagesSheet: View {
    let messages: [ACARSMessage]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List(messages) { message in
                ACARSMessageRow(message: message)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Mensagens (\(messages.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Aircraft Messages Sheet (Detailed)

struct AircraftMessagesSheet: View {
    let aircraft: ACARSTopAircraft
    let messages: [ACARSMessage]
    let isLoading: Bool
    @Environment(\.dismiss) var dismiss
    @State private var expandedMessageId: Int?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("Carregando mensagens...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if messages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Nenhuma mensagem encontrada")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List {
                        Section {
                            EmptyView()
                        } header: {
                            VStack(alignment: .leading, spacing: 2) {
                                if let flight = aircraft.flight, !flight.isEmpty {
                                    Text(flight)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(messages.count) mensagens")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        ForEach(messages) { message in
                            ACARSDetailedMessageRow(
                                message: message,
                                isExpanded: expandedMessageId == message.id,
                                onTap: {
                                    withAnimation {
                                        if expandedMessageId == message.id {
                                            expandedMessageId = nil
                                        } else {
                                            expandedMessageId = message.id
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("\(aircraft.tail)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", role: .cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ACARSDetailedMessageRow: View {
    let message: ACARSMessage
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row (always visible)
            Button(action: onTap) {
                HStack(alignment: .top) {
                    Image(systemName: message.labelIcon)
                        .font(.title3)
                        .foregroundStyle(Color.fromName(message.labelColor))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if let label = message.label {
                                Text(label)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(4)
                            }

                            if let labelDesc = message.labelDesc {
                                Text(labelDesc)
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                            }

                            Spacer()

                            Text(formatTime(message.time))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        if let route = message.displayRoute {
                            Label(route, systemImage: "airplane.departure")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }

                        // Preview or full text
                        if let text = message.text, !text.isEmpty {
                            if isExpanded {
                                Text(text)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .materialCard(cornerRadius: 8)
                            } else {
                                Text(text.prefix(60) + (text.count > 60 ? "..." : ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ timeString: String) -> String {
        let parts = timeString.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[1].prefix(5))
        }
        return timeString
    }
}

#Preview {
    ACARSView()
        .environmentObject(AppState())
}
