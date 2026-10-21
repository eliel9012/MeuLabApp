import Foundation
import RealityKit
import UIKit

/// North-up OpenStreetMap tiles around Franca, aligned to the radar's geographic origin.
@MainActor
enum RadarMapSnapshot {
    private static let zoom = 9
    private static let tileSize = 256.0
    private static let imageSize = CGSize(width: 1_024, height: 1_024)
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 24 * 1_024 * 1_024, diskCapacity: 100 * 1_024 * 1_024)
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = 8
        return URLSession(configuration: config)
    }()

    private struct Tile: Hashable {
        let x: Int
        let y: Int
    }

    static func texture(radiusKilometers: Double) async throws -> TextureResource {
        let center = Geodesy.approximateFranca
        let latDelta = radiusKilometers / 111.32
        let lonDelta = latDelta / cos(center.latitudeDegrees * .pi / 180)
        let topLeft = pixel(latitude: center.latitudeDegrees + latDelta,
                            longitude: center.longitudeDegrees - lonDelta)
        let bottomRight = pixel(latitude: center.latitudeDegrees - latDelta,
                                longitude: center.longitudeDegrees + lonDelta)
        let minX = Int(floor(topLeft.x / tileSize))
        let maxX = Int(floor(bottomRight.x / tileSize))
        let minY = Int(floor(topLeft.y / tileSize))
        let maxY = Int(floor(bottomRight.y / tileSize))
        var tiles: [Tile: UIImage] = [:]

        // This fixed region fetches only its visible tiles. URLSession honors cache headers.
        for y in minY...maxY {
            for x in minX...maxX {
                try Task.checkCancellation()
                let tile = Tile(x: x, y: y)
                guard let url = URL(string: "https://tile.openstreetmap.org/\(zoom)/\(x)/\(y).png") else { continue }
                var request = URLRequest(url: url)
                request.setValue("MeuLabVision/1.0 (+https://meulab.fun/contact)", forHTTPHeaderField: "User-Agent")
                request.cachePolicy = .useProtocolCachePolicy
                if let (data, response) = try? await session.data(for: request),
                   let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let image = UIImage(data: data) {
                    tiles[tile] = image
                }
            }
        }
        guard tiles.count >= 2 else { throw RadarMapError.tilesUnavailable }
        let scaleX = imageSize.width / (bottomRight.x - topLeft.x)
        let scaleY = imageSize.height / (bottomRight.y - topLeft.y)
        let franca = pixel(latitude: center.latitudeDegrees, longitude: center.longitudeDegrees)
        let marker = CGPoint(x: (franca.x - topLeft.x) * scaleX,
                             y: (franca.y - topLeft.y) * scaleY)

        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { context in
            UIColor(red: 0.08, green: 0.12, blue: 0.14, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: imageSize))
            for (tile, bitmap) in tiles {
                bitmap.draw(in: CGRect(
                    x: (Double(tile.x) * tileSize - topLeft.x) * scaleX,
                    y: (Double(tile.y) * tileSize - topLeft.y) * scaleY,
                    width: tileSize * scaleX + 0.5,
                    height: tileSize * scaleY + 0.5
                ))
            }
            drawFranca(at: marker, in: context.cgContext)
            drawAttribution()
        }
        guard let cgImage = image.cgImage else { throw RadarMapError.imageUnavailable }
        return try await TextureResource(
            image: cgImage,
            withName: "franca-map-\(Int(radiusKilometers))",
            options: .init(semantic: .color)
        )
    }

    private static func pixel(latitude: Double, longitude: Double) -> CGPoint {
        let world = tileSize * pow(2, Double(zoom))
        let lat = latitude * .pi / 180
        return CGPoint(x: (longitude + 180) / 360 * world,
                       y: (1 - asinh(tan(lat)) / .pi) / 2 * world)
    }

    private static func drawFranca(at point: CGPoint, in context: CGContext) {
        UIColor.systemCyan.setFill()
        context.fillEllipse(in: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18))
        UIColor.white.setStroke()
        context.setLineWidth(3)
        context.strokeEllipse(in: CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24))
        let title = "FRANCA · SP"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24), .foregroundColor: UIColor.white
        ]
        let size = title.size(withAttributes: attributes)
        let label = CGRect(x: point.x + 20, y: point.y - 20, width: size.width + 22, height: 43)
        UIColor.black.withAlphaComponent(0.82).setFill()
        UIBezierPath(roundedRect: label, cornerRadius: 9).fill()
        title.draw(at: CGPoint(x: label.minX + 11, y: label.minY + 8), withAttributes: attributes)
    }

    private static func drawAttribution() {
        let title = "© OpenStreetMap contributors"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 26), .foregroundColor: UIColor.white
        ]
        let size = title.size(withAttributes: attributes)
        let label = CGRect(x: imageSize.width - size.width - 22, y: imageSize.height - 48,
                           width: size.width + 14, height: 40)
        UIColor.black.withAlphaComponent(0.75).setFill()
        UIBezierPath(roundedRect: label, cornerRadius: 6).fill()
        title.draw(at: CGPoint(x: label.minX + 7, y: label.minY + 5), withAttributes: attributes)
    }
}

private enum RadarMapError: Error {
    case tilesUnavailable, imageUnavailable
}
