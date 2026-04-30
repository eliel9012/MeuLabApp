import SwiftUI

// MARK: - MacOS9Label
// Lilac badge / section label — matches #CCCCFF blocks from Figma HTML.

struct MacOS9Label: View {
    let text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: MacOS9Metrics.inlineSpacing) {
            if let symbol = systemImage {
                Image(systemName: symbol)
                    .font(.system(size: 10))
                    .foregroundStyle(MacOS9Colors.labelBadgeText)
            }
            Text(text)
                .font(MacOS9Typography.menuLabel())
                .foregroundStyle(MacOS9Colors.labelBadgeText)
        }
        .padding(.horizontal, MacOS9Metrics.badgePaddingH)
        .padding(.vertical, MacOS9Metrics.badgePaddingV)
        .background(MacOS9Colors.labelBadge)
        .overlay(
            Rectangle()
                .strokeBorder(
                    MacOS9Colors.border.opacity(0.4), lineWidth: MacOS9Metrics.borderWidth)
        )
    }
}

// MARK: - MacOS9SectionHeader
// Section header combining label badge + optional subtitle

struct MacOS9SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: MacOS9Metrics.itemSpacing) {
            MacOS9Label(text: title, systemImage: systemImage)
            if let sub = subtitle {
                Text(sub)
                    .font(MacOS9Typography.caption())
                    .foregroundStyle(MacOS9Colors.secondaryText)
            }
            Spacer()
        }
    }
}

// MARK: - MacOS9StatusBadge
// Replaces the existing `StatusBadge` with Mac OS 9 style

struct MacOS9StatusBadge: View {
    let status: String

    private var color: Color {
        switch status.lowercased() {
        case "running", "active", "healthy", "online", "ativo":
            return MacOS9Colors.statusGreen
        case "exited", "inactive", "inativo", "stopped":
            return MacOS9Colors.statusOrange
        case "unhealthy", "failed", "error", "erro":
            return MacOS9Colors.statusRed
        default:
            return MacOS9Colors.secondaryText
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(MacOS9Typography.caption())
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .overlay(
                Rectangle()
                    .strokeBorder(color.opacity(0.6), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        MacOS9Label(text: "ADS-B", systemImage: "airplane")
        MacOS9Label(text: "Rádio", systemImage: "radio")
        MacOS9Label(text: "Sistema")

        Divider()

        MacOS9SectionHeader(title: "Aeronaves", subtitle: "12 detectadas", systemImage: "airplane")
        MacOS9SectionHeader(title: "CPU", subtitle: "34%", systemImage: "cpu")

        Divider()

        HStack {
            MacOS9StatusBadge(status: "running")
            MacOS9StatusBadge(status: "exited")
            MacOS9StatusBadge(status: "unhealthy")
        }
    }
    .padding()
    .background(MacOS9Colors.windowBackground)
}
