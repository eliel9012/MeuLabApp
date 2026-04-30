import SwiftUI

// MARK: - MacOS9Panel
// Classic Mac panel/card with bevel variants.
// Matches the bordered content panels from the Figma HTML reference.

enum Mac9PanelStyle {
    case raised  // Default: light-grey bg, outward bevel, hard shadow
    case sunken  // Inset/scrollable areas: white bg, inward bevel
    case flat  // No bevel, 1px border only
    case content  // Accent (purple) border, white background
}

struct MacOS9Panel<Content: View>: View {
    var style: Mac9PanelStyle = .raised
    var padding: CGFloat = MacOS9Metrics.windowPadding
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(background)
            .overlay(bevel)
            .overlay(border)
            .shadow(
                color: style == .raised ? MacOS9Colors.dropShadow : .clear,
                radius: 0,
                x: MacOS9Metrics.dropShadowX,
                y: MacOS9Metrics.dropShadowY
            )
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .raised: Rectangle().fill(MacOS9Colors.panelBackground)
        case .sunken: Rectangle().fill(MacOS9Colors.contentPanel)
        case .flat: Rectangle().fill(MacOS9Colors.panelBackground)
        case .content: Rectangle().fill(MacOS9Colors.contentPanel)
        }
    }

    @ViewBuilder
    private var bevel: some View {
        switch style {
        case .raised: Mac9BevelBorder(isRaised: true, width: MacOS9Metrics.bevelWidth)
        case .sunken: Mac9BevelBorder(isRaised: false, width: MacOS9Metrics.bevelWidth)
        case .flat: EmptyView()
        case .content: EmptyView()
        }
    }

    @ViewBuilder
    private var border: some View {
        switch style {
        case .content:
            RoundedRectangle(cornerRadius: MacOS9Metrics.panelCornerRadius)
                .strokeBorder(MacOS9Colors.accentBorder, lineWidth: MacOS9Metrics.borderWidth)
        default:
            Rectangle()
                .strokeBorder(MacOS9Colors.border, lineWidth: MacOS9Metrics.borderWidth)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        MacOS9Panel(style: .raised) {
            Text("Raised panel — cards, sections")
                .mac9Body()
        }

        MacOS9Panel(style: .sunken) {
            Text("Sunken panel — scroll areas, log views")
                .mac9Body()
        }

        MacOS9Panel(style: .flat) {
            Text("Flat panel — no bevel")
                .mac9Body()
        }

        MacOS9Panel(style: .content) {
            Text("Content panel — purple accent border")
                .mac9Body()
        }
    }
    .padding()
    .background(MacOS9Colors.windowBackground)
}
