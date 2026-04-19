// MARK: - Integration with Existing BibleView

/*
 This file shows how to integrate the new Bible Reader with Siri support
 into the existing BibleView/BibleNavigateView structure without duplication.

 Current Structure (Existing):
 ├── BibleView (main tab)
 ├── BibleNavigateView (books → chapters → verses)
 ├── BibleSearchView (full-text search)
 └── BibleRandomView (random verse picker)

 New Structure (With Reading Enhancement):
 ├── BibleView (main tab) ✓ unchanged
 ├── BibleNavigateView (books → chapters)
 ├── BibleChapterReaderView ← NEW: reader with Siri integration
 ├── BibleSearchView ✓ unchanged
 └── BibleRandomView ✓ unchanged
*/

import SwiftUI

// MARK: - Extension: Add Reader Button to BibleNavigateView

/*
 Modify existing /Views/Tabs/BibleNavigateView.swift to add a "Read" button
 when a chapter is displayed.

 Current code (hypothetical):

 struct BibleChapterView: View {
     let chapter: BibleChapter

     var body: some View {
         List(chapter.verses, id: \.number) { verse in
             VerseRow(verseNumber: verse.number, text: verse.text)
         }
     }
 }

 → Change to:
*/

struct BibleChapterViewWithReader: View {
    let bookName: String
    let bookSlug: String
    let chapterNumber: Int
    let verses: [String]

    @State private var showReader = false
    @State private var readerViewModel: BibleReaderViewModel?

    var body: some View {
        VStack {
            // Standard verse list
            List(Array(verses.enumerated()), id: \.offset) { index, verse in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(verse)
                        .font(.body)
                }
            }
            .navigationTitle("Capítulo \(chapterNumber)")

            // Read Button at bottom
            Button(action: { showReader = true }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Ler Capítulo")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
            }
        }
        .sheet(isPresented: $showReader) {
            BibleChapterReaderView()
                .onAppear {
                    let vm = BibleReaderViewModel()
                    vm.setChapter(book: bookName, chapter: chapterNumber, verses: verses)
                    self.readerViewModel = vm
                }
        }
    }
}

// MARK: - Extension: BibleRandomView Integration

/*
 Update BibleRandomView to include a "Read Verse" button that can start reading.

 Current structure (hypothetical):

 struct BibleRandomView: View {
     @State private var randomVerse: BibleVerse?

     var body: some View {
         // Display random verse
         // Button to get another random verse
     }
 }

 → Extend with reader integration:
*/

// Extension on existing view model to support single-verse reading
extension BibleReaderViewModel {
    func playSingleVerse(_ verse: String, from book: String, chapter: Int) {
        setChapter(book: book, chapter: chapter, verses: [verse])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            play()
        }
    }
}

// MARK: - Extension: BibleSearchView Integration

/*
 Add "Read Results" option to search results.

 Current structure (hypothetical):

 struct BibleSearchView: View {
     @State private var searchResults: [SearchResult]

     var body: some View {
         List(searchResults) { result in
             Text(result.verse)
         }
     }
 }

 → Extend with:
*/

struct BibleSearchViewWithReader: View {
    @State private var searchQuery = ""
    @State private var searchResults: [String] = []
    @State private var showReader = false
    @State private var selectedResultIndex = 0

