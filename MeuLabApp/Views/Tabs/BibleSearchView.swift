import SwiftUI

struct BibleSearchView: View {
    @State private var query = ""
    @State private var results: [BibleVerse] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var loader: BibleLoader { BibleLoader.shared }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MacOS9Colors.secondaryText)

                TextField("Buscar versículos... (min. 3 letras)", text: $query)
                    .font(MacOS9Typography.body(14))
                    .autocorrectionDisabled()
                    .onChange(of: query) { _, newValue in
                        performSearch(query: newValue)
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(MacOS9Colors.contentPanel)
            .overlay(Mac9BevelBorder(isRaised: false))
            .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Results
            if query.count < 3 {
                searchPrompt
            } else if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                noResultsView
            } else {
                resultsList
            }
        }
    }

    // MARK: - Sub-views

    private var searchPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.magnifyingglass")
                .font(MacOS9Typography.body(36))
                .foregroundStyle(MacOS9Colors.statusOrange)
            Text("Digite pelo menos 3 caracteres para buscar versículos.")
                .font(MacOS9Typography.body(14))
                .foregroundStyle(MacOS9Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MacOS9Colors.windowBackground)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(MacOS9Typography.body(36))
                .foregroundStyle(MacOS9Colors.secondaryText)
            Text("Nenhum versículo encontrado para \"\(query)\".")
                .font(MacOS9Typography.body(14))
                .foregroundStyle(MacOS9Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        List(results) { verse in
            NavigationLink(
                destination: BibleChapterView(
                    bookSlug: verse.book,
                    bookName: BibleCatalogue.book(slug: verse.book)?.name ?? verse.book,
                    chapterNumber: verse.chapter
                )
            ) {
                SearchResultRow(verse: verse)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MacOS9Colors.windowBackground)
    }

    // MARK: - Search

    @MainActor
    private func performSearch(query: String) {
        searchTask?.cancel()

        guard query.count >= 3 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let q = query
            let found = await Task.detached(priority: .userInitiated) {
                await BibleLoader.shared.search(query: q, limit: 60)
            }.value

            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let verse: BibleVerse

    private var bookName: String {
        BibleCatalogue.book(slug: verse.book)?.name ?? verse.book
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(bookName) \(verse.chapter):\(verse.number)")
                .font(MacOS9Typography.menuLabel(12))
                .foregroundStyle(MacOS9Colors.statusOrange)

            Text(verse.text)
                .font(MacOS9Typography.body(14))
                .foregroundStyle(MacOS9Colors.primaryText)
                .lineLimit(3)
        }
        .padding(10)
        .background(MacOS9Colors.contentPanel)
        .overlay(Mac9BevelBorder(isRaised: true))
        .overlay(Rectangle().strokeBorder(MacOS9Colors.border, lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        BibleSearchView()
    }
}
