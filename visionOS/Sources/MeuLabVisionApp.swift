import SwiftUI

@main
struct MeuLabVisionApp: App {
    @State private var flights = FlightStore()
    @State private var lab = VisionLabStore()

    var body: some Scene {
        WindowGroup(id: "mission-control") {
            VisionRootView()
                .environment(flights)
                .environment(lab)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1820, height: 850)

        WindowGroup(id: "radar-volume") {
            RadarVolumeView()
                .environment(flights)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.9, height: 0.6, depth: 0.9, in: .meters)
    }
}
