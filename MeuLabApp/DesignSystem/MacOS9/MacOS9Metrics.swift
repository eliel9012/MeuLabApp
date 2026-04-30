import SwiftUI

// MARK: - Mac OS 9 Metrics / Layout Constants

public enum MacOS9Metrics {

    // MARK: Title Bar
    /// Title bar height adapted for iPhone touch targets (HTML reference: 19px)
    public static let titleBarHeight: CGFloat = 28

    // MARK: Borders
    /// Primary border width (1px pixel-perfect)
    public static let borderWidth: CGFloat = 1
    /// Bevel edge width (2px per HTML shadows)
    public static let bevelWidth: CGFloat = 2

    // MARK: Shadows (hard, no blur — classic Mac style)
    public static let dropShadowX: CGFloat = 2
    public static let dropShadowY: CGFloat = 2
    public static let dropShadowBlur: CGFloat = 0

    // MARK: Corner Radii
    /// Window / outer container — no rounding, pixel-perfect
    public static let windowCornerRadius: CGFloat = 0
    /// Inner content panels — subtle rounding per HTML (border-radius: 5px)
    public static let panelCornerRadius: CGFloat = 4
    /// Buttons — square, no rounding
    public static let buttonCornerRadius: CGFloat = 0

    // MARK: Spacing
    public static let windowPadding: CGFloat = 8
    public static let sectionSpacing: CGFloat = 12
    public static let itemSpacing: CGFloat = 6
    public static let inlineSpacing: CGFloat = 4

    // MARK: Buttons
    /// Minimum tappable height on iPhone (adapted from tiny Mac desktop buttons)
    public static let buttonMinHeight: CGFloat = 44
    public static let buttonPaddingH: CGFloat = 12
    public static let buttonPaddingV: CGFloat = 8

    // MARK: Label Badges (HTML: 8px h-padding, 2px v-padding)
    public static let badgePaddingH: CGFloat = 10
    public static let badgePaddingV: CGFloat = 3

    // MARK: List Rows
    public static let listRowHeight: CGFloat = 44
    public static let listRowPadding: CGFloat = 10

    // MARK: Title Bar Decorative Lines
    /// Number of decorative horizontal stripes each side of title text
    public static let titleBarStripeCount: Int = 4
    public static let titleBarStripeSpacing: CGFloat = 2
}
