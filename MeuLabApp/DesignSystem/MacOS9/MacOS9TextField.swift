import SwiftUI

// MARK: - MacOS9TextField
// Classic Mac OS 9 text input: white bg, sunken bevel, 1px border.

struct MacOS9TextField: View {
    let placeholder: String
    @Binding var text: String
    var systemImage: String? = nil
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: MacOS9Metrics.inlineSpacing) {
            if let symbol = systemImage {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(MacOS9Colors.secondaryText)
            }
            TextField(placeholder, text: $text)
                .font(MacOS9Typography.body())
                .foregroundStyle(MacOS9Colors.primaryText)
                .focused($isFocused)
                .tint(MacOS9Colors.selection)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(MacOS9Colors.contentPanel)
        .overlay(Mac9BevelBorder(isRaised: false, width: MacOS9Metrics.bevelWidth))
        .overlay(
            Rectangle()
                .strokeBorder(
                    isFocused ? MacOS9Colors.selection : MacOS9Colors.border,
                    lineWidth: isFocused ? 2 : MacOS9Metrics.borderWidth
                )
        )
        .animation(.linear(duration: 0.1), value: isFocused)
    }
}

// MARK: - MacOS9SearchField
// Variant with clear button

struct MacOS9SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: MacOS9Metrics.inlineSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(MacOS9Colors.secondaryText)

            TextField(placeholder, text: $text)
                .font(MacOS9Typography.body())
                .foregroundStyle(MacOS9Colors.primaryText)
                .tint(MacOS9Colors.selection)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(MacOS9Colors.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(MacOS9Colors.contentPanel)
        .overlay(Mac9BevelBorder(isRaised: false, width: 1))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        MacOS9TextField(placeholder: "Callsign ou matrícula", text: .constant(""))
        MacOS9TextField(
            placeholder: "Servidor", text: .constant("10.0.1.50"), systemImage: "server.rack")
        MacOS9SearchField(placeholder: "Buscar containers", text: .constant("nginx"))
    }
    .padding()
    .background(MacOS9Colors.windowBackground)
}
