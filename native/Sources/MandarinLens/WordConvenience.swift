import AppKit
import AVFoundation
import UniformTypeIdentifiers

@MainActor final class WordSpeaker: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    @Published var status = ""
    func stop() { synthesizer.stopSpeaking(at: .immediate) }
    func speak(_ text: String, language: String) {
        let prefix = language.hasPrefix("zh") ? "zh" : language
        guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix(prefix) }) else { status = "Install a \(language) voice in macOS Accessibility → Spoken Content."; return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: String(text.prefix(1000))); utterance.voice = voice; utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        synthesizer.speak(utterance); status = ""
    }
}
extension Vocabulary {
    func exportWords() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Kamihi-Lens-words.json"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do { try JSONEncoder().encode(words).write(to: destination, options: .atomic); status = "Words exported locally." }
        catch { status = "Export failed: \(error.localizedDescription)" }
    }
}
