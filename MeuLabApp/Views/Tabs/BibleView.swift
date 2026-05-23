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
                // Mac OS 9 window background
                MacOS9Colors.windowBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Custom tab picker
                    bibleTabPicker
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    Divider()
                        .opacity(0.3)

                    // Tab content
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
            .navigationTitle("📖 A Bíblia")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("ACF")
                        .font(MacOS9Typography.caption())
                        .foregroundStyle(MacOS9Colors.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(MacOS9Colors.labelBadge)
                        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Tab Picker

    private var bibleTabPicker: some View {
        HStack(spacing: 6) {
            ForEach(BibleTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                } label: {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(MacOS9Typography.menuLabel())
                        .foregroundStyle(
                            selectedTab == tab
                                ? MacOS9Colors.selectedText : MacOS9Colors.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedTab == tab {
                                Rectangle()
                                    .fill(MacOS9Colors.selection)
                                    .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            MacOS9Colors.panelBackground
        )
        .overlay(
            Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1)
        )
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
