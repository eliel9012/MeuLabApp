import CoreLocation
import Foundation

// ============================================================
// ETAPA POR GPS
// Descobre em qual parada do roteiro o viajante está de fato.
// ============================================================

@MainActor
final class TripLocator: NSObject, ObservableObject {
    static let shared = TripLocator()

    /// Stage detected from the device position, when close enough to one.
    @Published private(set) var stopHere: TripStop?
    /// Distance to the nearest stage, whether or not it counts as "here".
    @Published private(set) var nearestDistance: CLLocationDistance?
    @Published private(set) var nearestStop: TripStop?
    @Published private(set) var isAuthorized = false
    @Published private(set) var lastFix: Date?
    /// Latest position, for callers that need the raw fix rather than a matched stop.
    @Published private(set) var lastKnownLocation: CLLocation?

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
        // Stage granularity, not turn-by-turn: a coarse filter is plenty and costs
        // far less battery on a two-week trip.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            manager.startUpdatingLocation()
        default:
            isAuthorized = false
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    fileprivate func evaluate(_ location: CLLocation) {
        let engine = TripEngine.shared
        lastFix = Date()
        lastKnownLocation = location
        if let (stop, distance) = engine.nearestStop(to: location) {
            nearestStop = stop
            nearestDistance = distance
            stopHere = distance <= TripEngine.arrivalRadius ? stop : nil
        } else {
            nearestStop = nil
            nearestDistance = nil
            stopHere = nil
        }
    }
}

extension TripLocator: CLLocationManagerDelegate {
    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            TripLocator.shared.evaluate(latest)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            let locator = TripLocator.shared
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                locator.isAuthorized = true
                manager.startUpdatingLocation()
            default:
                locator.isAuthorized = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Position is a convenience here — the itinerary still works without it.
        print("TripLocator error: \(error.localizedDescription)")
    }
}
