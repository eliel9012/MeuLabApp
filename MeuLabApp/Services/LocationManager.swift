import Foundation
import CoreLocation
import Combine

/// Gerenciador de localização do usuário
@MainActor
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let locationManager = CLLocationManager()

    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    @Published var locationError: String?

    // Localização do receptor fixo (Franca, SP)
    static let receiverLocation = CLLocation(latitude: -20.512504, longitude: -47.400830)

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Atualiza a cada 100m
        authorizationStatus = locationManager.authorizationStatus
        updateAuthorizationState()
    }

    // MARK: - Public Methods

    /// Solicita permissão de localização
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Inicia monitoramento de localização
    func startUpdating() {
        guard isAuthorized else {
            requestPermission()
            return
        }
        locationManager.startUpdatingLocation()
    }

    /// Para monitoramento de localização
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }

    /// Solicita localização única
    func requestLocation() {
        guard isAuthorized else {
            requestPermission()
            return
        }
        locationManager.requestLocation()
    }

    // MARK: - Distance Calculations

    /// Calcula distância do usuário até uma coordenada (em milhas náuticas)
    func distanceToUser(latitude: Double, longitude: Double) -> Double? {
        guard let userLoc = userLocation else { return nil }
        let targetLocation = CLLocation(latitude: latitude, longitude: longitude)
        let distanceMeters = userLoc.distance(from: targetLocation)
        return distanceMeters / 1852.0 // Converte para milhas náuticas
    }

    /// Calcula distância do receptor fixo até uma coordenada (em milhas náuticas)
    func distanceToReceiver(latitude: Double, longitude: Double) -> Double {
        let targetLocation = CLLocation(latitude: latitude, longitude: longitude)
        let distanceMeters = Self.receiverLocation.distance(from: targetLocation)
        return distanceMeters / 1852.0
    }

    /// Calcula bearing do usuário até uma coordenada (em graus)
    func bearingToUser(latitude: Double, longitude: Double) -> Double? {
        guard let userLoc = userLocation else { return nil }
        return calculateBearing(
            from: userLoc.coordinate,
            to: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
    }

    /// Distância do usuário ao receptor (em km)
    var distanceToReceiver: Double? {
        guard let userLoc = userLocation else { return nil }
        return userLoc.distance(from: Self.receiverLocation) / 1000.0
    }

    /// Coordenada do usuário
    var userCoordinate: CLLocationCoordinate2D? {
        userLocation?.coordinate
    }

    // MARK: - Private Methods

    private func updateAuthorizationState() {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isAuthorized = true
            locationError = nil
        case .denied:
            isAuthorized = false
            locationError = "Localização negada. Ative em Ajustes."
        case .restricted:
            isAuthorized = false
            locationError = "Localização restrita neste dispositivo."
        case .notDetermined:
            isAuthorized = false
            locationError = nil
        @unknown default:
            isAuthorized = false
        }
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.degreesToRadians
        let lon1 = from.longitude.degreesToRadians
        let lat2 = to.latitude.degreesToRadians
        let lon2 = to.longitude.degreesToRadians

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x).radiansToDegrees

        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            self.userLocation = location
            self.locationError = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationError = "Localização negada"
                case .locationUnknown:
                    self.locationError = "Localização indisponível"
                default:
                    self.locationError = "Erro de localização"
                }
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            self.updateAuthorizationState()

            if self.isAuthorized {
                manager.startUpdatingLocation()
            }
        }
    }
}

// MARK: - Extensions

extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}

// MARK: - Compass Direction

extension LocationManager {
    /// Converte bearing em direção cardeal
    static func compassDirection(from bearing: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((bearing + 22.5) / 45.0) % 8
        return directions[index]
    }
}
