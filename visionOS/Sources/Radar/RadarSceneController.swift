import Foundation
import RealityKit
import UIKit
import simd

/// Keeps a stable scene graph and reconciles entities incrementally by ICAO/hex.
@MainActor
final class RadarSceneController {
    let root = Entity()
    private let background = Entity()
    private let markerLayer = Entity()
    private let factory = AircraftEntityFactory()
    private var markers: [String: ModelEntity] = [:]
    private var stems: [String: ModelEntity] = [:]
    private var currentRadius: Double = -1
    private let groundY: Float = -0.22
    private let visualRadius: Float = 0.34

    init() {
        root.name = "radar-root"
        background.name = "radar-background"
        root.addChild(background)
        root.addChild(markerLayer)
    }

    func buildBackground(radiusKilometers: Double) {
        guard radiusKilometers != currentRadius else { return }
        currentRadius = radiusKilometers
        background.children.forEach { $0.removeFromParent() }

        let base = ModelEntity(
            mesh: .generateBox(size: [0.72, 0.018, 0.72]),
            materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.14), isMetallic: false)]
        )
        base.position = [0, groundY - 0.012, 0]
        background.addChild(base)

        for x in [-0.36 as Float, 0.36] {
            let edge = ModelEntity(
                mesh: .generateBox(size: [0.003, 0.02, 0.72]),
                materials: [SimpleMaterial(color: UIColor.cyan.withAlphaComponent(0.45), isMetallic: true)]
            )
            edge.position = [x, groundY - 0.01, 0]
            background.addChild(edge)
        }
        for z in [-0.36 as Float, 0.36] {
            let edge = ModelEntity(
                mesh: .generateBox(size: [0.72, 0.02, 0.003]),
                materials: [SimpleMaterial(color: UIColor.cyan.withAlphaComponent(0.45), isMetallic: true)]
            )
            edge.position = [0, groundY - 0.01, z]
            background.addChild(edge)
        }

        for fraction in [Float(0.25), Float(0.5), Float(0.75), Float(1.0)] {
            let radius = visualRadius * fraction
            let segments = 48
            for i in 0..<segments {
                let a = Float(i) * 2 * .pi / Float(segments)
                let b = Float(i + 1) * 2 * .pi / Float(segments)
                let p = SIMD3<Float>(radius * cos(a), groundY, radius * sin(a))
                let q = SIMD3<Float>(radius * cos(b), groundY, radius * sin(b))
                let delta = q - p
                let length = simd_length(delta)
                let segment = ModelEntity(
                    mesh: .generateBox(size: [0.0012, 0.0012, length]),
                    materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.7), isMetallic: false)]
                )
                segment.position = (p + q) / 2
                segment.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: simd_normalize(delta))
                background.addChild(segment)
            }
        }

        let eastWest = ModelEntity(mesh: .generateBox(size: [0.68, 0.001, 0.001]), materials: [SimpleMaterial(color: .systemGray3, isMetallic: false)])
        eastWest.position.y = groundY
        background.addChild(eastWest)
        let northSouth = ModelEntity(mesh: .generateBox(size: [0.001, 0.001, 0.68]), materials: [SimpleMaterial(color: .systemGray3, isMetallic: false)])
        northSouth.position.y = groundY
        background.addChild(northSouth)

        // North marker (not an absolute compass reading of the physical room).
        let north = ModelEntity(mesh: .generateBox(size: [0.014, 0.003, 0.026]), materials: [SimpleMaterial(color: .systemRed, isMetallic: false)])
        north.position = [0, groundY + 0.003, -visualRadius]
        background.addChild(north)
        let antenna = ModelEntity(mesh: .generateSphere(radius: 0.009), materials: [SimpleMaterial(color: .systemBlue, isMetallic: true)])
        antenna.position = [0, groundY + 0.01, 0]
        background.addChild(antenna)
    }

    func reconcile(aircraft: [Aircraft], selectedHex: String?, settings: RadarSettings, ageByHex: [String: Double]) {
        let newIDs = Set(aircraft.map(\.hex))
        for key in Array(markers.keys) where !newIDs.contains(key) {
            markers.removeValue(forKey: key)?.removeFromParent()
            stems.removeValue(forKey: key)?.removeFromParent()
        }

        for flight in aircraft {
            guard let lat = flight.latitude, let lon = flight.longitude else { continue }
            let entity: ModelEntity
            if let existing = markers[flight.hex] {
                entity = existing
            } else {
                entity = factory.make(hex: flight.hex)
                markers[flight.hex] = entity
                markerLayer.addChild(entity)
                let stem = ModelEntity(
                    mesh: .generateBox(size: [0.0015, 1, 0.0015]),
                    materials: [SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.65), isMetallic: false)]
                )
                stems[flight.hex] = stem
                markerLayer.addChild(stem)
            }
            let horizontalAltitude = flight.geometricAltitudeMeters ?? flight.altitudeMeters ?? 0
            let enu = Geodesy.enu(.init(latitudeDegrees: lat, longitudeDegrees: lon, altitudeMeters: horizontalAltitude), relativeTo: Geodesy.approximateFranca)
            let visual = Geodesy.visualPosition(
                enu: enu,
                displayedAltitudeMeters: flight.altitudeMeters ?? 0,
                radiusKilometers: settings.radiusKilometers,
                verticalExaggeration: settings.verticalExaggeration
            )
            guard let visual else { continue }
            entity.position = [Float(visual.x), Float(visual.y), Float(visual.z)]
            let track = Float(flight.trackDegrees ?? 0) * .pi / 180
            entity.orientation = simd_quatf(angle: -track, axis: [0, 1, 0])
            let isAging = (ageByHex[flight.hex] ?? 0) > 15
            factory.restyle(entity, selected: flight.hex == selectedHex, aging: isAging)
            if let stem = stems[flight.hex] {
                let height = max(0.001, Float(visual.y) - groundY)
                stem.position = [Float(visual.x), groundY + height / 2, Float(visual.z)]
                stem.scale = [1, height, 1]
                let color: UIColor = flight.hex == selectedHex ? .cyan : (isAging ? .systemOrange : .systemBlue)
                stem.model?.materials = [SimpleMaterial(color: color.withAlphaComponent(0.65), isMetallic: false)]
            }
        }
    }

    var markerCount: Int { markers.count }
}
