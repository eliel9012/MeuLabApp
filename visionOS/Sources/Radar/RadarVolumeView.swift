import RealityKit
import SwiftUI

struct RadarVolumeView: View {
    @Environment(FlightStore.self) private var store
    @State private var scene = RadarSceneController()
    @State private var mapTexture: TextureResource?
    @State private var dragStartY: Float?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            RealityView { content, attachments in
                scene.buildBackground(radiusKilometers: store.settings.radiusKilometers)
                scene.setMap(mapTexture)
                scene.reconcile(
                    aircraft: store.renderableAircraft(at: timeline.date),
                    selectedHex: store.selectedHex,
                    settings: store.settings,
                    ageByHex: positionAges(at: timeline.date)
                )
                content.add(scene.root)
                placeLabels(attachments: attachments, content: content, at: timeline.date)
            } update: { content, attachments in
                // SwiftUI tracks store accesses in the update closure, so this is
                // invoked when aircraft, settings or the selection changes.
                scene.buildBackground(radiusKilometers: store.settings.radiusKilometers)
                scene.setMap(mapTexture)
                scene.reconcile(
                    aircraft: store.renderableAircraft(at: timeline.date),
                    selectedHex: store.selectedHex,
                    settings: store.settings,
                    ageByHex: positionAges(at: timeline.date)
                )
                placeLabels(attachments: attachments, content: content, at: timeline.date)
            } attachments: {
                ForEach(store.renderableAircraft(at: timeline.date)) { flight in
                    Attachment(id: flight.hex) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(flight.callsign)
                                .font(.caption.bold())
                                .foregroundStyle(store.selectedHex == flight.hex ? .cyan : .primary)
                            Text(flight.altitudeFeet.map { "\(Int($0).formatted()) ft" } ?? "—")
                            Text(flight.speedKilometersPerHour.map { "\(Int($0).formatted()) km/h" } ?? "—")
                            Text(flight.trackDegrees.map { "\(Int($0))°" } ?? "—")
                        }
                        .font(.caption2)
                        .monospacedDigit()
                        .padding(8)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(TapGesture().targetedToAnyEntity().onEnded { value in
                guard value.entity.name.hasPrefix("flight:") else { return }
                store.selectedHex = String(value.entity.name.dropFirst("flight:".count))
            })
            .gesture(DragGesture(coordinateSpace: .global).targetedToEntity(scene.tableSurface)
                .onChanged { value in
                    if dragStartY == nil { dragStartY = scene.root.position.y }
                    let movement = value.convert(value.translation3D, from: .global, to: .scene)
                    scene.root.position.y = min(0.25, max(-0.25, (dragStartY ?? 0) + movement.y))
                }
                .onEnded { _ in dragStartY = nil })
        }
        .onAppear { store.isVolumeOpen = true }
        .onDisappear { store.isVolumeOpen = false }
        .task { store.start() }
        .task(id: store.settings.radiusKilometers) {
            mapTexture = nil
            do {
                mapTexture = try await RadarMapSnapshot.texture(radiusKilometers: store.settings.radiusKilometers)
            } catch {
                // The radar grid remains available if MapKit cannot load.
            }
        }
    }

    private func positionAges(at date: Date) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: store.aircraft.compactMap { aircraft in
            store.ageOfPosition(aircraft, at: date).map { (aircraft.hex, $0) }
        })
    }

    private func placeLabels(attachments: RealityViewAttachments, content: RealityViewContent, at date: Date) {
        for flight in store.renderableAircraft(at: date) {
            guard let lat = flight.latitude, let lon = flight.longitude,
                  let label = attachments.entity(for: flight.hex) else { continue }
            let coordinate = GeodeticCoordinate(
                latitudeDegrees: lat,
                longitudeDegrees: lon,
                altitudeMeters: flight.geometricAltitudeMeters ?? flight.altitudeMeters ?? 0
            )
            let enu = Geodesy.enu(coordinate, relativeTo: Geodesy.approximateFranca)
            guard let visual = Geodesy.visualPosition(
                enu: enu,
                displayedAltitudeMeters: flight.altitudeMeters ?? 0,
                radiusKilometers: store.settings.radiusKilometers,
                verticalExaggeration: store.settings.verticalExaggeration
            ) else { continue }
            label.position = [Float(visual.x) + 0.035, Float(visual.y) + 0.035, Float(visual.z)]
            if label.parent == nil { scene.root.addChild(label) }
        }
    }
}
