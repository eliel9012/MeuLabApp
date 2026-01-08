import SwiftUI

struct ACARSView: View {
    @EnvironmentObject var appState: AppState
    @State private var showMessagesList = false
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var selectedAircraft: ACARSTopAircraft?
    @State private var aircraftMessages: [ACARSMessage] = []
    @State private var isLoadingAircraftMessages = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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
                }
                .padding()
            }
            .navigationTitle("ACARS")
            .searchable(text: $searchText, prompt: "Buscar voo ou matrícula")
            .onSubmit(of: .search) {
                Task { await searchFlight() }
            }
            .sheet(isPresented: $showMessagesList) {
                ACARSMessagesSheet(messages: appState.acarsMessages)
            }
            .sheet(item: $selectedAircraft) { aircraft in
                AircraftMessagesSheet(
                    aircraft: aircraft,
                    messages: aircraftMessages,
                    isLoading: isLoadingAircraftMessages
                )
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.purple)
                Text("Hoje")
                    .font(.headline)
                Spacer()
                if let peak = summary.today.peakHour {
                    Text("Pico: \(peak)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ACARSStatCard(
                    title: "Mensagens",
                    value: "\(summary.today.messages)",
                    icon: "envelope.fill",
                    color: .purple
                )

                ACARSStatCard(
                    title: "Voos",
                    value: "\(summary.today.flights)",
                    icon: "airplane",
                    color: .blue
                )

                ACARSStatCard(
                    title: "Aeronaves",
                    value: "\(summary.today.aircraft)",
                    icon: "airplane.circle",
                    color: .green
                )
            }

            // 24h stats
            HStack(spacing: 16) {
                Label("\(summary.last24h.messages) msgs/24h", systemImage: "clock")
                Spacer()
                Label("\(summary.lastHour) msgs/hora", systemImage: "clock.badge")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Hourly Chart

    private var hourlyChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                Text("Últimas 12 Horas")
                    .font(.headline)
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
                                let width = CGFloat(hour.messages) / CGFloat(maxMessages) * geo.size.width
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.purple.opacity(0.7))
                                    .frame(width: max(width, 2))
                            }
                            .frame(height: 20)

                            Text("\(hour.messages)")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Top Aircraft

    @ViewBuilder
    private func topAircraftSection(_ aircraft: [ACARSTopAircraft]) -> some View {
        if !aircraft.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.orange)
                    Text("Top Aeronaves")
                        .font(.headline)
                    Spacer()
                    Text("Toque para ver mensagens")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(aircraft.enumerated()), id: \.element.id) { index, ac in
                    Button {
                        loadMessagesForAircraft(ac)
                    } label: {
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text(ac.tail)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .monospacedDigit()

                            if !ac.flight.isEmpty {
                                Text("(\(ac.flight))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(ac.count) msgs")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Top Labels

    @ViewBuilder
    private func topLabelsSection(_ labels: [ACARSTopLabel]) -> some View {
        if !labels.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(.green)
                    Text("Tipos de Mensagem")
                        .font(.headline)
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(labels) { label in
                        HStack {
                            Text(label.label)
                                .font(.caption)
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(4)

                            Text(label.description)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()

                            Text("\(label.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    // MARK: - Recent Messages

    private var recentMessagesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "envelope.badge")
                    .foregroundStyle(.blue)
                Text("Mensagens Recentes")
                    .font(.headline)

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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Search

    private func searchFlight() async {
        guard !searchText.isEmpty else { return }
        isSearching = true
        // TODO: Implement search via API
        isSearching = false
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

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray5))
        .cornerRadius(10)
    }
}

struct ACARSMessageRow: View {
    let message: ACARSMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: message.labelIcon)
                .font(.title3)
                .foregroundStyle(Color(message.labelColor))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.displayFlight)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()

                    if let tail = message.tail, message.flight != nil {
                        Text("(\(tail))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(formatTime(message.time))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let route = message.displayRoute {
                    Label(route, systemImage: "airplane.departure")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let labelDesc = message.labelDesc {
                    Text(labelDesc)
                        .font(.caption)
                        .foregroundStyle(.purple)
                }

                if let text = message.text, !text.isEmpty {
                    Text(text.prefix(80) + (text.count > 80 ? "..." : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
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
            .navigationTitle("Mensagens (\(messages.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
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
                }
            }
            .navigationTitle("\(aircraft.tail)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VStack(alignment: .leading) {
                        if !aircraft.flight.isEmpty {
                            Text(aircraft.flight)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(messages.count) mensagens")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") {
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
                        .foregroundStyle(Color(message.labelColor))
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
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
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
