import AVFoundation
import Observation

@Observable
final class BibleSpeechService: NSObject {
    enum SpeechState {
        case idle
        case playing
        case paused
        case stopped
    }

    private(set) var currentState: SpeechState = .idle
    private(set) var currentVerseIndex: Int = 0
    private(set) var totalVerses: Int = 0

    private let synthesizer = AVSpeechSynthesizer()
    private var verseTexts: [String] = []
    private var startFromIndex: Int = 0
    /// Maps each active AVSpeechUtterance to its verse index
    private var utteranceIndexMap: [AVSpeechUtterance: Int] = [:]
    /// Cached best available pt-BR voice
    private let preferredVoice: AVSpeechSynthesisVoice? = {
        // Prefer premium/enhanced voices for natural speech
        let ptBRVoices = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language == "pt-BR"
        }
        // .premium > .enhanced > .default
        if let premium = ptBRVoices.first(where: { $0.quality == .premium }) {
            return premium
        }
        if let enhanced = ptBRVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return AVSpeechSynthesisVoice(language: "pt-BR")
    }()

    var onVerseChanged: ((Int) -> Void)?
    var onStateChanged: ((SpeechState) -> Void)?
    var onComplete: (() -> Void)?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func queueChapter(verses: [String]) {
        stop()
        self.verseTexts = verses
        self.totalVerses = verses.count
        self.currentVerseIndex = 0
    }

    func play() {
        guard !verseTexts.isEmpty else { return }

        if currentState == .paused {
            synthesizer.continueSpeaking()
            updateState(.playing)
            return
        }

        speakFrom(index: 0)
    }

    func pause() {
        guard currentState == .playing else { return }
        synthesizer.pauseSpeaking(at: .word)
        updateState(.paused)
    }

    func resume() {
        guard currentState == .paused else { return }
        synthesizer.continueSpeaking()
        updateState(.playing)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        utteranceIndexMap.removeAll()
        currentVerseIndex = 0
        updateState(.idle)
    }

    func skipToVerse(_ index: Int) {
        guard index >= 0, index < verseTexts.count else { return }
        synthesizer.stopSpeaking(at: .immediate)
        utteranceIndexMap.removeAll()
        speakFrom(index: index)
    }

    // MARK: - Private

    private func speakFrom(index: Int) {
        currentVerseIndex = index
        startFromIndex = index
        onVerseChanged?(index)

        for i in index..<verseTexts.count {
            let utterance = AVSpeechUtterance(string: verseTexts[i])
            utterance.voice = preferredVoice
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
            utterance.pitchMultiplier = 1.05
            utterance.volume = 1.0
            utterance.preUtteranceDelay = i == index ? 0.1 : 0.35
            utterance.postUtteranceDelay = 0.15
            utteranceIndexMap[utterance] = i
            synthesizer.speak(utterance)
        }

        updateState(.playing)
    }

    private func updateState(_ newState: SpeechState) {
        guard currentState != newState else { return }
        currentState = newState
        onStateChanged?(newState)
    }
}

extension BibleSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        guard let index = utteranceIndexMap[utterance] else { return }
        if currentVerseIndex != index {
            currentVerseIndex = index
            onVerseChanged?(index)
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        guard let index = utteranceIndexMap.removeValue(forKey: utterance) else { return }
        if index == verseTexts.count - 1 {
            utteranceIndexMap.removeAll()
            updateState(.idle)
            currentVerseIndex = 0
            onComplete?()
        }
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        utteranceIndexMap.removeValue(forKey: utterance)
    }
}
