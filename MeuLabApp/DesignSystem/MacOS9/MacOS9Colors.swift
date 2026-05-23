import SwiftUI

// MARK: - Mac OS 9 Color Palette
// Extracted from the Figma reference (modelos macos9.html)

public enum MacOS9Colors {

    // MARK: Window & Surface
    /// Main window background — #EEEEEE
    public static let windowBackground = Color(red: 0.933, green: 0.933, blue: 0.933)
    /// Title bar / inactive surface — #CCCCCC
    public static let titleBar = Color(red: 0.800, green: 0.800, blue: 0.800)
    /// Panel / card background — #DDDDDD
    public static let panelBackground = Color(red: 0.867, green: 0.867, blue: 0.867)
    /// White content area
    public static let contentPanel = Color.white

    // MARK: Borders
    /// Primary 1-px border — #262626
    public static let border = Color(red: 0.149, green: 0.149, blue: 0.149)
    /// Accent border (purple) — #7B61FF
    public static let accentBorder = Color(red: 0.482, green: 0.380, blue: 1.000)

    // MARK: Bevel
    /// Bevel highlight — top/left inner edge (white 60%)
    public static let bevelHighlight = Color.white.opacity(0.60)
    /// Bevel shadow — bottom/right inner edge (#262626 40%)
    public static let bevelShadow = Color(red: 0.149, green: 0.149, blue: 0.149).opacity(0.40)
    /// Subtle inner bevel (#262626 10%)
    public static let bevelShadowSubtle = Color(red: 0.149, green: 0.149, blue: 0.149).opacity(0.10)
    /// Hard drop shadow — #262626 (2px offset, 0 blur)
    public static let dropShadow = Color(red: 0.149, green: 0.149, blue: 0.149)

    // MARK: Labels & Badges
    /// Lilac label badge — #CCCCFF
    public static let labelBadge = Color(red: 0.800, green: 0.800, blue: 1.000)
    /// Label badge text (dark)
    public static let labelBadgeText = Color(red: 0.149, green: 0.149, blue: 0.149)

    // MARK: Text
    /// Primary text — #262626
    public static let primaryText = Color(red: 0.149, green: 0.149, blue: 0.149)
    /// Secondary / placeholder text — #666666
    public static let secondaryText = Color(red: 0.400, green: 0.400, blue: 0.400)

    // MARK: Selection
    /// Classic Mac selection blue
    public static let selection = Color(red: 0.000, green: 0.000, blue: 0.502)
    public static let selectedText = Color.white

    // MARK: Status
    public static let statusGreen = Color(red: 0.000, green: 0.600, blue: 0.000)
    public static let statusRed = Color(red: 0.750, green: 0.000, blue: 0.000)
    public static let statusOrange = Color(red: 0.850, green: 0.450, blue: 0.000)
    public static let statusBlue = Color(red: 0.000, green: 0.000, blue: 0.700)

    // MARK: Button
    public static let buttonFace = windowBackground
    public static let buttonBorder = border
    public static let buttonPressed = Color(red: 0.667, green: 0.667, blue: 0.667)

    // MARK: Scrollbar
    public static let scrollbarTrack = Color(red: 0.667, green: 0.667, blue: 0.667)
    public static let scrollbarThumb = Color(red: 0.600, green: 0.600, blue: 1.000)
}
