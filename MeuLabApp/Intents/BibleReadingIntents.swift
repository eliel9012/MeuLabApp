import AppIntents
import Foundation

// MARK: - Read Chapter Intent

@available(iOS 16, *)
struct ReadChapterIntent: AppIntent {
    static var title: LocalizedStringResource = "Ler Capítulo da Bíblia"
    static var description = IntentDescription(
        "Inicia a leitura de um capítulo específico da Bíblia")
    static var openAppWhenRun = true

    @Parameter(title: "Livro", description: "Nome do livro (ex: João, Lucas, Mateus)")
    var book: String?

    @Parameter(title: "Capítulo", description: "Número do capítulo")
    var chapter: Int?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let book = self.book ?? "João"
        let chapter = self.chapter ?? 3

        UserDefaults.standard.set(book, forKey: "bibleReaderBook")
        UserDefaults.standard.set(chapter, forKey: "bibleReaderChapter")
        UserDefaults.standard.set(true, forKey: "bibleReaderShouldPlay")

        let dialog = "Abrindo \(book) capítulo \(chapter) para leitura"
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Ler \(\.$book) capítulo \(\.$chapter)")
    }
}

// MARK: - Pause Bible Reading Intent

@available(iOS 16, *)
struct PauseBibleReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "Pausar Leitura da Bíblia"
    static var description = IntentDescription("Pausa a leitura atual da Bíblia")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set("pause", forKey: "bibleReaderAction")
        return .result(dialog: IntentDialog(stringLiteral: "Leitura pausada"))
    }
}

// MARK: - Resume Bible Reading Intent

@available(iOS 16, *)
struct ResumeBibleReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "Retomar Leitura da Bíblia"
    static var description = IntentDescription("Retoma a leitura pausada da Bíblia")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set("resume", forKey: "bibleReaderAction")
        return .result(dialog: IntentDialog(stringLiteral: "Leitura retomada"))
    }
}

// MARK: - Stop Bible Reading Intent

@available(iOS 16, *)
struct StopBibleReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "Parar Leitura da Bíblia"
    static var description = IntentDescription("Para a leitura atual e reinicia")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        UserDefaults.standard.set("stop", forKey: "bibleReaderAction")

        return .result(dialog: IntentDialog(stringLiteral: "Leitura parada"))
    }
}
