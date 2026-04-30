import SwiftUI

// MARK: - MacOS9Theme
// Central entry point for the Mac OS 9 design system.
// Apply `.mac9Theme()` once at the root of the app to set system-wide appearance.

extension View {
    /// Apply Mac OS 9 theme globally: forces light mode, sets background colour,
    /// and configures navigation/tab bar appearance.
    func mac9Theme() -> some View {
        self
            .preferredColorScheme(.light)
            .tint(MacOS9Colors.selection)
            .background(MacOS9Colors.windowBackground)
            .onAppear { MacOS9Theme.applyAppearance() }
    }
}

// MARK: - Appearance configuration (UIKit)

enum MacOS9Theme {

    /// Call once at app launch to style UIKit navigation bars, tab bars, etc.
    static func applyAppearance() {
        configureNavigationBar()
        configureTabBar()
        configureToolbar()
        configureProgressView()
        configureSwitch()
    }

    // MARK: Navigation Bar

    private static func configureNavigationBar() {
        let uiTitleFont =
            UIFont(name: "Charcoal", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(MacOS9Colors.titleBar)
        appearance.shadowColor = UIColor(MacOS9Colors.border)
        appearance.titleTextAttributes = [
            .font: uiTitleFont,
            .foregroundColor: UIColor(MacOS9Colors.primaryText),
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont(name: "AppleGaramond-Light", size: 28)
                ?? UIFont.systemFont(ofSize: 28, weight: .light),
            .foregroundColor: UIColor(MacOS9Colors.primaryText),
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(MacOS9Colors.selection)
    }

    // MARK: Tab Bar

    private static func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(MacOS9Colors.titleBar)
        appearance.shadowColor = UIColor(MacOS9Colors.border)

        let normalFont = UIFont(name: "Geneva", size: 10) ?? UIFont.systemFont(ofSize: 10)
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes = [
            .font: normalFont,
            .foregroundColor: UIColor(MacOS9Colors.secondaryText),
        ]
        itemAppearance.selected.titleTextAttributes = [
            .font: normalFont,
            .foregroundColor: UIColor(MacOS9Colors.primaryText),
        ]
        itemAppearance.normal.iconColor = UIColor(MacOS9Colors.secondaryText)
        itemAppearance.selected.iconColor = UIColor(MacOS9Colors.primaryText)

        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(MacOS9Colors.primaryText)
    }

    // MARK: Toolbar

    private static func configureToolbar() {
        let appearance = UIToolbarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(MacOS9Colors.titleBar)
        appearance.shadowColor = UIColor(MacOS9Colors.border)
        UIToolbar.appearance().standardAppearance = appearance
        UIToolbar.appearance().scrollEdgeAppearance = appearance
        UIToolbar.appearance().tintColor = UIColor(MacOS9Colors.primaryText)
    }

    // MARK: Progress View

    private static func configureProgressView() {
        UIProgressView.appearance().progressTintColor = UIColor(MacOS9Colors.statusBlue)
        UIProgressView.appearance().trackTintColor = UIColor(MacOS9Colors.panelBackground)
    }

    // MARK: Switch

    private static func configureSwitch() {
        UISwitch.appearance().onTintColor = UIColor(MacOS9Colors.statusBlue)
    }
}

// MARK: - GlassSection Mac9 Replacement
// GlassSection is used across the app — redirect it to a Mac OS 9 VStack.

struct GlassSection<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = MacOS9Metrics.sectionSpacing, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(spacing: spacing) {
            content
        }
    }
}
