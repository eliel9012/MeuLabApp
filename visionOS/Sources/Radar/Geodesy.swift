import Foundation

struct GeodeticCoordinate: Sendable {
    let latitudeDegrees: Double
    let longitudeDegrees: Double
    let altitudeMeters: Double
}

struct CartesianCoordinate: Sendable {
    let x: Double
    let y: Double
    let z: Double
}

struct ENUCoordinate: Sendable {
    let east: Double
    let north: Double
    let up: Double

    var horizontalDistanceMeters: Double { hypot(east, north) }
}

/// Coordinate in a 0.9 m wide RealityKit volume. X east, Y up, -Z north.
struct RadarVisualCoordinate: Sendable {
    let x: Double
    let y: Double
    let z: Double
}

/// WGS84 ellipsoid, Earth-centered Cartesian coordinates and East-North-Up coordinates.
enum Geodesy {
    static let semiMajorAxis = 6_378_137.0
    static let inverseFlattening = 298.257223563
    static let eccentricitySquared = 1 - pow(1 - 1 / inverseFlattening, 2)
    // Same ADS-B receiver position used by MeuLab on iPhone.
    static let approximateFranca = GeodeticCoordinate(latitudeDegrees: -20.512504, longitudeDegrees: -47.400830, altitudeMeters: 0)

    static func ecef(_ c: GeodeticCoordinate) -> CartesianCoordinate {
        let lat = c.latitudeDegrees * .pi / 180
        let lon = c.longitudeDegrees * .pi / 180
        let sinLat = sin(lat)
        let cosLat = cos(lat)
        let radius = semiMajorAxis / sqrt(1 - eccentricitySquared * sinLat * sinLat)
        return CartesianCoordinate(
            x: (radius + c.altitudeMeters) * cosLat * cos(lon),
            y: (radius + c.altitudeMeters) * cosLat * sin(lon),
            z: (radius * (1 - eccentricitySquared) + c.altitudeMeters) * sinLat
        )
    }

    static func enu(_ c: GeodeticCoordinate, relativeTo origin: GeodeticCoordinate) -> ENUCoordinate {
        let a = ecef(c)
        let b = ecef(origin)
        let dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z
        let lat = origin.latitudeDegrees * .pi / 180
        let lon = origin.longitudeDegrees * .pi / 180
        let sinLat = sin(lat), cosLat = cos(lat), sinLon = sin(lon), cosLon = cos(lon)
        return ENUCoordinate(
            east: -sinLon * dx + cosLon * dy,
            north: -sinLat * cosLon * dx - sinLat * sinLon * dy + cosLat * dz,
            up: cosLat * cosLon * dx + cosLat * sinLon * dy + sinLat * dz
        )
    }

    /// Deliberately non-uniform vertical exaggeration for a human-scale volume.
    /// The horizontal range spans 0.34 m in each direction; "Y" is not to that scale.
    static func visualPosition(enu: ENUCoordinate, displayedAltitudeMeters: Double,
                               radiusKilometers: Double, verticalExaggeration: Double) -> RadarVisualCoordinate? {
        guard radiusKilometers.isFinite, radiusKilometers > 0,
              verticalExaggeration.isFinite, verticalExaggeration > 0,
              displayedAltitudeMeters.isFinite else { return nil }
        let normalized = 0.34 / (radiusKilometers * 1000)
        return RadarVisualCoordinate(
            x: enu.east * normalized,
            y: -0.22 + min(0.44, max(0, displayedAltitudeMeters) / 16_000 * 0.24 * verticalExaggeration),
            z: -enu.north * normalized
        )
    }

    static func feetToMeters(_ feet: Double) -> Double { feet * 0.3048 }
    static func knotsToKilometersPerHour(_ knots: Double) -> Double { knots * 1.852 }
}
