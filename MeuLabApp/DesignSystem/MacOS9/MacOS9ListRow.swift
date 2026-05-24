import SwiftUI

// MARK: - MacOS9ListRow
// Classic Mac OS 9 list row: Geneva body text, pixel separator, highlight on selection.

struct MacOS9ListRow: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    var isSelected: Bool = false
    var showDisclosure: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button(action: action) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: MacOS9Metrics.itemSpacing) {
            if let symbol = systemImage {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(
                        isSelected ? MacOS9Colors.selectedText : MacOS9Colors.secondaryText
                    )
                    .frame(width: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MacOS9Typography.body())
                    .foregroundStyle(
                        isSelected ? MacOS9Colors.selectedText : MacOS9Colors.primaryText
                    )
                    .lineLimit(1)

                if let sub = subtitle {
                    Text(sub)
                        .font(MacOS9Typography.caption())
                        .foregroundStyle(
                            isSelected
                                ? MacOS9Colors.selectedText.opacity(0.8)
                                : MacOS9Colors.secondaryText
                        )
                        .lineLimit(1)
                }
            }

            Spacer()

            if showDisclosure && action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9))
                    .foregroundStyle(
                        isSelected
                            ? MacOS9Colors.selectedText.opacity(0.7) : MacOS9Colors.secondaryText)
            }
        }
        .padding(.horizontal, MacOS9Metrics.listRowPadding)
        .frame(minHeight: MacOS9Metrics.listRowHeight)
        .background(isSelected ? MacOS9Colors.selection : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - MacOS9List
// Container for a list of rows with pixel separators

struct MacOS9List<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(item)
                if index < items.count - 1 {
                    MacOS9Divider()
                }
            }
        }
        .background(MacOS9Colors.contentPanel)
        .overlay(Mac9BevelBorder(isRaised: false, width: MacOS9Metrics.bevelWidth))
        .overlay(
            Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: MacOS9Metrics.borderWidth))
    }
}

// MARK: - Preview

private struct SampleItem: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
}

#Preview {
    let items = [
        SampleItem(name: "N12345", detail: "Boeing 737 · 35,000 ft"),
        SampleItem(name: "PT-ABC", detail: "Embraer E195 · 28,000 ft"),
        SampleItem(name: "G-AAAA", detail: "Airbus A320 · 32,000 ft"),
    ]

    VStack(spacing: 12) {
        MacOS9List(items: items) { item in
            MacOS9ListRow(
                title: item.name,
                subtitle: item.detail,
                systemImage: "airplane",
                action: {}
            )
        }

        MacOS9ListRow(
            title: "Selected row", subtitle: "Detail", systemImage: "star.fill", isSelected: true
        )
        .background(MacOS9Colors.contentPanel)
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
    }
    .padding()
    .background(MacOS9Colors.windowBackground)
}
