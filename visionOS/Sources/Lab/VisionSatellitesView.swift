import SwiftUI

private struct VisionSatellitePasses: Decodable {
    let passCount: Int
    let passes: [VisionSatellitePass]
    enum CodingKeys: String, CodingKey { case passCount = "pass_count", passes }
}

private struct VisionSatellitePass: Decodable, Identifiable {
    let satellite: String
    let aosUtc: String
    let losUtc: String
    let durationSec: Int
    let maxElevationDeg: Double
    var id: String { "\(satellite)-\(aosUtc)" }
    enum CodingKeys: String, CodingKey {
        case satellite
        case aosUtc = "aos_utc", losUtc = "los_utc"
        case durationSec = "duration_sec", maxElevationDeg = "max_elevation_deg"
    }
}

private struct VisionMeteorStatus: Decodable {
    let windowActive: Bool
    let windowReason: String?
    let tleAge: String?
    enum CodingKeys: String, CodingKey {
        case windowActive = "window_active", windowReason = "window_reason", tleAge = "tle_age"
    }
}

private struct VisionSatDumpStatus: Decodable {
    let satdumpRunning: Bool?
    let autotrackRunning: Bool?
    enum CodingKeys: String, CodingKey {
        case satdumpRunning = "satdump_running", autotrackRunning = "autotrack_running"
    }
}

struct VisionSatellitesView: View {
    @State private var meteor: [VisionSatellitePass] = []
    @State private var orbcomm: [VisionSatellitePass] = []
    @State private var meteorStatus: VisionMeteorStatus?
    @State private var satdump: VisionSatDumpStatus?
    @State private var error: String?
    @State private var loading = false
    @State private var updatedAt: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label("Satélites", systemImage: "satellite").font(.largeTitle.bold())
                    Spacer()
                    if loading { ProgressView() }
                    Button("Atualizar", systemImage: "arrow.clockwise") { Task { await refresh() } }
                }
                Text("Passagens calculadas pelo servidor com TLE atual")
                    .font(.callout).foregroundStyle(.secondary)
                if let error {
                    Label("API2: \(error)", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                HStack(spacing: 14) {
                    statusCard("Meteor", value: meteorStatus.map { $0.windowActive ? "Janela ativa" : "Aguardando" } ?? "—",
                               symbol: "satellite.fill")
                    statusCard("SatDump", value: satdump?.satdumpRunning.map { $0 ? "Recebendo" : "Parado" } ?? "—",
                               symbol: "antenna.radiowaves.left.and.right")
                    statusCard("Autotrack", value: satdump?.autotrackRunning.map { $0 ? "Ativo" : "Parado" } ?? "—",
                               symbol: "scope")
                }
                if let age = meteorStatus?.tleAge {
                    Text("Idade do TLE: \(age)").font(.caption).foregroundStyle(.secondary)
                }
                passSection("Meteor · próximos passes", passes: meteor)
                passSection("Orbcomm · próximos passes", passes: orbcomm)
                if let updatedAt {
                    Text("Atualizado \(updatedAt.formatted(date: .omitted, time: .standard)) · MeuLab API2")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .task {
            while !Task.isCancelled {
                await refresh()
                do { try await Task.sleep(for: .seconds(120)) }
                catch { break }
            }
        }
    }

    private func statusCard(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func passSection(_ title: String, passes: [VisionSatellitePass]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
            if passes.isEmpty {
                Text(error == nil ? "Nenhuma passagem prevista nas próximas 24 horas." : "Previsão indisponível.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(passes) { pass in
                    HStack(spacing: 18) {
                        Image(systemName: "satellite.fill").foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pass.satellite).font(.headline)
                            Text("Entrada \(formatted(pass.aosUtc)) · saída \(formatted(pass.losUtc))")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(pass.maxElevationDeg.formatted(.number.precision(.fractionLength(0))))°")
                                .font(.headline)
                            Text("\(pass.durationSec / 60) min").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private func formatted(_ timestamp: String) -> String {
        if let date = ISO8601DateFormatter().date(from: timestamp) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return timestamp.replacingOccurrences(of: "T", with: " ")
    }

    private func refresh() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let api = try VisionAPIClient(api2: true)
            async let meteorResult: VisionSatellitePasses = api.fetch("meteor/passes/next?hours=24&min_elevation=10&limit=10")
            async let orbcommResult: VisionSatellitePasses = api.fetch("orbcomm/passes/next?hours=24&min_elevation=15&limit=10")
            async let statusResult: VisionMeteorStatus = api.fetch("meteor/status")
            async let satdumpResult: VisionSatDumpStatus = api.fetch("satdump/status")
            let (m, o, s, d) = try await (meteorResult, orbcommResult, statusResult, satdumpResult)
            meteor = m.passes
            orbcomm = o.passes
            meteorStatus = s
            satdump = d
            error = nil
            updatedAt = Date()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
