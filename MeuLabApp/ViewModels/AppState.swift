import Combine
import CoreLocation
import Foundation
import SwiftUI

#if canImport(WeatherKit)
    import WeatherKit
#endif

@MainActor
class AppState: ObservableObject {
    // MARK: - Active Tab Gating
    //
    // Este app mantem varias tabs "visitadas" vivas no ZStack (opacity=0). Quando
    // o AppState publica atualizacoes frequentes (ex.: ADSB a cada 0.5s), mesmo as
    // views escondidas recompoem e isso explode CPU e deixa a UI lenta ao trocar de tab.
    @Published private(set) var activeTabRawValue: String = "adsb"
    @Published var intelligenceContext: [String: String]?
    func setActiveTab(_ rawValue: String) {
        let didChange = activeTabRawValue != rawValue
        activeTabRawValue = rawValue
        guard didChange, hasBootstrapped else { return }

        Task { @MainActor [weak self] in
            await self?.refreshActiveTabNow(force: false)
        }
    }

    func updateRadarBounds(_ bounds: [Double]) {
        guard bounds.count == 4 else {
            self.radarBoundingBox = bounds
            return
        }

        let minLat = min(bounds[0], bounds[1])
        let maxLat = max(bounds[0], bounds[1])
        let minLon = min(bounds[2], bounds[3])
        let maxLon = max(bounds[2], bounds[3])
        self.radarBoundingBox = [minLat, maxLat, minLon, maxLon]
    }

    // MARK: - ADS-B
    @Published var adsbSummary: ADSBSummary? {
        didSet { rebuildADSBViewCache() }
    }
    @Published var aircraftList: [Aircraft] = [] {
        didSet { rebuildADSBViewCache() }
    }
    @Published var localAircraftCount: Int = 0  // Aeronaves do radar local
    @Published var openskyAircraftCount: Int = 0  // Aeronaves da OpenSky
    @Published var adsbError: String?
    @Published var adsbLoading = false
    @Published var isOpenSkyEnabled: Bool = false {
        didSet {
            lastOpenSkyRefresh = nil
            lastADSBSummaryRefresh = nil
            lastADSBListRefresh = nil
            Task { await refreshADSB(includeSummary: true, includeAircraft: true) }
        }
    }
    @Published private(set) var manualAirlineOverrides: [String: String] = [:]
    @Published private(set) var adsbAirlines: [Airline] = []
    @Published private(set) var adsbNearbyAircraftPreview: [Aircraft] = []

    // MARK: - Map Coordination
    @Published var mapFocusAircraft: Aircraft?
    @Published var radarBoundingBox: [Double]?  // [minLat, maxLat, minLon, maxLon]

    // MARK: - System
    @Published var systemStatus: SystemStatus?
    @Published var systemError: String?
    @Published var systemLoading = false

    // MARK: - Fire Stick
    @Published var firestickDeviceStatuses: [FirestickDeviceStatus] = []
    @Published var firestickError: String?
    @Published var firestickLoading = false

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
    @Published var acarsHistory: ACARSHistoryResponse?
    @Published var acarsAlerts: [ACARSAlert] = []
    @Published var acarsError: String?
    @Published var acarsLoading = false

    // MARK: - System Extras
    @Published var processes: [ProcessItem] = []
    @Published var partitions: [Partition] = []
    @Published var networkInterfaces: [NetworkInterface] = []
    @Published var systemExtrasError: String?

    // MARK: - Docker
    @Published var dockerVersion: DockerVersionResponse?
    @Published var dockerContainers: [DockerContainer] = []
    @Published var dockerError: String?

    // MARK: - Systemd
    @Published var systemdServices: [SystemdService] = []
    @Published var systemdError: String?

    // MARK: - SatDump Extras
    @Published var satDumpStatus: SatDumpStatus?
    @Published var satDumpError: String?

    // MARK: - ADSB Extras
    @Published var adsbHistory: ADSBHistoryResponse?
    @Published var adsbAlerts: [ADSBAlert] = []
    @Published var adsbHistoryError: String?
    @Published var tuyaSensor: TuyaTemperatureHumidityResponse?
    @Published var tuyaSensorError: String?
    @Published var tuyaSensorLoading = false

    // MARK: - Metrics
    @Published var metrics: MetricsResponse?
    @Published var metricsError: String?

    // MARK: - Timers
    //
    // Arquitetura: cada grupo de módulos tem seu próprio timer independente.
    // Só módulos da tab ativa são atualizados no ritmo rápido.
    // Módulos de tabs inativas NÃO fazem polling (zero custo).
    private var adsbTimer: Timer?
    private var moduleTimer: Timer?

    // Per-group in-flight guards — nunca bloqueia outro grupo.
    private var adsbInFlight = false
    private var systemInFlight = false
    private var radioInFlight = false
    private var weatherInFlight = false
    private var satelliteInFlight = false
    private var acarsInFlight = false

    // Intervalos de cada módulo quando a tab está ativa
    private let adsbTimerInterval: TimeInterval = 0.75
    private let adsbSummaryInterval: TimeInterval = 0.75
    private let adsbAircraftInterval: TimeInterval = 1.5
    private let systemInterval: TimeInterval = 5.0
    private let firestickInterval: TimeInterval = 10.0
    private let radioInterval: TimeInterval = 5.0
    private let radioBackgroundInterval: TimeInterval = 15.0
    private let weatherInterval: TimeInterval = 60.0
    private let satelliteInterval: TimeInterval = 120.0
    private let acarsInterval: TimeInterval = 10.0
    private let processesInterval: TimeInterval = 10.0
    private let partitionsInterval: TimeInterval = 60.0
    private let networkInterval: TimeInterval = 10.0
    private let dockerStatusInterval: TimeInterval = 20.0
    private let dockerVersionInterval: TimeInterval = 300.0
    private let systemdInterval: TimeInterval = 30.0
    private let satDumpStatusInterval: TimeInterval = 60.0
    private let adsbHistoryInterval: TimeInterval = 300.0
    private let adsbAlertsInterval: TimeInterval = 60.0
    private let tuyaSensorInterval: TimeInterval = 30.0
    private let acarsHistoryInterval: TimeInterval = 300.0
    private let acarsAlertsInterval: TimeInterval = 60.0
    private let metricsInterval: TimeInterval = 10.0

    private var lastADSBSummaryRefresh: Date?
    private var lastADSBListRefresh: Date?
    private var lastSystemRefresh: Date?
    private var lastFirestickRefresh: Date?
    private var lastRadioRefresh: Date?
    private var lastWeatherRefresh: Date?
    private var lastSatelliteRefresh: Date?
    private var lastACARSRefresh: Date?
    private var lastProcessesRefresh: Date?
    private var lastPartitionsRefresh: Date?
    private var lastNetworkRefresh: Date?
    private var lastDockerStatusRefresh: Date?
    private var lastDockerVersionRefresh: Date?
    private var lastSystemdRefresh: Date?
    private var lastSatDumpStatusRefresh: Date?
    private var lastADSBHistoryRefresh: Date?
    private var lastADSBAlertsRefresh: Date?
    private var lastTuyaSensorRefresh: Date?
    private var lastACARSHistoryRefresh: Date?
    private var lastACARSAlertsRefresh: Date?
    private var lastMetricsRefresh: Date?
    private var lastOpenSkyRefresh: Date?

    private let api = APIService.shared
    private let openSkyService = OpenSkyService.shared
    private let manualAirlineOverridesDefaultsKey = "adsb.manualAirlineOverrides"
    private var hasBootstrapped = false

    init() {
        loadManualAirlineOverrides()
        rebuildADSBViewCache()
    }

    deinit {
        adsbTimer?.invalidate()
        moduleTimer?.invalidate()
    }

    // MARK: - Timer Management

