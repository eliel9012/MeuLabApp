import Foundation
import SwiftUI
import Combine
import CoreLocation
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
    func setActiveTab(_ rawValue: String) {
        activeTabRawValue = rawValue
    }
    
    func updateRadarBounds(_ bounds: [Double]) {
        self.radarBoundingBox = bounds
    }

    // MARK: - ADS-B
    @Published var adsbSummary: ADSBSummary?
    @Published var aircraftList: [Aircraft] = []
    @Published var localAircraftCount: Int = 0      // Aeronaves do radar local
    @Published var openskyAircraftCount: Int = 0    // Aeronaves da OpenSky
    @Published var adsbError: String?
    @Published var adsbLoading = false
    @Published var isOpenSkyEnabled: Bool = false {
        didSet {
            // Trigger refresh immediately when enabled
            if isOpenSkyEnabled {
                lastOpenSkyRefresh = nil // Força o refresh no próximo ciclo
                Task { await refreshADSB() }
            }
        }
    }
    @Published private(set) var manualAirlineOverrides: [String: String] = [:]
    
    // MARK: - Map Coordination
    @Published var mapFocusAircraft: Aircraft?
    @Published var radarBoundingBox: [Double]? // [minLat, maxLat, minLon, maxLon]

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

    // MARK: - Metrics
    @Published var metrics: MetricsResponse?
    @Published var metricsError: String?

    // MARK: - Timers
    private var refreshTimer: Timer?
    private let refreshTickInterval: TimeInterval = 0.5 // base tick for throttled refresh (2x/s)
    private var refreshAllInFlight = false

    private let adsbInterval: TimeInterval = 0.5
    private let systemInterval: TimeInterval = 5.0
    private let firestickInterval: TimeInterval = 10.0
    private let radioInterval: TimeInterval = 5.0
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
    private let acarsHistoryInterval: TimeInterval = 300.0
    private let acarsAlertsInterval: TimeInterval = 60.0
    private let metricsInterval: TimeInterval = 10.0

    private var lastADSBRefresh: Date?
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
    private var lastACARSHistoryRefresh: Date?
    private var lastACARSAlertsRefresh: Date?
    private var lastMetricsRefresh: Date?
    private var lastOpenSkyRefresh: Date?

    private let api = APIService.shared
    private let openSkyService = OpenSkyService.shared
    private let manualAirlineOverridesDefaultsKey = "adsb.manualAirlineOverrides"

    init() {
        loadManualAirlineOverrides()
        startRefreshTimer()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Timer Management

    private func startRefreshTimer() {
        guard refreshTimer == nil else { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshTickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAllData()
            }
        }
    }

    func setRefreshEnabled(_ enabled: Bool) {
        if enabled {
            startRefreshTimer()
        } else {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    private func refreshAllData() async {
        // Prevent overlapping refresh cycles from piling up when network calls are slow.
        if refreshAllInFlight { return }
        refreshAllInFlight = true
        defer { refreshAllInFlight = false }

        let now = Date()

        // Gate frequent polling by active tab to avoid heavy background churn.
        // Keep some light background refresh for widgets, but much less frequently.
        let active = activeTabRawValue
        let isADSBActive = (active == "adsb" || active == "map")
        let isSystemActive = (active == "system" || active == "infra")
        let isRadioActive = (active == "radio")
        let isWeatherActive = (active == "weather")
        let isSatelliteActive = (active == "satellite")
        let isACARSActive = (active == "acars")

        let adsbEffective = isADSBActive ? adsbInterval : 10.0
        let systemEffective = isSystemActive ? systemInterval : 30.0
        let firestickEffective = isSystemActive ? firestickInterval : 60.0
        let radioEffective = isRadioActive ? radioInterval : 30.0
        let weatherEffective = isWeatherActive ? weatherInterval : 300.0
        let satelliteEffective = isSatelliteActive ? satelliteInterval : 600.0
        let acarsEffective = isACARSActive ? acarsInterval : 60.0
        let processesEffective = isSystemActive ? processesInterval : 60.0
        let networkEffective = isSystemActive ? networkInterval : 60.0
        let metricsEffective = (isADSBActive || isSystemActive) ? metricsInterval : 60.0

        // Compute refresh flags on the main actor before launching async work.
        let refreshADSBNow = shouldRefresh(last: lastADSBRefresh, interval: adsbEffective, now: now)
        let refreshSystemNow = shouldRefresh(last: lastSystemRefresh, interval: systemEffective, now: now)
        let refreshFirestickNow = shouldRefresh(last: lastFirestickRefresh, interval: firestickEffective, now: now)
        let refreshRadioNow = shouldRefresh(last: lastRadioRefresh, interval: radioEffective, now: now)
        let refreshWeatherNow = shouldRefresh(last: lastWeatherRefresh, interval: weatherEffective, now: now)
        let refreshSatelliteNow = shouldRefresh(last: lastSatelliteRefresh, interval: satelliteEffective, now: now)
        let refreshACARSNow = shouldRefresh(last: lastACARSRefresh, interval: acarsEffective, now: now)
        let refreshProcessesNow = shouldRefresh(last: lastProcessesRefresh, interval: processesEffective, now: now)
        let refreshPartitionsNow = shouldRefresh(last: lastPartitionsRefresh, interval: partitionsInterval, now: now)
        let refreshNetworkNow = shouldRefresh(last: lastNetworkRefresh, interval: networkEffective, now: now)
        let refreshDockerStatusNow = shouldRefresh(last: lastDockerStatusRefresh, interval: dockerStatusInterval, now: now)
        let refreshDockerVersionNow = shouldRefresh(last: lastDockerVersionRefresh, interval: dockerVersionInterval, now: now)
        let refreshSystemdNow = shouldRefresh(last: lastSystemdRefresh, interval: systemdInterval, now: now)
        let refreshSatDumpStatusNow = shouldRefresh(last: lastSatDumpStatusRefresh, interval: satDumpStatusInterval, now: now)
        let refreshADSBHistoryNow = shouldRefresh(last: lastADSBHistoryRefresh, interval: adsbHistoryInterval, now: now)
        let refreshADSBAlertsNow = shouldRefresh(last: lastADSBAlertsRefresh, interval: adsbAlertsInterval, now: now)
        let refreshACARSHistoryNow = shouldRefresh(last: lastACARSHistoryRefresh, interval: acarsHistoryInterval, now: now)
        let refreshACARSAlertsNow = shouldRefresh(last: lastACARSAlertsRefresh, interval: acarsAlertsInterval, now: now)
        let refreshMetricsNow = shouldRefresh(last: lastMetricsRefresh, interval: metricsEffective, now: now)

        if refreshADSBNow { lastADSBRefresh = now }
        if refreshSystemNow { lastSystemRefresh = now }
        if refreshFirestickNow { lastFirestickRefresh = now }
        if refreshRadioNow { lastRadioRefresh = now }
        if refreshWeatherNow { lastWeatherRefresh = now }
        if refreshSatelliteNow { lastSatelliteRefresh = now }
        if refreshACARSNow { lastACARSRefresh = now }
        if refreshProcessesNow { lastProcessesRefresh = now }
        if refreshPartitionsNow { lastPartitionsRefresh = now }
        if refreshNetworkNow { lastNetworkRefresh = now }
        if refreshDockerStatusNow { lastDockerStatusRefresh = now }
        if refreshDockerVersionNow { lastDockerVersionRefresh = now }
        if refreshSystemdNow { lastSystemdRefresh = now }
        if refreshSatDumpStatusNow { lastSatDumpStatusRefresh = now }
        if refreshADSBHistoryNow { lastADSBHistoryRefresh = now }
        if refreshADSBAlertsNow { lastADSBAlertsRefresh = now }
        if refreshACARSHistoryNow { lastACARSHistoryRefresh = now }
        if refreshACARSAlertsNow { lastACARSAlertsRefresh = now }
        if refreshMetricsNow { lastMetricsRefresh = now }

        // Refresh in parallel, but throttle per category
        async let adsb: () = refreshADSBNow ? refreshADSB() : ()
        async let system: () = refreshSystemNow ? refreshSystem() : ()
        async let firestick: () = refreshFirestickNow ? refreshFirestick() : ()
        async let radio: () = refreshRadioNow ? refreshRadio() : ()
        async let weather: () = refreshWeatherNow ? refreshWeather() : ()
        async let satellite: () = refreshSatelliteNow ? refreshSatellite() : ()
        async let acars: () = refreshACARSNow ? refreshACARS() : ()
        async let processes: () = refreshProcessesNow ? refreshProcesses() : ()
        async let partitions: () = refreshPartitionsNow ? refreshPartitions() : ()
        async let network: () = refreshNetworkNow ? refreshNetwork() : ()
        async let dockerStatus: () = refreshDockerStatusNow ? refreshDockerStatus() : ()
        async let dockerVersion: () = refreshDockerVersionNow ? refreshDockerVersion() : ()
        async let systemd: () = refreshSystemdNow ? refreshSystemd() : ()
        async let satdumpStatus: () = refreshSatDumpStatusNow ? refreshSatDumpStatus() : ()
        async let adsbHistory: () = refreshADSBHistoryNow ? refreshADSBHistory() : ()
        async let adsbAlerts: () = refreshADSBAlertsNow ? refreshADSBAlerts() : ()
        async let acarsHistory: () = refreshACARSHistoryNow ? refreshACARSHistory() : ()
        async let acarsAlerts: () = refreshACARSAlertsNow ? refreshACARSAlerts() : ()
        async let metrics: () = refreshMetricsNow ? refreshMetrics() : ()

        _ = await (adsb, system, firestick, radio, weather, satellite, acars, processes, partitions, network, dockerStatus, dockerVersion, systemd, satdumpStatus, adsbHistory, adsbAlerts, acarsHistory, acarsAlerts, metrics)
    }

    private func shouldRefresh(last: Date?, interval: TimeInterval, now: Date) -> Bool {
        if let last, now.timeIntervalSince(last) < interval {
            return false
        }
        return true
    }

    // MARK: - ADS-B

    func refreshADSB() async {
        guard !adsbLoading else { 
            print("[ADSB] ⏭️ Skipping refresh - already loading")
            return 
        }
        adsbLoading = true
        defer { adsbLoading = false }
        
        print("[ADSB] 🔄 Starting refresh...")
        
        do {
            print("[ADSB] 📡 Fetching summary and aircraft list...")
            async let summaryTask = api.fetchADSBSummary()
            async let localTask = api.fetchAircraftList(limit: 100)

            let summaryResult: Result<ADSBSummary, Error>
            let localResult: Result<AircraftList, Error>

            do {
                let summary = try await summaryTask
                summaryResult = .success(summary)
            } catch {
                summaryResult = .failure(error)
            }

            do {
                let localAircraftList = try await localTask
                localResult = .success(localAircraftList)
            } catch {
                localResult = .failure(error)
            }

            var localItems: [Aircraft] = []
            if case .success(let localAircraft) = localResult {
                localItems = localAircraft.items.map { ac in
                    var modifiedAc = ac.with(source: .local, dualTracked: false)
                    
                    // Inject registration from cache if missing
                    if (modifiedAc.registration == nil || modifiedAc.registration?.isEmpty == true),
                       let cachedReg = self.registrationCache[modifiedAc.callsign] {
                        modifiedAc.registration = cachedReg
                        // print("[ADSB] 🔗 Linked \(modifiedAc.callsign) to \(cachedReg)")
                    }

                    if let manualAirline = manualAirlineOverride(for: modifiedAc) {
                        modifiedAc.airline = manualAirline
                    }
                    
                    return modifiedAc
                }
                print("[ADSB] ✅ Aircraft list received: \(localItems.count) aircraft")
                if let first = localItems.first {
                    print("[ADSB]   First aircraft: \(first.callsign) at \(first.altitudeFt) ft, VR: \(first.verticalRateFpm) fpm")
                }
            } else {
                print("[ADSB] ❌ Failed to fetch aircraft list")
            }

            let localSuccess: Bool
            switch localResult {
            case .success:
                localSuccess = true
            case .failure(let error):
                localSuccess = false
                print("[ADSB] ❌ Aircraft list error: \(error.localizedDescription)")
            }

            if localSuccess {
                self.localAircraftCount = localItems.count
                // Premature update removed. Final list will be updated after merge.
            }

            // --- OpenSky Integration ---
            var openSkyItems: [Aircraft] = []
            if isOpenSkyEnabled {
                // Throttle OpenSky to avoid rate limits (e.g., every 10s)
                let openSkyInterval: TimeInterval = 10.0
                if shouldRefresh(last: lastOpenSkyRefresh, interval: openSkyInterval, now: Date()) {
                    print("[ADSB] 🌍 Fetching OpenSky data...")
                    do {
                        // Calculate bounding box: prioritize radar map visible area
                        var box: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? = nil
                        
                        if let rBox = radarBoundingBox, rBox.count == 4 {
                            box = (minLat: rBox[0], maxLat: rBox[1], minLon: rBox[2], maxLon: rBox[3])
                            print("[ADSB] 🌍 Fetching OpenSky for radar box: [\(rBox[0]), \(rBox[1]), \(rBox[2]), \(rBox[3])]")
                        } else if let loc = LocationManager.shared.userLocation?.coordinate {
                             let delta = 5.0 // Slightly smaller default
                             box = (minLat: loc.latitude - delta, maxLat: loc.latitude + delta, 
                                    minLon: loc.longitude - delta, maxLon: loc.longitude + delta)
                             print("[ADSB] 🌍 Fetching OpenSky for user location")
                        } else {
                            // Fallback to Franca, SP
                            let lat = -20.5386
                            let lon = -47.4008
                            let delta = 5.0
                            box = (minLat: lat - delta, maxLat: lat + delta, 
                                   minLon: lon - delta, maxLon: lon + delta)
                            print("[ADSB] 🌍 Fetching OpenSky for fallback location")
                        }
                        
                        let states = try await openSkyService.fetchStates(boundingBox: box)
                        openSkyItems = states
                        self.lastOpenSkyRefresh = Date()
                        self.openskyAircraftCount = openSkyItems.count
                        print("[ADSB] 🌍 OpenSky data received: \(openSkyItems.count) aircraft")
                    } catch {
                        print("[ADSB] ⚠️ OpenSky error: \(error.localizedDescription)")
                    }
                } else {
                    // Keep existing OpenSky items if not refreshing yet
                    openSkyItems = self.aircraftList.filter { $0.source == .opensky }
                }
            } else {
                self.openskyAircraftCount = 0
            }

            // Merge Lists
            // Priority: Local > OpenSky (if dual tracked, keep local and mark as dual)
            var mergedMap: [String: Aircraft] = [:]
            
            // 1. Add Local
            for ac in localItems {
                mergedMap[ac.id] = ac
            }
            
            // 2. Merge OpenSky
            for ac in openSkyItems {
                if let existing = mergedMap[ac.id] {
                    // Collision: It's dual tracked!
                    mergedMap[ac.id] = existing.with(source: .local, dualTracked: true)
                } else {
                    // Unique to OpenSky
                    mergedMap[ac.id] = ac
                }
            }
            
            let finalAircraftList = Array(mergedMap.values)
            
            if localSuccess || isOpenSkyEnabled {
                self.localAircraftCount = localItems.count
                // We update list if anything changed
                // Use Set comparison for efficiency if needed, or simple equality if Aircraft is Equatable
                
                // Note: We might want to sort them? Usually View handles sorting.
                
                self.aircraftList = finalAircraftList
                print("[ADSB] 🌍 Final list updated: \(self.aircraftList.count) aircraft (Local: \(localItems.count), OpenSky: \(openSkyItems.count))")
            } else {
                 print("[ADSB] ⏭️ Aircraft list refresh skipped or failed")
            }

            if case .success(var summary) = summaryResult {
                print("[ADSB] ✅ Summary received: \(summary.totalNow) aircraft")
                
                // If OpenSky is enabled, we override the counts with our merged list
                if isOpenSkyEnabled {
                    let total = finalAircraftList.count
                    let climbing = finalAircraftList.filter { $0.verticalRateFpm > 256 }.count
                    let descending = finalAircraftList.filter { $0.verticalRateFpm < -256 }.count
                    let cruising = total - climbing - descending
                    
                    let newMovement = Movement(climbing: climbing, descending: descending, cruising: cruising)
                    
                    // Create updated summary
                    summary = ADSBSummary(
                        timestamp: summary.timestamp,
                        totalNow: total,
                        withPos: finalAircraftList.filter { $0.hasPosition }.count,
                        above10000: finalAircraftList.filter { $0.altitudeFt > 10000 }.count,
                        nonCivilNow: summary.nonCivilNow, // We don't have this for OpenSky easily
                        movement: newMovement,
                        averages: summary.averages, // Keep local averages or recalculate? Keep local for now.
                        highlights: summary.highlights,
                        airlines: summary.airlines,
                        topModels: summary.topModels,
                        stats24h: summary.stats24h
                    )
                    print("[ADSB] 🌍 Global summary calculated: \(total) aircraft (C: \(climbing), D: \(descending), Z: \(cruising))")
                }

                if self.adsbSummary != summary {
                    print("[ADSB] 📝 Updating summary (changed)")
                    self.adsbSummary = summary
                    WidgetDataManager.shared.updateADSB(
                        total: summary.totalNow,
                        withPos: summary.withPos
                    )
                } else {
                    print("[ADSB] ⏭️ Summary unchanged, skipping update")
                }
            }

            var firstError: Error?
            if case .failure(let error) = summaryResult {
                firstError = error
            }
            if firstError == nil, case .failure(let error) = localResult {
                firstError = error
            }

            if (self.adsbSummary != nil || !self.aircraftList.isEmpty) {
                self.adsbError = nil
            } else {
                self.adsbError = firstError?.localizedDescription
            }
        } catch {
            if adsbSummary == nil {
                self.adsbError = error.localizedDescription
            }
        }
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

            let statuses: [FirestickDeviceStatus] = try await withThrowingTaskGroup(of: FirestickDeviceStatus.self) { group in
                for dev in devices {
                    group.addTask {
                        let st = try await APIService.shared.fetchFirestickStatus(id: dev.id, force: false)
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
            let data: WeatherData
            
            // Check for user location
            if LocationManager.shared.isAuthorized, let loc = LocationManager.shared.userLocation {
                // Prefer backend (WeatherKit REST when configured); fallback to Open-Meteo.
                do {
                    data = try await api.fetchWeather(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                } catch {
                    data = try await api.fetchWeatherOpenMeteo(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                }
                
                // Try reverse geocoding for city name (optional enhancement)
                // For now, it uses coordinates string from APIService
            } else {
                // Fallback to Lab API (Franca, SP)
                data = try await api.fetchWeather()
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

    #if canImport(WeatherKit)
    @available(iOS 16.0, *)
    private func fetchWeatherKitWeatherData(location: CLLocation) async throws -> WeatherData {
        let service = WeatherService.shared
        let weather = try await service.weather(for: location)

        let current = weather.currentWeather
        let daily = weather.dailyForecast

        let currentWeather = CurrentWeather(
            tempC: Int(round(current.temperature.converted(to: UnitTemperature.celsius).value)),
            feelsLikeC: Int(round(current.apparentTemperature.converted(to: UnitTemperature.celsius).value)),
            humidity: Int(round(current.humidity * 100.0)),
            windKmh: Int(round(current.wind.speed.converted(to: UnitSpeed.kilometersPerHour).value)),
            windDir: LocationManager.compassDirection(from: current.wind.direction.converted(to: UnitAngle.degrees).value),
            description: weatherKitConditionPT(current.condition),
            // WeatherKit exposes precipitation intensity with a unit not representable by Foundation's UnitSpeed.
            // Keep it as a best-effort scalar (typically mm/h) to fit the existing model.
            precipMm: current.precipitationIntensity.value,
            uvIndex: Int(current.uvIndex.value)
        )

        let today = daily.forecast.first
        let todayWeather = TodayWeather(
            maxTempC: Int(round(today?.highTemperature.converted(to: UnitTemperature.celsius).value ?? Double(currentWeather.tempC))),
            minTempC: Int(round(today?.lowTemperature.converted(to: UnitTemperature.celsius).value ?? Double(currentWeather.tempC))),
            rainChance: Int(round((today?.precipitationChance ?? 0) * 100.0)),
            rainMm: (today?.precipitationAmount.converted(to: UnitLength.millimeters).value ?? 0),
            uvIndex: Int(today?.uvIndex.value ?? current.uvIndex.value)
        )

        var forecast: [ForecastDay] = []
        for day in daily.forecast.dropFirst().prefix(7) {
            forecast.append(
                ForecastDay(
                    date: isoDay(day.date),
                    maxTempC: Int(round(day.highTemperature.converted(to: UnitTemperature.celsius).value)),
                    minTempC: Int(round(day.lowTemperature.converted(to: UnitTemperature.celsius).value)),
                    rainChance: Int(round(day.precipitationChance * 100.0)),
                    rainMm: day.precipitationAmount.converted(to: UnitLength.millimeters).value,
                    uvIndex: Int(day.uvIndex.value)
                )
            )
        }

        return WeatherData(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            location: String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude),
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

    private func hasAnyMatchingAirlineOverrideKey(between lhs: Aircraft, and rhs: Aircraft) -> Bool {
        let left = Set(airlineOverrideKeys(for: lhs))
        let right = Set(airlineOverrideKeys(for: rhs))
        return !left.isDisjoint(with: right)
    }

    private func normalizedLookupToken(_ value: String?) -> String? {
        guard let token = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    private func loadManualAirlineOverrides() {
        guard let data = UserDefaults.standard.data(forKey: manualAirlineOverridesDefaultsKey) else {
            return
        }
        if let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            manualAirlineOverrides = decoded
        }
    }

    private func persistManualAirlineOverrides() {
        if let data = try? JSONEncoder().encode(manualAirlineOverrides) {
            UserDefaults.standard.set(data, forKey: manualAirlineOverridesDefaultsKey)
        }
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
                   let tail = msg.tail, !tail.isEmpty {
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
                    print("[ACARS]   First message: \(first.flight ?? "N/A") - \(first.label ?? "N/A")")
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
        lastADSBRefresh = nil
        lastSystemRefresh = nil
        lastFirestickRefresh = nil
        lastRadioRefresh = nil
        lastWeatherRefresh = nil
        lastSatelliteRefresh = nil
        lastACARSRefresh = nil
        lastProcessesRefresh = nil
        lastPartitionsRefresh = nil
        lastNetworkRefresh = nil
        lastDockerStatusRefresh = nil
        lastDockerVersionRefresh = nil
        lastSystemdRefresh = nil
        lastSatDumpStatusRefresh = nil
        lastADSBHistoryRefresh = nil
        lastADSBAlertsRefresh = nil
        lastACARSHistoryRefresh = nil
        lastACARSAlertsRefresh = nil
        lastMetricsRefresh = nil
        await refreshAllData()
    }
}

struct LabIntelligenceSnapshot {
    let aircraft: [Aircraft]
    let adsbSummary: ADSBSummary?
    let system: SystemStatus?
    let lastImages: LastImages?
    let passes: [SatellitePass]
    let acarsSummary: ACARSSummary?
    let acarsMessages: [ACARSMessage]
    let adsbAlerts: [ADSBAlert]
    let acarsAlerts: [ACARSAlert]
    let adsbHistory: ADSBHistoryResponse?
    let acarsHistory: ACARSHistoryResponse?
    let metrics: MetricsResponse?

    @MainActor
    init(state: AppState) {
        aircraft = state.aircraftList
        adsbSummary = state.adsbSummary
        system = state.systemStatus
        lastImages = state.lastImages
        passes = state.passes
        acarsSummary = state.acarsSummary
        acarsMessages = state.acarsMessages
        adsbAlerts = state.adsbAlerts
        acarsAlerts = state.acarsAlerts
        adsbHistory = state.adsbHistory
        acarsHistory = state.acarsHistory
        metrics = state.metrics
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
        let withPos = snapshot.adsbSummary?.withPos ?? snapshot.aircraft.filter { $0.lat != nil && $0.lon != nil }.count
        let fastest = snapshot.aircraft.max(by: { $0.speedKt < $1.speedKt })
        let closest = snapshot.aircraft.compactMap { ac -> Aircraft? in
            guard ac.distanceNm != nil else { return nil }
            return ac
        }.min(by: { ($0.distanceNm ?? .greatestFiniteMagnitude) < ($1.distanceNm ?? .greatestFiniteMagnitude) })

        let cpu = Int(snapshot.system?.cpu?.usagePercent ?? 0)
        let mem = Int(snapshot.system?.memory?.usedPercent ?? 0)
        let temp = snapshot.system?.cpu?.temperatureC.map { String(format: "%.0f", $0) } ?? "-"
        let lastPass = snapshot.lastImages.map { "\($0.images.count) imagens em \(compactPassName($0.passName))" } ?? "sem passe recente"
        let acarsToday = snapshot.acarsSummary?.today.messages ?? snapshot.acarsMessages.count

        var lines: [String] = []
        lines.append("Radar: \(total) aeronaves (\(withPos) com posição).")
        if let fastest {
            lines.append("Mais rápida: \(fastest.displayCallsign) a \(fastest.speedKt) kt.")
        }
        if let closest, let d = closest.distanceNm {
            lines.append("Mais próxima: \(closest.displayCallsign) a \(String(format: "%.1f", d)) nm.")
        }
        lines.append("Satélite: \(lastPass).")
        lines.append("ACARS hoje: \(acarsToday) mensagens.")
        lines.append("Sistema: CPU \(cpu)% • RAM \(mem)% • Temp \(temp)°C.")
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
                .min(by: { ($0.distanceNm ?? .greatestFiniteMagnitude) < ($1.distanceNm ?? .greatestFiniteMagnitude) }),
               let d = ac.distanceNm {
                return "Aeronave mais próxima: \(ac.displayCallsign) a \(String(format: "%.1f", d)) nm."
            }
            return "Nenhuma aeronave com distância disponível no momento."
        }
        if q.contains("rapida") || q.contains("rápid") || q.contains("veloc") {
            if let ac = snapshot.aircraft.max(by: { $0.speedKt < $1.speedKt }) {
                return "Aeronave mais rápida: \(ac.displayCallsign) a \(ac.speedKt) kt (\(ac.speedKmh) km/h)."
            }
            return "Não encontrei velocidade de aeronaves agora."
        }
        if q.contains("satel") || q.contains("meteor") || q.contains("passe") {
            if let last = snapshot.lastImages {
                return "Último passe: \(compactPassName(last.passName)) com \(last.images.count) imagens."
            }
            return "Sem passe de satélite recente no momento."
        }
        if q.contains("cpu") || q.contains("ram") || q.contains("sistema") || q.contains("temperatura") {
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

    func semanticSearch(query: String, snapshot: LabIntelligenceSnapshot, limit: Int = 10) -> [LabSearchResult] {
        let tokens = tokenizeIntelligence(query)
        guard !tokens.isEmpty else { return [] }
        var results: [LabSearchResult] = []

        for ac in snapshot.aircraft {
            let haystack = normalizeIntelligence([ac.callsign, ac.registration, ac.model, ac.hex, ac.airline].compactMap { $0 }.joined(separator: " "))
            let score = scoreIntelligence(tokens, in: haystack)
            if score > 0 {
                let subtitle = [ac.registration, ac.model, ac.hex?.uppercased()].compactMap { $0 }.joined(separator: " • ")
                results.append(.init(
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
                results.append(.init(
                    id: "pass_\(pass.id)",
                    category: "Satélite",
                    title: pass.satelliteName,
                    subtitle: compactPassName(pass.name),
                    score: score
                ))
            }
        }

        for msg in snapshot.acarsMessages {
            let haystack = normalizeIntelligence([msg.flight, msg.tail, msg.label, msg.text, msg.departure, msg.destination].compactMap { $0 }.joined(separator: " "))
            let score = scoreIntelligence(tokens, in: haystack)
            if score > 0 {
                let route = msg.displayRoute ?? "-"
                results.append(.init(
                    id: "acars_\(msg.id)",
                    category: "ACARS",
                    title: msg.displayFlight,
                    subtitle: "\(msg.label ?? "-") • \(route)",
                    score: score
                ))
            }
        }

        for alert in snapshot.adsbAlerts {
            let haystack = normalizeIntelligence([alert.callsign, alert.registration, alert.model, alert.aircraft].compactMap { $0 }.joined(separator: " "))
            let score = scoreIntelligence(tokens, in: haystack)
            if score > 0 {
                let title = alert.callsign ?? alert.registration ?? alert.aircraft
                results.append(.init(
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
            events.append(.init(
                id: "adsb_\(alert.id)",
                timeLabel: compactTime(alert.timestamp),
                category: "ADS-B",
                title: "Alerta de tráfego",
                detail: title
            ))
        }

        for alert in snapshot.acarsAlerts {
            events.append(.init(
                id: "acars_\(alert.id)",
                timeLabel: alert.timestamp.toDisplayHHMM() ?? "-",
                category: "ACARS",
                title: "Alerta de mensagem",
                detail: alert.id
            ))
        }

        if let last = snapshot.lastImages {
            events.append(.init(
                id: "sat_\(last.timestamp)",
                timeLabel: compactTime(last.timestamp),
                category: "Satélite",
                title: "Último passe capturado",
                detail: "\(last.images.count) imagens • \(compactPassName(last.passName))"
            ))
        }

        if let sys = snapshot.system {
            let cpu = Int(sys.cpu?.usagePercent ?? 0)
            let mem = Int(sys.memory?.usedPercent ?? 0)
            events.append(.init(
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
            list.append(.init(
                id: "cpu_hot",
                title: "CPU alta",
                detail: "Abrir painel de sistema e investigar processos.",
                targetTab: "system"
            ))
        }

        if !snapshot.adsbAlerts.isEmpty {
            list.append(.init(
                id: "adsb_alerts",
                title: "Alertas ADS-B",
                detail: "Abrir ADS-B com foco em aeronaves críticas.",
                targetTab: "adsb"
            ))
        }

        if !snapshot.acarsAlerts.isEmpty {
            list.append(.init(
                id: "acars_alerts",
                title: "Alertas ACARS",
                detail: "Revisar mensagens recentes e histórico.",
                targetTab: "acars"
            ))
        }

        if snapshot.lastImages == nil {
            list.append(.init(
                id: "sat_check",
                title: "Sem passe recente",
                detail: "Abrir Satélite e validar previsão/coleta.",
                targetTab: "satellite"
            ))
        }

        if list.isEmpty {
            list.append(.init(
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
        let metricsOk = snapshot.metrics != nil

        return [
            .init(id: "adsb", source: "ADS-B", status: adsbOk ? "OK" : "Sem dados", detail: "Aeronaves: \(snapshot.aircraft.count)"),
            .init(id: "sat", source: "Satélite", status: satOk ? "OK" : "Sem dados", detail: "Passes: \(snapshot.passes.count)"),
            .init(id: "acars", source: "ACARS", status: acarsOk ? "OK" : "Sem dados", detail: "Msgs: \(snapshot.acarsMessages.count)"),
            .init(id: "sys", source: "Sistema", status: sysOk ? "OK" : "Sem dados", detail: "Host: \(snapshot.system?.hostname ?? "-")"),
            .init(id: "metrics", source: "Métricas", status: metricsOk ? "OK" : "Sem dados", detail: metricsOk ? "Latência disponível" : "Coleta indisponível")
        ]
    }

    func comparisons(from snapshot: LabIntelligenceSnapshot) -> [ComparisonInsight] {
        var insights: [ComparisonInsight] = []

        if let history = snapshot.adsbHistory {
            let todayPeak = history.days.first.flatMap { history.dailyPeaks[$0]?["peak"] } ?? 0
            let yesterdayPeak = history.days.dropFirst().first.flatMap { history.dailyPeaks[$0]?["peak"] } ?? 0
            insights.append(.init(
                id: "adsb_peak",
                metric: "Pico de aeronaves",
                current: "\(todayPeak)",
                previous: "\(yesterdayPeak)",
                delta: signedDelta(current: Double(todayPeak), previous: Double(yesterdayPeak), suffix: "")
            ))
        }

        if let acars = snapshot.acarsHistory {
            let todayMsgs = acars.last24hHours.reduce(0) { $0 + $1.messages }
            let yesterdayMsgs = acars.last7Days.dropFirst().first?.messages ?? 0
            insights.append(.init(
                id: "acars_msgs",
                metric: "Mensagens ACARS",
                current: "\(todayMsgs)",
                previous: "\(yesterdayMsgs)",
                delta: signedDelta(current: Double(todayMsgs), previous: Double(yesterdayMsgs), suffix: "")
            ))
        }

        if let cpuNow = snapshot.system?.cpu?.usagePercent,
           let avgResp = snapshot.metrics?.avgResponseMs {
            insights.append(.init(
                id: "sys_resp",
                metric: "CPU x Latência API",
                current: "\(Int(cpuNow))% CPU",
                previous: "\(Int(avgResp)) ms",
                delta: cpuNow > 75 && avgResp > 500 ? "Risco alto" : "Normal"
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
