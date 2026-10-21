import Foundation
import Observation

/// View state and polling lifecycle. All observable mutations take place on the main actor.
@MainActor
@Observable
final class FlightStore {
    var aircraft: [Aircraft] = []
    var selectedHex: String?
    var settings = RadarSettings()
    var lastReceivedAt: Date?
    var snapshotGeneratedAt: Date?
    var status = "Pronto para conectar"
    var errorMessage: String?
    var isConnected = false
    var isPaused = false
    var isLoading = false
    var isVolumeOpen = false
    var failureCount = 0

    @ObservationIgnored private let client: any ADSBProviding
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var fetching = false

    init(client: any ADSBProviding = ADSBClient()) {
        self.client = client
    }

    var selectedAircraft: Aircraft? { aircraft.first { $0.hex == selectedHex } }
    var receivedCount: Int { aircraft.count }
    var positionedCount: Int { aircraft.filter(\.hasPosition).count }
    var maxAltitudeFeet: Double? { aircraft.compactMap(\.altitudeFeet).max() }
    var maxSpeedKilometersPerHour: Double? { aircraft.compactMap(\.speedKilometersPerHour).max() }

    var filteredAircraft: [Aircraft] {
        switch settings.filter {
        case .all: return aircraft
        case .positioned: return aircraft.filter(\.hasPosition)
        case .withoutPosition: return aircraft.filter { !$0.hasPosition }
        }
    }

    func ageOfPosition(_ flight: Aircraft, at now: Date) -> Double? {
        guard let original = flight.seenPositionSeconds else { return nil }
        let anchor = snapshotGeneratedAt ?? lastReceivedAt ?? now
        return original + max(0, now.timeIntervalSince(anchor))
    }

    func isRenderable(_ flight: Aircraft, at now: Date) -> Bool {
        guard flight.hasPosition,
              let lat = flight.latitude, let lon = flight.longitude,
              let age = ageOfPosition(flight, at: now), age <= settings.maxPositionAgeSeconds,
              let altitude = flight.altitudeFeet, altitude >= settings.minimumAltitudeFeet else { return false }
        let enu = Geodesy.enu(.init(latitudeDegrees: lat, longitudeDegrees: lon, altitudeMeters: flight.geometricAltitudeMeters ?? flight.altitudeMeters ?? 0), relativeTo: Geodesy.approximateFranca)
        return enu.horizontalDistanceMeters <= settings.radiusKilometers * 1000
    }

    func renderableAircraft(at now: Date = Date()) -> [Aircraft] { aircraft.filter { isRenderable($0, at: now) } }

    func start() {
        if !isPaused { startPolling() }
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            stopPolling()
            status = "Atualizações pausadas"
        } else {
            startPolling()
        }
    }

    func startPolling() {
        guard !isPaused, pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, !self.isPaused {
                await self.refresh()
                let retry = min(60.0, 3.0 * pow(2.0, Double(min(self.failureCount, 5))))
                do { try await Task.sleep(for: .seconds(retry)) }
                catch { break }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func refresh() async {
        guard !fetching else { return }
        fetching = true
        isLoading = true
        defer { fetching = false; isLoading = false }
        if !isConnected {
            status = "Atualizando radar…"
        }
        do {
            let data = try await client.fetch()
            let snapshot = try await Task.detached(priority: .userInitiated) {
                try AircraftDecoder.decode(data)
            }.value
            guard !Task.isCancelled else { return }
            apply(snapshot)
            failureCount = 0
            isConnected = true
            errorMessage = nil
            status = "Conectado ao radar ADS-B"
        } catch {
            guard !Task.isCancelled else { return }
            failureCount += 1
            isConnected = false
            errorMessage = error.localizedDescription
            status = "Falha ao atualizar radar"
            // Keep previous actual observations, clearly marked disconnected.
        }
    }

    private func apply(_ snapshot: AircraftSnapshot) {
        aircraft = snapshot.aircraft
        lastReceivedAt = Date()
        snapshotGeneratedAt = snapshot.generatedAt
        if let selectedHex, !aircraft.contains(where: { $0.hex == selectedHex }) {
            self.selectedHex = nil
        }
        if selectedHex == nil {
            selectedHex = aircraft.first(where: { isRenderable($0, at: Date()) })?.hex
        }
        errorMessage = nil
    }
}
