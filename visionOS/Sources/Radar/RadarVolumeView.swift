import RealityKit
import SwiftUI

struct RadarVolumeView: View {
    @Environment(FlightStore.self) private var store
    @State private var scene = RadarSceneController()
    @State private var mapSurface: RadarMapSurface?
    @State private var mapRevision = 0
    @State private var cloudSurface: RadarCloudSurface?
    @State private var cloudRevision = 0
    @State private var dragStartPosition: SIMD3<Float>?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            RealityView { content, attachments in
                scene.buildBackground(radiusKilometers: store.settings.radiusKilometers)
                scene.setMap(mapSurface, revision: mapRevision)
                scene.setClouds(cloudSurface, revision: cloudRevision)
                scene.reconcile(
                    aircraft: store.renderableAircraft(at: timeline.date),
                    selectedHex: store.selectedHex,
                    settings: store.settings,
                    ageByHex: positionAges(at: timeline.date)
                )
                scene.updateSelectedTrail(
                    points: store.tracks[store.selectedHex ?? ""] ?? [],
                    selectedHex: store.selectedHex,
                    revision: store.trackRevision,
                    settings: store.settings,
                    visible: store.showTrails
                )
                content.add(scene.root)
                placeLabels(attachments: attachments, content: content, at: timeline.date)
            } update: { content, attachments in
                // SwiftUI tracks store accesses in the update closure, so this is
                // invoked when aircraft, settings or the selection changes.
                scene.buildBackground(radiusKilometers: store.settings.radiusKilometers)
                scene.setMap(mapSurface, revision: mapRevision)
                scene.setClouds(cloudSurface, revision: cloudRevision)
                scene.reconcile(
                    aircraft: store.renderableAircraft(at: timeline.date),
                    selectedHex: store.selectedHex,
                    settings: store.settings,
                    ageByHex: positionAges(at: timeline.date)
                )
                scene.updateSelectedTrail(
                    points: store.tracks[store.selectedHex ?? ""] ?? [],
                    selectedHex: store.selectedHex,
                    revision: store.trackRevision,
                    settings: store.settings,
                    visible: store.showTrails
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
                    if dragStartPosition == nil { dragStartPosition = scene.root.position }
                    let movement = value.convert(value.translation3D, from: .global, to: .scene)
                    let start = dragStartPosition ?? .zero
                    scene.root.position = [
                        min(0.18, max(-0.18, start.x + movement.x)),
                        min(0.25, max(-0.25, start.y + movement.y)),
                        start.z
                    ]
                }
                .onEnded { _ in dragStartPosition = nil })
        }
        .onAppear { store.isVolumeOpen = true }
        .onDisappear { store.isVolumeOpen = false }
        .task { store.start() }
        .task(id: "\(store.settings.radiusKilometers)-\(store.mapStyle.rawValue)") {
            mapSurface = nil
            mapRevision += 1
            do {
                let result = try await RadarMapSnapshot.surface(
                    radiusKilometers: store.settings.radiusKilometers,
                    style: store.mapStyle
                )
                guard !Task.isCancelled else { return }
                mapSurface = result
                mapRevision += 1
            } catch {
                // Real DEM relief and radar grid remain available if MapKit cannot load.
            }
        }
        .task(id: "\(store.settings.radiusKilometers)-\(store.showClouds)") {
            cloudSurface = nil
            cloudRevision += 1
            store.cloudCapturedAt = nil
            store.cloudError = nil
            guard store.showClouds else { return }
            while !Task.isCancelled {
                do {
                    let result = try await RadarCloudSnapshot.surface(radiusKilometers: store.settings.radiusKilometers)
                    guard !Task.isCancelled else { return }
                    cloudSurface = result
                    cloudRevision += 1
                    store.cloudCapturedAt = result.capturedAt
                    store.cloudError = nil
                    try await Task.sleep(for: .seconds(600))
                } catch {
                    guard !Task.isCancelled else { return }
                    cloudSurface = nil
                    cloudRevision += 1
                    store.cloudCapturedAt = nil
                    store.cloudError = error.localizedDescription
                    try? await Task.sleep(for: .seconds(120))
                }
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
            guard flight.latitude != nil, flight.longitude != nil,
                  let label = attachments.entity(for: flight.hex) else { continue }
            guard let position = scene.markerPosition(for: flight.hex) else { continue }
            label.position = position + [0.035, 0.035, 0]
            if label.parent == nil { scene.root.addChild(label) }
        }
    }
}
