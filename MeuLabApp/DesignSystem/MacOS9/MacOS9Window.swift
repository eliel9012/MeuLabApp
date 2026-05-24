import SwiftUI

// MARK: - MacOS9Window
// Main window container with title bar, bevel, hard shadow.

struct MacOS9Window<Content: View>: View {
    let title: String
    var isActive: Bool = true
    var showTitleBar: Bool = true
    var onClose: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            if showTitleBar {
                MacOS9TitleBar(title: title, isActive: isActive, onClose: onClose)
            }
            content
                .frame(maxWidth: .infinity)
        }
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
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            MacOS9Window(title: "ADS-B — Aeronaves") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("N12345 — Boeing 737")
                        .mac9Body()
                    Text("ALT 35,000 ft  •  GS 480 kts")
                        .mac9Caption()
                }
                .padding(MacOS9Metrics.windowPadding)
            }

            MacOS9Window(title: "Sistema", isActive: false) {
                Text("CPU: 34%  •  RAM: 2.1 GB")
                    .mac9Body()
                    .padding(MacOS9Metrics.windowPadding)
            }
        }
        .padding()
    }
    .background(MacOS9Colors.windowBackground)
}
