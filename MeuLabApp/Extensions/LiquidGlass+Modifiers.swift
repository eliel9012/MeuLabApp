import SwiftUI

// MARK: - Liquid Glass View Modifiers
// Native Liquid Glass styling for iOS 26+.

extension View {
    // MARK: Cards

    /// Primary glass card — used for section containers, hero cards, and key UI groups.
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
            .glassEffect(in: .rect(cornerRadius: cornerRadius))
    }

    /// Tinted glass card — carries a subtle colour accent (for colored sections like CPU, Memory, etc.).
    func glassCard(tint color: Color, cornerRadius: CGFloat = 16) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(0.35), lineWidth: 1.5)
            )
            .glassEffect(.regular.tint(color.opacity(0.15)), in: .rect(cornerRadius: cornerRadius))
    }

    /// Lightweight material card — for repeated list items where full glass is expensive.
    func materialCard(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    // MARK: Interactive Glass

    /// Interactive glass — for prominent floating action elements. Scales/shimmers on press.
    func glassInteractive(cornerRadius: CGFloat = 16) -> some View {
        self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
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
    var cornerRadius: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Section Container

/// Wraps children in a `GlassEffectContainer` for optimised rendering of multiple glass shapes.
struct GlassSection<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content
        }
    }
}