    var body: some View {
        VStack {
            SearchBar(text: $searchQuery)
                .onChange(of: searchQuery) { oldValue, newValue in
                    performSearch(newValue)
                }

            List(Array(searchResults.enumerated()), id: \.offset) { index, result in
                VStack(alignment: .leading, spacing: 4) {
                    Text(result)
                        .font(.body)

                    Button(action: {
                        selectedResultIndex = index
                        showReader = true
                    }) {
                        HStack {
                            Image(systemName: "play.circle")
                            Text("Ler")
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showReader) {
            BibleChapterReaderView()
                .onAppear {
                    let vm = BibleReaderViewModel()
                    let verse = searchResults[selectedResultIndex]
                    vm.playSingleVerse(verse, from: "Resultados", chapter: selectedResultIndex + 1)
                }
        }
    }

    private func performSearch(_ query: String) {
        // Existing BibleLoader search implementation
        // searchResults = BibleLoader.shared.search(query: query)
    }
}

// MARK: - ContentView Integration

/*
 Ensure BibleReaderIntegrationView is used instead of BibleView
 when Siri intends to open a reader.

 In ContentView.swift:
*/

// Example integration point
struct BibleTabVariant1: View {
    @State private var shouldShowReader = false

    var body: some View {
        Group {
            if shouldShowReader {
                BibleReaderIntegrationView()
            } else {
                BibleView()  // Existing view
            }
        }
        .onAppear {
            checkForSiriIntent()
        }
    }

    private func checkForSiriIntent() {
        let defaults = UserDefaults.standard
        shouldShowReader = defaults.bool(forKey: "bibleReaderShouldPlay")
    }
}

// Alternative: Add reader as sub-tab
struct BibleTabWithReader: View {
    @State private var selectedTab = "navigate"

    var body: some View {
        TabView(selection: $selectedTab) {
            BibleView()
                .tabItem {
                    Label("Navegar", systemImage: "book")
                }
                .tag("navigate")

            BibleReaderIntegrationView()
                .tabItem {
                    Label("Ler", systemImage: "play.circle")
                }
                .tag("reader")
        }
    }
}

// MARK: - UserDefaults Keys (Centralized)

struct BibleReaderUserDefaultsKeys {
    static let bookName = "bibleReaderBook"
    static let chapterNumber = "bibleReaderChapter"
    static let shouldAutoPlay = "bibleReaderShouldPlay"
    static let action = "bibleReaderAction"
    static let lastReadBook = "bibleLastReadBook"
    static let lastReadChapter = "bibleLastReadChapter"
    static let bookmarkVerses = "bibleBookmarkedVerses"  // Future: bookmarking
}

// MARK: - Persistence Extension

extension BibleReaderViewModel {
    func saveLastChapter() {
        let defaults = UserDefaults.standard
        defaults.set(currentBook, forKey: BibleReaderUserDefaultsKeys.lastReadBook)
        defaults.set(currentChapterNumber, forKey: BibleReaderUserDefaultsKeys.lastReadChapter)
    }

    func loadLastChapter() -> Bool {
        let defaults = UserDefaults.standard
        guard let book = defaults.string(forKey: BibleReaderUserDefaultsKeys.lastReadBook),
            let chapter = defaults.integer(forKey: BibleReaderUserDefaultsKeys.lastReadChapter)
                as? Int
        else {
            return false
        }

        // Load verses from BibleLoader or your data source
        // let verses = BibleLoader.shared.chapter(bookSlug: book.lowercased(), chapterNumber: chapter)?.verses ?? []
        // setChapter(book: book, chapter: chapter, verses: verses)

        return true
    }
}

// MARK: - Shortcut Extension

/*
 If user bookmarks verses, extend to support:
 "Ler meus versículos marcados no MeuLabApp"

 Implementation:
*/

struct BibleBookmarkedVersesIntent: AppIntent {
    static var title: LocalizedStringResource = "Ler Versículos Marcados"
    static var description = IntentDescription("Lê todos os versículos que você marcou")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set("loadBookmarked", forKey: "bibleReaderAction")
        return .result(dialog: IntentDialog(stringLiteral: "Abrindo seus versículos marcados"))
    }
}

// MARK: - Testing Helper

#if DEBUG
    struct BibleReaderTestHelper {
        static func testChapter() -> (book: String, chapter: Int, verses: [String]) {
            return (
                book: "João",
                chapter: 3,
                verses: SampleBibleData.johnChapter3Verses
            )
        }

        static func setTestData() {
            let defaults = UserDefaults.standard
            defaults.set("João", forKey: BibleReaderUserDefaultsKeys.bookName)
            defaults.set(3, forKey: BibleReaderUserDefaultsKeys.chapterNumber)
            defaults.set(true, forKey: BibleReaderUserDefaultsKeys.shouldAutoPlay)
        }

        static func clearTestData() {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: BibleReaderUserDefaultsKeys.bookName)
            defaults.removeObject(forKey: BibleReaderUserDefaultsKeys.chapterNumber)
            defaults.removeObject(forKey: BibleReaderUserDefaultsKeys.shouldAutoPlay)
        }
    }
#endif
