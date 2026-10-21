import RealityKit
import UIKit

/// Lightweight procedural aircraft symbols; local forward is -Z (north when track == 0).
@MainActor
final class AircraftEntityFactory {
    private let fuselageMesh = MeshResource.generateBox(size: [0.012, 0.006, 0.045])
    private let wingMesh = MeshResource.generateBox(size: [0.055, 0.003, 0.010])
    private let tailMesh = MeshResource.generateBox(size: [0.025, 0.004, 0.007])
    private let regular = SimpleMaterial(color: .systemBlue, isMetallic: true)
    private let aging = SimpleMaterial(color: .systemOrange, isMetallic: true)
    private let active = SimpleMaterial(color: .cyan, isMetallic: true)

    func make(hex: String) -> ModelEntity {
        let model = ModelEntity(mesh: fuselageMesh, materials: [regular])
        model.name = "flight:\(hex)"
        model.components.set(InputTargetComponent())
        // Larger invisible interaction envelope for comfortable gaze + pinch targets.
        model.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.043)]))

        let wings = ModelEntity(mesh: wingMesh, materials: [regular])
        wings.position = [0, 0, -0.004]
        model.addChild(wings)
        let tail = ModelEntity(mesh: tailMesh, materials: [regular])
        tail.position = [0, 0.002, 0.016]
        model.addChild(tail)
        return model
    }

    func restyle(_ model: ModelEntity, selected: Bool, aging: Bool) {
        let material = selected ? active : (aging ? self.aging : regular)
        model.model?.materials = [material]
        for child in model.children {
            if let wing = child as? ModelEntity { wing.model?.materials = [material] }
        }
        model.scale = SIMD3<Float>(repeating: selected ? 1.35 : 1.0)
    }
}
