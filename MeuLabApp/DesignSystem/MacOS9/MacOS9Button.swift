import SwiftUI

// MARK: - MacOS9Button
// Classic Mac OS 9 push button: grey face, bevel border, pressed state inverts bevel.

struct MacOS9Button: View {
    let label: String
    var systemImage: String? = nil
    var isDestructive: Bool = false
    var isDefault: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: MacOS9Metrics.inlineSpacing) {
                if let symbol = systemImage {
                    Image(systemName: symbol)
                        .font(.system(size: 12))
                }
                Text(label)
                    .font(MacOS9Typography.menuLabel())
            }
            .foregroundStyle(isDestructive ? MacOS9Colors.statusRed : MacOS9Colors.primaryText)
            .padding(.horizontal, MacOS9Metrics.buttonPaddingH)
            .padding(.vertical, MacOS9Metrics.buttonPaddingV)
            .frame(minHeight: MacOS9Metrics.buttonMinHeight)
            .background(
                // Shadow on the background fill only — applying it after the
                // label/overlay chain ghosts the button text (double-struck glyphs).
                (isPressed
                    ? MacOS9Colors.buttonPressed
                    : (isDefault ? MacOS9Colors.titleBar : MacOS9Colors.windowBackground))
                    .shadow(
                        color: isPressed ? .clear : MacOS9Colors.dropShadow,
                        radius: 0,
                        x: isPressed ? 0 : 1,
                        y: isPressed ? 0 : 1
                    )
            )
            .overlay(Mac9BevelBorder(isRaised: !isPressed, width: MacOS9Metrics.bevelWidth))
            .overlay(
                Rectangle()
                    .strokeBorder(MacOS9Colors.border, lineWidth: MacOS9Metrics.borderWidth)
            )
            .offset(x: isPressed ? 1 : 0, y: isPressed ? 1 : 0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(
            minimumDuration: 100,
            pressing: { pressing in
                withAnimation(.linear(duration: 0.05)) { isPressed = pressing }
            },
            perform: {}
        )
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - MacOS9SmallButton
// Inline small button variant (title bar, toolbars)

struct MacOS9SmallButton: View {
    let label: String
    var systemImage: String? = nil
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                if let symbol = systemImage {
                    Image(systemName: symbol)
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(MacOS9Typography.caption())
            }
            .foregroundStyle(MacOS9Colors.primaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isPressed ? MacOS9Colors.buttonPressed : MacOS9Colors.windowBackground)
            .overlay(Mac9BevelBorder(isRaised: !isPressed, width: 1))
            .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .onLongPressGesture(
            minimumDuration: 100,
            pressing: { pressing in isPressed = pressing },
            perform: {}
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        MacOS9Button(label: "OK", isDefault: true) {}
        MacOS9Button(label: "Cancelar") {}
        MacOS9Button(label: "Exportar", systemImage: "square.and.arrow.up") {}
        MacOS9Button(label: "Apagar", systemImage: "trash", isDestructive: true) {}

        Divider()

        HStack {
            MacOS9SmallButton(label: "Buscar", systemImage: "magnifyingglass") {}
            MacOS9SmallButton(label: "Fechar") {}
        }
    }
    .padding()
    .background(MacOS9Colors.windowBackground)
}
