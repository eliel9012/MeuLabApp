import RealityKit
import UIKit
import simd

/// Lightweight aircraft silhouettes built from shared procedural meshes. Forward is -Z.
@MainActor
final class AircraftEntityFactory {
    private let jetFuselage = MeshResource.generateCylinder(height: 0.054, radius: 0.0045)
    private let propFuselage = MeshResource.generateCylinder(height: 0.046, radius: 0.005)
    private let jetNose = MeshResource.generateCone(height: 0.015, radius: 0.0045)
    private let propNose = MeshResource.generateCone(height: 0.011, radius: 0.005)
    private let tailCone = MeshResource.generateCone(height: 0.012, radius: 0.0043)
    private let fin = MeshResource.generateBox(size: [0.0018, 0.016, 0.012])
    private let jetEngine = MeshResource.generateCylinder(height: 0.016, radius: 0.0036)
    private let propEngine = MeshResource.generateCylinder(height: 0.013, radius: 0.004)
    private let canopy = MeshResource.generateSphere(radius: 0.0043)
    private let window = MeshResource.generateSphere(radius: 0.00115)
    private let light = MeshResource.generateSphere(radius: 0.0018)
    private let winglet = MeshResource.generateBox(size: [0.0012, 0.006, 0.003])
    private let flap = MeshResource.generateBox(size: [0.023, 0.0007, 0.0015])
    private let propellerBlade = MeshResource.generateBox(size: [0.0011, 0.010, 0.0006])
    private let propellerHub = MeshResource.generateSphere(radius: 0.002)
    private var wingMeshes: [String: MeshResource] = [:]

    private let regular = SimpleMaterial(color: UIColor(red: 0.27, green: 0.68, blue: 1, alpha: 1), isMetallic: true)
    private let aging = SimpleMaterial(color: .systemOrange, isMetallic: true)
    private let active = SimpleMaterial(color: .cyan, isMetallic: true)
    private let glass = SimpleMaterial(color: UIColor(red: 0.04, green: 0.14, blue: 0.22, alpha: 1), isMetallic: true)
    private let motor = SimpleMaterial(color: .darkGray, isMetallic: true)
    private let intake = SimpleMaterial(color: .black, isMetallic: false)
    private let flapPaint = SimpleMaterial(color: UIColor(red: 0.12, green: 0.28, blue: 0.38, alpha: 1), isMetallic: true)

