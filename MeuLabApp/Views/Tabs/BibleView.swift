import SwiftUI

struct BibleView: View {
    @StateObject private var loader = BibleLoader.shared
    @State private var selectedTab: BibleTab = .navegar
    @State private var selectedBook: BibleBook? = nil
    @State private var selectedChapter: BibleChapter? = nil

    enum BibleTab: String, CaseIterable {
        case navegar  = "Navegar"
        case buscar   = "Buscar"
        case aleatorio = "Aleatório"

        var icon: String {
            switch self {
            case .navegar:   return "books.vertical"
            case .buscar:    return "magnifyingglass"
            case .aleatorio: return "dice"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient — parchment/mahogany feel matching the HTML design
                LinearGradient(
                    colors: [
                        Color(red: 0.24, green: 0.15, blue: 0.13).opacity(0.18),
                        Color(red: 0.96, green: 0.90, blue: 0.83).opacity(0.06),
                        Color(.systemBackground),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
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
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
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
                        .font(.subheadline)
                        .fontWeight(selectedTab == tab ? .semibold : .regular)
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.amber.opacity(0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.amber.opacity(0.4), lineWidth: 1)
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Amber Color Extension

extension Color {
    static let amber = Color(red: 0.83, green: 0.69, blue: 0.22)
    static let mogno = Color(red: 0.24, green: 0.15, blue: 0.13)
    static let parchment = Color(red: 0.96, green: 0.90, blue: 0.83)
}

#Preview {
    BibleView()
}
