import SwiftUI

// MARK: - Mac OS 9 Bevel Shape
// Draws the 4-edge bevel border (top/left = highlight, bottom/right = shadow).

struct Mac9BevelBorder: View {
    let isRaised: Bool
    let width: CGFloat

    init(isRaised: Bool = true, width: CGFloat = MacOS9Metrics.bevelWidth) {
        self.isRaised = isRaised
        self.width = width
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let highlight = isRaised ? MacOS9Colors.bevelHighlight : MacOS9Colors.bevelShadow
            let shadow = isRaised ? MacOS9Colors.bevelShadow : MacOS9Colors.bevelHighlight

            ZStack(alignment: .topLeading) {
                // Top edge
                Rectangle()
                    .fill(highlight)
                    .frame(width: w, height: width)
                    .position(x: w / 2, y: width / 2)

                // Left edge
                Rectangle()
                    .fill(highlight)
                    .frame(width: width, height: h)
                    .position(x: width / 2, y: h / 2)

                // Bottom edge
                Rectangle()
                    .fill(shadow)
                    .frame(width: w, height: width)
                    .position(x: w / 2, y: h - width / 2)

                // Right edge
                Rectangle()
                    .fill(shadow)
                    .frame(width: width, height: h)
                    .position(x: w - width / 2, y: h / 2)
            }
        }
    }
}

// MARK: - Mac OS 9 Modifiers

extension View {

    // MARK: Panel Modifiers

    /// Raised panel: light grey background + bevel + 1px dark border
    func mac9Panel(padding: CGFloat = MacOS9Metrics.windowPadding) -> some View {
        self
            .padding(padding)
            .background(
                // Shadow on background shape only — prevents text ghosting
                MacOS9Colors.panelBackground
                    .shadow(
                        color: MacOS9Colors.dropShadow,
                        radius: MacOS9Metrics.dropShadowBlur,
                        x: MacOS9Metrics.dropShadowX,
                        y: MacOS9Metrics.dropShadowY
                    )
            )
            .overlay(Mac9BevelBorder(isRaised: true))
            .overlay(
                Rectangle()
                    .strokeBorder(MacOS9Colors.border, lineWidth: MacOS9Metrics.borderWidth)
            )
    }

    /// Sunken / inset panel (e.g. scroll area, text field background)
    func mac9Sunken(padding: CGFloat = MacOS9Metrics.windowPadding) -> some View {
        self
            .padding(padding)
            .background(MacOS9Colors.contentPanel)
            .overlay(Mac9BevelBorder(isRaised: false))
            .overlay(
                Rectangle()
                    .strokeBorder(MacOS9Colors.border, lineWidth: MacOS9Metrics.borderWidth)
            )
    }

    /// Window-level container: window background + outer bevel + hard shadow
    func mac9Window() -> some View {
        self
            .background(
                MacOS9Colors.windowBackground
                    .shadow(
                        color: MacOS9Colors.dropShadow,
                        radius: 0,
                        x: MacOS9Metrics.dropShadowX,
                        y: MacOS9Metrics.dropShadowY
                    )
            )
            .overlay(Mac9BevelBorder(isRaised: true, width: 2))
            .overlay(
                Rectangle()
                    .strokeBorder(MacOS9Colors.border, lineWidth: MacOS9Metrics.borderWidth)
            )
    }

    /// Flat card: light panel background, 1px border, no bevel, no shadow.
    func mac9FlatCard(padding: CGFloat = MacOS9Metrics.windowPadding) -> some View {
        self
            .padding(padding)
            .background(MacOS9Colors.panelBackground)
            .overlay(
                Rectangle()
                    .strokeBorder(MacOS9Colors.border, lineWidth: MacOS9Metrics.borderWidth)
            )
    }

    /// Accent-bordered content area (purple border, white bg — from HTML panels)
    func mac9ContentPanel(padding: CGFloat = MacOS9Metrics.windowPadding) -> some View {
        self
            .padding(padding)
            .background(MacOS9Colors.contentPanel)
            .overlay(
                Rectangle()
                    .strokeBorder(MacOS9Colors.accentBorder, lineWidth: MacOS9Metrics.borderWidth)
            )
    }
}

// MARK: - Backward-compat: glassCard now renders Mac OS 9 panel
// This replaces the LiquidGlass implementation app-wide.
// The `glassCard` name is preserved so existing code needs no changes.

extension View {
    /// Mac OS 9 raised panel — replaces Liquid Glass glassCard across the app.
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self.mac9Panel(padding: MacOS9Metrics.windowPadding)
    }

    /// Tinted Mac OS 9 panel — accent border uses the tint color.
    func glassCard(tint color: Color, cornerRadius: CGFloat = 16) -> some View {
        self
            .padding(MacOS9Metrics.windowPadding)
            .background(
                MacOS9Colors.panelBackground
                    .shadow(
                        color: MacOS9Colors.dropShadow,
                        radius: 0,
                        x: MacOS9Metrics.dropShadowX,
                        y: MacOS9Metrics.dropShadowY
                    )
            )
            .overlay(Mac9BevelBorder(isRaised: true))
            .overlay(
                Rectangle()
                    .strokeBorder(color.opacity(0.8), lineWidth: MacOS9Metrics.borderWidth)
            )
    }

    /// Lightweight card — same as mac9FlatCard.
    func materialCard(cornerRadius: CGFloat = 12) -> some View {
        self.mac9FlatCard(padding: MacOS9Metrics.itemSpacing)
    }
}
