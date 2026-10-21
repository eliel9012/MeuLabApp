import Foundation

enum AircraftFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "Todas"
    case positioned = "Com posição"
    case withoutPosition = "Sem posição"
    var id: String { rawValue }
}

enum RadarMapStyle: String, CaseIterable, Identifiable, Sendable {
    case standard = "Padrão"
    case imagery = "Satélite"
    case hybrid = "Híbrido"

    var id: String { rawValue }
}

struct RadarSettings: Sendable {
    var radiusKilometers: Double = 100
    var verticalExaggeration: Double = 1.5
    var maxPositionAgeSeconds: Double = 30
    var minimumAltitudeFeet: Double = 0
    var filter: AircraftFilter = .all
}
