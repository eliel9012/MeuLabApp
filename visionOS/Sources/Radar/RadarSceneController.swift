import Foundation
import RealityKit
import UIKit
import simd

/// Keeps a stable scene graph and reconciles entities incrementally by ICAO/hex.
@MainActor
final class RadarSceneController {
    let root = Entity()
    let tableSurface = ModelEntity(
        mesh: .generateBox(size: [RadarVisualGeometry.tableWidth, 0.024, RadarVisualGeometry.tableWidth]),
        materials: [SimpleMaterial(color: UIColor.white.withAlphaComponent(0.14), isMetallic: false)]
    )
    private let background = Entity()
    private let markerLayer = Entity()
    private let trailLayer = Entity()
    private let factory = AircraftEntityFactory()
    private var markers: [String: ModelEntity] = [:]
    private var stems: [String: ModelEntity] = [:]
    private var terrainSurface: ModelEntity?
    private var currentRadius: Double = -1
    private var currentMapRevision = -1
    private var currentTrailKey = ""
    private let groundY = RadarVisualGeometry.groundY
    private let visualRadius = RadarVisualGeometry.mapRadius

    init() {
        root.name = "radar-root"
        background.name = "radar-background"
        tableSurface.name = "radar-table"
        tableSurface.position = [0, groundY - 0.012, 0]
        tableSurface.components.set(InputTargetComponent())
        tableSurface.components.set(CollisionComponent(shapes: [.generateBox(size: [RadarVisualGeometry.tableWidth, 0.03, RadarVisualGeometry.tableWidth])]))
        let grabber = ModelEntity(
            mesh: .generateBox(size: [0.18, 0.014, 0.03]),
            materials: [SimpleMaterial(color: UIColor.cyan.withAlphaComponent(0.75), isMetallic: true)]
        )
        grabber.name = "radar-table-grabber"
        grabber.position = [0, 0.019, 0.56]
        grabber.components.set(CollisionComponent(shapes: [.generateBox(size: [0.18, 0.025, 0.04])]))
        tableSurface.addChild(grabber)
        root.addChild(background)
        root.addChild(tableSurface)
        root.addChild(trailLayer)
        root.addChild(markerLayer)
    }

    func buildBackground(radiusKilometers: Double) {
        guard radiusKilometers != currentRadius else { return }
        currentRadius = radiusKilometers
        background.children.forEach { $0.removeFromParent() }
        terrainSurface = nil
        currentMapRevision = -1

        let halfTable = RadarVisualGeometry.tableWidth / 2
        for x in [-halfTable, halfTable] {
            let edge = ModelEntity(
                mesh: .generateBox(size: [0.004, 0.026, RadarVisualGeometry.tableWidth]),
                materials: [SimpleMaterial(color: UIColor.cyan.withAlphaComponent(0.45), isMetallic: true)]
            )
            edge.position = [x, groundY - 0.01, 0]
            background.addChild(edge)
        }
        for z in [-halfTable, halfTable] {
            let edge = ModelEntity(
                mesh: .generateBox(size: [RadarVisualGeometry.tableWidth, 0.026, 0.004]),
                materials: [SimpleMaterial(color: UIColor.cyan.withAlphaComponent(0.45), isMetallic: true)]
            )
            edge.position = [0, groundY - 0.01, z]
            background.addChild(edge)
        }

        for fraction in [Float(0.25), Float(0.5), Float(0.75), Float(1.0)] {
            let radius = visualRadius * fraction
            let outerRing = fraction == 1.0
            let segments = 48
            for i in 0..<segments {
                let a = Float(i) * 2 * .pi / Float(segments)
                let b = Float(i + 1) * 2 * .pi / Float(segments)
                let px = radius * cos(a), pz = radius * sin(a)
                let qx = radius * cos(b), qz = radius * sin(b)
                let p = SIMD3<Float>(px, surfaceY(x: px, z: pz) + 0.005, pz)
                let q = SIMD3<Float>(qx, surfaceY(x: qx, z: qz) + 0.005, qz)
                let delta = q - p
                let length = simd_length(delta)
                let segment = ModelEntity(
                    mesh: .generateBox(size: [outerRing ? 0.0028 : 0.0015,
                                              outerRing ? 0.0028 : 0.0015, length]),
                    materials: [SimpleMaterial(color: (outerRing ? UIColor.cyan : UIColor.white)
                        .withAlphaComponent(outerRing ? 0.9 : 0.5), isMetallic: false)]
                )
                segment.position = (p + q) / 2
                segment.orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: simd_normalize(delta))
                background.addChild(segment)
            }
        }

