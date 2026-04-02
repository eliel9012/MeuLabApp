import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

#if canImport(UIKit)
extension UIColor {
    static func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1)
        -> UIColor
    {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Color {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}
#endif
