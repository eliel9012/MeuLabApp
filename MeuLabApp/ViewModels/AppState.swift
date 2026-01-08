import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    // MARK: - ADS-B
    @Published var adsbSummary: ADSBSummary?
    @Published var aircraftList: [Aircraft] = []
    @Published var localAircraftCount: Int = 0      // Aeronaves do radar local
    @Published var networkAircraftCount: Int = 0    // Aeronaves da rede ADSB.lol
    @Published var adsbError: String?
    @Published var adsbLoading = false
    @Published var showNetworkAircraft: Bool = true // Toggle para mostrar/ocultar rede

    // MARK: - System
    @Published var systemStatus: SystemStatus?
    @Published var systemError: String?
    @Published var systemLoading = false

    // MARK: - Radio
    @Published var nowPlaying: NowPlaying?
    @Published var radioError: String?
    @Published var radioLoading = false

    // MARK: - Weather
    @Published var weather: WeatherData?
    @Published var weatherError: String?
    @Published var weatherLoading = false

    // MARK: - Satellite
    @Published var lastImages: LastImages?
    @Published var passes: [SatellitePass] = []
    @Published var satelliteError: String?
    @Published var satelliteLoading = false

    // MARK: - ACARS
    @Published var acarsSummary: ACARSSummary?
    @Published var acarsMessages: [ACARSMessage] = []
    @Published var acarsHourly: [ACARSHourStat] = []
    @Published var acarsError: String?
    @Published var acarsLoading = false

    // MARK: - Timers
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 0.25 // 250ms

    private let api = APIService.shared

    init() {
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Timer Management

    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAllData()
            }
        }
    }

    private func refreshAllData() async {
        // Refresh in parallel, but don't block UI
        async let adsb: () = refreshADSB()
        async let system: () = refreshSystem()
        async let radio: () = refreshRadio()
        async let weather: () = refreshWeather()
        async let satellite: () = refreshSatellite()
        async let acars: () = refreshACARS()

        _ = await (adsb, system, radio, weather, satellite, acars)
    }

    // MARK: - ADS-B

    func refreshADSB() async {
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
            if self.adsbSummary != summary {
                self.adsbSummary = summary
            }

            if self.aircraftList != combined {
                self.aircraftList = combined
            }

            self.adsbError = nil
        } catch {
            // Only show error if we don't have cached data
            if adsbSummary == nil {
                self.adsbError = error.localizedDescription
            }
        }
    }

    /// Busca aeronaves da rede ADSB.lol sem propagar erros
    private func fetchNetworkAircraftSafe() async -> [Aircraft] {
        do {
            return try await api.fetchADSBLolAircraft()
        } catch {
            // Silenciosamente retorna vazio se falhar
            return []
        }
    }

    // MARK: - System

    func refreshSystem() async {
        do {
            let status = try await api.fetchSystemStatus()

            if self.systemStatus != status {
                self.systemStatus = status
            }
            self.systemError = nil
        } catch {
            if systemStatus == nil {
                self.systemError = error.localizedDescription
            }
        }
    }

    // MARK: - Radio

    func refreshRadio() async {
        do {
            let playing = try await api.fetchNowPlaying()

            if self.nowPlaying != playing {
                self.nowPlaying = playing
                // Update Now Playing in Control Center
                AudioPlayer.shared.updateNowPlayingInfo(track: playing)
            }
            self.radioError = nil
        } catch {
            if nowPlaying == nil {
                self.radioError = error.localizedDescription
            }
        }
    }

    // MARK: - Weather

    func refreshWeather() async {
        do {
            let data = try await api.fetchWeather()

            if self.weather != data {
                self.weather = data
            }
            self.weatherError = nil
        } catch {
            if weather == nil {
                self.weatherError = error.localizedDescription
            }
        }
    }

    // MARK: - Satellite

    func refreshSatellite() async {
        do {
            let images = try await api.fetchLastImages()
            let passesList = try await api.fetchPasses()

            if self.lastImages != images {
                self.lastImages = images
            }

            let newPasses = passesList.passes
            if self.passes != newPasses {
                self.passes = newPasses
            }

            self.satelliteError = nil
        } catch {
            if lastImages == nil {
                self.satelliteError = error.localizedDescription
            }
        }
    }

    // MARK: - ACARS

    func refreshACARS() async {
        do {
            let summary = try await api.fetchACARSSummary()
            let messageList = try await api.fetchACARSMessages(limit: 20)
            let hourly = try await api.fetchACARSHourly()

            if self.acarsSummary != summary {
                self.acarsSummary = summary
            }

            let newMessages = messageList.messages
            if self.acarsMessages != newMessages {
                self.acarsMessages = newMessages
            }

            let newHourly = hourly.hours
            if self.acarsHourly != newHourly {
                self.acarsHourly = newHourly
            }

            self.acarsError = nil
        } catch {
            if acarsSummary == nil {
                self.acarsError = error.localizedDescription
            }
        }
    }

    // MARK: - Manual Refresh (for pull-to-refresh)

    func forceRefresh() async {
        await refreshAllData()
    }
}
