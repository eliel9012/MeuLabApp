// swift-tools-version: 6.0
// Testes da área Apuração. Compila os MESMOS arquivos do app (links simbólicos em
// Sources/ApuracaoCore) e decodifica os JSONs reais do espelho do TSE em Fixtures.
import PackageDescription

let package = Package(
    name: "ApuracaoTests",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "ApuracaoCore", path: "Sources/ApuracaoCore"),
        .testTarget(
            name: "ApuracaoCoreTests",
            dependencies: ["ApuracaoCore"],
            path: "Tests/ApuracaoCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ],
    swiftLanguageModes: [.v5]
)
