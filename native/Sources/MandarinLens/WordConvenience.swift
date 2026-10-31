import AppKit
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@MainActor final class WordSpeaker: NSObject, ObservableObject, @preconcurrency AVSpeechSynthesizerDelegate {
    static let shared = WordSpeaker()
    private lazy var synthesizer: AVSpeechSynthesizer = { let value = AVSpeechSynthesizer(); value.delegate = self; return value }()
    private var current: AVSpeechUtterance?
    @Published private(set) var playingID: String?
    @Published var status = ""
    var isSpeaking: Bool { playingID != nil }
    static func key(_ text: String,_ language: String) -> String { language+"|"+text }
    func isPlaying(_ text: String,language: String) -> Bool { playingID == Self.key(text,language) }
    func stop() { let active = current != nil; current = nil; playingID = nil; if active { synthesizer.stopSpeaking(at: .immediate) } }
    func speak(_ text: String, language: String) {
        if isPlaying(text,language: language) { stop(); return }
        stop()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let prefix = language.hasPrefix("zh") ? "zh" : language
        let requested = language == "zh-Hant" ? "zh-TW" : language.hasPrefix("zh") ? "zh-CN" : language == "vi" ? "vi-VN" : language == "pl" ? "pl-PL" : language
        guard let voice = AVSpeechSynthesisVoice(language: requested) ?? AVSpeechSynthesisVoice.speechVoices().first(where: { prefix == "zh" ? ($0.language.hasPrefix("zh-CN") || $0.language.hasPrefix("zh-TW")) : $0.language.hasPrefix(prefix) }) else { status = "Install a \(language) voice in macOS Accessibility → Spoken Content."; return }
        let utterance = AVSpeechUtterance(string: text); utterance.voice = voice; utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        current = utterance; playingID = Self.key(text,language); status = ""; synthesizer.speak(utterance)
    }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { finished(utterance) }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { finished(utterance) }
    private func finished(_ utterance: AVSpeechUtterance) { guard current === utterance else { return }; current = nil; playingID = nil }
}
extension Vocabulary {
    func exportWords() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Kamihi-Lens-words.json"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do { try JSONEncoder().encode(words).write(to: destination, options: .atomic); status = "Words exported locally." }
        catch { status = "Export failed: \(error.localizedDescription)" }
    }
}

struct SpeechControl: SwiftUI.View {
    @SwiftUI.ObservedObject var speaker: WordSpeaker
    let text: String
    let language: String
    let title: String
    var body: some SwiftUI.View {
        SwiftUI.Button { speaker.speak(text,language: language) } label: { SwiftUI.Image(systemName: speaker.isPlaying(text,language: language) ? "stop.fill" : "play.fill").font(.system(size: 12)).frame(width: 30,height: 30) }
            .buttonStyle(.plain).foregroundStyle(SwiftUI.Color.lensAccent)
            .accessibilityLabel(speaker.isPlaying(text,language: language) ? "Stop \(title) audio" : "Listen to \(title)")
            .help(speaker.isPlaying(text,language: language) ? "Stop \(title)" : "Play \(title)")
    }
}