    private func startRefreshTimers() {
        guard adsbTimer == nil else { return }
        // Timer dedicado ao ADS-B com cadence menos agressiva para reduzir CPU e wakeups.
        adsbTimer = Timer.scheduledTimer(withTimeInterval: adsbTimerInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.tickADSB()
            }
        }
        // Timer para os demais módulos — cada grupo roda independente via in-flight flags
        moduleTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.tickActiveModules()
            }
        }
    }

    func bootstrapIfNeeded() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        startRefreshTimers()

        Task { @MainActor [weak self] in
            await self?.refreshActiveTabNow(force: true)
            // Pré-carrega rádio em background para já ter album/artista ao abrir
            await self?.refreshRadio()
        }
    }

    func setRefreshEnabled(_ enabled: Bool) {
        guard hasBootstrapped else { return }
        if enabled {
            startRefreshTimers()
        } else {
            adsbTimer?.invalidate()
            adsbTimer = nil
            moduleTimer?.invalidate()
            moduleTimer = nil
        }
    }

    // MARK: - ADSB Tick (independente)

    private func tickADSB(forceVisible: Bool = false) async {
        let active = activeTabRawValue
        let isADSBActive = forceVisible || active == "adsb" || active == "map" || active == "intelligence"
        guard isADSBActive else { return }  // Não gasta CPU se a tab não está visível
        guard !adsbInFlight else { return }
        adsbInFlight = true
        defer { adsbInFlight = false }

        let now = Date()
        let doSummary =
            adsbSummary == nil
            || shouldRefresh(last: lastADSBSummaryRefresh, interval: adsbSummaryInterval, now: now)
        let doAircraft =
            aircraftList.isEmpty
            || shouldRefresh(last: lastADSBListRefresh, interval: adsbAircraftInterval, now: now)
        guard doSummary || doAircraft else { return }

        if doSummary { lastADSBSummaryRefresh = now }
        if doAircraft { lastADSBListRefresh = now }
        await refreshADSB(includeSummary: doSummary, includeAircraft: doAircraft)
    }

    // MARK: - Demais módulos — só a tab ativa atualiza

    private func tickActiveModules() async {
        let active = activeTabRawValue
        let now = Date()

        // Rádio sempre atualiza em background (intervalo maior quando não é a tab ativa)
        await tickRadio(now, background: active != "radio")

        switch active {
        case "adsb", "map":
            // ADSB live já roda no seu próprio timer rápido.
            // Aqui só atualizamos dados complementares (history, alerts, metrics).
            await tickADSBExtras(now)

        case "system", "infra":
            await tickSystem(now)

        case "weather":
            await tickWeather(now)

        case "satellite":
            await tickSatellite(now)

        case "acars":
            await tickACARS(now)

        case "intelligence":
            await tickIntelligence(now)

        default:
            break
        }
    }

    // --- Grupos de refresh isolados ---

    private func tickADSBExtras(_ now: Date) async {
        let doHistory = shouldRefresh(
            last: lastADSBHistoryRefresh, interval: adsbHistoryInterval, now: now)
        let doAlerts = shouldRefresh(
            last: lastADSBAlertsRefresh, interval: adsbAlertsInterval, now: now)
        let doTuya =
            shouldRefresh(last: lastTuyaSensorRefresh, interval: tuyaSensorInterval, now: now)
            || tuyaSensor == nil
        let doMetrics = shouldRefresh(last: lastMetricsRefresh, interval: metricsInterval, now: now)
        if doHistory { lastADSBHistoryRefresh = now }
        if doAlerts { lastADSBAlertsRefresh = now }
        if doTuya { lastTuyaSensorRefresh = now }
        if doMetrics { lastMetricsRefresh = now }

        async let history: () = doHistory ? refreshADSBHistory() : ()
        async let alerts: () = doAlerts ? refreshADSBAlerts() : ()
        async let tuya: () = doTuya ? refreshTuyaSensor() : ()
        async let metrics: () = doMetrics ? refreshMetrics() : ()
        _ = await (history, alerts, tuya, metrics)
    }

    private func tickSystem(_ now: Date) async {
        guard !systemInFlight else { return }
        systemInFlight = true
        defer { systemInFlight = false }

        let doSys = shouldRefresh(last: lastSystemRefresh, interval: systemInterval, now: now)
        let doFire = shouldRefresh(
            last: lastFirestickRefresh, interval: firestickInterval, now: now)
        let doProc = shouldRefresh(
            last: lastProcessesRefresh, interval: processesInterval, now: now)
        let doParts = shouldRefresh(
            last: lastPartitionsRefresh, interval: partitionsInterval, now: now)
        let doNet = shouldRefresh(last: lastNetworkRefresh, interval: networkInterval, now: now)
        let doDkSt = shouldRefresh(
            last: lastDockerStatusRefresh, interval: dockerStatusInterval, now: now)
        let doDkVer = shouldRefresh(
            last: lastDockerVersionRefresh, interval: dockerVersionInterval, now: now)
        let doSysd = shouldRefresh(last: lastSystemdRefresh, interval: systemdInterval, now: now)
        let doSatdump = shouldRefresh(
            last: lastSatDumpStatusRefresh, interval: satDumpStatusInterval, now: now)
        let doMetrics = shouldRefresh(last: lastMetricsRefresh, interval: metricsInterval, now: now)

        if doSys { lastSystemRefresh = now }
        if doFire { lastFirestickRefresh = now }
        if doProc { lastProcessesRefresh = now }
        if doParts { lastPartitionsRefresh = now }
        if doNet { lastNetworkRefresh = now }
        if doDkSt { lastDockerStatusRefresh = now }
        if doDkVer { lastDockerVersionRefresh = now }
        if doSysd { lastSystemdRefresh = now }
        if doSatdump { lastSatDumpStatusRefresh = now }
        if doMetrics { lastMetricsRefresh = now }

        async let sys: () = doSys ? refreshSystem() : ()
        async let fire: () = doFire ? refreshFirestick() : ()
        async let proc: () = doProc ? refreshProcesses() : ()
        async let parts: () = doParts ? refreshPartitions() : ()
        async let net: () = doNet ? refreshNetwork() : ()
        async let dkStatus: () = doDkSt ? refreshDockerStatus() : ()
        async let dkVersion: () = doDkVer ? refreshDockerVersion() : ()
        async let sysd: () = doSysd ? refreshSystemd() : ()
        async let satdump: () = doSatdump ? refreshSatDumpStatus() : ()
        async let metrics: () = doMetrics ? refreshMetrics() : ()
        _ = await (sys, fire, proc, parts, net, dkStatus, dkVersion, sysd, satdump, metrics)
    }

    private func tickRadio(_ now: Date, background: Bool = false) async {
        guard !radioInFlight else { return }
        radioInFlight = true
        defer { radioInFlight = false }
        let interval = background ? radioBackgroundInterval : radioInterval
        guard shouldRefresh(last: lastRadioRefresh, interval: interval, now: now) else { return }
        lastRadioRefresh = now
        await refreshRadio()
    }

    private func tickWeather(_ now: Date) async {
        guard !weatherInFlight else { return }
        weatherInFlight = true
        defer { weatherInFlight = false }
        guard shouldRefresh(last: lastWeatherRefresh, interval: weatherInterval, now: now) else {
            return
        }
        lastWeatherRefresh = now
        await refreshWeather()
    }

    private func tickSatellite(_ now: Date) async {
        guard !satelliteInFlight else { return }
        satelliteInFlight = true
        defer { satelliteInFlight = false }
        guard shouldRefresh(last: lastSatelliteRefresh, interval: satelliteInterval, now: now)
        else { return }
        lastSatelliteRefresh = now
        await refreshSatellite()
    }

    private func tickACARS(_ now: Date) async {
        guard !acarsInFlight else { return }
        acarsInFlight = true
        defer { acarsInFlight = false }

        let doAcars = shouldRefresh(last: lastACARSRefresh, interval: acarsInterval, now: now)
        let doHistory = shouldRefresh(
            last: lastACARSHistoryRefresh, interval: acarsHistoryInterval, now: now)
        let doAlerts = shouldRefresh(
            last: lastACARSAlertsRefresh, interval: acarsAlertsInterval, now: now)
        if doAcars { lastACARSRefresh = now }
        if doHistory { lastACARSHistoryRefresh = now }
        if doAlerts { lastACARSAlertsRefresh = now }

        async let acars: () = doAcars ? refreshACARS() : ()
        async let history: () = doHistory ? refreshACARSHistory() : ()
        async let alerts: () = doAlerts ? refreshACARSAlerts() : ()
        _ = await (acars, history, alerts)
    }

    private func tickIntelligence(_ now: Date) async {
        await tickADSB(forceVisible: true)
        await tickADSBExtras(now)
        await tickSystem(now)
        await tickWeather(now)
        await tickSatellite(now)
        await tickACARS(now)
    }

    // MARK: - Helpers

    private func shouldRefresh(last: Date?, interval: TimeInterval, now: Date) -> Bool {
        if let last, now.timeIntervalSince(last) < interval {
            return false
        }
        return true
    }

    // MARK: - ADS-B

    func refreshADSB(includeSummary: Bool = true, includeAircraft: Bool = true) async {
        guard includeSummary || includeAircraft else { return }
        guard !adsbLoading else { return }
        adsbLoading = true
        defer { adsbLoading = false }

        let summaryTask = includeSummary ? Task { try await api.fetchADSBSummary() } : nil
        let localTask = includeAircraft ? Task { try await api.fetchAircraftList(limit: 100) } : nil

        var summaryResult: Result<ADSBSummary, Error>?
        var localResult: Result<AircraftList, Error>?

        if let summaryTask {
            do {
                summaryResult = .success(try await summaryTask.value)
            } catch {
                summaryResult = .failure(error)
            }
        }

        if let localTask {
            do {
                localResult = .success(try await localTask.value)
            } catch {
                localResult = .failure(error)
            }
        }

        var finalAircraftList = self.aircraftList

        if includeAircraft {
            switch localResult {
            case .success(let localAircraft):
                let localItems = localAircraft.items.map { normalizeAircraftForDisplay($0) }
                let merged = mergeADSBAircraft(localItems: localItems)

                self.localAircraftCount = localItems.count
                finalAircraftList = merged
                if self.aircraftList != merged {
                    self.aircraftList = merged
                }

                if !isOpenSkyEnabled, let currentSummary = self.adsbSummary {
                    let updatedSummary = overlayAircraftMetrics(
                        on: currentSummary,
                        using: merged,
                        preserveServerTotals: true
                    )
                    if updatedSummary != currentSummary {
                        self.adsbSummary = updatedSummary
                        WidgetDataManager.shared.updateADSB(
                            total: updatedSummary.totalNow,
                            withPos: updatedSummary.withPos
                        )
                    }
                }
            case .failure:
                finalAircraftList = self.aircraftList
            case .none:
                break
            }
        }

        if case .success(let summary) = summaryResult {
            let resolvedSummary =
                isOpenSkyEnabled
                ? overlayAircraftMetrics(
                    on: summary, using: finalAircraftList, preserveServerTotals: false)
                : summary

            if self.adsbSummary != resolvedSummary {
                self.adsbSummary = resolvedSummary
                WidgetDataManager.shared.updateADSB(
                    total: resolvedSummary.totalNow,
                    withPos: resolvedSummary.withPos
                )
            }
        } else if includeAircraft, isOpenSkyEnabled, let currentSummary = self.adsbSummary {
            let updatedSummary = overlayAircraftMetrics(
                on: currentSummary,
                using: finalAircraftList,
                preserveServerTotals: false
            )
            if updatedSummary != currentSummary {
                self.adsbSummary = updatedSummary
                WidgetDataManager.shared.updateADSB(
                    total: updatedSummary.totalNow,
                    withPos: updatedSummary.withPos
                )
            }
        }

        var firstError: Error?
        if case .failure(let error) = summaryResult {
            firstError = error
        }
        if firstError == nil, case .failure(let error) = localResult {
            firstError = error
        }

        if self.adsbSummary != nil || !self.aircraftList.isEmpty {
            self.adsbError = nil
        } else {
            self.adsbError = firstError?.localizedDescription
        }
    }

    func refreshTuyaSensor() async {
        guard !tuyaSensorLoading else { return }
        tuyaSensorLoading = true
        defer { tuyaSensorLoading = false }

        do {
            let response = try await api.fetchTuyaTemperatureHumidity()

            if self.tuyaSensor != response {
                self.tuyaSensor = response
            }

            self.tuyaSensorError = response.friendlyErrorMessage
        } catch {
            if tuyaSensor == nil {
                self.tuyaSensorError = error.localizedDescription
            }
        }
    }

    /// OpenSky roda em background separado — nunca bloqueia o refresh rápido do ADSB local.
    private var cachedOpenSkyItems: [Aircraft] = []

    private func refreshOpenSkyBackground() async {
        var box: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? = nil

        if let rBox = radarBoundingBox, rBox.count == 4 {
            box = (minLat: rBox[0], maxLat: rBox[1], minLon: rBox[2], maxLon: rBox[3])
        } else if let loc = LocationManager.shared.userLocation?.coordinate {
            let delta = 5.0
            box = (
                minLat: loc.latitude - delta, maxLat: loc.latitude + delta,
                minLon: loc.longitude - delta, maxLon: loc.longitude + delta
            )
        } else {
            let lat = -20.5386
            let lon = -47.4008
            let delta = 5.0
            box = (
                minLat: lat - delta, maxLat: lat + delta,
                minLon: lon - delta, maxLon: lon + delta
            )
        }

        do {
            let states = try await openSkyService.fetchStates(boundingBox: box)
            self.cachedOpenSkyItems = states
            self.openskyAircraftCount = states.count
        } catch {
            // Mantém o cache anterior em caso de erro
        }
    }

    private func normalizeAircraftForDisplay(_ aircraft: Aircraft) -> Aircraft {
        var modified = aircraft.with(source: .local, dualTracked: false)
        if modified.registration == nil || modified.registration?.isEmpty == true,
            let cachedReg = self.registrationCache[modified.callsign]
        {
            modified.registration = cachedReg
        }
        if let manualAirline = manualAirlineOverride(for: modified) {
            modified.airline = manualAirline
        }
        return modified
    }

    private func mergeADSBAircraft(localItems: [Aircraft]) -> [Aircraft] {
        var openSkyItems: [Aircraft] = []
        if isOpenSkyEnabled {
            openSkyItems = self.cachedOpenSkyItems
            let openSkyInterval: TimeInterval = 10.0
            if shouldRefresh(last: lastOpenSkyRefresh, interval: openSkyInterval, now: Date()) {
                self.lastOpenSkyRefresh = Date()
                Task { [weak self] in
                    await self?.refreshOpenSkyBackground()
                }
            }
        } else {
            self.openskyAircraftCount = 0
        }

        var mergedMap: [String: Aircraft] = [:]
        for ac in localItems {
            mergedMap[ac.id] = ac
        }
        for ac in openSkyItems {
            if let existing = mergedMap[ac.id] {
                mergedMap[ac.id] = existing.with(source: .local, dualTracked: true)
            } else {
                mergedMap[ac.id] = ac
            }
        }
        return Array(mergedMap.values)
    }

    private func overlayAircraftMetrics(
        on summary: ADSBSummary,
        using aircraft: [Aircraft],
        preserveServerTotals: Bool
    ) -> ADSBSummary {
        guard !aircraft.isEmpty else { return summary }

        let total = preserveServerTotals ? summary.totalNow : aircraft.count
        let climbing = aircraft.filter { $0.verticalRateFpm > 256 }.count
        let descending = aircraft.filter { $0.verticalRateFpm < -256 }.count
        let cruising = max(0, aircraft.count - climbing - descending)

        return ADSBSummary(
            timestamp: summary.timestamp,
            totalNow: total,
            withPos: aircraft.filter { $0.hasPosition }.count,
            above10000: aircraft.filter { $0.altitudeFt > 10000 }.count,
            nonCivilNow: summary.nonCivilNow,
            movement: Movement(climbing: climbing, descending: descending, cruising: cruising),
            averages: summary.averages,
            highlights: summary.highlights,
            airlines: summary.airlines,
            topModels: summary.topModels,
            stats24h: summary.stats24h
        )
    }

    // MARK: - System

    func refreshSystem() async {
        guard !systemLoading else { return }
        systemLoading = true
        defer { systemLoading = false }
        do {
            let status = try await api.fetchSystemStatus()

            if self.systemStatus != status {
                self.systemStatus = status
                WidgetDataManager.shared.updateSystem(
                    cpu: status.cpu?.usagePercent ?? 0,
                    memory: status.memory?.usedPercent ?? 0,
                    disk: status.disk?.usedPercent ?? 0
                )
            }
            self.systemError = nil
        } catch {
            if systemStatus == nil {
                self.systemError = error.localizedDescription
            }
        }
    }

    // MARK: - Fire Stick

    func refreshFirestick() async {
        guard !firestickLoading else { return }
        firestickLoading = true
        defer { firestickLoading = false }

        do {
            let devicesResp = try await api.fetchFirestickDevices()
            let devices = devicesResp.devices

            let statuses: [FirestickDeviceStatus] = try await withThrowingTaskGroup(
                of: FirestickDeviceStatus.self
            ) { group in
                for dev in devices {
                    group.addTask {
                        let st = try await APIService.shared.fetchFirestickStatus(
                            id: dev.id, force: false)
                        return FirestickDeviceStatus(device: dev, status: st)
                    }
                }

                var out: [FirestickDeviceStatus] = []
                out.reserveCapacity(devices.count)
                for try await item in group {
                    out.append(item)
                }
                return out
            }

            let sorted = statuses.sorted { a, b in
                a.device.name.localizedCaseInsensitiveCompare(b.device.name) == .orderedAscending
            }

            if self.firestickDeviceStatuses != sorted {
                self.firestickDeviceStatuses = sorted
            }
            self.firestickError = nil
        } catch {
            self.firestickError = error.localizedDescription
        }
    }

    // MARK: - Radio

    func refreshRadio() async {
        guard !radioLoading else { return }
        radioLoading = true
        defer { radioLoading = false }
        do {
            // Tenta resolver localmente para reduzir latência e dependência do backend
            let playing: NowPlaying
            if let local = try? await LocalNowPlayingFetcher.fetch() {
                playing = local
            } else {
                playing = try await api.fetchNowPlaying()
            }

            if self.nowPlaying != playing {
                self.nowPlaying = playing
                // Update Now Playing in Control Center
                AudioPlayer.shared.updateNowPlayingInfo(track: playing)

                // Update Widget
                // Update Widget
                WidgetDataManager.shared.updateRadio(
                    frequency: "Ao Vivo",
                    description: playing.displayTitle,
                    signal: 100
                )
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
        guard !weatherLoading else { return }
        weatherLoading = true
        defer { weatherLoading = false }

        do {
            var data: WeatherData
            let fallbackCoordinate = LocationManager.receiverLocation.coordinate

            // Check for user location
            if LocationManager.shared.isAuthorized, let loc = LocationManager.shared.userLocation {
                // Prefer native WeatherKit; fallback to backend and then Open-Meteo.
                #if canImport(WeatherKit)
                    if #available(iOS 16.0, *) {
                        do {
                            data = try await fetchWeatherKitWeatherData(location: loc)
                        } catch {
                            do {
                                data = try await api.fetchWeather(
                                    lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                            } catch {
                                data = try await api.fetchWeatherOpenMeteo(
                                    lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                            }
                        }
                    } else {
                        do {
                            data = try await api.fetchWeather(
                                lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                        } catch {
                            data = try await api.fetchWeatherOpenMeteo(
                                lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                        }
                    }
                #else
                    do {
                        data = try await api.fetchWeather(
                            lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                    } catch {
                        data = try await api.fetchWeatherOpenMeteo(
                            lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                    }
                #endif

                // Try reverse geocoding for city name (optional enhancement)
                // For now, it uses coordinates string from APIService
                data = try await enrichWeatherForecastIfNeeded(
                    data,
                    lat: loc.coordinate.latitude,
                    lon: loc.coordinate.longitude
                )
            } else {
                // Fallback to Lab API (Franca, SP)
                let baseWeather = try await api.fetchWeather()
                data = try await enrichWeatherForecastIfNeeded(
                    baseWeather,
                    lat: fallbackCoordinate.latitude,
                    lon: fallbackCoordinate.longitude
                )
            }

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

    private func enrichWeatherForecastIfNeeded(_ data: WeatherData, lat: Double, lon: Double)
        async throws -> WeatherData
    {
        let needsForecast = data.forecast.count < 10
        let needsHourly = (data.hourly?.isEmpty ?? true)
        let needsDetails =
            data.today.description == nil
            || data.forecast.contains {
                $0.description == nil || $0.sunrise == nil || $0.sunset == nil
            }

        guard needsForecast || needsHourly || needsDetails else { return data }

        let enriched = try await api.fetchWeatherOpenMeteo(lat: lat, lon: lon)
        return WeatherData(
            timestamp: data.timestamp,
            location: data.location,
            current: CurrentWeather(
                tempC: data.current.tempC,
                feelsLikeC: data.current.feelsLikeC,
                humidity: data.current.humidity,
                windKmh: data.current.windKmh,
                windDir: data.current.windDir,
                description: data.current.description,
                precipMm: data.current.precipMm,
                uvIndex: data.current.uvIndex,
                weatherCode: data.current.weatherCode ?? enriched.current.weatherCode,
                isDaylight: data.current.isDaylight ?? enriched.current.isDaylight
            ),
            today: TodayWeather(
                maxTempC: data.today.maxTempC,
                minTempC: data.today.minTempC,
                rainChance: data.today.rainChance,
                rainMm: data.today.rainMm,
                uvIndex: data.today.uvIndex,
                description: data.today.description ?? enriched.today.description,
                sunrise: data.today.sunrise ?? enriched.today.sunrise,
                sunset: data.today.sunset ?? enriched.today.sunset
            ),
            forecast: mergedForecastDays(primary: data.forecast, fallback: enriched.forecast),
            hourly: needsHourly ? enriched.hourly : data.hourly
        )
    }

    private func mergedForecastDays(primary: [ForecastDay], fallback: [ForecastDay]) -> [ForecastDay] {
        if primary.count < 10 {
            return fallback
        }

        let fallbackByDate = Dictionary(uniqueKeysWithValues: fallback.map { ($0.date, $0) })
        return primary.map { day in
            guard let fallback = fallbackByDate[day.date] else { return day }
            return ForecastDay(
                date: day.date,
                maxTempC: day.maxTempC,
                minTempC: day.minTempC,
                rainChance: day.rainChance,
                rainMm: day.rainMm,
                uvIndex: day.uvIndex,
                description: day.description ?? fallback.description,
                sunrise: day.sunrise ?? fallback.sunrise,
                sunset: day.sunset ?? fallback.sunset
            )
        }
    }

    #if canImport(WeatherKit)
        @available(iOS 16.0, *)
        private func fetchWeatherKitWeatherData(location: CLLocation) async throws -> WeatherData {
            let service = WeatherService.shared
            let weather = try await service.weather(for: location)

            let current = weather.currentWeather
            let daily = weather.dailyForecast

            let currentWeather = CurrentWeather(
                tempC: Int(round(current.temperature.converted(to: UnitTemperature.celsius).value)),
                feelsLikeC: Int(
                    round(current.apparentTemperature.converted(to: UnitTemperature.celsius).value)),
                humidity: Int(round(current.humidity * 100.0)),
                windKmh: Int(
                    round(current.wind.speed.converted(to: UnitSpeed.kilometersPerHour).value)),
                windDir: LocationManager.compassDirection(
                    from: current.wind.direction.converted(to: UnitAngle.degrees).value),
                description: weatherKitConditionPT(current.condition),
                // WeatherKit exposes precipitation intensity with a unit not representable by Foundation's UnitSpeed.
                // Keep it as a best-effort scalar (typically mm/h) to fit the existing model.
                precipMm: current.precipitationIntensity.value,
                uvIndex: Int(current.uvIndex.value)
            )

            let today = daily.forecast.first
            let todayWeather = TodayWeather(
                maxTempC: Int(
                    round(
                        today?.highTemperature.converted(to: UnitTemperature.celsius).value
                            ?? Double(currentWeather.tempC))),
                minTempC: Int(
                    round(
                        today?.lowTemperature.converted(to: UnitTemperature.celsius).value
                            ?? Double(currentWeather.tempC))),
                rainChance: Int(round((today?.precipitationChance ?? 0) * 100.0)),
                rainMm: today?.precipitationAmountByType.precipitation.converted(to: .millimeters)
                    .value ?? 0,
                uvIndex: Int(today?.uvIndex.value ?? current.uvIndex.value)
            )

            var forecast: [ForecastDay] = []
            for day in daily.forecast.dropFirst().prefix(10) {
                forecast.append(
                    ForecastDay(
                        date: isoDay(day.date),
                        maxTempC: Int(
                            round(day.highTemperature.converted(to: UnitTemperature.celsius).value)),
                        minTempC: Int(
                            round(day.lowTemperature.converted(to: UnitTemperature.celsius).value)),
                        rainChance: Int(round(day.precipitationChance * 100.0)),
                        rainMm: day.precipitationAmountByType.precipitation.converted(
                            to: .millimeters
                        ).value,
                        uvIndex: Int(day.uvIndex.value)
                    )
                )
            }

            return WeatherData(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                location: String(
                    format: "%.4f, %.4f", location.coordinate.latitude,
                    location.coordinate.longitude),
                current: currentWeather,
                today: todayWeather,
                forecast: forecast
            )
        }

        @available(iOS 16.0, *)
        private func weatherKitConditionPT(_ condition: WeatherCondition) -> String {
            switch condition {
            case .clear: return "Céu limpo"
            case .mostlyClear: return "Quase limpo"
            case .partlyCloudy: return "Parcialmente nublado"
            case .mostlyCloudy: return "Muito nublado"
            case .cloudy: return "Nublado"
            case .foggy: return "Nevoeiro"
            case .haze: return "Neblina"
            case .windy: return "Vento"
            case .drizzle: return "Garoa"
            case .rain: return "Chuva"
            case .heavyRain: return "Chuva forte"
            case .thunderstorms: return "Trovoadas"
            case .hail: return "Granizo"
            case .sleet: return "Aguaneve"
            case .snow: return "Neve"
            case .heavySnow: return "Neve forte"
            case .blizzard: return "Nevasca"
            default: return "Tempo"
            }
        }
    #endif

    private func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Satellite

    func refreshSatellite() async {
        guard !satelliteLoading else { return }
        satelliteLoading = true
        defer { satelliteLoading = false }
        do {
            // 1. Fetch past images/passes (existing logic)
            async let imagesTask = api.fetchLastImages()
            async let passesTask = api.fetchPasses()

            let (images, passesList) = try await (imagesTask, passesTask)

            if self.lastImages != images {
                self.lastImages = images
            }

            let newPasses = passesList.passes.map { $0.toSatellitePass }
            if self.passes != newPasses {
                self.passes = newPasses
            }

            // 2. Fetch predictions for Widget (New logic)
            await SatellitePassPredictor.shared.fetchAndPredict()
            if let next = SatellitePassPredictor.shared.predictedPasses.first {
                WidgetDataManager.shared.updateSatellite(
                    name: next.safeSatelliteName,
                    nextPass: next.formattedAOSbrt,
                    elevation: "\(Int(next.maxElevation))°"
                )
            }

            self.satelliteError = nil
        } catch {
            if lastImages == nil {
                self.satelliteError = error.localizedDescription
            }
        }
    }

    // MARK: - SatDump Status

    func refreshSatDumpStatus() async {
        do {
            let result = try await api.fetchSatDumpStatus()
            if self.satDumpStatus != result.status {
                self.satDumpStatus = result.status
            }
            self.satDumpError = nil
        } catch {
            if satDumpStatus == nil {
                self.satDumpError = error.localizedDescription
            }
        }
    }

    // MARK: - Registration Cache
    private var registrationCache: [String: String] = [:]

    // MARK: - Manual Airline Overrides

    func saveManualAirlineOverride(_ airlineName: String, for aircraft: Aircraft) {
        let cleaned = airlineName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        let keys = airlineOverrideKeys(for: aircraft)
        guard !keys.isEmpty else { return }

        for key in keys {
            manualAirlineOverrides[key] = cleaned
        }
        persistManualAirlineOverrides()

        // Reflect immediately in list to update UI sections (including "Companhias Aéreas")
        aircraftList = aircraftList.map { item in
            var updated = item
            if hasAnyMatchingAirlineOverrideKey(between: aircraft, and: item) {
                updated.airline = cleaned
            }
            return updated
        }
    }

    func manualAirlineOverride(for aircraft: Aircraft) -> String? {
        for key in airlineOverrideKeys(for: aircraft) {
            if let value = manualAirlineOverrides[key], !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func airlineOverrideKeys(for aircraft: Aircraft) -> [String] {
        var keys: [String] = []

        if let hex = normalizedLookupToken(aircraft.hex) {
            keys.append("hex:\(hex)")
        }
        if let reg = normalizedLookupToken(aircraft.registration) {
            keys.append("reg:\(reg)")
        }
        if let callsign = normalizedLookupToken(aircraft.callsign) {
            keys.append("callsign:\(callsign)")
        }

        return keys
    }

    private func hasAnyMatchingAirlineOverrideKey(between lhs: Aircraft, and rhs: Aircraft) -> Bool
    {
        let left = Set(airlineOverrideKeys(for: lhs))
        let right = Set(airlineOverrideKeys(for: rhs))
        return !left.isDisjoint(with: right)
    }

    private func normalizedLookupToken(_ value: String?) -> String? {
        guard
            let token = value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased(),
            !token.isEmpty
        else {
            return nil
        }
        return token
    }

    private func loadManualAirlineOverrides() {
        guard let data = UserDefaults.standard.data(forKey: manualAirlineOverridesDefaultsKey)
        else {
            return
        }
        if let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            manualAirlineOverrides = decoded
            rebuildADSBViewCache()
        }
    }

    private func persistManualAirlineOverrides() {
        if let data = try? JSONEncoder().encode(manualAirlineOverrides) {
            UserDefaults.standard.set(data, forKey: manualAirlineOverridesDefaultsKey)
        }
        rebuildADSBViewCache()
    }

    private func rebuildADSBViewCache() {
        if !aircraftList.isEmpty {
            var grouped: [String: (displayName: String, count: Int)] = [:]

            for aircraft in aircraftList {
                let effectiveName = manualAirlineOverride(for: aircraft) ?? aircraft.airline
                guard let cleaned = normalizedAirlineDisplayName(effectiveName) else { continue }
                let key = cleaned.folding(
                    options: [.diacriticInsensitive, .caseInsensitive], locale: .current
                ).uppercased()

                if var current = grouped[key] {
                    current.count += 1
                    grouped[key] = current
                } else {
                    grouped[key] = (displayName: cleaned, count: 1)
                }
            }

            adsbAirlines = grouped.values
                .map { Airline(name: $0.displayName, count: $0.count) }
                .sorted {
                    if $0.count == $1.count {
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    return $0.count > $1.count
                }
        } else {
            adsbAirlines = adsbSummary?.airlines ?? []
        }

        adsbNearbyAircraftPreview =
            aircraftList
            .filter { $0.computedDistanceNm < 100000 }
            .sorted { $0.computedDistanceNm < $1.computedDistanceNm }
            .prefix(5)
            .map { $0 }
    }

    private func normalizedAirlineDisplayName(_ value: String?) -> String? {
        guard let cleaned = value?.trimmingCharacters(in: .whitespacesAndNewlines), !cleaned.isEmpty
        else {
            return nil
        }
        return cleaned
    }

    // MARK: - ACARS

    func refreshACARS() async {
        guard !acarsLoading else {
            print("[ACARS] ⏭️ Skipping refresh - already loading")
            return
        }
        acarsLoading = true
        defer { acarsLoading = false }

        print("[ACARS] 🔄 Starting refresh...")

        do {
            print("[ACARS] 📡 Fetching summary...")
            let summary = try await api.fetchACARSSummary()
            print("[ACARS] ✅ Summary received: \(summary.today.messages) messages today")

            print("[ACARS] 📡 Fetching messages...")
            let messageList = try await api.fetchACARSMessages(limit: 20)
            print("[ACARS] ✅ Messages received: \(messageList.messages.count) messages")

            // Populate registration cache from ACARS
            var newRegistrations = 0
            for msg in messageList.messages {
                if let flight = msg.flight, !flight.isEmpty,
                    let tail = msg.tail, !tail.isEmpty
                {
                    if registrationCache[flight] == nil {
                        registrationCache[flight] = tail
                        newRegistrations += 1
                    }
                }
            }
            if newRegistrations > 0 {
                print("[ACARS] 💾 Cached \(newRegistrations) new registrations from ACARS")
            }

            print("[ACARS] 📡 Fetching hourly stats...")
            let hourly = try await api.fetchACARSHourly()
            print("[ACARS] ✅ Hourly stats received: \(hourly.hours.count) hours")

            if self.acarsSummary != summary {
                print("[ACARS] 📝 Updating summary (changed)")
                self.acarsSummary = summary
            } else {
                print("[ACARS] ⏭️ Summary unchanged, skipping update")
            }

            let newMessages = messageList.messages
            if self.acarsMessages != newMessages {
                print("[ACARS] 📝 Updating messages: \(newMessages.count) messages")
                if let first = newMessages.first {
                    print(
                        "[ACARS]   First message: \(first.flight ?? "N/A") - \(first.label ?? "N/A")"
                    )
                }
                self.acarsMessages = newMessages

                if let msg = newMessages.first {
                    WidgetDataManager.shared.updateACARS(
                        lastMessage: msg.text ?? msg.labelDesc ?? "Mensagem Recebida",
                        total: self.acarsSummary?.today.messages ?? 0,
                        time: msg.time
                    )
                }
            } else {
                print("[ACARS] ⏭️ Messages unchanged, skipping update")
            }

            let newHourly = hourly.hours
            if self.acarsHourly != newHourly {
                print("[ACARS] 📝 Updating hourly stats: \(newHourly.count) hours")
                self.acarsHourly = newHourly
            } else {
                print("[ACARS] ⏭️ Hourly stats unchanged, skipping update")
            }

            self.acarsError = nil
            print("[ACARS] ✅ Refresh completed successfully")
        } catch {
            print("[ACARS] ❌ Error during refresh: \(error.localizedDescription)")
            if let apiError = error as? APIError {
                print("[ACARS]   API Error details: \(apiError)")
            }
            if acarsSummary == nil {
                print("[ACARS] 📝 Setting error message (no previous data)")
                self.acarsError = error.localizedDescription
            } else {
                print("[ACARS] ⏭️ Keeping previous data despite error")
            }
        }
    }

    func refreshACARSHistory() async {
        do {
            let history = try await api.fetchACARSHistory()
            if self.acarsHistory != history {
                self.acarsHistory = history
            }
        } catch {
            // Keep previous data if available
        }
    }

    func refreshACARSAlerts() async {
        do {
            let alerts = try await api.fetchACARSAlerts()
            if self.acarsAlerts != alerts.alerts {
                self.acarsAlerts = alerts.alerts
            }
        } catch {
            // Keep previous data if available
        }
    }

    // MARK: - System Extras

    func refreshProcesses() async {
        do {
            let list = try await api.fetchProcesses(limit: 5)
            if self.processes != list.items {
                self.processes = list.items
            }
        } catch {
            if processes.isEmpty {
                self.systemExtrasError = error.localizedDescription
            }
        }
    }

    func refreshPartitions() async {
        do {
            let list = try await api.fetchPartitions()
            if self.partitions != list.partitions {
                self.partitions = list.partitions
            }
        } catch {
            if partitions.isEmpty {
                self.systemExtrasError = error.localizedDescription
            }
        }
    }

    func refreshNetwork() async {
        do {
            let list = try await api.fetchNetworkStats()
            if self.networkInterfaces != list.interfaces {
                self.networkInterfaces = list.interfaces
            }
        } catch {
            if networkInterfaces.isEmpty {
                self.systemExtrasError = error.localizedDescription
            }
        }
    }

    // MARK: - Docker

    func refreshDockerStatus() async {
        do {
            let status = try await api.fetchDockerStatus(health: true)
            if self.dockerContainers != status.containers {
                self.dockerContainers = status.containers
            }
            self.dockerError = nil
        } catch {
            if dockerContainers.isEmpty {
                self.dockerError = error.localizedDescription
            }
        }
    }

    func refreshDockerVersion() async {
        do {
            let version = try await api.fetchDockerVersion()
            if self.dockerVersion != version {
                self.dockerVersion = version
            }
        } catch {
            if dockerVersion == nil {
                self.dockerError = error.localizedDescription
            }
        }
    }

    // MARK: - Systemd

    func refreshSystemd() async {
        do {
            let status = try await api.fetchSystemdStatus()
            if self.systemdServices != status.services {
                self.systemdServices = status.services
            }
            self.systemdError = nil
        } catch {
            if systemdServices.isEmpty {
                self.systemdError = error.localizedDescription
            }
        }
    }

    // MARK: - ADSB History/Alerts

    func refreshADSBHistory() async {
        do {
            let history = try await api.fetchADSBHistory()
            if self.adsbHistory != history {
                self.adsbHistory = history
            }
        } catch {
            if adsbHistory == nil {
                self.adsbHistoryError = error.localizedDescription
            }
        }
    }

    func refreshADSBAlerts() async {
        do {
            let alerts = try await api.fetchADSBAlerts()
            if self.adsbAlerts != alerts.alerts {
                self.adsbAlerts = alerts.alerts
            }
        } catch {
            if adsbAlerts.isEmpty {
                self.adsbHistoryError = error.localizedDescription
            }
        }
    }

    // MARK: - Metrics

    func refreshMetrics() async {
        do {
            let metrics = try await api.fetchMetrics()
            if self.metrics != metrics {
                self.metrics = metrics
            }
        } catch {
            if self.metrics == nil {
                self.metricsError = error.localizedDescription
            }
        }
    }

    // MARK: - Manual Refresh (for pull-to-refresh)

    func forceRefresh() async {
        await refreshActiveTabNow(force: true)
    }

    private func refreshActiveTabNow(force: Bool) async {
        let active = activeTabRawValue

        if force {
            switch active {
            case "adsb", "map":
                lastADSBSummaryRefresh = nil
                lastADSBListRefresh = nil
                lastADSBHistoryRefresh = nil
                lastADSBAlertsRefresh = nil
                lastTuyaSensorRefresh = nil
                lastMetricsRefresh = nil
                adsbInFlight = false

            case "system", "infra":
                lastSystemRefresh = nil
                lastFirestickRefresh = nil
                lastProcessesRefresh = nil
                lastPartitionsRefresh = nil
                lastNetworkRefresh = nil
                lastDockerStatusRefresh = nil
                lastDockerVersionRefresh = nil
                lastSystemdRefresh = nil
                lastSatDumpStatusRefresh = nil
                lastMetricsRefresh = nil
                systemInFlight = false

            case "radio":
                lastRadioRefresh = nil
                radioInFlight = false

            case "weather":
                lastWeatherRefresh = nil
                weatherInFlight = false

            case "satellite":
                lastSatelliteRefresh = nil
                satelliteInFlight = false

            case "acars":
                lastACARSRefresh = nil
                lastACARSHistoryRefresh = nil
                lastACARSAlertsRefresh = nil
                acarsInFlight = false

            case "intelligence":
                lastADSBSummaryRefresh = nil
                lastADSBListRefresh = nil
                lastADSBHistoryRefresh = nil
                lastADSBAlertsRefresh = nil
                lastTuyaSensorRefresh = nil
                lastMetricsRefresh = nil
                lastSystemRefresh = nil
                lastFirestickRefresh = nil
                lastProcessesRefresh = nil
                lastPartitionsRefresh = nil
                lastNetworkRefresh = nil
                lastDockerStatusRefresh = nil
                lastDockerVersionRefresh = nil
                lastSystemdRefresh = nil
                lastSatDumpStatusRefresh = nil
                lastWeatherRefresh = nil
                lastSatelliteRefresh = nil
                lastACARSRefresh = nil
                lastACARSHistoryRefresh = nil
                lastACARSAlertsRefresh = nil
                adsbInFlight = false
                systemInFlight = false
                weatherInFlight = false
                satelliteInFlight = false
                acarsInFlight = false

            default:
                break
            }
        }

        let now = Date()
        switch active {
        case "adsb", "map":
            await tickADSB()
            await tickADSBExtras(now)

        case "system", "infra":
            await tickSystem(now)

        case "radio":
            await tickRadio(now)

        case "weather":
            await tickWeather(now)

        case "satellite":
            await tickSatellite(now)

        case "acars":
            await tickACARS(now)

        case "intelligence":
            await tickIntelligence(now)

        default:
            break
        }
    }
}

struct LabIntelligenceSnapshot {
    let aircraft: [Aircraft]
    let adsbSummary: ADSBSummary?
    let system: SystemStatus?
    let weather: WeatherData?
    let lastImages: LastImages?
    let passes: [SatellitePass]
    let acarsSummary: ACARSSummary?
    let acarsMessages: [ACARSMessage]
    let adsbAlerts: [ADSBAlert]
    let acarsAlerts: [ACARSAlert]
    let adsbHistory: ADSBHistoryResponse?
    let acarsHistory: ACARSHistoryResponse?
    let metrics: MetricsResponse?
    let firestickStatuses: [FirestickDeviceStatus]
    let processes: [ProcessItem]
    let partitions: [Partition]
    let networkInterfaces: [NetworkInterface]
    let dockerVersion: DockerVersionResponse?
    let dockerContainers: [DockerContainer]
    let systemdServices: [SystemdService]
    let satDumpStatus: SatDumpStatus?
    let nowPlaying: NowPlaying?

    @MainActor
    init(state: AppState) {
        aircraft = state.aircraftList
        adsbSummary = state.adsbSummary
        system = state.systemStatus
        weather = state.weather
        lastImages = state.lastImages
        passes = state.passes
        acarsSummary = state.acarsSummary
        acarsMessages = state.acarsMessages
        adsbAlerts = state.adsbAlerts
        acarsAlerts = state.acarsAlerts
        adsbHistory = state.adsbHistory
        acarsHistory = state.acarsHistory
        metrics = state.metrics
        firestickStatuses = state.firestickDeviceStatuses
        processes = state.processes
        partitions = state.partitions
        networkInterfaces = state.networkInterfaces
        dockerVersion = state.dockerVersion
        dockerContainers = state.dockerContainers
        systemdServices = state.systemdServices
        satDumpStatus = state.satDumpStatus
        nowPlaying = state.nowPlaying
    }
}

struct LabSearchResult: Identifiable, Equatable {
    let id: String
    let category: String
    let title: String
    let subtitle: String
    let score: Int
}

struct LabTimelineEvent: Identifiable, Equatable {
    let id: String
    let timeLabel: String
    let category: String
    let title: String
    let detail: String
}

struct LabPlaybookSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let targetTab: String
}

struct DataQualityItem: Identifiable, Equatable {
    let id: String
    let source: String
    let status: String
    let detail: String
}

struct ComparisonInsight: Identifiable, Equatable {
    let id: String
    let metric: String
    let current: String
    let previous: String
    let delta: String
}

actor LabIntelligenceService {
    static let shared = LabIntelligenceService()

    func briefing(from snapshot: LabIntelligenceSnapshot) -> String {
        let total = snapshot.adsbSummary?.totalNow ?? snapshot.aircraft.count
        let withPos =
            snapshot.adsbSummary?.withPos
            ?? snapshot.aircraft.filter { $0.lat != nil && $0.lon != nil }.count
        let fastest = snapshot.aircraft.max(by: { $0.speedKt < $1.speedKt })
        let closest = snapshot.aircraft.compactMap { ac -> Aircraft? in
            guard ac.distanceNm != nil else { return nil }
            return ac
        }.min(by: {
            ($0.distanceNm ?? .greatestFiniteMagnitude)
                < ($1.distanceNm ?? .greatestFiniteMagnitude)
        })

        let cpu = Int(snapshot.system?.cpu?.usagePercent ?? 0)
        let mem = Int(snapshot.system?.memory?.usedPercent ?? 0)
        let temp = snapshot.system?.cpu?.temperatureC.map { String(format: "%.0f", $0) } ?? "-"
        let lastPass =
            snapshot.lastImages.map {
                "\($0.images.count) imagens em \(compactPassName($0.passName))"
            } ?? "sem passe recente"
        let acarsToday = snapshot.acarsSummary?.today.messages ?? snapshot.acarsMessages.count
        let weatherLine: String
        if let weather = snapshot.weather {
            weatherLine =
                "Clima: \(weather.current.tempC)°C • \(weather.current.description.lowercased()) • chuva \(weather.current.precipMm.formattedBR(decimals: 1)) mm."
        } else {
            weatherLine = "Clima: leitura indisponível no momento."
        }

        var lines: [String] = []
        lines.append("Radar: \(total) aeronaves (\(withPos) com posição).")
        if let fastest {
            lines.append("Mais rápida: \(fastest.displayCallsign) a \(fastest.speedKt) kt.")
        }
        if let closest, let d = closest.distanceNm {
            lines.append(
                "Mais próxima: \(closest.displayCallsign) a \(String(format: "%.1f", d)) nm.")
        }
        lines.append("Satélite: \(lastPass).")
        lines.append("ACARS hoje: \(acarsToday) mensagens.")
        lines.append("Sistema: CPU \(cpu)% • RAM \(mem)% • Temp \(temp)°C.")
        lines.append(weatherLine)
        return lines.joined(separator: "\n")
    }

    func summarizeAlerts(from snapshot: LabIntelligenceSnapshot) -> String {
        let adsbCount = snapshot.adsbAlerts.count
        let acarsCount = snapshot.acarsAlerts.count
        if adsbCount == 0 && acarsCount == 0 {
            return "Sem alertas recentes de ADS-B ou ACARS."
        }

        var lines: [String] = []
        lines.append("Alertas recentes: ADS-B \(adsbCount) • ACARS \(acarsCount).")
        if let latestADSB = snapshot.adsbAlerts.first {
            let ref = latestADSB.callsign ?? latestADSB.registration ?? latestADSB.aircraft
            lines.append("Último ADS-B: \(ref) em \(latestADSB.timestamp).")
        }
        if let latestACARS = snapshot.acarsAlerts.first {
            let ts = latestACARS.timestamp.toDisplayHHMM() ?? "-"
            lines.append("Último ACARS: \(latestACARS.id) às \(ts).")
        }
        return lines.joined(separator: "\n")
    }

    func ask(_ query: String, snapshot: LabIntelligenceSnapshot) -> String {
        let q = normalizeIntelligence(query)
        if q.isEmpty { return briefing(from: snapshot) }
        if q.contains("briefing") || q.contains("resumo") || q.contains("status geral") {
            return briefing(from: snapshot)
        }
        if q.contains("alerta") {
            return summarizeAlerts(from: snapshot)
        }
        if q.contains("proxim") || q.contains("perto") {
            if let ac = snapshot.aircraft.compactMap({ $0.distanceNm != nil ? $0 : nil })
                .min(by: {
                    ($0.distanceNm ?? .greatestFiniteMagnitude)
                        < ($1.distanceNm ?? .greatestFiniteMagnitude)
                }),
                let d = ac.distanceNm
            {
                return
                    "Aeronave mais próxima: \(ac.displayCallsign) a \(String(format: "%.1f", d)) nm."
            }
            return "Nenhuma aeronave com distância disponível no momento."
        }
        if q.contains("rapida") || q.contains("rápid") || q.contains("veloc") {
            if let ac = snapshot.aircraft.max(by: { $0.speedKt < $1.speedKt }) {
                return
                    "Aeronave mais rápida: \(ac.displayCallsign) a \(ac.speedKt) kt (\(ac.speedKmh) km/h)."
            }
            return "Não encontrei velocidade de aeronaves agora."
        }
        if q.contains("satel") || q.contains("meteor") || q.contains("passe") {
            if let last = snapshot.lastImages {
                return
                    "Último passe: \(compactPassName(last.passName)) com \(last.images.count) imagens."
            }
            return "Sem passe de satélite recente no momento."
        }
        if q.contains("cpu") || q.contains("ram") || q.contains("sistema")
            || q.contains("temperatura")
        {
            let cpu = Int(snapshot.system?.cpu?.usagePercent ?? 0)
            let mem = Int(snapshot.system?.memory?.usedPercent ?? 0)
            let temp = snapshot.system?.cpu?.temperatureC.map { String(format: "%.0f", $0) } ?? "-"
            return "Sistema agora: CPU \(cpu)% • RAM \(mem)% • Temp \(temp)°C."
        }

        let matches = semanticSearch(query: query, snapshot: snapshot, limit: 5)
        if matches.isEmpty {
            return "Não encontrei resultados relevantes para “\(query)”."
        }
        let top = matches.prefix(3).map { "• \($0.category): \($0.title)" }.joined(separator: "\n")
        return "Resultados mais próximos para “\(query)”:\n\(top)"
    }

    func semanticSearch(query: String, snapshot: LabIntelligenceSnapshot, limit: Int = 10)
        -> [LabSearchResult]
    {
        let tokens = tokenizeIntelligence(query)
        guard !tokens.isEmpty else { return [] }
        var results: [LabSearchResult] = []

        for ac in snapshot.aircraft {
            let haystack = normalizeIntelligence(
                [ac.callsign, ac.registration, ac.model, ac.hex, ac.airline].compactMap { $0 }
                    .joined(separator: " "))
            let score = scoreIntelligence(tokens, in: haystack)
            if score > 0 {
                let subtitle = [ac.registration, ac.model, ac.hex?.uppercased()].compactMap { $0 }
                    .joined(separator: " • ")
                results.append(
                    .init(
                        id: "ac_\(ac.id)",
                        category: "Aeronave",
                        title: ac.displayCallsign,
                        subtitle: subtitle.isEmpty ? "Sem metadados adicionais" : subtitle,
                        score: score
                    ))
            }
        }

        for pass in snapshot.passes {
            let haystack = normalizeIntelligence("\(pass.name) \(pass.satelliteName)")
            let score = scoreIntelligence(tokens, in: haystack)
            if score > 0 {
                results.append(
                    .init(
                        id: "pass_\(pass.id)",
                        category: "Satélite",
                        title: pass.satelliteName,
                        subtitle: compactPassName(pass.name),
                        score: score
                    ))
            }
        }

        for msg in snapshot.acarsMessages {
            let haystack = normalizeIntelligence(
                [msg.flight, msg.tail, msg.label, msg.text, msg.departure, msg.destination]
                    .compactMap { $0 }.joined(separator: " "))
            let score = scoreIntelligence(tokens, in: haystack)
            if score > 0 {
                let route = msg.displayRoute ?? "-"
                results.append(
                    .init(
                        id: "acars_\(msg.id)",
                        category: "ACARS",
                        title: msg.displayFlight,
                        subtitle: "\(msg.label ?? "-") • \(route)",
                        score: score
                    ))
            }
        }

        for alert in snapshot.adsbAlerts {
            let haystack = normalizeIntelligence(
                [alert.callsign, alert.registration, alert.model, alert.aircraft].compactMap { $0 }
                    .joined(separator: " "))
            let score = scoreIntelligence(tokens, in: haystack)
            if score > 0 {
                let title = alert.callsign ?? alert.registration ?? alert.aircraft
                results.append(
                    .init(
                        id: "adsb_alert_\(alert.id)",
                        category: "Alerta ADS-B",
                        title: title,
                        subtitle: alert.timestamp,
                        score: score
                    ))
            }
        }

        return results.sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.title < rhs.title }
            return lhs.score > rhs.score
        }
        .prefix(limit)
        .map { $0 }
    }

    func timeline(from snapshot: LabIntelligenceSnapshot, limit: Int = 14) -> [LabTimelineEvent] {
        var events: [LabTimelineEvent] = []

        for alert in snapshot.adsbAlerts {
            let title = alert.callsign ?? alert.registration ?? alert.aircraft
            events.append(
                .init(
                    id: "adsb_\(alert.id)",
                    timeLabel: compactTime(alert.timestamp),
                    category: "ADS-B",
                    title: "Alerta de tráfego",
                    detail: title
                ))
        }

        for alert in snapshot.acarsAlerts {
            events.append(
                .init(
                    id: "acars_\(alert.id)",
                    timeLabel: alert.timestamp.toDisplayHHMM() ?? "-",
                    category: "ACARS",
                    title: "Alerta de mensagem",
                    detail: alert.id
                ))
        }

        if let last = snapshot.lastImages {
            events.append(
                .init(
                    id: "sat_\(last.timestamp)",
                    timeLabel: compactTime(last.timestamp),
                    category: "Satélite",
                    title: "Último passe capturado",
                    detail: "\(last.images.count) imagens • \(compactPassName(last.passName))"
                ))
        }

        if let weather = snapshot.weather {
            events.append(
                .init(
                    id: "weather_\(weather.timestamp)",
                    timeLabel: compactTime(weather.timestamp),
                    category: "Clima",
                    title: "Leitura meteorológica",
                    detail: "\(weather.current.tempC)°C • \(weather.current.description)"
                ))
        }

        if let sys = snapshot.system {
            let cpu = Int(sys.cpu?.usagePercent ?? 0)
            let mem = Int(sys.memory?.usedPercent ?? 0)
            events.append(
                .init(
                    id: "sys_\(sys.timestamp)",
                    timeLabel: compactTime(sys.timestamp),
                    category: "Sistema",
                    title: "Snapshot de saúde",
                    detail: "CPU \(cpu)% • RAM \(mem)%"
                ))
        }

        return events.sorted { $0.timeLabel > $1.timeLabel }.prefix(limit).map { $0 }
    }

    func playbooks(from snapshot: LabIntelligenceSnapshot) -> [LabPlaybookSuggestion] {
        var list: [LabPlaybookSuggestion] = []

        let cpu = Int(snapshot.system?.cpu?.usagePercent ?? 0)
        if cpu >= 80 {
            list.append(
                .init(
                    id: "cpu_hot",
                    title: "CPU alta",
                    detail: "Abrir painel de sistema e investigar processos.",
                    targetTab: "system"
                ))
        }

        if !snapshot.adsbAlerts.isEmpty {
            list.append(
                .init(
                    id: "adsb_alerts",
                    title: "Alertas ADS-B",
                    detail: "Abrir ADS-B com foco em aeronaves críticas.",
                    targetTab: "adsb"
                ))
        }

        if !snapshot.acarsAlerts.isEmpty {
            list.append(
                .init(
                    id: "acars_alerts",
                    title: "Alertas ACARS",
                    detail: "Revisar mensagens recentes e histórico.",
                    targetTab: "acars"
                ))
        }

        if let weather = snapshot.weather,
            weather.current.precipMm >= 0.3 || weather.today.rainChance >= 55
        {
            list.append(
                .init(
                    id: "weather_watch",
                    title: "Acompanhar clima",
                    detail: "Abrir Clima e revisar chuva, vento e janela horária.",
                    targetTab: "weather"
                ))
        }

        if snapshot.lastImages == nil {
            list.append(
                .init(
                    id: "sat_check",
                    title: "Sem passe recente",
                    detail: "Abrir Satélite e validar previsão/coleta.",
                    targetTab: "satellite"
                ))
        }

        if list.isEmpty {
            list.append(
                .init(
                    id: "healthy",
                    title: "Operação estável",
                    detail: "Sem ação crítica agora. Recomendado: checar Analytics.",
                    targetTab: "analytics"
                ))
        }
        return list
    }

    func dataQuality(from snapshot: LabIntelligenceSnapshot) -> [DataQualityItem] {
        let adsbOk = (snapshot.adsbSummary != nil || !snapshot.aircraft.isEmpty)
        let satOk = (snapshot.lastImages != nil || !snapshot.passes.isEmpty)
        let acarsOk = (snapshot.acarsSummary != nil || !snapshot.acarsMessages.isEmpty)
        let sysOk = snapshot.system != nil
        let weatherOk = snapshot.weather != nil
        let metricsOk = snapshot.metrics != nil

        return [
            .init(
                id: "adsb", source: "ADS-B", status: adsbOk ? "OK" : "Sem dados",
                detail: "Aeronaves: \(snapshot.aircraft.count)"),
            .init(
                id: "sat", source: "Satélite", status: satOk ? "OK" : "Sem dados",
                detail: "Passes: \(snapshot.passes.count)"),
            .init(
                id: "acars", source: "ACARS", status: acarsOk ? "OK" : "Sem dados",
                detail: "Msgs: \(snapshot.acarsMessages.count)"),
            .init(
                id: "weather", source: "Clima", status: weatherOk ? "OK" : "Sem dados",
                detail: weatherOk ? snapshot.weather?.current.description ?? "-" : "Coleta indisponível"),
            .init(
                id: "sys", source: "Sistema", status: sysOk ? "OK" : "Sem dados",
                detail: "Host: \(snapshot.system?.hostname ?? "-")"),
            .init(
                id: "metrics", source: "Métricas", status: metricsOk ? "OK" : "Sem dados",
                detail: metricsOk ? "Latência disponível" : "Coleta indisponível"),
        ]
    }

    func comparisons(from snapshot: LabIntelligenceSnapshot) -> [ComparisonInsight] {
        var insights: [ComparisonInsight] = []

        if let history = snapshot.adsbHistory {
            let todayPeak = history.days.first.flatMap { history.dailyPeaks[$0]?["peak"] } ?? 0
            let yesterdayPeak =
                history.days.dropFirst().first.flatMap { history.dailyPeaks[$0]?["peak"] } ?? 0
            insights.append(
                .init(
                    id: "adsb_peak",
                    metric: "Pico de aeronaves",
                    current: "\(todayPeak)",
                    previous: "\(yesterdayPeak)",
                    delta: signedDelta(
                        current: Double(todayPeak), previous: Double(yesterdayPeak), suffix: "")
                ))
        }

        if let acars = snapshot.acarsHistory {
            let todayMsgs = acars.last24hHours.reduce(0) { $0 + $1.messages }
            let yesterdayMsgs = acars.last7Days.dropFirst().first?.messages ?? 0
            insights.append(
                .init(
                    id: "acars_msgs",
                    metric: "Mensagens ACARS",
                    current: "\(todayMsgs)",
                    previous: "\(yesterdayMsgs)",
                    delta: signedDelta(
                        current: Double(todayMsgs), previous: Double(yesterdayMsgs), suffix: "")
                ))
        }

        if let cpuNow = snapshot.system?.cpu?.usagePercent,
            let avgResp = snapshot.metrics?.avgResponseMs
        {
            insights.append(
                .init(
                    id: "sys_resp",
                    metric: "CPU x Latência API",
                    current: "\(Int(cpuNow))% CPU",
                    previous: "\(Int(avgResp)) ms",
                    delta: cpuNow > 75 && avgResp > 500 ? "Risco alto" : "Normal"
                ))
        }

        if let weather = snapshot.weather {
            insights.append(
                .init(
                    id: "weather_rain",
                    metric: "Chuva prevista",
                    current: "\(weather.today.rainChance)%",
                    previous: "\(weather.today.rainMm.formattedBR(decimals: 1)) mm",
                    delta: weather.today.rainChance >= 60 || weather.today.rainMm >= 5 ? "Atenção" : "Baixo risco"
                ))
        }

        return insights
    }

    private func scoreIntelligence(_ tokens: [String], in haystack: String) -> Int {
        var score = 0
        for token in tokens where !token.isEmpty {
            if haystack == token {
                score += 10
            } else if haystack.contains(token) {
                score += 3
            }
        }
        return score
    }
}

private func compactTime(_ ts: String) -> String {
    if let date = Formatters.isoDateNoFrac.date(from: ts) ?? Formatters.isoDate.date(from: ts) {
        return Formatters.time.string(from: date)
    }
    if ts.count >= 16 {
        let start = ts.index(ts.startIndex, offsetBy: 11)
        let end = ts.index(start, offsetBy: min(5, ts.distance(from: start, to: ts.endIndex)))
        return String(ts[start..<end])
    }
    return ts
}

private func signedDelta(current: Double, previous: Double, suffix: String) -> String {
    let delta = current - previous
    let sign = delta >= 0 ? "+" : ""
    return "\(sign)\(Int(delta))\(suffix)"
}

private func tokenizeIntelligence(_ text: String) -> [String] {
    normalizeIntelligence(text).split(separator: " ").map(String.init).filter { $0.count > 1 }
}

private func normalizeIntelligence(_ text: String) -> String {
    text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        .replacingOccurrences(of: "[^a-zA-Z0-9\\s-]", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
}

private func compactPassName(_ text: String) -> String {
    text.replacingOccurrences(of: "_", with: " ")
}
