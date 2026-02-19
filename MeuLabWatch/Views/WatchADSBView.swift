import SwiftUI

/// Detalhes ADS-B para watchOS
struct WatchADSBView: View {
    @State private var isLoading = true
    @State private var summary: WatchADSBData?
    @State private var aircraft: [WatchAircraft] = []
    @State private var error: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if isLoading {
                    ProgressView("Carregando...")
                        .frame(maxWidth: .infinity)
                } else if let error {
                    ErrorView(message: error) {
                        Task { await loadData() }
                    }
                } else {
                    // Contadores
                    if let summary {
                        HStack {
                            StatItem(value: "\(summary.totalNow)", label: "No ar")
                            StatItem(value: "\(summary.withPos)", label: "Com pos.")
                        }
                        
                        Divider()
                    }
                    
                    // Lista de aeronaves
                    Text("Próximas")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    if aircraft.isEmpty {
                        Text("Nenhuma aeronave")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(aircraft) { ac in
                            HStack(spacing: 8) {
                                // Logo
                                if let logoURL = WatchAirlineLogo.url(fromCallsign: ac.callsign) ?? (ac.airline != nil ? WatchAirlineLogo.url(for: ac.airline!) : nil) {
                                    AsyncImage(url: logoURL) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fit)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    Image(systemName: "airplane.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                        .frame(width: 24, height: 24)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(ac.displayCallsign)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    HStack(spacing: 4) {
                                        if let airline = ac.airline {
                                            Text(airline)
                                                .font(.system(size: 8))
                                                .foregroundStyle(.blue)
                                        }
                                        if let model = ac.model {
                                            Text(model)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(ac.altitudeFt) ft")
                                        .font(.caption2)
                                    if let dist = ac.distanceNm {
                                        Text(String(format: "%.0f nm", dist))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("ADS-B")
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
            let list = try await aircraftTask
            aircraft = list.items
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}

/// Item de estatística compacto
struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// View de erro reutilizável
struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption2)
                .multilineTextAlignment(.center)
            Button("Tentar novamente", action: retry)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WatchADSBView()
}
