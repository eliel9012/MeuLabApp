import SwiftUI

// MARK: - MacOS9Screen
// Full-screen wrapper that applies the Mac OS 9 window background,
// a top title bar (mapped from NavigationView title), and scrollable content.
// Designed to wrap NavigationStack or standalone views.

struct MacOS9Screen<Content: View>: View {
    var title: String = ""
    var showTitleBar: Bool = true
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            // Global background
            MacOS9Colors.windowBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if showTitleBar && !title.isEmpty {
                    MacOS9TitleBar(title: title, isActive: true)
                        .zIndex(10)
                }

                ScrollView {
                    content
                        .padding(MacOS9Metrics.windowPadding)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - MacOS9ScrollableContent
// Plain scrollable area with Mac OS 9 background, no title bar.

struct MacOS9ScrollableContent<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            MacOS9Colors.windowBackground.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: MacOS9Metrics.sectionSpacing) {
                    content
                }
                .padding(MacOS9Metrics.windowPadding)
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - MacOS9EmptyState
// Empty state view with Mac OS 9 style

struct MacOS9EmptyState: View {
    let title: String
    var message: String? = nil
    var systemImage: String = "doc"

    var body: some View {
        VStack(spacing: MacOS9Metrics.itemSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(MacOS9Colors.secondaryText)

            Text(title)
                .font(MacOS9Typography.windowTitle())
                .foregroundStyle(MacOS9Colors.primaryText)

            if let msg = message {
                Text(msg)
                    .font(MacOS9Typography.caption())
                    .foregroundStyle(MacOS9Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(MacOS9Metrics.windowPadding * 2)
        .mac9FlatCard()
    }
}

// MARK: - MacOS9LoadingView
// Loading state

struct MacOS9LoadingView: View {
    var message: String = "Carregando…"

    var body: some View {
        HStack(spacing: MacOS9Metrics.itemSpacing) {
            ProgressView()
                .tint(MacOS9Colors.primaryText)
                .scaleEffect(0.8)
            Text(message)
                .font(MacOS9Typography.body())
                .foregroundStyle(MacOS9Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(MacOS9Metrics.windowPadding)
        .mac9FlatCard()
    }
}

// MARK: - MacOS9ErrorCard
// Error state — replaces the app-wide `ErrorCard` component

struct MacOS9ErrorCard: View {
    let message: String
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: MacOS9Metrics.itemSpacing) {
            HStack(spacing: MacOS9Metrics.inlineSpacing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(MacOS9Colors.statusRed)
                    .font(.system(size: 12))
                Text("Erro")
                    .font(MacOS9Typography.menuLabel())
                    .foregroundStyle(MacOS9Colors.statusRed)
            }

            Text(message)
                .font(MacOS9Typography.caption())
                .foregroundStyle(MacOS9Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let retry = retryAction {
                MacOS9Button(
                    label: "Tentar Novamente", systemImage: "arrow.clockwise", action: retry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .mac9Panel()
    }
}

// MARK: - MacOS9StatCard
// Stat card for metrics dashboards — replaces the global `StatCard` component

struct MacOS9StatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = MacOS9Colors.primaryText

    var body: some View {
        VStack(spacing: MacOS9Metrics.inlineSpacing) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(color)

                Text(title)
                    .font(MacOS9Typography.caption())
                    .foregroundStyle(MacOS9Colors.secondaryText)
                    .lineLimit(1)
            }

            Text(value)
                .font(MacOS9Typography.windowTitle(14))
                .foregroundStyle(MacOS9Colors.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(MacOS9Colors.panelBackground)
        .overlay(Mac9BevelBorder(isRaised: true, width: 1))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
        .shadow(color: MacOS9Colors.dropShadow, radius: 0, x: 1, y: 1)
    }
}

// MARK: - Preview

#Preview {
    MacOS9Screen(title: "Sistema") {
        VStack(spacing: MacOS9Metrics.sectionSpacing) {
            MacOS9SectionHeader(title: "Métricas", systemImage: "waveform")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                MacOS9StatCard(
                    title: "Uptime", value: "2d 4h", icon: "clock", color: MacOS9Colors.statusGreen)
                MacOS9StatCard(
                    title: "CPU", value: "34%", icon: "cpu", color: MacOS9Colors.statusOrange)
                MacOS9StatCard(
                    title: "RAM", value: "2.1 GB", icon: "memorychip",
                    color: MacOS9Colors.statusBlue)
                MacOS9StatCard(
                    title: "Requests", value: "1.2k", icon: "arrow.up.arrow.down",
                    color: MacOS9Colors.primaryText)
            }

            MacOS9EmptyState(
                title: "Nenhum dado", message: "Verifique a conexão com o servidor.",
                systemImage: "wifi.slash")

            MacOS9ErrorCard(
                message: "Falha ao conectar ao servidor. Verifique as configurações de rede.")

            MacOS9LoadingView()
        }
    }
}
