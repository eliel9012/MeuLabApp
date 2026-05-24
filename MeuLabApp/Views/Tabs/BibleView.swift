import SwiftUI

struct BibleView: View {
    @StateObject private var loader = BibleLoader.shared
    @State private var selectedTab: BibleTab = .navegar
    @State private var selectedBook: BibleBook? = nil
    @State private var selectedChapter: BibleChapter? = nil

    enum BibleTab: String, CaseIterable {
        case navegar = "Navegar"
        case buscar = "Buscar"
        case aleatorio = "Aleatório"

        var icon: String {
            switch self {
            case .navegar: return "books.vertical"
            case .buscar: return "magnifyingglass"
            case .aleatorio: return "dice"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MacOS9Colors.windowBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    BibleHeader(selectedTab: selectedTab)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 8)

                    bibleTabPicker
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)

                    Rectangle()
                        .fill(MacOS9Colors.border)
                        .frame(height: 1)

                    switch selectedTab {
                    case .navegar:
                        BibleNavigateView(
                            selectedBook: $selectedBook,
                            selectedChapter: $selectedChapter
                        )
                    case .buscar:
                        BibleSearchView()
                    case .aleatorio:
                        BibleRandomView()
                    }
                }
            }
            .navigationTitle("A Bíblia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("ACF")
                        .font(MacOS9Typography.menuLabel(12))
                        .foregroundStyle(MacOS9Colors.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(MacOS9Colors.labelBadge)
                        .overlay(Mac9BevelBorder(isRaised: true))
                        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Tab Picker

    private var bibleTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(BibleTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(MacOS9Typography.menuLabel(12))
                        .foregroundStyle(
                            selectedTab == tab
                                ? MacOS9Colors.selectedText : MacOS9Colors.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(selectedTab == tab ? MacOS9Colors.selection : MacOS9Colors.panelBackground)
                        .overlay(Mac9BevelBorder(isRaised: selectedTab != tab))
                        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(MacOS9Colors.panelBackground)
        .overlay(Mac9BevelBorder(isRaised: true))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
    }
}

private struct BibleHeader: View {
    let selectedTab: BibleView.BibleTab

    private var subtitle: String {
        switch selectedTab {
        case .navegar: return "Livros e capítulos"
        case .buscar: return "Busca textual"
        case .aleatorio: return "Versículo aleatório"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(MacOS9Typography.bodyBold(22))
                .frame(width: 40, height: 40)
                .background(MacOS9Colors.contentPanel)
                .overlay(Mac9BevelBorder(isRaised: true))
                .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text("A Bíblia")
                    .font(MacOS9Typography.windowTitle(20))
                    .foregroundStyle(MacOS9Colors.primaryText)
                Text(subtitle)
                    .font(MacOS9Typography.caption(12))
                    .foregroundStyle(MacOS9Colors.secondaryText)
            }

            Spacer()
        }
        .padding(12)
        .background(MacOS9Colors.panelBackground)
        .overlay(Mac9BevelBorder(isRaised: true))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
    }
}

// MARK: - Amber Color Extension

extension Color {
    static let amber = MacOS9Colors.statusOrange
    static let mogno = MacOS9Colors.border
    static let parchment = MacOS9Colors.contentPanel
}

#Preview {
    BibleView()
}