    func make(aircraft: Aircraft) -> ModelEntity {
        let model = ModelEntity()
        model.name = "flight:\(aircraft.hex)"
        let prop = isPropellerAircraft(aircraft.aircraftType)
        let cylinderRotation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        let noseRotation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        model.addChild(part(prop ? propFuselage : jetFuselage, [0, 0, 0], rotation: cylinderRotation, painted: true))
        model.addChild(part(prop ? propNose : jetNose, [0, 0, prop ? -0.028 : -0.034], rotation: noseRotation, painted: true))
        model.addChild(part(tailCone, [0, 0, prop ? 0.028 : 0.031], rotation: cylinderRotation, painted: true))

        for side: Float in [-1, 1] {
            model.addChild(part(wingMesh(side: side, prop: prop, tail: false), .zero, painted: true))
            model.addChild(part(wingMesh(side: side, prop: prop, tail: true), .zero, painted: true))
            addEngine(to: model, side: side, prop: prop, rotation: cylinderRotation)

            let tip = part(light, [side * (prop ? 0.043 : 0.041), 0.002, prop ? -0.009 : 0.006], painted: false)
            tip.model?.materials = [SimpleMaterial(color: side < 0 ? .systemRed : .systemGreen, isMetallic: false)]
            model.addChild(tip)
            if !prop {
                model.addChild(detail(winglet, [side * 0.040, 0.004, 0.006], material: regular))
            }
            let trailing = part(flap, [side * 0.024, 0.001, prop ? 0.001 : 0.009], painted: false)
            trailing.model?.materials = [flapPaint]
            trailing.orientation = simd_quatf(angle: side * (prop ? -0.09 : 0.22), axis: [0, 1, 0])
            model.addChild(trailing)

            // Cabin windows stay dark when the aircraft color changes with selection or age.
            for row in 0..<5 {
                model.addChild(detail(window, [side * (prop ? 0.0048 : 0.0043), 0.0019,
                                                -0.016 + Float(row) * 0.008], material: glass))
            }
        }

        let verticalTail = part(fin, [0, 0.009, prop ? 0.025 : 0.027], painted: true)
        verticalTail.orientation = simd_quatf(angle: -0.22, axis: [1, 0, 0])
        model.addChild(verticalTail)
        let cockpit = detail(canopy, [0, 0.003, prop ? -0.024 : -0.027], material: glass)
        cockpit.scale = [1, 0.42, prop ? 1.35 : 1.7]
        model.addChild(cockpit)
        model.addChild(detail(light, [0, 0.006, 0.008], material: SimpleMaterial(color: .systemRed, isMetallic: false)))

        model.components.set(InputTargetComponent())
        model.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.055)]))
        return model
    }

    func restyle(_ model: ModelEntity, selected: Bool, aging: Bool) {
        let material = selected ? active : (aging ? self.aging : regular)
        for child in model.children where child.name == "paint" {
            (child as? ModelEntity)?.model?.materials = [material]
        }
        model.scale = SIMD3<Float>(repeating: selected ? 1.4 : 1.15)
    }

    private func addEngine(to model: ModelEntity, side: Float, prop: Bool, rotation: simd_quatf) {
        let x = side * (prop ? 0.017 : 0.015)
        let y: Float = prop ? 0.000 : -0.004
        let z: Float = prop ? -0.014 : 0.003
        model.addChild(detail(prop ? propEngine : jetEngine, [x, y, z], rotation: rotation, material: motor))
        model.addChild(detail(propellerHub, [x, y, z - (prop ? 0.008 : 0.010)], material: intake))
        guard prop else { return }
        for angle in [Float(0), .pi / 2, .pi, 3 * .pi / 2] {
            let blade = detail(propellerBlade, [x, y, z - 0.011], material: motor)
            blade.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
            blade.position.x += sin(angle) * 0.005
            blade.position.y += cos(angle) * 0.005
            model.addChild(blade)
        }
    }

    private func part(_ mesh: MeshResource, _ position: SIMD3<Float>,
                      rotation: simd_quatf = simd_quatf(), painted: Bool) -> ModelEntity {
        let entity = ModelEntity(mesh: mesh, materials: [regular])
        entity.name = painted ? "paint" : "detail"
        entity.position = position
        entity.orientation = rotation
        return entity
    }

    private func detail(_ mesh: MeshResource, _ position: SIMD3<Float>,
                        rotation: simd_quatf = simd_quatf(), material: SimpleMaterial) -> ModelEntity {
        let entity = part(mesh, position, rotation: rotation, painted: false)
        entity.model?.materials = [material]
        return entity
    }

    private func wingMesh(side: Float, prop: Bool, tail: Bool) -> MeshResource {
        let key = "\(side)-\(prop)-\(tail)"
        if let cached = wingMeshes[key] { return cached }
        let outline: [SIMD2<Float>]
        if tail {
            outline = [[0.002, 0.020], [0.002, 0.033], [0.021, 0.033], [0.021, 0.028]]
        } else if prop {
            outline = [[0.003, -0.018], [0.003, 0.006], [0.043, -0.005], [0.043, -0.013]]
        } else {
            outline = [[0.003, -0.014], [0.003, 0.012], [0.041, 0.009], [0.041, 0.003]]
        }
        var ring = outline.map { SIMD2<Float>(side * $0.x, $0.y) }
        if side < 0 { ring.reverse() }
        let halfThickness: Float = tail ? 0.0008 : 0.0012
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        func addQuad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
            let base = UInt32(vertices.count)
            let normal = simd_normalize(simd_cross(b - a, c - a))
            vertices.append(contentsOf: [a, b, c, d])
            normals.append(contentsOf: Array(repeating: normal, count: 4))
            indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
        }
        let top = ring.map { SIMD3<Float>($0.x, halfThickness, $0.y) }
        let bottom = ring.map { SIMD3<Float>($0.x, -halfThickness, $0.y) }
        addQuad(top[0], top[1], top[2], top[3])
        addQuad(bottom[3], bottom[2], bottom[1], bottom[0])
        for index in 0..<4 {
            let next = (index + 1) % 4
            addQuad(top[index], bottom[index], bottom[next], top[next])
        }
        var descriptor = MeshDescriptor(name: tail ? "stabilizer" : "wing")
        descriptor.positions = .init(vertices)
        descriptor.normals = .init(normals)
        descriptor.primitives = .triangles(indices)
        let mesh = (try? MeshResource.generate(from: [descriptor]))
            ?? .generateBox(size: [tail ? 0.020 : 0.040, 0.002, 0.010])
        wingMeshes[key] = mesh
        return mesh
    }

    private func isPropellerAircraft(_ type: String?) -> Bool {
        guard let type = type?.uppercased() else { return false }
        return ["C1", "C2", "C3", "BE", "PA", "PC", "AT", "DH8", "E12", "SF3"].contains { type.hasPrefix($0) }
    }
}
