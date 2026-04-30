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
