import RealityKit
import UIKit
import simd

/// Detailed, lightweight 3D aircraft. Local forward is -Z (north at track 0).
@MainActor
final class AircraftEntityFactory {
    private let fuselage = MeshResource.generateCylinder(height: 0.052, radius: 0.0046)
    private let nose = MeshResource.generateCone(height: 0.014, radius: 0.0046)
    private let tailCone = MeshResource.generateCone(height: 0.011, radius: 0.0043)
    private let wing = MeshResource.generateBox(size: [0.034, 0.0018, 0.009])
    private let stabilizer = MeshResource.generateBox(size: [0.019, 0.0015, 0.005])
    private let fin = MeshResource.generateBox(size: [0.002, 0.013, 0.011])
    private let engine = MeshResource.generateCylinder(height: 0.014, radius: 0.003)
    private let canopy = MeshResource.generateSphere(radius: 0.004)
    private let light = MeshResource.generateSphere(radius: 0.0018)
    private let propeller = MeshResource.generateBox(size: [0.001, 0.018, 0.001])

    private let regular = SimpleMaterial(color: UIColor(red: 0.27, green: 0.68, blue: 1, alpha: 1), isMetallic: true)
    private let aging = SimpleMaterial(color: .systemOrange, isMetallic: true)
    private let active = SimpleMaterial(color: .cyan, isMetallic: true)
    private let glass = SimpleMaterial(color: UIColor(red: 0.04, green: 0.14, blue: 0.22, alpha: 1), isMetallic: true)
    private let motor = SimpleMaterial(color: .darkGray, isMetallic: true)

    func make(aircraft: Aircraft) -> ModelEntity {
        let model = ModelEntity()
        model.name = "flight:\(aircraft.hex)"
        model.addChild(part(fuselage, [0, 0, 0], rotation: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]), painted: true))
        model.addChild(part(nose, [0, 0, -0.033], rotation: simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]), painted: true))
        model.addChild(part(tailCone, [0, 0, 0.031], rotation: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]), painted: true))

        let isProp = isPropellerAircraft(aircraft.aircraftType)
        for side: Float in [-1, 1] {
            let wingPart = part(wing, [side * 0.018, 0, isProp ? -0.004 : 0.001],
                                rotation: simd_quatf(angle: side * (isProp ? -0.08 : -0.23), axis: [0, 1, 0]), painted: true)
            model.addChild(wingPart)
            model.addChild(part(stabilizer, [side * 0.009, 0.002, 0.023],
                                rotation: simd_quatf(angle: side * -0.17, axis: [0, 1, 0]), painted: true))
            let motorPart = part(engine, [side * 0.014, -0.004, isProp ? -0.010 : 0.000],
                                 rotation: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]), painted: false)
            motorPart.model?.materials = [motor]
            model.addChild(motorPart)
            if isProp {
                let blade = part(propeller, [side * 0.014, -0.004, -0.019], painted: false)
                blade.model?.materials = [motor]
                model.addChild(blade)
            }
            let tip = part(light, [side * 0.034, 0.001, 0.005], painted: false)
            tip.model?.materials = [SimpleMaterial(color: side < 0 ? .systemRed : .systemGreen, isMetallic: false)]
            model.addChild(tip)
        }
        model.addChild(part(fin, [0, 0.008, 0.023], painted: true))
        let cockpit = part(canopy, [0, 0.003, -0.024], painted: false)
        cockpit.scale = [1, 0.45, 1.8]
        cockpit.model?.materials = [glass]
        model.addChild(cockpit)

        model.components.set(InputTargetComponent())
        model.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.047)]))
        return model
    }

    func restyle(_ model: ModelEntity, selected: Bool, aging: Bool) {
        let material = selected ? active : (aging ? self.aging : regular)
        for child in model.children where child.name == "paint" {
            (child as? ModelEntity)?.model?.materials = [material]
        }
        model.scale = SIMD3<Float>(repeating: selected ? 1.25 : 1)
    }

    private func part(_ mesh: MeshResource, _ position: SIMD3<Float>,
                      rotation: simd_quatf = simd_quatf(), painted: Bool) -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [regular])
        entity.name = painted ? "paint" : "detail"
        entity.position = position
        entity.orientation = rotation
        return entity
    }

    private func isPropellerAircraft(_ type: String?) -> Bool {
        guard let type = type?.uppercased() else { return false }
        return ["C1", "C2", "C3", "BE", "PA", "PC", "AT", "DH8", "E12", "SF3"].contains { type.hasPrefix($0) }
    }
}
