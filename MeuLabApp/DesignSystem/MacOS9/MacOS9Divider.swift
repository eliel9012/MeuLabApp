import SwiftUI

// MARK: - MacOS9Divider
// 1px pixel-perfect divider using the classic Mac border colour.

struct MacOS9Divider: View {
    var orientation: Axis = .horizontal
    var color: Color = MacOS9Colors.border
    var opacity: CGFloat = 0.5

    var body: some View {
        if orientation == .horizontal {
            Rectangle()
                .fill(color.opacity(opacity))
                .frame(maxWidth: .infinity)
                .frame(height: 1)
        } else {
            Rectangle()
                .fill(color.opacity(opacity))
                .frame(maxHeight: .infinity)
                .frame(width: 1)
        }
    }
}

// MARK: - Grooved Divider (title-bar style)
// Two stacked lines: dark on top, light below — classic Platinum grooved separator

struct MacOS9GroovedDivider: View {
    var body: some View {
        VStack(spacing: 0) {
            MacOS9Divider(color: MacOS9Colors.border, opacity: 0.5)
            MacOS9Divider(color: .white, opacity: 0.6)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        Text("Above divider").mac9Body()
        MacOS9Divider()
        Text("Below divider").mac9Body()
        MacOS9GroovedDivider()
        Text("Below grooved divider").mac9Body()
    }
    .padding()
    .background(MacOS9Colors.windowBackground)
}
