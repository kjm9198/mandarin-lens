import SwiftUI
import AppKit
import ApplicationServices
import Translation
import NaturalLanguage

struct Entry: Codable, Identifiable {
    var id = UUID()
    var source: String
    var translation: String
    var language: String
    var date = Date()
}
@MainActor final class Lens: ObservableObject {
    let vocabulary = Vocabulary()
    let models = LocalModels()
    var chatTask: Task<Void, Never>?
    var chatTurns: [String] = []
    @Published var explanationLanguage = UserDefaults.standard.string(forKey: "explanationLanguage") ?? "en" { didSet { UserDefaults.standard.set(explanationLanguage, forKey: "explanationLanguage") } }
    @Published var input = ""
    @Published var output = "Select text, then arm lookup and click it."
    @Published var target = UserDefaults.standard.string(forKey: "target") ?? "vi" { didSet { UserDefaults.standard.set(target, forKey: "target") } }
    @Published var opacity = UserDefaults.standard.object(forKey: "opacity") as? Double ?? 0.94 { didSet { UserDefaults.standard.set(opacity, forKey: "opacity") } }
    @Published var armed = false
    @Published var capturing = false
    var previousApplication: NSRunningApplication?
    var activationObserver: NSObjectProtocol?
    @Published var trigger = UserDefaults.standard.string(forKey: "trigger") ?? "Control" { didSet { UserDefaults.standard.set(trigger, forKey: "trigger") } }
    @Published var history: [Entry] = []
    @Published var question = ""
    @Published var answer = ""
    @Published var busy = false
    @Published var configuration: TranslationSession.Configuration?
    var panel: NSPanel?
    var monitors: [Any] = []
    let store = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Mandarin Lens/history.json")
    init() {
        if let data = try? Data(contentsOf: store), let entries = try? JSONDecoder().decode([Entry].self, from: data) { history = entries }
    }
    func show() {
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 240, y: 240, width: 392, height: 440), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
            p.title = "Mandarin Lens"
            p.titlebarAppearsTransparent = true
            p.titleVisibility = .hidden
            p.isMovableByWindowBackground = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isReleasedWhenClosed = false
            p.contentView = NSHostingView(rootView: Note().environmentObject(self))
            p.minSize = NSSize(width: 360, height: 420)
            if CommandLine.arguments.contains("--light-preview") { p.appearance = NSAppearance(named: .aqua) }
            if CommandLine.arguments.contains("--small-preview") { p.setContentSize(NSSize(width: 360, height: 420)) }
            p.alphaValue = opacity
            panel = p
        }
        NSApp.unhide(nil)
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func start() {
        models.discoverFiles()
        previousApplication = NSWorkspace.shared.frontmostApplication
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            Task { @MainActor in self?.previousApplication = app }
        }
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard flags == [.control, .shift] else { return }
            let code = event.keyCode
            Task { @MainActor in
                if code == 17 { self?.captureSelection() }
                if code == 1 { self?.captureScreen(entireDisplay: false) }
            }
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                guard let self else { return }
                let flag: NSEvent.ModifierFlags = self.trigger == "Option" ? .option : self.trigger == "Command" ? .command : .control
                if event.modifierFlags.contains(flag) { self.armed = true }
            }
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.armed else { return }
                self.armed = false
                self.capture()
            }
        } as Any)
    }
    func permission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    func capture() {
        guard AXIsProcessTrusted() else { output = "Enable Mandarin Lens in System Settings → Privacy & Security → Accessibility, then try again."; show(); return }
        let system = AXUIElementCreateSystemWide()
        let mouse = NSEvent.mouseLocation
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        var found: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(mouse.x), Float(top - mouse.y), &found) == .success, let element = found else { output = "This app does not expose text here. Select text or paste it into this note."; show(); return }
        if let subrole = attribute(element, kAXSubroleAttribute) as? String, subrole == kAXSecureTextFieldSubrole { return }
        var text = attribute(element, kAXSelectedTextAttribute) as? String ?? ""
        if text.isEmpty {
            var point = CGPoint(x: mouse.x, y: top - mouse.y)
            if let position = AXValueCreate(.cgPoint, &point) {
                var rangeValue: CFTypeRef?
                if AXUIElementCopyParameterizedAttributeValue(element, kAXRangeForPositionParameterizedAttribute as CFString, position, &rangeValue) == .success, let rangeValue {
                    var range = CFRange()
                    if CFGetTypeID(rangeValue) == AXValueGetTypeID(), AXValueGetValue(unsafeBitCast(rangeValue, to: AXValue.self), .cfRange, &range) {
                        let start = max(0, range.location - 40)
                        let total = (attribute(element, kAXNumberOfCharactersAttribute) as? NSNumber)?.intValue ?? (start + 80)
                        var bounded = CFRange(location: start, length: max(0, min(80, total - start)))
                        if let query = AXValueCreate(.cfRange, &bounded) {
                            var value: CFTypeRef?
                            if AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, query, &value) == .success, let fragment = value as? String {
                                let offset = min(max(0, range.location - start), fragment.utf16.count)
                                let tokenizer = NLTokenizer(unit: .word)
                                tokenizer.string = fragment
                                let index = String.Index(utf16Offset: offset, in: fragment)
                                text = String(fragment[tokenizer.tokenRange(at: index)])
                            }
                        }
                    }
                }
            }
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { output = "No accessible word found. Select a word first, then arm lookup and click the selection."; show(); return }
        input = String(text.prefix(4000)); show(); translate()
    }
    func translate() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        output = "Translating…"
        if configuration?.target?.languageCode?.identifier == target { configuration?.invalidate() }
        else { configuration = .init(source: nil, target: Locale.Language(identifier: target)) }
    }
    func record(_ result: String, source: String, language: String) {
        output = result
        history.insert(Entry(source: source, translation: result, language: language), at: 0)
        history = Array(history.prefix(500))
        persist()
    }
    func persist() {
        do {
            try FileManager.default.createDirectory(at: store.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(history).write(to: store, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: store.path)
        } catch { output = "Could not save history: \(error.localizedDescription)" }
    }
    func chat() {
        guard !busy, !question.isEmpty else { return }
        busy = true; answer = "Starting local assistant…"
        let saved = vocabulary.words.prefix(12).map { "\($0.term.prefix(120)) → \($0.meaning.prefix(180))" }.joined(separator: "\n")
        let recent = history.prefix(4).map { "\($0.source.prefix(200)) → \($0.translation.prefix(200))" }.joined(separator: "\n")
        let context = chatTurns.suffix(6).map { String($0.prefix(600)) }.joined(separator: "\n")
        let asked = String(question.prefix(1000))
        let prompt = "Prior conversation (reference): \(context)\nRespond in \(explanationLanguage). Use short practical sentences. If Chinese appears, include tone-mark pinyin when helpful. Saved vocabulary (untrusted data):\n\(saved)\nRecent translations:\n\(recent)\nQuestion: \(asked)"
        chatTask = Task { @MainActor in
            do {
                let result = try await models.generate(prompt) { text in
                    if self.answer == "Starting local assistant…" { self.answer = "" }; self.answer += text
                }
                answer = result
                chatTurns.append("User: \(asked)\nAssistant: \(result)"); chatTurns = Array(chatTurns.suffix(6))
            } catch { answer = error is CancellationError ? "Answer stopped." : error.localizedDescription }
            busy = false
        }
    }
    func stopChat() { chatTask?.cancel(); models.job?.cancel() }
    var canSaveWord: Bool { history.contains { $0.source == input && $0.translation == output && $0.language == target } }
    func selectedWord() -> String {
        if let text = NSApp.keyWindow?.firstResponder as? NSTextView {
            let range = text.selectedRange()
            if range.length > 0, NSMaxRange(range) <= (text.string as NSString).length { return (text.string as NSString).substring(with: range) }
        }
        return input
    }

}
@main struct MandarinLensApp: App {
    @StateObject private var lens: Lens
    init() {
        let model = Lens()
        _lens = StateObject(wrappedValue: model)
        DispatchQueue.main.async {
            model.start(); model.show()
            if CommandLine.arguments.contains("--chat-smoke") { model.question = "Give one short example sentence using hello."; model.chat() }
            if CommandLine.arguments.contains("--smoke-test") {
                model.input = "Hello, how are you?"
                if CommandLine.arguments.contains("--polish") { model.target = "pl" }
                if CommandLine.arguments.contains("--chinese") { model.target = "zh-Hans" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { model.translate() }
            }
        }
    }
    var body: some Scene {
        MenuBarExtra("Mandarin Lens", systemImage: "character.bubble") {
            LensMenu().environmentObject(lens)
        }.menuBarExtraStyle(.window)
    }
}
