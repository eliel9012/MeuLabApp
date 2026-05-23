import SwiftUI
import UIKit

// MARK: - Mac OS 9 Typography System
// Font hierarchy from the Figma reference (modelos macos9.html)
//
// REQUIRED FONT FILES (place in Resources/Fonts/ and add to Xcode target):
//   AppleGaramond-Light.ttf          → editorial titles
//   AppleGaramond-LightItalic.ttf    → editorial italic
//   AppleGaramond.ttf                → regular
//   AppleGaramond-Bold.ttf           → bold
//   Charcoal.ttf                     → headings / menus / title bars
//   Geneva.ttf (or GENEVA.TTF)       → body / labels / lists
//
// Run `MacOS9Typography.debugAvailableFonts()` in console to validate loading.

public enum MacOS9Typography {

    // MARK: PostScript font names
    // These are the PostScript names (not file names) iOS requires.
    private static let garamondLight = "AppleGaramondLight"
    private static let garamondRegular = "AppleGaramond"
    private static let garamondBold = "AppleGaramond-Bold"
    private static let garamondItalic = "AppleGaramondLight-Italic"
    private static let charcoal = "Charcoal"
    private static let geneva = "GenevaPlain"

    // MARK: Fallbacks
    private static let garamondFallback = "Georgia"
    private static let charcoalFallback = "Helvetica Neue"
    private static let genevaFallback = "Helvetica Neue"

    // MARK: - Font Accessors

    /// Safe font loader — uses PostScript name, falls back gracefully.
    public static func font(_ postScriptName: String, fallback: String, size: CGFloat) -> Font {
        font([postScriptName], fallback: fallback, size: size)
    }

    public static func font(_ postScriptNames: [String], fallback: String, size: CGFloat) -> Font {
        for postScriptName in postScriptNames where UIFont(name: postScriptName, size: size) != nil {
            return Font.custom(postScriptName, size: size)
        }
        return .custom(fallback, size: size)
    }

    static func uiFont(_ postScriptNames: [String], fallback: UIFont, size: CGFloat) -> UIFont {
        for postScriptName in postScriptNames {
            if let font = UIFont(name: postScriptName, size: size) {
                return font
            }
        }
        return fallback.withSize(size)
    }

    // MARK: Apple Garamond (Editorial titles)

    /// Apple Garamond Light, 24pt — hero editorial title (like HTML reference)
    public static func editorialTitle(_ size: CGFloat = 24) -> Font {
        font([garamondLight, "AppleGaramond-Light"], fallback: garamondFallback, size: size)
    }

    /// Apple Garamond, 18pt — section title
    public static func editorialHeading(_ size: CGFloat = 18) -> Font {
        font(garamondRegular, fallback: garamondFallback, size: size)
    }

    /// Apple Garamond Bold
    public static func editorialBold(_ size: CGFloat = 16) -> Font {
        font(garamondBold, fallback: garamondFallback, size: size)
    }

    /// Apple Garamond Light Italic
    public static func editorialItalic(_ size: CGFloat = 16) -> Font {
        font([garamondItalic, "AppleGaramond-LightItalic"], fallback: garamondFallback, size: size)
    }

    // MARK: Charcoal (Headings, title bars, menus)

    /// Charcoal 12pt — window / section headline (HTML: "Headlines for titles & sections")
    public static func windowTitle(_ size: CGFloat = 14) -> Font {
        font([charcoal], fallback: charcoalFallback, size: size)
    }

    /// Charcoal 10pt — menu label / small heading (HTML: "Small headlines for menus")
    public static func menuLabel(_ size: CGFloat = 12) -> Font {
        font([charcoal], fallback: charcoalFallback, size: size)
    }

    // MARK: Geneva (Body, labels, lists)

    /// Geneva 10pt — primary body text (HTML: "Body text for most content")
    public static func body(_ size: CGFloat = 13) -> Font {
        font([geneva, "Geneva"], fallback: genevaFallback, size: size)
    }

    /// Geneva 10pt bold, letter-spaced — highlighted body text
    public static func bodyBold(_ size: CGFloat = 13) -> Font {
        font([geneva, "Geneva"], fallback: genevaFallback, size: size)
    }

    /// Geneva 9pt — smaller body / list items
    public static func caption(_ size: CGFloat = 11) -> Font {
        font([geneva, "Geneva"], fallback: genevaFallback, size: size)
    }

    /// Geneva 7pt — disclaimer / fine print
    public static func finePrint(_ size: CGFloat = 9) -> Font {
        font([geneva, "Geneva"], fallback: genevaFallback, size: size)
    }

    // MARK: - Debug Helper

    /// Call this from a debug view or console to verify font loading.
    public static func debugAvailableFonts() {
        let targets = [
            garamondLight, garamondRegular, garamondBold, garamondItalic, charcoal, geneva,
            "Geneva", "AppleGaramond-Light", "AppleGaramond-LightItalic",
        ]
        for name in targets {
            let loaded = UIFont(name: name, size: 12) != nil
            print("[MacOS9Typography] \(loaded ? "✓" : "✗") \(name)")
        }
    }
}

// MARK: - SwiftUI Font Modifiers

extension View {
    /// Apply Apple Garamond editorial title style
    func mac9EditorialTitle(_ size: CGFloat = 24) -> some View {
        self.font(MacOS9Typography.editorialTitle(size))
            .foregroundStyle(MacOS9Colors.primaryText)
    }

    /// Apply Charcoal window title style
    func mac9WindowTitle(_ size: CGFloat = 14) -> some View {
        self.font(MacOS9Typography.windowTitle(size))
            .foregroundStyle(MacOS9Colors.primaryText)
    }

    /// Apply Geneva body style
    func mac9Body(_ size: CGFloat = 13) -> some View {
        self.font(MacOS9Typography.body(size))
            .foregroundStyle(MacOS9Colors.primaryText)
    }

    /// Apply Geneva caption style
    func mac9Caption(_ size: CGFloat = 11) -> some View {
        self.font(MacOS9Typography.caption(size))
            .foregroundStyle(MacOS9Colors.secondaryText)
    }
}
