import Foundation
import Combine

/// Módulo de estado para ADS-B
@MainActor
class ADSBStateModule: ObservableObject {
    @Published var summary: ADSBSummary?
    @Published var aircraftList: [Aircraft] = []
    @Published var localAircraftCount: Int = 0      // Aeronaves do radar local
    @Published var networkAircraftCount: Int = 0    // Aeronaves da rede ADSB.lol
    @Published var error: String?
    @Published var isLoading = false
    @Published var showNetworkAircraft: Bool = true // Toggle para mostrar/ocultar rede

    private let api: APIServiceProtocol

    init(api: APIServiceProtocol) {
        self.api = api
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Buscar dados locais e da rede em paralelo
            async let summaryTask = api.fetchADSBSummary()
            async let localTask = api.fetchAircraftList(limit: 100)
            async let networkTask = fetchNetworkAircraftSafe()

            let summary = try await summaryTask
            let localAircraft = try await localTask

            // Marcar aeronaves locais com source = .local
            var localItems = localAircraft.items.map { $0.with(source: .local) }
            let localHexSet = Set(localItems.compactMap { $0.hex })

            // Buscar aeronaves da rede (não falha se der erro)
            let networkAircraft = await networkTask

            // Filtrar aeronaves da rede que não estão no radar local
            let uniqueNetworkAircraft = networkAircraft.filter { ac in
                guard let hex = ac.hex else { return true }
                return !localHexSet.contains(hex)
            }

            // Atualizar contadores
            self.localAircraftCount = localItems.count
            self.networkAircraftCount = uniqueNetworkAircraft.count

            // Combinar listas (locais primeiro, depois rede se habilitado)
            var combined = localItems
            if showNetworkAircraft {
                combined.append(contentsOf: uniqueNetworkAircraft)
            }

            // Only update if data changed (prevents UI jitter)
            if self.summary != summary {
                self.summary = summary
            }

            if self.aircraftList != combined {
                self.aircraftList = combined
            }

            self.error = nil
            Logger.info("ADSB refresh: \(localItems.count) locais + \(uniqueNetworkAircraft.count) rede")
        } catch {
            // Only show error if we don't have cached data
            if summary == nil {
                self.error = error.localizedDescription
                Logger.error("ADSB refresh error: \(error.localizedDescription)")
            }
        }
    }

    /// Busca aeronaves da rede ADSB.lol sem propagar erros
    private func fetchNetworkAircraftSafe() async -> [Aircraft] {
        do {
            return try await api.fetchADSBLolAircraft()
        } catch {
            // Silenciosamente retorna vazio se falhar
            Logger.warning("ADSB.lol fetch failed (non-fatal): \(error.localizedDescription)")
            return []
        }
    }
}
