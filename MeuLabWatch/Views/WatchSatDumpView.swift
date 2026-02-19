import SwiftUI

/// Detalhes do SatDump para watchOS com previsao de passes
struct WatchSatDumpView: View {
    @State private var isLoading = true
    @State private var status: WatchSatDumpData?
    @State private var passes: [WatchPass] = []
    @State private var error: String?
    @State private var nextPasses: [WatchPredictedPass] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Text("Carregando...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else if let error {
                    ErrorView(message: error) {
                        Task { await loadData() }
                    }
                } else {
                    // Status atual
                    if let sat = status?.status {
                        StatusCard(isRunning: sat.running == true, currentPass: sat.currentPass)
                    }

                    // Proximo passe previsto
                    if !nextPasses.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "satellite")
                                    .foregroundStyle(.orange)
                                Text("Proximos")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            ForEach(nextPasses.prefix(3)) { pass in
                                NextPassRow(pass: pass)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Ultimo passe
                    if let sat = status?.status, let last = sat.lastPass {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "satellite.fill")
                                    .foregroundStyle(.blue)
                                Text("Ultimo Passe")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            if let satellite = last.satellite {
                                Text(satellite)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            if let timestamp = last.timestamp {
                                Text(formatTimestamp(timestamp))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // Passes recentes
                    if !passes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Historico")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            ForEach(passes.prefix(4)) { pass in
                                HStack {
                                    Text(pass.satellite)
                                        .font(.caption2)
                                    Spacer()
                                    Text(formatTimestamp(pass.timestamp))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .navigationTitle("Satelite")
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
            async let statusTask = WatchAPIService.shared.fetchSatDumpStatus()
            async let passesTask = WatchAPIService.shared.fetchPasses()

            status = try await statusTask
            let list = try await passesTask
            passes = list.passes

            // Gera previsao de proximos passes (simplificado)
            generateNextPasses()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func generateNextPasses() {
        // Gera previsao simplificada de passes do Meteor M2-X
        // Em producao, isso viria da API ou calculo TLE
        let now = Date()
        nextPasses = [
            WatchPredictedPass(
                id: "1",
                satellite: "Meteor M2-x",
                time: now.addingTimeInterval(3600 * 4), // +4h
                elevation: 65,
                quality: .excellent
            ),
            WatchPredictedPass(
                id: "2",
                satellite: "Meteor M2-x",
                time: now.addingTimeInterval(3600 * 10), // +10h
                elevation: 42,
                quality: .good
            ),
            WatchPredictedPass(
                id: "3",
                satellite: "Meteor M2-x",
                time: now.addingTimeInterval(3600 * 16), // +16h
                elevation: 78,
                quality: .excellent
            )
        ]
    }

    private func formatTimestamp(_ timestamp: String) -> String {
        // Simplifica o timestamp para exibicao compacta
        if timestamp.count > 16 {
            let start = timestamp.index(timestamp.startIndex, offsetBy: 11)
            let end = timestamp.index(timestamp.startIndex, offsetBy: 16)
            return String(timestamp[start..<end])
        }
        return timestamp
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let isRunning: Bool
    let currentPass: String?

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isRunning ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: isRunning ? "satellite.fill" : "satellite")
                    .font(.system(size: 16))
                    .foregroundStyle(isRunning ? .green : .secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isRunning ? "Recebendo" : "Aguardando")
                    .font(.caption)
                    .fontWeight(.semibold)

                if let current = currentPass {
                    Text(current)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Proximo passe em breve")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
    }
}

// MARK: - Next Pass Row

struct NextPassRow: View {
    let pass: WatchPredictedPass

    var body: some View {
        HStack(spacing: 8) {
            // Indicador de qualidade
            Circle()
                .fill(pass.quality.color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(pass.satellite)
                    .font(.caption2)
                    .fontWeight(.medium)

                Text(pass.formattedTime)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(pass.elevation)°")
                    .font(.caption2)
                    .fontWeight(.medium)

                Text(pass.timeUntil)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            Image(systemName: "arrow.up.right.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(pass.quality.color.opacity(0.85))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(Color.white.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Predicted Pass Model

struct WatchPredictedPass: Identifiable {
    let id: String
    let satellite: String
    let time: Date
    let elevation: Int
    let quality: PassQuality

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }

    var timeUntil: String {
        let interval = time.timeIntervalSince(Date())
        if interval < 0 { return "Agora" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    enum PassQuality {
        case excellent
        case good
        case fair

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .orange
            case .fair: return .gray
            }
        }
    }
}

#Preview {
    WatchSatDumpView()
}
