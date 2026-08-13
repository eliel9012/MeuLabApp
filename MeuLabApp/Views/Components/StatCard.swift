import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        MacOS9StatCard(title: title, value: value, icon: icon, color: color)
    }
}

// MARK: - EmptyStateCard
// Mac OS 9 styled empty-state placeholder — sunken panel with icon, title and description.
// Used wherever a list/collection has no items yet (e.g. RemoteControlView command history).

struct EmptyStateCard: View {
    let title: String
    let description: String
    let systemImage: String

    var body: some View {
        VStack(spacing: MacOS9Metrics.itemSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(MacOS9Colors.secondaryText)

            Text(title)
                .font(MacOS9Typography.windowTitle(14))
                .foregroundStyle(MacOS9Colors.primaryText)

            Text(description)
                .font(MacOS9Typography.caption())
                .foregroundStyle(MacOS9Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(MacOS9Metrics.windowPadding * 2)
        .frame(maxWidth: .infinity)
        .background(MacOS9Colors.contentPanel)
        .overlay(Mac9BevelBorder(isRaised: false, width: MacOS9Metrics.bevelWidth))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: MacOS9Metrics.borderWidth))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
        StatCard(
            title: "Uptime", value: "2d 4h 12m", icon: "clock", color: MacOS9Colors.statusGreen)
        StatCard(
            title: "Requests", value: "1.2k", icon: "arrow.up.arrow.down",
            color: MacOS9Colors.statusBlue)
    }
    .padding()
    .background(MacOS9Colors.windowBackground)
}
