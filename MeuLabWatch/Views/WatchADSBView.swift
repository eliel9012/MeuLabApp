import SwiftUI

struct WatchADSBView: View {
    @State private var isLoading = true
    @State private var summary: WatchADSBData?
    @State private var aircraft: [WatchAircraft] = []
    @State private var highlights: WatchADSBHighlights?
    @State private var error: String?

    var body: some View {
        WatchLabScreen(title: "ADS-B", icon: "airplane", tint: WatchLabTheme.blue) {
            if isLoading {
                WatchLabPanel(tint: WatchLabTheme.blue) {
                    WatchLabStateView(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Atualizando",
                        subtitle: "Buscando radar local e aeronaves próximas.",
                        tint: WatchLabTheme.blue,
                        actionTitle: nil,
                        action: nil
                    )
                }
            } else if let error {
                WatchLabPanel(tint: WatchLabTheme.red) {
                    WatchLabStateView(
                        icon: "wifi.exclamationmark",
                        title: "Falha",
                        subtitle: error,
                        tint: WatchLabTheme.red,
                        actionTitle: "Tentar",
                        action: { Task { await loadData() } }
                    )
                }
            } else {
                if let summary {
                    WatchLabPanel(tint: WatchLabTheme.blue) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Radar ao vivo")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(WatchLabTheme.ink)
                                Text("\(summary.totalNow)")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(WatchLabTheme.ink)
                                Text("aeronaves no ar")
                                    .font(.caption2)
                                    .foregroundStyle(WatchLabTheme.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                WatchLabMetricPill(
                                    title: "Com posição",
                                    value: "\(summary.withPos)",
                                    tint: WatchLabTheme.green,
                                    icon: "location"
                                )

                                if let nonCivil = summary.nonCivilNow, nonCivil > 0 {
                                    WatchLabMetricPill(
                                        title: "Não civil",
                                        value: "\(nonCivil)",
                                        tint: WatchLabTheme.violet,
                                        icon: "shield"
                                    )
                                }
                            }
                        }
                    }
                }

                // Highlights section
                if let highlights, let highlightList = highlights.highlights, !highlightList.isEmpty
                {
                    WatchLabPanel(tint: WatchLabTheme.orange) {
                        HStack {
                            Text("Destaques")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WatchLabTheme.ink)
                            Spacer()
                            if let mil = highlights.militaryCount, mil > 0 {
                                Text("\(mil) militar")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(WatchLabTheme.red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(WatchLabTheme.red.opacity(0.14)))
                            }
                        }

                        ForEach(highlightList.prefix(3)) { hl in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(highlightColor(hl.category).opacity(0.14))
                                    .frame(width: 24, height: 24)
                                    .overlay {
                                        Image(systemName: highlightIcon(hl.category))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(highlightColor(hl.category))
                                    }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(hl.callsign ?? hl.registration ?? hl.id)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(WatchLabTheme.ink)
                                        .lineLimit(1)
                                    if let reason = hl.reason {
                                        Text(reason)
                                            .font(.system(size: 9))
                                            .foregroundStyle(WatchLabTheme.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                if let dist = hl.distanceNm {
                                    Text(String(format: "%.0f nm", dist))
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(WatchLabTheme.secondary)
                                }
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                        }
                    }
                }

                WatchLabPanel(tint: WatchLabTheme.cyan) {
                    Text("Próximas aeronaves")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    if aircraft.isEmpty {
                        Text("Nenhuma aeronave próxima.")
                            .font(.caption2)
                            .foregroundStyle(WatchLabTheme.secondary)
                    } else {
                        ForEach(aircraft.prefix(5)) { ac in
                            WatchAircraftRow(aircraft: ac)
                        }
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            async let summaryTask = WatchAPIService.shared.fetchADSBSummary()
            async let aircraftTask = WatchAPIService.shared.fetchAircraftList()

            summary = try await summaryTask
            aircraft = try await aircraftTask.items

            // Highlights - best effort
            highlights = try? await WatchAPIService.shared.fetchADSBHighlights()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func highlightColor(_ category: String?) -> Color {
        switch category {
        case "military": return WatchLabTheme.red
        case "government": return WatchLabTheme.orange
        case "interesting": return WatchLabTheme.violet
        case "closest": return WatchLabTheme.green
        default: return WatchLabTheme.cyan
        }
    }

    private func highlightIcon(_ category: String?) -> String {
        switch category {
        case "military": return "shield.fill"
        case "government": return "building.columns"
        case "interesting": return "star.fill"
        case "closest": return "location.fill"
        default: return "airplane"
        }
    }
}

struct WatchAircraftRow: View {
    let aircraft: WatchAircraft

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(WatchLabTheme.blue.opacity(0.14))
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: "airplane")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WatchLabTheme.blue)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(aircraft.displayCallsign)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WatchLabTheme.ink)
                    .lineLimit(1)

                Text(aircraft.model ?? aircraft.airline ?? "Sem modelo")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WatchLabTheme.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(aircraft.altitudeFt) ft")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchLabTheme.ink)
                Text(aircraft.distanceNm.map { String(format: "%.0f nm", $0) } ?? "--")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WatchLabTheme.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(WatchLabTheme.blue.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

#Preview {
    WatchADSBView()
}
