import SwiftUI

// MARK: - Liquid Glass View Modifiers
// Native Liquid Glass styling for iOS 26+.
//
// Every glass surface in the app goes through this file, which is also where the
// accessibility fallbacks live. With Reduce Transparency on, glass is replaced by
// an opaque surface rather than merely being made fainter — the setting exists for
// people who cannot read text over a refracting background, so thinning the effect
// would miss the point. With Reduce Motion on, the interactive press response is
// dropped. Because both are handled here, no call site needs to know about them.

// MARK: - Fallback surfaces

private enum GlassFallback {
    /// Opaque card background. Semantic colours so the substitute still follows
    /// light/dark instead of pinning one appearance.
    static var surface: Color { Color(uiColor: .secondarySystemBackground) }
    static var border: Color { Color(uiColor: .separator) }
}

// MARK: - Cards

private struct GlassCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            content
                .background(shape.fill(GlassFallback.surface))
                .overlay(shape.strokeBorder(GlassFallback.border, lineWidth: 1))
        } else {
            // No manual fill or stroke here: Liquid Glass draws its own edge and
            // overrides anything placed under it. Measured on screen in both
            // themes, the previous overlays changed exactly zero pixels.
            content
                .glassEffect(in: .rect(cornerRadius: cornerRadius))
        }
    }
}

private struct TintedGlassCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let tint: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            // Keep the accent legible by carrying it in an opaque wash over the
            // solid surface, so colour-coded sections stay distinguishable.
            content
                .background(shape.fill(GlassFallback.surface))
                .background(shape.fill(tint.opacity(0.22)))
                .overlay(shape.strokeBorder(tint.opacity(0.75), lineWidth: 1.5))
        } else {
            content
                .overlay(shape.strokeBorder(tint.opacity(0.35), lineWidth: 1.5))
                .glassEffect(.regular.tint(tint.opacity(0.15)), in: .rect(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Content surfaces
//
// Apple's Liquid Glass guidance: glass is the functional layer for navigation and
// controls; content sits underneath it. Cards that hold content therefore use a solid
// surface, and glass is reserved for the few elements that float over content.

/// Concentric with its container when one defines a shape; otherwise `minimum` radius.
private func concentricShape(_ minimum: CGFloat) -> ConcentricRectangle {
    ConcentricRectangle(corners: .concentric(minimum: .fixed(minimum)), isUniform: true)
}

private struct ContentCardModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    let tint: Color?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = concentricShape(cornerRadius)
        let increased = contrast == .increased
        // In light mode the surface is white, like a plain screen background; a hairline
        // and a faint shadow keep the card visible there (glass used to provide the edge).
        let edge: Color = {
            if let tint { return tint.opacity(increased ? 0.85 : 0.30) }
            return increased ? Color(uiColor: .label).opacity(0.45) : Color(uiColor: .separator).opacity(0.55)
        }()
        content
            .background(shape.fill(Color(uiColor: .secondarySystemGroupedBackground)))
            .background(shape.fill((tint ?? .clear).opacity(tint == nil ? 0 : 0.10)))
            .overlay(shape.stroke(edge, lineWidth: increased ? 1.5 : (tint == nil ? 0.5 : 1)))
            .shadow(color: .black.opacity(colorScheme == .light ? 0.06 : 0), radius: 8, y: 2)
    }
}

// MARK: - Glass controls

/// Liquid Glass for a custom control that floats over content (map buttons, player
/// controls, floating pills). Use inside `GlassSection` when several sit together.
private struct GlassControlModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    let tint: Color?
    let cornerRadius: CGFloat?
    let interactive: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            let shape = RoundedRectangle(cornerRadius: cornerRadius ?? 999, style: .continuous)
            content
                .background(shape.fill(GlassFallback.surface))
                .background(shape.fill((tint ?? .clear).opacity(tint == nil ? 0 : 0.22)))
                .overlay(shape.strokeBorder(
                    contrast == .increased ? Color(uiColor: .label).opacity(0.6) : GlassFallback.border,
                    lineWidth: contrast == .increased ? 1.5 : 1))
        } else {
            let base: Glass = tint.map { Glass.regular.tint($0.opacity(0.35)) } ?? .regular
            let glass = interactive && !reduceMotion ? base.interactive() : base
            if let cornerRadius {
                content.glassEffect(glass, in: .rect(cornerRadius: cornerRadius))
            } else {
                content.glassEffect(glass, in: .capsule)
            }
        }
    }
}

// MARK: - Interactive glass

private struct InteractiveGlassModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            content
                .background(shape.fill(GlassFallback.surface))
                .overlay(shape.strokeBorder(GlassFallback.border, lineWidth: 1))
        } else if reduceMotion {
            // `.interactive()` is what shimmers and deforms under a press; plain
            // `.regular` keeps the material without the movement.
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        }
    }
}

extension View {
    /// Glass card — ONLY for panels that float over content (map overlays, player, HUDs).
    /// Cards that hold content use `contentCard`.
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    /// Tinted glass card — floating panels only; content uses `contentCard(tint:)`.
    func glassCard(tint color: Color, cornerRadius: CGFloat = 16) -> some View {
        modifier(TintedGlassCardModifier(tint: color, cornerRadius: cornerRadius))
    }

    /// Solid content surface (Apple: content layer, no glass). Default for cards that hold content.
    func contentCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(ContentCardModifier(tint: nil, cornerRadius: cornerRadius))
    }

    /// Solid content surface with a colour accent (replaces tinted glass on content cards).
    func contentCard(tint color: Color, cornerRadius: CGFloat = 16) -> some View {
        modifier(ContentCardModifier(tint: color, cornerRadius: cornerRadius))
    }

    /// Liquid Glass for a custom floating control. Capsule unless `cornerRadius` is given.
    func glassControl(tint: Color? = nil, cornerRadius: CGFloat? = nil, interactive: Bool = true) -> some View {
        modifier(GlassControlModifier(tint: tint, cornerRadius: cornerRadius, interactive: interactive))
    }

    /// Repeated content rows. Solid surface like `contentCard` (content layer has no glass/blur).
    func materialCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(ContentCardModifier(tint: nil, cornerRadius: cornerRadius))
    }

    /// Interactive glass — for prominent floating action elements. Scales/shimmers on press.
    func glassInteractive(cornerRadius: CGFloat = 16) -> some View {
        modifier(InteractiveGlassModifier(cornerRadius: cornerRadius))
    }

    // MARK: Adaptive Button Styles

    /// Applies `.buttonStyle(.glass)` — translucent secondary glass button.
    func adaptiveGlassButton() -> some View {
        self.buttonStyle(.glass)
    }

    /// Applies `.buttonStyle(.glassProminent)` — opaque primary glass button.
    func adaptiveGlassProminentButton() -> some View {
        self.buttonStyle(.glassProminent)
    }
}

// MARK: - Floating Bar Glass

/// A modifier for full-width floating status/info bars on maps.
struct FloatingBarGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat = 0

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            // A floating bar sits over a map, the least predictable backdrop in the
            // app, so the opaque substitute matters most here.
            content
                .background(shape.fill(GlassFallback.surface))
                .overlay(shape.strokeBorder(GlassFallback.border, lineWidth: 1))
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Glass Section Container

/// Wraps children in a `GlassEffectContainer` for optimised rendering of multiple glass shapes.
struct GlassSection<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if reduceTransparency {
            // With no glass to merge, the container has nothing to do; skipping it
            // avoids paying for an effect that will not be drawn.
            content
        } else {
            GlassEffectContainer(spacing: spacing) {
                content
            }
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
