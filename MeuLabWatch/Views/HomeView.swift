import SwiftUI

/// Tela de Resumo com cards compactos de cada categoria
struct HomeView: View {
    @State private var isLoading = true
    @State private var error: String?
    @State private var adsb: WatchADSBData?
    @State private var acars: WatchACARSData?
    @State private var system: WatchSystemData?
    @State private var weather: WatchWeatherData?
    @State private var infra: WatchInfraData?
    @State private var satdump: WatchSatDumpData?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if isLoading {
                    ProgressView("Carregando...")
                        .padding(.top, 40)
                } else if let error {
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.title)
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                        Button("Tentar novamente") {
                            Task { await loadData() }
                        }
                        .font(.caption)
                    }
                    .padding()
                } else {
                    // ADS-B Card
                    if let adsb {
                        SummaryCard(
                            title: "ADS-B",
                            icon: "airplane.radar",
                            color: .blue,
                            lines: [
                                "\(adsb.totalNow) no ar",
                                "\(adsb.withPos) com posição",
                            ]
                        )
                    }

                    // ACARS Card
                    if let acars {
                        SummaryCard(
                            title: "ACARS",
                            icon: "envelope.badge.fill",
                            color: .orange,
                            lines: [
                                "\(acars.messagesTotal) msgs",
                                "\(acars.uniqueFlights ?? 0) voos",
                            ]
                        )
                    }

                    // Sistema Card
                    if let system {
                        SummaryCard(
                            title: "Sistema",
                            icon: "cpu.fill",
                            color: .green,
                            lines: [
                                "CPU: \(Int(system.cpuPercent))%",
                                "RAM: \(Int(system.memoryPercent))%",
                            ]
                        )
                    }

                    // Infra Card
                    if let infra {
                        let running = infra.docker.containers.filter { $0.state == "running" }.count
                        SummaryCard(
                            title: "Infra",
                            icon: "server.rack",
                            color: .purple,
                            lines: ["\(running) containers"]
                        )
                    }

                    // Clima Card
                    if let weather, let current = weather.current {
                        SummaryCard(
                            title: "Clima",
                            icon: "cloud.sun.fill",
                            color: .cyan,
                            lines: ["\(Int(current.temperature))°C"]
                        )
                    }

                    // SatDump Card
                    if let satdump, let status = satdump.status {
                        let lastSat = status.lastPass?.satellite ?? "N/A"
                        SummaryCard(
                            title: "SatDump",
                            icon: "antenna.radiowaves.left.and.right",
                            color: .pink,
                            lines: ["Último: \(lastSat)"]
                        )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Resumo")
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
            // Buscar dados em paralelo
            async let adsbTask = WatchAPIService.shared.fetchADSBSummary()
            async let acarsTask = WatchAPIService.shared.fetchACARSSummary()
            async let systemTask = WatchAPIService.shared.fetchSystemStatus()
            async let weatherTask = WatchAPIService.shared.fetchWeather()
            async let infraTask = WatchAPIService.shared.fetchInfraSummary()
            async let satdumpTask = WatchAPIService.shared.fetchSatDumpStatus()

            // Usar resultados individuais para não falhar tudo se um endpoint falhar
            adsb = try? await adsbTask
            acars = try? await acarsTask
            system = try? await systemTask
            weather = try? await weatherTask
            infra = try? await infraTask
            satdump = try? await satdumpTask

            // Se nenhum dado foi carregado, mostra erro
            if adsb == nil && acars == nil && system == nil {
                error = "Falha ao conectar"
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

/// Card compacto para resumo
struct SummaryCard: View {
    let title: String
    let icon: String
    let color: Color
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 18, height: 18)
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            if let first = lines.first {
                Text(first)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            if lines.count > 1 {
                Text(lines[1])
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .cornerRadius(8)
    }
}

#Preview {
    HomeView()
}
