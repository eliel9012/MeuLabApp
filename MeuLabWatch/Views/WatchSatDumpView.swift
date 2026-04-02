import SwiftUI

struct WatchSatDumpView: View {
    @State private var isLoading = true
    @State private var status: WatchSatDumpData?
    @State private var passes: [WatchPass] = []
    @State private var predictions: [WatchMeteorPass] = []
    @State private var error: String?

    var body: some View {
        WatchLabScreen(
            title: "Satélite", icon: "antenna.radiowaves.left.and.right", tint: WatchLabTheme.violet
        ) {
            if isLoading {
                WatchLabPanel(tint: WatchLabTheme.violet) {
                    WatchLabStateView(
                        icon: "satellite",
                        title: "Atualizando",
                        subtitle: "Buscando últimos passes e previsões.",
                        tint: WatchLabTheme.violet,
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
                // Status atual
                WatchLabPanel(tint: WatchLabTheme.violet) {
                    Text(status?.status?.running == true ? "Recebendo sinais" : "Aguardando passe")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    if let currentPass = status?.status?.currentPass {
                        Text(currentPass)
                            .font(.caption2)
                            .foregroundStyle(WatchLabTheme.secondary)
                    } else if let lastSat = status?.status?.lastPass?.satellite {
                        Text("Último: \(lastSat)")
                            .font(.caption2)
                            .foregroundStyle(WatchLabTheme.secondary)
                    }
                }

                // Próximo passe previsto
                if let nextPass = predictions.first(where: { $0.isUpcoming }) {
                    WatchLabPanel(tint: WatchLabTheme.green) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Próximo passe")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(WatchLabTheme.secondary)

                                Text(nextPass.timeUntil)
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundStyle(WatchLabTheme.green)

                                Text(nextPass.satellite ?? "Meteor M2-x")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(WatchLabTheme.ink)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                if let el = nextPass.maxElevation {
                                    WatchLabMetricPill(
                                        title: "Elevação",
                                        value: "\(Int(el))°",
                                        tint: el >= 30 ? WatchLabTheme.green : WatchLabTheme.orange,
                                        icon: "arrow.up.right"
                                    )
                                }
                                Text(nextPass.durationMinutes)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(WatchLabTheme.secondary)
                            }
                        }

                        // Quality indicator
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: i < nextPass.qualityStars ? "star.fill" : "star")
                                    .font(.system(size: 8))
                                    .foregroundStyle(
                                        i < nextPass.qualityStars
                                            ? WatchLabTheme.green : WatchLabTheme.tertiary)
                            }
                            Spacer()
                        }
                    }
                }

                // Previsões futuras
                let upcomingPasses = predictions.filter { $0.isUpcoming }.dropFirst().prefix(3)
                if !upcomingPasses.isEmpty {
                    WatchLabPanel(tint: WatchLabTheme.cyan) {
                        Text("Previsões")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WatchLabTheme.ink)

                        ForEach(Array(upcomingPasses)) { pass in
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(pass.satellite ?? "Sat")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(WatchLabTheme.ink)
                                        .lineLimit(1)
                                    Text(pass.timeUntil)
                                        .font(.system(size: 10))
                                        .foregroundStyle(WatchLabTheme.secondary)
                                }
                                Spacer()
                                if let el = pass.maxElevation {
                                    Text("\(Int(el))°")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            el >= 30 ? WatchLabTheme.green : WatchLabTheme.orange)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Histórico recente
                if !passes.isEmpty {
                    WatchLabPanel(tint: WatchLabTheme.blue) {
                        Text("Histórico recente")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WatchLabTheme.ink)

                        ForEach(passes.prefix(4)) { pass in
                            HStack {
                                Text(pass.satellite)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(WatchLabTheme.ink)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatTimestamp(pass.timestamp))
                                    .font(.caption2)
                                    .foregroundStyle(WatchLabTheme.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
        }
        .task { await loadData() }
        .refreshable { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        error = nil
        do {
            async let statusTask = WatchAPIService.shared.fetchSatDumpStatus()
            async let passesTask = WatchAPIService.shared.fetchPasses()
            status = try await statusTask
            passes = try await passesTask.passes

            // Predictions - best effort
            if let meteorResponse = try? await WatchAPIService.shared.fetchMeteorPasses() {
                predictions = meteorResponse.passes ?? []
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        if timestamp.count > 16 {
            let start = timestamp.index(timestamp.startIndex, offsetBy: 11)
            let end = timestamp.index(timestamp.startIndex, offsetBy: 16)
            return String(timestamp[start..<end])
        }
        return timestamp
    }
}

#Preview {
    WatchSatDumpView()
}
