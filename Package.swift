// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MeuLabApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MeuLabApp",
            targets: ["MeuLabApp"]),
    ],
    targets: [
        .target(
            name: "MeuLabApp",
            path: "MeuLabApp",
            exclude: [
                // These files are duplicated under other directories (same basename),
                // and are not part of the Xcode target sources. Exclude them so SwiftPM builds work.
                "Services/RadarWebViewStore.swift",
                "Services/RadioNowPlayingFetcher.swift",
                "Services/SatellitePassPredictor.swift",

                // Extra files present on disk but not wired into the iOS Xcode target.
                // They cause redeclarations/missing generated types when building via SwiftPM.
                "Services/HexLookupService.swift",
                "Views/Components/PlaneSpottersView.swift",
                "Views/Settings/SiriShortcutsView.swift",
                "Views/Tabs/AircraftDetailView.swift",
                "Views/Tabs/AllSatellitePassesView.swift",
            ]),
    ]
)
