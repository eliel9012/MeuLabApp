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
            path: "MeuLabApp"),
    ]
)
