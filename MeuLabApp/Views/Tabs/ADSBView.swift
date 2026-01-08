import SwiftUI
import MapKit

struct ADSBView: View {
    @EnvironmentObject var appState: AppState
    @State private var showAircraftList = false
    @State private var showFullscreenMap = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Map Preview
                    if !appState.aircraftList.isEmpty {
                        mapPreviewSection
                    }

                    // Summary Cards
                    if let summary = appState.adsbSummary {
                        summarySection(summary)
                    } else if let error = appState.adsbError {
                        ErrorCard(message: error)
                    } else {
                        LoadingCard()
                    }

                    // Aircraft List Preview
                    if !appState.aircraftList.isEmpty {
                        aircraftPreviewSection
                    }
                }
                .padding()
            }
            .navigationTitle("ADS-B")
            .sheet(isPresented: $showAircraftList) {
                AircraftListSheet(aircraft: appState.aircraftList)
            }
            .fullScreenCover(isPresented: $showFullscreenMap) {
                FullscreenMapView()
                    .environmentObject(appState)
            }
        }
    }

    @ViewBuilder
    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "map")
                    .foregroundStyle(.blue)
                Text("Mapa ao Vivo")
                    .font(.headline)

                Spacer()

                Button {
                    showFullscreenMap = true
                } label: {
                    Label("Expandir", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
            }

            AircraftMapView(aircraft: appState.aircraftList)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    showFullscreenMap = true
                }
        }
    }

    @ViewBuilder
    private func summarySection(_ summary: ADSBSummary) -> some View {
        // Main stats
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "No Ar",
                value: "\(summary.totalNow)",
                icon: "airplane",
                color: .blue
            )

            StatCard(
                title: "Com Posição",
                value: "\(summary.withPos)",
                icon: "location.fill",
                color: .green
            )

            StatCard(
                title: "Subindo",
                value: "\(summary.movement.climbing)",
                icon: "arrow.up.circle.fill",
                color: .green
            )

            StatCard(
                title: "Descendo",
                value: "\(summary.movement.descending)",
                icon: "arrow.down.circle.fill",
                color: .orange
            )

            StatCard(
                title: "Em Cruzeiro",
                value: "\(summary.movement.cruising)",
                icon: "arrow.right.circle.fill",
                color: .blue
            )

            StatCard(
                title: "Não-Civil",
                value: "\(summary.nonCivilNow)",
                icon: "shield.fill",
                color: .purple
            )
        }

        // Averages
        HStack(spacing: 12) {
            AverageCard(
                title: "Alt. Média",
                value: "\(summary.averages.altitudeFt.formatted()) ft",
                icon: "arrow.up.and.down"
            )

            AverageCard(
                title: "Vel. Média",
                value: "\(summary.averages.speedKt) kt",
                icon: "gauge.with.needle"
            )
        }

        // Highlights
        if let highlights = summary.highlights {
            highlightsSection(highlights)
        }

        // Airlines
        if !summary.airlines.isEmpty {
            airlinesSection(summary.airlines)
        }
    }

    @ViewBuilder
    private func highlightsSection(_ highlights: Highlights) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Destaques")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                if let highest = highlights.highest, highest.callsign != nil {
                    HighlightRow(
                        icon: "arrow.up.to.line",
                        iconColor: .blue,
                        title: "Mais Alto",
                        callsign: highest.callsign ?? "???",
                        detail: "\(highest.altitudeFt ?? 0) ft"
                    )
                }

                if let fastest = highlights.fastest, fastest.callsign != nil {
                    HighlightRow(
                        icon: "hare.fill",
                        iconColor: .orange,
                        title: "Mais Rápido",
                        callsign: fastest.callsign ?? "???",
                        detail: "\(fastest.speedKt ?? 0) kt"
                    )
                }

                if let closest = highlights.closest, closest.callsign != nil {
                    HighlightRow(
                        icon: "location.fill",
                        iconColor: .green,
                        title: "Mais Perto",
                        callsign: closest.callsign ?? "???",
                        detail: String(format: "%.1f nm", closest.distanceNm ?? 0)
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private func airlinesSection(_ airlines: [Airline]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Companhias")
                .font(.headline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(airlines) { airline in
                    HStack {
                        Text(airline.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(airline.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var aircraftPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Aeronaves Próximas")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showAircraftList = true
                } label: {
                    Text("Ver Todos")
                        .font(.subheadline)
                }
            }

            VStack(spacing: 8) {
                ForEach(appState.aircraftList.prefix(5)) { aircraft in
                    AircraftRow(aircraft: aircraft)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AverageCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct HighlightRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let callsign: String
    let detail: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(callsign)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

struct AircraftRow: View {
    let aircraft: Aircraft

    var body: some View {
        HStack {
            Image(systemName: aircraft.movementIcon)
                .foregroundStyle(Color(aircraft.movementColor))

            VStack(alignment: .leading, spacing: 2) {
                Text(aircraft.displayCallsign)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()

                if let airline = aircraft.airline {
                    Text(airline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(aircraft.altitudeFt) ft")
                    .font(.caption)
                    .monospacedDigit()

                if let dist = aircraft.distanceNm {
                    Text(String(format: "%.1f nm", dist))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

struct AircraftListSheet: View {
    let aircraft: [Aircraft]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List(aircraft) { ac in
                AircraftRow(aircraft: ac)
            }
            .navigationTitle("Aeronaves (\(aircraft.count))")
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

struct ErrorCard: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()

            Text("Carregando...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ADSBView()
        .environmentObject(AppState())
}
