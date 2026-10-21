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
        .defaultSize(width: 1120, height: 850)

        WindowGroup(id: "radar-volume") {
            RadarVolumeView()
                .environment(flights)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.2, height: 1.2, depth: 0.8, in: .meters)
        .defaultWindowPlacement { _, context in
            guard let control = context.windows.first(where: { $0.id == "mission-control" }) else {
                return WindowPlacement()
            }
            return WindowPlacement(.trailing(control))
        }

    }
}
