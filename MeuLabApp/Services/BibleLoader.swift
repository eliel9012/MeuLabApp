import Foundation

/// Loads and caches Bible chapter data from the bundled bible.json.
/// The JSON format is: { "slug": [[verse1, verse2, ...], ...chapters...], ... }
@MainActor
final class BibleLoader: ObservableObject {
    static let shared = BibleLoader()

    private nonisolated(unsafe) var rawData: [String: [[String]]] = [:]
    private nonisolated(unsafe) var lowercasedData: [String: [[String]]] = [:]
    private var chapterCache: [String: BibleChapter] = [:]
    private var loadTask: Task<Void, Never>?

    private init() {
        // bible.json tem ~4 MB: decodifica fora da main para não congelar a abertura da aba.
        loadTask = Task { await loadJSON() }
    }

    /// Aguarda o carregamento do bible.json (retorna na hora se já carregou).
    func ensureLoaded() async {
        await loadTask?.value
    }

    // MARK: - Public API

    func chapter(bookSlug: String, chapterNumber: Int) -> BibleChapter? {
        let key = "\(bookSlug)-\(chapterNumber)"
        if let cached = chapterCache[key] { return cached }

        guard let chapters = rawData[bookSlug],
            chapterNumber >= 1,
            chapterNumber <= chapters.count
        else { return nil }

        let verseTexts = chapters[chapterNumber - 1]
        let verses = verseTexts.enumerated().map { idx, text in
            BibleVerse(
                id: "\(bookSlug)-\(chapterNumber)-\(idx + 1)",
                book: bookSlug,
                chapter: chapterNumber,
                number: idx + 1,
                text: text
            )
        }
        let chapter = BibleChapter(
            id: key,
            bookSlug: bookSlug,
            number: chapterNumber,
            verses: verses
        )
        chapterCache[key] = chapter
        return chapter
    }

    nonisolated func search(query: String, limit: Int = 50) -> [BibleVerse] {
        guard query.count >= 3 else { return [] }
        let lower = query.lowercased()
        var results: [BibleVerse] = []

        for book in BibleCatalogue.books {
            guard let lcChapters = lowercasedData[book.slug],
                let origChapters = rawData[book.slug]
            else { continue }
            for (chIdx, lcVerses) in lcChapters.enumerated() {
                let chNum = chIdx + 1
                let origVerses = origChapters[chIdx]
                for (vIdx, lcText) in lcVerses.enumerated() {
                    if lcText.contains(lower) {
                        results.append(
                            BibleVerse(
                                id: "\(book.slug)-\(chNum)-\(vIdx + 1)",
                                book: book.slug,
                                chapter: chNum,
                                number: vIdx + 1,
                                text: origVerses[vIdx]
                            ))
                        if results.count >= limit { return results }
                    }
                }
            }
        }
        return results
    }

    func randomVerse() -> BibleVerse? {
        let books = BibleCatalogue.books
        guard let book = books.randomElement(),
            let chapters = rawData[book.slug],
            let chIdx = chapters.indices.randomElement(),
            let vIdx = chapters[chIdx].indices.randomElement()
        else { return nil }

        let chNum = chIdx + 1
        let text = chapters[chIdx][vIdx]
        return BibleVerse(
            id: "\(book.slug)-\(chNum)-\(vIdx + 1)",
            book: book.slug,
            chapter: chNum,
            number: vIdx + 1,
            text: text
        )
    }

    // MARK: - Private

    private func loadJSON() async {
        let loaded = await Task.detached(priority: .userInitiated) {
            () -> (raw: [String: [[String]]], lower: [String: [[String]]])? in
            guard let url = Bundle.main.url(forResource: "bible", withExtension: "json") else {
                print("[BibleLoader] bible.json not found in bundle")
                return nil
            }
            do {
                let data = try Data(contentsOf: url)
                let raw = try JSONDecoder().decode([String: [[String]]].self, from: data)
                let lower = raw.mapValues { chapters in
                    chapters.map { verses in verses.map { $0.lowercased() } }
                }
                return (raw, lower)
            } catch {
                print("[BibleLoader] Failed to load bible.json: \(error)")
                return nil
            }
        }.value
        guard let loaded else { return }
        rawData = loaded.raw
        lowercasedData = loaded.lower
    }
}
