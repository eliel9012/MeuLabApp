import MapKit
import RealityKit
import UIKit

/// Apple Maps snapshot centered on the same receiver used by the iPhone app.
@MainActor
enum RadarMapSnapshot {
    private static let imageSize = CGSize(width: 1_024, height: 1_024)

    static func texture(radiusKilometers: Double, style: RadarMapStyle) async throws -> TextureResource {
        let center = Geodesy.approximateFranca
        let latitudeDelta = radiusKilometers * 2 / 111.32
        let longitudeDelta = latitudeDelta / cos(center.latitudeDegrees * .pi / 180)
        let coordinate = CLLocationCoordinate2D(
            latitude: center.latitudeDegrees,
            longitude: center.longitudeDegrees
        )

        let options = MKMapSnapshotter.Options()
        options.size = imageSize
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
        switch style {
        case .standard: options.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        case .imagery: options.preferredConfiguration = MKImageryMapConfiguration(elevationStyle: .flat)
        case .hybrid: options.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .flat)
        }

        try Task.checkCancellation()
        let snapshot = try await MKMapSnapshotter(options: options).start()
        try Task.checkCancellation()
        let marker = snapshot.point(for: coordinate)
        let image = UIGraphicsImageRenderer(size: imageSize).image { context in
            snapshot.image.draw(in: CGRect(origin: .zero, size: imageSize))
            drawFranca(at: marker, in: context.cgContext)
        }
        guard let cgImage = image.cgImage else { throw RadarMapError.imageUnavailable }
        return try await TextureResource(
            image: cgImage,
            withName: "franca-apple-map-\(Int(radiusKilometers))-\(style.rawValue)",
            options: .init(semantic: .color)
        )
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
}

private enum RadarMapError: Error {
    case imageUnavailable
}
