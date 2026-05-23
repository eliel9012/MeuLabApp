import SwiftUI

// MARK: - MacOS9TitleBar
// Classic Mac OS 9 title bar with decorative stripe pattern,
// close button (left), zoom button (right), and Charcoal title text.

struct MacOS9TitleBar: View {
    let title: String
    var isActive: Bool = true
    var onClose: (() -> Void)? = nil
    var onZoom: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(isActive ? MacOS9Colors.titleBar : MacOS9Colors.panelBackground)

            // Main content: close — title — zoom
            HStack(spacing: 4) {
                // Close button
                Mac9TitleBarButton(symbol: "xmark", action: onClose)
                    .padding(.leading, 4)

                stripeRegion()
                    .frame(maxWidth: .infinity)

                // Title text
                Text(title)
                    .font(MacOS9Typography.windowTitle())
                    .foregroundStyle(
                        isActive ? MacOS9Colors.primaryText : MacOS9Colors.secondaryText
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 6)
                    .background(isActive ? MacOS9Colors.titleBar : MacOS9Colors.panelBackground)

                stripeRegion()
                    .frame(maxWidth: .infinity)

                // Zoom / collapse button
                Mac9TitleBarButton(symbol: "plus", action: onZoom)
                    .padding(.trailing, 4)
            }
        }
        .frame(height: MacOS9Metrics.titleBarHeight)
        // Bottom separator line
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MacOS9Colors.border)
                .frame(height: MacOS9Metrics.borderWidth)
        }
        // Inset bevel on title bar itself
        .overlay(Mac9BevelBorder(isRaised: true, width: 1))
    }

    // MARK: - Decorative stripe block
    @ViewBuilder
    private func stripeRegion() -> some View {
        Canvas { ctx, size in
            let stripeH: CGFloat = 1
            let gap: CGFloat = 2
            var y: CGFloat = 3
            while y < size.height - 3 {
                let rect = CGRect(x: 0, y: y, width: size.width, height: stripeH)
                ctx.fill(Path(rect), with: .color(MacOS9Colors.bevelHighlight))
                let rectD = CGRect(x: 0, y: y + stripeH, width: size.width, height: stripeH)
                ctx.fill(Path(rectD), with: .color(MacOS9Colors.bevelShadow))
                y += gap + stripeH * 2
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Title Bar Square Button

private struct Mac9TitleBarButton: View {
    let symbol: String
    let action: (() -> Void)?
    @State private var isPressed = false

    var body: some View {
        Button {
            action?()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(MacOS9Colors.primaryText)
                .frame(width: 16, height: 16)
                .background(
                    Rectangle()
                        .fill(
                            isPressed ? MacOS9Colors.buttonPressed : MacOS9Colors.windowBackground)
                )
                .overlay(Mac9BevelBorder(isRaised: !isPressed, width: 1))
                .overlay(
                    Rectangle()
                        .strokeBorder(MacOS9Colors.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onLongPressGesture(
            minimumDuration: 100,
            pressing: { pressing in isPressed = pressing },
            perform: {}
        )
        .disabled(action == nil)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        MacOS9TitleBar(title: "ADS-B Tracker", isActive: true)
        MacOS9TitleBar(title: "Sistema", isActive: false)
        MacOS9TitleBar(title: "Radar", isActive: true, onClose: {}, onZoom: {})
    }
    .padding()
    .background(MacOS9Colors.windowBackground)
}