        // North marker (not an absolute compass reading of the physical room).
        let north = ModelEntity(mesh: .generateBox(size: [0.014, 0.003, 0.026]), materials: [SimpleMaterial(color: .systemRed, isMetallic: false)])
        north.position = [0, surfaceY(x: 0, z: -visualRadius) + 0.012, -visualRadius]
        background.addChild(north)
        let antenna = ModelEntity(mesh: .generateSphere(radius: 0.009), materials: [SimpleMaterial(color: .systemBlue, isMetallic: true)])
        antenna.position = [0, surfaceY(x: 0, z: 0) + 0.014, 0]
        background.addChild(antenna)
    }

    func setMap(_ surface: RadarMapSurface?, revision: Int) {
        guard currentMapRevision != revision else { return }
        currentMapRevision = revision
        terrainSurface?.removeFromParent()
        terrainSurface = nil
        if let terrain = RadarTerrain.shared {
            let textureCoordinates = surface?.textureCoordinates
            guard let mesh = try? terrain.mesh(radiusKilometers: currentRadius,
                                               textureCoordinates: textureCoordinates) else { return }
            let material: any Material
            if let surface {
                var mapped = SimpleMaterial(color: .white, isMetallic: false)
                mapped.color = .init(tint: .white, texture: .init(surface.texture))
                material = mapped
            } else {
                material = SimpleMaterial(color: UIColor.systemGray2, isMetallic: false)
            }
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.name = "franca-terrain"
            background.addChild(entity)
            terrainSurface = entity
        } else if let surface {
            let plane = ModelEntity(
                mesh: .generatePlane(width: visualRadius * 2, depth: visualRadius * 2),
                materials: [UnlitMaterial(texture: surface.texture)]
            )
            plane.position = [0, groundY + 0.002, 0]
            background.addChild(plane)
            terrainSurface = plane
        }
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
                entity = factory.make(aircraft: flight)
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
            let terrainY = surfaceY(x: Float(visual.x), z: Float(visual.z))
            entity.position = [Float(visual.x), max(Float(visual.y), terrainY + 0.016), Float(visual.z)]
            let track = Float(flight.trackDegrees ?? 0) * .pi / 180
            entity.orientation = simd_quatf(angle: -track, axis: [0, 1, 0])
            let isAging = (ageByHex[flight.hex] ?? 0) > 15
            factory.restyle(entity, selected: flight.hex == selectedHex, aging: isAging)
            if let stem = stems[flight.hex] {
                let height = max(0.001, entity.position.y - terrainY)
                stem.position = [Float(visual.x), terrainY + height / 2, Float(visual.z)]
                stem.scale = [1, height, 1]
                let color: UIColor = flight.hex == selectedHex ? .cyan : (isAging ? .systemOrange : .systemBlue)
                stem.model?.materials = [SimpleMaterial(color: color.withAlphaComponent(0.65), isMetallic: false)]
            }
        }
    }

    func updateSelectedTrail(points: [FlightTrackPoint], selectedHex: String?, revision: Int,
                             settings: RadarSettings, visible: Bool) {
        let key = "\(selectedHex ?? "")-\(revision)-\(settings.radiusKilometers)-\(settings.verticalExaggeration)-\(visible)"
        guard key != currentTrailKey else { return }
        currentTrailKey = key
        trailLayer.children.forEach { $0.removeFromParent() }
        guard visible, points.count >= 2 else { return }
        let positions: [SIMD3<Float>] = points.compactMap { point in
            let coordinate = GeodeticCoordinate(latitudeDegrees: point.latitude,
                                                longitudeDegrees: point.longitude,
                                                altitudeMeters: point.altitudeMeters)
            let enu = Geodesy.enu(coordinate, relativeTo: Geodesy.approximateFranca)
            guard enu.horizontalDistanceMeters <= settings.radiusKilometers * 1_000,
                  let visual = Geodesy.visualPosition(
                    enu: enu, displayedAltitudeMeters: point.altitudeMeters,
                    radiusKilometers: settings.radiusKilometers,
                    verticalExaggeration: settings.verticalExaggeration
                  ) else { return nil }
            let x = Float(visual.x), z = Float(visual.z)
            return [x, max(Float(visual.y), surfaceY(x: x, z: z) + 0.018), z]
        }
        for (start, end) in zip(positions, positions.dropFirst()) {
            let delta = end - start
            let length = simd_length(delta)
            guard length > 0.001 else { continue }
            let segment = ModelEntity(
                mesh: .generateBox(size: [0.0018, 0.0018, length]),
                materials: [SimpleMaterial(color: UIColor.cyan.withAlphaComponent(0.75), isMetallic: false)]
            )
            segment.position = (start + end) / 2
            segment.orientation = simd_quatf(from: [0, 0, 1], to: simd_normalize(delta))
            trailLayer.addChild(segment)
        }
    }

    var markerCount: Int { markers.count }

    func markerPosition(for hex: String) -> SIMD3<Float>? { markers[hex]?.position }

    private func surfaceY(x: Float, z: Float) -> Float {
        guard let terrain = RadarTerrain.shared, currentRadius > 0 else { return groundY }
        return terrain.surfaceY(x: x, z: z, radiusKilometers: currentRadius)
    }
}
