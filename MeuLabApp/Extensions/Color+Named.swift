import SwiftUI

extension Color {
    static func fromName(_ name: String) -> Color {
        switch name.lowercased() {
        case "blue":
            return .blue
        case "green":
            return .green
        case "orange":
            return .orange
        case "red":
            return .red
        case "gray":
            return .gray
        default:
            return .gray
        }
    }
}
