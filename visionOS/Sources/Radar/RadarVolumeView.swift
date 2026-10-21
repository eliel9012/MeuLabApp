import RealityKit
import SwiftUI

struct RadarVolumeView: View {
    @Environment(FlightStore.self) private var store
    @State private var scene = RadarSceneController()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            RealityView { content, attachments in
                scene.buildBackground(radiusKilometers: store.settings.radiusKilometers)
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
        }
        .onAppear { store.isVolumeOpen = true }
        .onDisappear { store.isVolumeOpen = false }
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
            if label.parent == nil { content.add(label) }
        }
    }
}

/// Window preview keeps the live radar visible beside Mission Control.
/// The separate RealityKit volume remains available through Radar 3D.
struct RadarPreviewView: View {
    @Environment(FlightStore.self) private var store

    var body: some View {
        TimelineView(.periodic(from: .now, by: 5)) { timeline in
            GeometryReader { geometry in
                ZStack {
                    grid(size: geometry.size)

                    ForEach(store.renderableAircraft(at: timeline.date)) { flight in
                        if let point = radarPoint(for: flight, size: geometry.size) {
                            let aging = (store.ageOfPosition(flight, at: timeline.date) ?? 0) > 15
                            let tint: Color = store.selectedHex == flight.hex ? .cyan : (aging ? .orange : .blue)

                            Path { path in
                                path.move(to: point.ground)
                                path.addLine(to: point.aircraft)
                            }
                            .stroke(tint.opacity(0.72), style: StrokeStyle(lineWidth: 1.5, dash: [3, 4]))

                            Circle()
                                .fill(tint)
                                .frame(width: 6, height: 6)
                                .position(point.ground)

                            Button {
                                store.selectedHex = flight.hex
                            } label: {
                                Image(systemName: "airplane")
                                    .font(.system(size: store.selectedHex == flight.hex ? 30 : 25, weight: .bold))
                                    .rotationEffect(.degrees((flight.trackDegrees ?? 0) - 45))
                                    .foregroundStyle(tint)
                                    .shadow(color: tint.opacity(0.8), radius: 8)
                            }
                            .buttonStyle(.plain)
                            .position(point.aircraft)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(flight.callsign)
                                    .font(.caption.bold())
                                    .foregroundStyle(tint)
                                Text(flight.altitudeFeet.map { "\(Int($0).formatted()) ft" } ?? "—")
                                Text(flight.speedKilometersPerHour.map { "\(Int($0).formatted()) km/h" } ?? "—")
                                Text(flight.trackDegrees.map { "\(Int($0))°" } ?? "—")
                            }
                            .font(.caption2)
                            .monospacedDigit()
                            .padding(9)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(tint.opacity(0.45)))
                            .fixedSize()
                            .position(x: point.aircraft.x + 62, y: point.aircraft.y - 28)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func grid(size: CGSize) -> some View {
        Canvas { context, _ in
            let width = size.width * 0.92
            let height = size.height * 0.26
            let left = (size.width - width) / 2
            let top = size.height * 0.66
            let center = CGPoint(x: size.width / 2, y: top + height * 0.49)

            var base = Path()
            base.move(to: CGPoint(x: left + width * 0.10, y: top))
            base.addLine(to: CGPoint(x: left + width * 0.90, y: top))
            base.addLine(to: CGPoint(x: left + width, y: top + height))
            base.addLine(to: CGPoint(x: left, y: top + height))
            base.closeSubpath()
            context.fill(base, with: .color(.white.opacity(0.12)))
            context.stroke(base, with: .color(.white.opacity(0.5)), lineWidth: 2)

            for fraction in [0.25, 0.5, 0.75, 1.0] {
                let ellipse = Path(ellipseIn: CGRect(
                    x: center.x - width * 0.44 * fraction,
                    y: center.y - height * 0.39 * fraction,
                    width: width * 0.88 * fraction,
                    height: height * 0.78 * fraction
                ))
                context.stroke(ellipse, with: .color(.white.opacity(0.52)), lineWidth: 1)
            }

            var axes = Path()
            axes.move(to: CGPoint(x: left + width * 0.06, y: center.y))
            axes.addLine(to: CGPoint(x: left + width * 0.94, y: center.y))
            axes.move(to: CGPoint(x: center.x, y: top + height * 0.10))
            axes.addLine(to: CGPoint(x: center.x, y: top + height * 0.94))
            context.stroke(axes, with: .color(.white.opacity(0.35)), lineWidth: 1)

            context.fill(Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)), with: .color(.blue))
            context.draw(Text("N").font(.caption.bold()).foregroundColor(.red), at: CGPoint(x: center.x, y: top - 12))
            context.draw(Text("W").font(.caption).foregroundColor(.white), at: CGPoint(x: left + 15, y: center.y))
            context.draw(Text("E").font(.caption).foregroundColor(.white), at: CGPoint(x: left + width - 15, y: center.y))
            context.draw(Text("S").font(.caption).foregroundColor(.white), at: CGPoint(x: center.x, y: top + height - 10))
        }
    }

    private func radarPoint(for flight: Aircraft, size: CGSize) -> (ground: CGPoint, aircraft: CGPoint)? {
        guard let lat = flight.latitude, let lon = flight.longitude else { return nil }
        let enu = Geodesy.enu(
            .init(latitudeDegrees: lat, longitudeDegrees: lon,
                  altitudeMeters: flight.geometricAltitudeMeters ?? flight.altitudeMeters ?? 0),
            relativeTo: Geodesy.approximateFranca
        )
        guard let visual = Geodesy.visualPosition(
            enu: enu,
            displayedAltitudeMeters: flight.altitudeMeters ?? 0,
            radiusKilometers: store.settings.radiusKilometers,
            verticalExaggeration: store.settings.verticalExaggeration
        ) else { return nil }
        let baseCenterY = size.height * 0.66 + size.height * 0.26 * 0.49
        let ground = CGPoint(
            x: size.width / 2 + visual.x / 0.34 * size.width * 0.39,
            y: baseCenterY + visual.z / 0.34 * size.height * 0.095
        )
        let altitude = max(0, min(1, (visual.y + 0.22) / 0.44))
        return (ground, CGPoint(x: ground.x, y: ground.y - altitude * size.height * 0.46))
    }
}
