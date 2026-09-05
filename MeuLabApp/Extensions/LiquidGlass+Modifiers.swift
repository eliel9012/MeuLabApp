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

private struct MaterialCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if reduceTransparency {
            content
                .background(shape.fill(GlassFallback.surface))
                .overlay(shape.strokeBorder(GlassFallback.border, lineWidth: 1))
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
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
    /// Primary glass card — used for section containers, hero cards, and key UI groups.
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }

    /// Tinted glass card — carries a subtle colour accent (for colored sections like CPU, Memory, etc.).
    func glassCard(tint color: Color, cornerRadius: CGFloat = 16) -> some View {
        modifier(TintedGlassCardModifier(tint: color, cornerRadius: cornerRadius))
    }

    /// Lightweight material card — for repeated list items where full glass is expensive.
    func materialCard(cornerRadius: CGFloat = 12) -> some View {
        modifier(MaterialCardModifier(cornerRadius: cornerRadius))
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
