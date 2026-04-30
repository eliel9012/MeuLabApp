import SwiftUI

// MARK: - Legacy Liquid Glass Modifiers
// These methods previously used iOS 26 Liquid Glass (glassEffect).
// They now delegate to the Mac OS 9 design system in MacOS9Modifiers.swift.
// No call sites need to change — the visual output is the new Mac OS 9 bevel style.

extension View {

    // glassCard, materialCard, glassCard(tint:) → defined in MacOS9Modifiers.swift

    // MARK: Interactive (now Mac OS 9 raised panel press animation)

    /// Was: glassEffect.interactive. Now: raised Mac OS 9 panel.
    func glassInteractive(cornerRadius: CGFloat = 16) -> some View {
        self.mac9Panel()
    }

    // MARK: Button Styles

    /// Was: .buttonStyle(.glass). Now: Mac OS 9 plain button wrapper.
    func adaptiveGlassButton() -> some View {
        self.buttonStyle(Mac9ButtonStyle())
    }

    /// Was: .buttonStyle(.glassProminent). Now: Mac OS 9 default button style.
    func adaptiveGlassProminentButton() -> some View {
        self.buttonStyle(Mac9ProminentButtonStyle())
    }
}

// MARK: - Mac OS 9 Button Styles

struct Mac9ButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MacOS9Typography.menuLabel())
            .foregroundStyle(MacOS9Colors.primaryText)
            .padding(.horizontal, MacOS9Metrics.buttonPaddingH)
            .padding(.vertical, MacOS9Metrics.buttonPaddingV)
            .frame(minHeight: 36)
            .background(
                configuration.isPressed ? MacOS9Colors.buttonPressed : MacOS9Colors.windowBackground
            )
            .overlay(Mac9BevelBorder(isRaised: !configuration.isPressed, width: 1))
            .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
            .shadow(
                color: configuration.isPressed ? .clear : MacOS9Colors.dropShadow,
                radius: 0, x: 1, y: 1
            )
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
    }
}

struct Mac9ProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MacOS9Typography.menuLabel())
            .foregroundStyle(MacOS9Colors.primaryText)
            .padding(.horizontal, MacOS9Metrics.buttonPaddingH)
            .padding(.vertical, MacOS9Metrics.buttonPaddingV)
            .frame(minHeight: 36)
            .background(
                configuration.isPressed ? MacOS9Colors.buttonPressed : MacOS9Colors.titleBar
            )
            .overlay(Mac9BevelBorder(isRaised: !configuration.isPressed, width: 2))
            .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
            .shadow(
                color: configuration.isPressed ? .clear : MacOS9Colors.dropShadow,
                radius: 0, x: 1, y: 1
            )
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 1 : 0)
    }
}

// MARK: - Floating Bar (maps, status bars)

/// Floating bar for MapView overlays — now Mac OS 9 panel style.
struct FloatingBarGlass: ViewModifier {
    var cornerRadius: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(MacOS9Colors.windowBackground.opacity(0.92))
            .overlay(Mac9BevelBorder(isRaised: true, width: 1))
            .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
            .shadow(color: MacOS9Colors.dropShadow, radius: 0, x: 2, y: 2)
    }
}

// NOTE: GlassSection is defined in MacOS9Theme.swift
// NOTE: glassCard / materialCard are defined in MacOS9Modifiers.swift
