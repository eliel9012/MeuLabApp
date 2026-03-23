import Foundation
import Observation
import SwiftUI

@Observable
final class BibleReaderViewModel {
    private(set) var currentBook: String = "João"
    private(set) var currentChapterNumber: Int = 3
    private(set) var verses: [String] = []

    private(set) var highlightedVerseIndex: Int = 0
    private(set) var isPlaying: Bool = false
    private(set) var isPaused: Bool = false

    let speechService: BibleSpeechService = .init()

    init() {
        setupSpeechServiceCallbacks()
    }

    private func setupSpeechServiceCallbacks() {
        speechService.onVerseChanged = { [weak self] index in
            DispatchQueue.main.async {
                self?.highlightedVerseIndex = index
                self?.scrollToCurrentVerse()
            }
        }

        speechService.onStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .idle:
                    self?.isPlaying = false
                    self?.isPaused = false
                case .playing:
                    self?.isPlaying = true
                    self?.isPaused = false
                case .paused:
                    self?.isPlaying = false
                    self?.isPaused = true
                case .stopped:
                    self?.isPlaying = false
                    self?.isPaused = false
                }
            }
        }

        speechService.onComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.isPlaying = false
                self?.isPaused = false
            }
        }
    }

    func setChapter(book: String, chapter: Int, verses: [String]) {
        speechService.stop()

        self.currentBook = book
        self.currentChapterNumber = chapter
        self.verses = verses
        self.highlightedVerseIndex = 0
        self.isPlaying = false
        self.isPaused = false

        speechService.queueChapter(verses: verses)
    }

    func loadChapterIfNeeded(book: String, chapter: Int, verses: [String]) {
        guard
            self.verses.isEmpty || self.currentBook != book || self.currentChapterNumber != chapter
        else { return }
        setChapter(book: book, chapter: chapter, verses: verses)
    }

    func play() {
        if verses.isEmpty {
            return
        }
        speechService.play()
    }

    func pause() {
        speechService.pause()
    }

    func resume() {
        speechService.resume()
    }

    func stop() {
        speechService.stop()
        highlightedVerseIndex = 0
        isPlaying = false
        isPaused = false
    }

    func skipToVerse(_ index: Int) {
        guard index >= 0, index < verses.count else { return }
        speechService.skipToVerse(index)
    }

    func getVerseWithNumber(_ index: Int) -> String {
        guard index < verses.count else { return "" }
        return "\(index + 1). \(verses[index])"
    }

    private func scrollToCurrentVerse() {
        // Callback para coordenar scroll na View principal
    }
}
