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
                    .foregroundStyle(.secondary)

                TextField("Buscar versículos… (min. 3 letras)", text: $query)
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
            .background(
                .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.amber.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal)
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
                .font(.system(size: 48))
                .foregroundStyle(Color.amber.opacity(0.6))
            Text("Digite pelo menos 3 caracteres para buscar versículos.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Nenhum versículo encontrado para \"\(query)\".")
                .font(.callout)
                .foregroundStyle(.secondary)
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
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.amber)

            Text(verse.text)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.amber.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        BibleSearchView()
    }
}
