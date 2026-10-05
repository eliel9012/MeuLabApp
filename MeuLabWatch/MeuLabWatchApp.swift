import SwiftUI

@main
struct MeuLabWatchApp: App {
    var body: some Scene {
        WindowGroup {
            EnhancedWatchContentView()
        }
    }
}

// MARK: - Dynamic Type

/// A fixed-size system font that still follows the user's text-size setting.
/// At the default setting it renders exactly `size` points, so layouts look the
/// same as `.font(.system(size:))`; larger settings scale it like the nearest text style.
private struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo style: Font.TextStyle?) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style ?? Self.textStyle(for: size))
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }

    /// The text style whose default size is closest, so scaling follows the same curve.
    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case ..<11.5: return .caption2
        case ..<12.5: return .caption
        case ..<13.5: return .footnote
        case ..<15.5: return .subheadline
        case ..<16.5: return .callout
        case ..<18: return .body
        case ..<21: return .title3
        case ..<25: return .title2
        case ..<31: return .title
        default: return .largeTitle
        }
    }
}

extension View {
    /// Drop-in for `.font(.system(size:weight:design:))` that scales with Dynamic Type.
    func scaledFont(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo style: Font.TextStyle? = nil
    ) -> some View {
        modifier(ScaledSystemFont(size: size, weight: weight, design: design, relativeTo: style))
    }
}
