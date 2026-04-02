import SwiftUI

// MARK: - Bible Reader Integration Container

struct BibleReaderIntegrationView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = BibleReaderViewModel()

    var body: some View {
        BibleChapterReaderView()
            .onAppear {
                checkForPendingIntents()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    checkForPendingIntents()
                }
            }
    }

    private func checkForPendingIntents() {
        let defaults = UserDefaults.standard

        if let book = defaults.string(forKey: "bibleReaderBook") {
            let chapter = defaults.integer(forKey: "bibleReaderChapter")
            guard chapter > 0 else { return }
            let shouldPlay = defaults.bool(forKey: "bibleReaderShouldPlay")

            let sampleVerses = SampleBibleData.johnChapter3Verses
            viewModel.setChapter(book: book, chapter: chapter, verses: sampleVerses)

            if shouldPlay {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    viewModel.play()
                }
            }

            defaults.removeObject(forKey: "bibleReaderBook")
            defaults.removeObject(forKey: "bibleReaderChapter")
            defaults.removeObject(forKey: "bibleReaderShouldPlay")
        }

        if let action = defaults.string(forKey: "bibleReaderAction") {
            switch action {
            case "pause": viewModel.pause()
            case "resume": viewModel.resume()
            case "stop": viewModel.stop()
            default: break
            }
            defaults.removeObject(forKey: "bibleReaderAction")
        }
    }
}

#Preview {
    BibleReaderIntegrationView()
}
