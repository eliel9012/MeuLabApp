import Foundation

// MARK: - Models

struct BibleVerse: Identifiable, Hashable {
    let id: String  // e.g. "genesis-1-1"
    let book: String  // slug
    let chapter: Int
    let number: Int
    let text: String
}

struct BibleChapter: Identifiable {
    let id: String  // e.g. "genesis-1"
    let bookSlug: String
    let number: Int
    let verses: [BibleVerse]
}

struct BibleBook: Identifiable, Hashable {
    let id: String  // slug
    let slug: String
    let name: String
    let testament: Testament
    let chapterCount: Int

    enum Testament: String {
        case old = "Antigo Testamento"
        case new = "Novo Testamento"
    }
}

// MARK: - Catalogue (compile-time metadata)

struct BibleCatalogue {
    static let books: [BibleBook] = [
        // Antigo Testamento
        .init(id: "genesis", slug: "genesis", name: "Gênesis", testament: .old, chapterCount: 50),
        .init(id: "exodo", slug: "exodo", name: "Êxodo", testament: .old, chapterCount: 40),
        .init(
            id: "levitico", slug: "levitico", name: "Levítico", testament: .old, chapterCount: 27),
        .init(id: "numeros", slug: "numeros", name: "Números", testament: .old, chapterCount: 36),
        .init(
            id: "deuteronomio", slug: "deuteronomio", name: "Deuteronômio", testament: .old,
            chapterCount: 34),
        .init(id: "josue", slug: "josue", name: "Josué", testament: .old, chapterCount: 24),
        .init(id: "juizes", slug: "juizes", name: "Juízes", testament: .old, chapterCount: 21),
        .init(id: "rute", slug: "rute", name: "Rute", testament: .old, chapterCount: 4),
        .init(
            id: "1-samuel", slug: "1-samuel", name: "1 Samuel", testament: .old, chapterCount: 31),
        .init(
            id: "2-samuel", slug: "2-samuel", name: "2 Samuel", testament: .old, chapterCount: 24),
        .init(id: "1-reis", slug: "1-reis", name: "1 Reis", testament: .old, chapterCount: 22),
        .init(id: "2-reis", slug: "2-reis", name: "2 Reis", testament: .old, chapterCount: 25),
        .init(
            id: "1-cronicas", slug: "1-cronicas", name: "1 Crônicas", testament: .old,
            chapterCount: 29),
        .init(
            id: "2-cronicas", slug: "2-cronicas", name: "2 Crônicas", testament: .old,
            chapterCount: 36),
        .init(id: "esdras", slug: "esdras", name: "Esdras", testament: .old, chapterCount: 10),
        .init(id: "neemias", slug: "neemias", name: "Neemias", testament: .old, chapterCount: 13),
        .init(id: "ester", slug: "ester", name: "Ester", testament: .old, chapterCount: 10),
        .init(id: "jo", slug: "jo", name: "Jó", testament: .old, chapterCount: 42),
        .init(id: "salmos", slug: "salmos", name: "Salmos", testament: .old, chapterCount: 150),
        .init(
            id: "proverbios", slug: "proverbios", name: "Provérbios", testament: .old,
            chapterCount: 31),
        .init(
            id: "eclesiastes", slug: "eclesiastes", name: "Eclesiastes", testament: .old,
            chapterCount: 12),
        .init(id: "canticos", slug: "canticos", name: "Cânticos", testament: .old, chapterCount: 8),
        .init(id: "isaias", slug: "isaias", name: "Isaías", testament: .old, chapterCount: 66),
        .init(
            id: "jeremias", slug: "jeremias", name: "Jeremias", testament: .old, chapterCount: 52),
        .init(
            id: "lamentacoes-de-jeremias", slug: "lamentacoes-de-jeremias", name: "Lamentações",
            testament: .old, chapterCount: 5),
        .init(
            id: "ezequiel", slug: "ezequiel", name: "Ezequiel", testament: .old, chapterCount: 48),
        .init(id: "daniel", slug: "daniel", name: "Daniel", testament: .old, chapterCount: 12),
        .init(id: "oseias", slug: "oseias", name: "Oséias", testament: .old, chapterCount: 14),
        .init(id: "joel", slug: "joel", name: "Joel", testament: .old, chapterCount: 3),
        .init(id: "amos", slug: "amos", name: "Amós", testament: .old, chapterCount: 9),
        .init(id: "obadias", slug: "obadias", name: "Obadias", testament: .old, chapterCount: 1),
        .init(id: "jonas", slug: "jonas", name: "Jonas", testament: .old, chapterCount: 4),
        .init(id: "miqueias", slug: "miqueias", name: "Miquéias", testament: .old, chapterCount: 7),
        .init(id: "naum", slug: "naum", name: "Naum", testament: .old, chapterCount: 3),
        .init(
            id: "habacuque", slug: "habacuque", name: "Habacuque", testament: .old, chapterCount: 3),
        .init(id: "sofonias", slug: "sofonias", name: "Sofonias", testament: .old, chapterCount: 3),
        .init(id: "ageu", slug: "ageu", name: "Ageu", testament: .old, chapterCount: 2),
        .init(
            id: "zacarias", slug: "zacarias", name: "Zacarias", testament: .old, chapterCount: 14),
        .init(
            id: "malaquias", slug: "malaquias", name: "Malaquias", testament: .old, chapterCount: 4),
        // Novo Testamento
        .init(id: "mateus", slug: "mateus", name: "Mateus", testament: .new, chapterCount: 28),
        .init(id: "marcos", slug: "marcos", name: "Marcos", testament: .new, chapterCount: 16),
        .init(id: "lucas", slug: "lucas", name: "Lucas", testament: .new, chapterCount: 24),
        .init(id: "joao", slug: "joao", name: "João", testament: .new, chapterCount: 21),
        .init(id: "atos", slug: "atos", name: "Atos", testament: .new, chapterCount: 28),
        .init(id: "romanos", slug: "romanos", name: "Romanos", testament: .new, chapterCount: 16),
        .init(
            id: "1-corintios", slug: "1-corintios", name: "1 Coríntios", testament: .new,
            chapterCount: 16),
        .init(
            id: "2-corintios", slug: "2-corintios", name: "2 Coríntios", testament: .new,
            chapterCount: 13),
        .init(id: "galatas", slug: "galatas", name: "Gálatas", testament: .new, chapterCount: 6),
        .init(id: "efesios", slug: "efesios", name: "Efésios", testament: .new, chapterCount: 6),
        .init(
            id: "filipenses", slug: "filipenses", name: "Filipenses", testament: .new,
            chapterCount: 4),
        .init(
            id: "colossenses", slug: "colossenses", name: "Colossenses", testament: .new,
            chapterCount: 4),
        .init(
            id: "1-tessalonicenses", slug: "1-tessalonicenses", name: "1 Tessalonicenses",
            testament: .new, chapterCount: 5),
        .init(
            id: "2-tessalonicenses", slug: "2-tessalonicenses", name: "2 Tessalonicenses",
            testament: .new, chapterCount: 3),
        .init(
            id: "1-timoteo", slug: "1-timoteo", name: "1 Timóteo", testament: .new, chapterCount: 6),
        .init(
            id: "2-timoteo", slug: "2-timoteo", name: "2 Timóteo", testament: .new, chapterCount: 4),
        .init(id: "tito", slug: "tito", name: "Tito", testament: .new, chapterCount: 3),
        .init(id: "filemom", slug: "filemom", name: "Filemom", testament: .new, chapterCount: 1),
        .init(id: "hebreus", slug: "hebreus", name: "Hebreus", testament: .new, chapterCount: 13),
        .init(id: "tiago", slug: "tiago", name: "Tiago", testament: .new, chapterCount: 5),
        .init(id: "1-pedro", slug: "1-pedro", name: "1 Pedro", testament: .new, chapterCount: 5),
        .init(id: "2-pedro", slug: "2-pedro", name: "2 Pedro", testament: .new, chapterCount: 3),
        .init(id: "1-joao", slug: "1-joao", name: "1 João", testament: .new, chapterCount: 5),
        .init(id: "2-joao", slug: "2-joao", name: "2 João", testament: .new, chapterCount: 1),
        .init(id: "3-joao", slug: "3-joao", name: "3 João", testament: .new, chapterCount: 1),
        .init(id: "judas", slug: "judas", name: "Judas", testament: .new, chapterCount: 1),
        .init(
            id: "apocalipse", slug: "apocalipse", name: "Apocalipse", testament: .new,
            chapterCount: 22),
    ]

    static let oldTestament: [BibleBook] = books.filter { $0.testament == .old }
    static let newTestament: [BibleBook] = books.filter { $0.testament == .new }

    static func book(slug: String) -> BibleBook? {
        books.first { $0.slug == slug }
    }
}
