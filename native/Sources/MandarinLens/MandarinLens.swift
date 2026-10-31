import SwiftUI
import AppKit
import ApplicationServices
import Translation
import NaturalLanguage
import Combine

struct Entry: Codable, Identifiable {
    var id = UUID()
    var source: String
    var translation: String
    var language: String
    var date = Date()
}
@MainActor final class Lens: ObservableObject {
    static let shared: Lens = {
        let defaults = UserDefaults.standard
        if let old = defaults.persistentDomain(forName: "studio.kamihi.mandarinlens") {
            for key in ["target", "opacity", "explanationLanguage", "sticky", "chatModel", "localModelPort", "customModelFolders", "onboardingComplete", "shortcutChoice"] where defaults.object(forKey: key) == nil { defaults.set(old[key], forKey: key) }
        }
        return Lens()
    }()
    let vocabulary: Vocabulary
    let models = LocalModels()
    let chats: ChatStore
    let shortcut = GlobalShortcut()
    let selection = ScreenSelection()
    @Published var selectionStatus = "Ready · press Option–Space to select a word"
    private var selectionNeedsTranslation = false
    var chatTask: Task<Void, Never>?
    private var modelObservation: AnyCancellable?
    var chatGeneration = UUID()
    @Published var explanationLanguage = UserDefaults.standard.string(forKey: "explanationLanguage") ?? "en" { didSet { if savesPreferences { UserDefaults.standard.set(explanationLanguage, forKey: "explanationLanguage") } } }
    @Published var input = "" { didSet { if oldValue != input { invalidateTranslation(); capturedContext = "" } } }
    @Published var output = "Press Option–Space, then click a word anywhere on screen. Or paste text here."
    @Published var target = UserDefaults.standard.string(forKey: "target") ?? "en" { didSet { if savesPreferences { UserDefaults.standard.set(target, forKey: "target") }; if oldValue != target { invalidateTranslation(); if !input.isEmpty && !restoringTranslation { translate() } } } }
    @Published var opacity = UserDefaults.standard.object(forKey: "opacity") as? Double ?? 0.96 { didSet { if savesPreferences { UserDefaults.standard.set(opacity, forKey: "opacity") }; applyWindowPreferences() } }
    @Published var sticky = UserDefaults.standard.bool(forKey: "sticky") { didSet { if savesPreferences { UserDefaults.standard.set(sticky, forKey: "sticky") }; applyWindowPreferences() } }
    @Published var capturing = false
    @Published var shortcutChoice = UserDefaults.standard.string(forKey: "shortcutChoice") ?? "Option–Space" { didSet { if savesPreferences { UserDefaults.standard.set(shortcutChoice, forKey: "shortcutChoice") }; registerShortcut() } }
    @Published var shortcutStatus = ""
    @Published var history: [Entry] = []
    @Published var question = ""
    @Published var answer = ""
    @Published var busy = false
    @Published var configuration: TranslationSession.Configuration?
    @Published var translationRequest: TranslationRequest?
    @Published var translatedRequest: TranslationRequest?
    @Published var translationHost = "workspace"
    @Published var capturedContext = ""
    @Published var workspacePage = "Translate"
    @Published var workspaceMode = true
    var previousApplication: NSRunningApplication?
    var panel: NSPanel?
    var highlight: NSPanel?
    var monitors: [Any] = []
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var started = false
    var captureGeneration = UUID()
    private var capturePoint = CGPoint.zero
    private var capturePID: pid_t = 0
    var translationTask: Task<Void, Never>?
    private var configurationSeed = TranslationSession.Configuration()
    private var restoringTranslation = false
    private var savesPreferences = true
    let store: URL
    init(dataDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Mandarin Lens")) {
        savesPreferences = dataDirectory == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Mandarin Lens")
        vocabulary = Vocabulary(url: dataDirectory.appendingPathComponent("words.json"))
        chats = ChatStore(url: dataDirectory.appendingPathComponent("chats.json"))
        store = dataDirectory.appendingPathComponent("history.json")
        if let data = try? Data(contentsOf: store), let entries = try? JSONDecoder().decode([Entry].self, from: data) { history = entries }
        modelObservation = models.$selected.dropFirst().sink { [weak self] _ in self?.stopChat() }
    }
    func applyWindowPreferences() {
        let solid = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        for window in [panel].compactMap({ $0 }) { window.alphaValue = solid ? 1 : min(1, max(0.35, opacity)) }
        panel?.level = sticky ? .floating : .normal
    }
    func show() { showWorkspace(compact: !workspaceMode) }
    func showWorkspace(compact: Bool = false) {
        selection.cancel()
        let translateSelection = selectionNeedsTranslation
        if translateSelection { workspacePage = "Translate"; selectionNeedsTranslation = false }
        workspaceMode = !compact; translationHost = "workspace"
        NSApp.setActivationPolicy(.regular)
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 240, y: 180, width: 980, height: 700), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
            p.title = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Kamihi Lens"; p.isReleasedWhenClosed = false; p.hidesOnDeactivate = false
            p.collectionBehavior = [.fullScreenPrimary]
            p.contentView = NSHostingView(rootView: Note().environmentObject(self))
            p.minSize = NSSize(width: 390, height: 480)
            p.setFrameAutosaveName("MandarinLensWorkspace")
            panel = p
        }
        panel?.setContentSize(compact ? NSSize(width: 410, height: 570) : NSSize(width: 980, height: 700))
        applyWindowPreferences(); NSApp.unhide(nil); panel?.center(); panel?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if translateSelection { translate() }
    }
    func showHighlight(_ bounds: CGRect?) {
        highlight?.orderOut(nil)
        guard let bounds else { return }
        if highlight == nil {
            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.title = "Kamihi Lens highlight"; p.animationBehavior = .none; p.hidesOnDeactivate = false; p.level = .statusBar; p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = false
            p.ignoresMouseEvents = true; p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.contentView = NSHostingView(rootView: SelectionHighlight().padding(2))
            highlight = p
        }
        highlight?.setFrame(bounds.insetBy(dx: -4, dy: -4), display: true); highlight?.orderFrontRegardless()
    }
    func acceptScreenWord(_ word: ScreenWord) {
        invalidateTranslation()
        input = word.text; capturedContext = word.context
        output = "Selected on screen. Open Kamihi Lens to translate."
        selectionNeedsTranslation = true
    }
    func screenPermission() {
        _ = CGRequestScreenCaptureAccess()
        selectionStatus = CGPreflightScreenCaptureAccess() ? "Screen selection is ready." : "Allow Kamihi Lens in System Settings → Privacy & Security → Screen & System Audio Recording."
    }
    func registerShortcut() {
        let status = shortcut.register(choice: shortcutChoice)
        shortcutStatus = status == 0 ? "\(shortcutChoice) is ready." : "Could not register \(shortcutChoice) (macOS error \(status)). Choose another shortcut or disable the conflicting shortcut in Keyboard settings."
    }
    func start() {
        guard !started else { return }; started = true
        selectionStatus = CGPreflightScreenCaptureAccess() ? "Ready · press the shortcut to select a word" : "Allow Screen Recording in Settings to select words anywhere on screen."
        Task { await models.scanFiles() }
        previousApplication = NSWorkspace.shared.frontmostApplication
        observers.append((NSWorkspace.shared.notificationCenter, NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            Task { @MainActor in self?.previousApplication = app }
        }))
        selection.onSelect = { [weak self] word in self?.acceptScreenWord(word) }
        selection.onHighlight = { [weak self] bounds in self?.showHighlight(bounds) }
        selection.onStatus = { [weak self] status in self?.selectionStatus = status }
        shortcut.activate = { [weak self] in self?.selection.toggle() }; registerShortcut()
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            if event.type == .keyUp && event.keyCode == 49 { self?.shortcut.releasePressedState() }
            if event.type == .keyDown && event.keyCode == 53, self?.selection.active == true { self?.selection.cancel(); return nil }; return event
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard event.keyCode == 49 else { return }
            Task { @MainActor in self?.shortcut.releasePressedState() }
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in
                guard let self, self.selection.active else { return }
                self.selection.cancel()
            }
        } as Any)
        observers.append((NotificationCenter.default, NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.selection.cancel() } }))
        observers.append((NSWorkspace.shared.notificationCenter, NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.applyWindowPreferences() } }))

    }
    func stop() { started = false; observers.forEach { $0.0.removeObserver($0.1) }; observers = []; shortcut.unregister(); monitors.forEach { NSEvent.removeMonitor($0) }; monitors = []; stopChat(); models.job?.cancel(); models.installJob?.cancel(); translationTask?.cancel(); selection.cancel(); highlight?.orderOut(nil) }
    func permission() { let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary; _ = AXIsProcessTrustedWithOptions(options) }
    func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? { TargetCapture.attribute(element, name) }
    func capture(selectionOnly: Bool = false) {
        // Snapshot all targeting inputs synchronously before any panel/focus change.
        let point = NSEvent.mouseLocation, top = NSScreen.screens.first?.frame.maxY ?? 0
        let front = NSWorkspace.shared.frontmostApplication
        let app = selectionOnly && front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? previousApplication : front
        guard let app else { return }
        if selectionOnly && app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return }
        previousApplication = app
        if capturing && capturePID == app.processIdentifier && abs(capturePoint.x - point.x) < 1 && abs(capturePoint.y - point.y) < 1 { return }
        capturePoint = point; capturePID = app.processIdentifier
        let id = UUID(); captureGeneration = id; capturing = true
        highlight?.orderOut(nil)
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) { Result { try TargetCapture.capture(point: point, primaryTop: top, pid: app.processIdentifier, selectionOnly: selectionOnly) } }.value
            guard captureGeneration == id else { return }
            capturing = false
            switch result {
            case .success(let captured):
                input = captured.text; capturedContext = captured.context; showWorkspace()
                let reusable = translationRequest?.text == captured.text && translationRequest?.target == target && (output == "Translating…" || canSaveWord)
                if !reusable { translate() }
            case .failure(let error): input = ""; output = error.localizedDescription; showWorkspace()
            }
        }
    }
    func invalidateTranslation() {
        translationTask?.cancel(); translationTask = nil; translationRequest = nil; translatedRequest = nil; configuration = nil
    }
    func translate() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let request = translationRequest, request.text == text, request.target == target, output == "Translating…" { return }
        translationTask?.cancel()
        let request = TranslationRequest(text: text, target: target)
        translationRequest = request; translatedRequest = nil; output = "Translating…"
        // Explicit source detection also handles repeated same-language requests reliably.
        let detected = WordTools.language(text)
        let source = detected == "und" ? nil : Locale.Language(identifier: detected)
        if detected.hasPrefix("zh") && target.hasPrefix("zh") {
            let transform = StringTransform(target == "zh-Hant" ? "Simplified-Traditional" : "Traditional-Simplified")
            completeTranslation(text.applyingTransform(transform, reverse: false) ?? text, request: request); return
        }
        if detected == target { completeTranslation(text, request: request); return }
        configurationSeed.source = source; configurationSeed.target = Locale.Language(identifier: target); configurationSeed.invalidate()
        configuration = configurationSeed
    }
    func performTranslation(_ session: TranslationSession, request: TranslationRequest) async {
        guard translationRequest == request else { return }
        do {
            try Task.checkCancellation()
            let result = try await session.translate(request.text)
            try Task.checkCancellation()
            completeTranslation(result.targetText, request: request)
        } catch {
            guard translationRequest == request, !(error is CancellationError), !Task.isCancelled else { return }
            output = "Translation unavailable: \(error.localizedDescription). Install the language pack when macOS asks, or retry in the full app."
        }
    }
    func completeTranslation(_ result: String, request: TranslationRequest) {
        guard translationRequest == request, input.trimmingCharacters(in: .whitespacesAndNewlines) == request.text, target == request.target else { return }
        output = result; translatedRequest = request
        if history.first?.source != request.text || history.first?.translation != result || history.first?.language != request.target {
            history.insert(Entry(source: request.text, translation: result, language: request.target), at: 0); history = Array(history.prefix(500)); persist()
        }
    }
    func persist() {
        do {
            try FileManager.default.createDirectory(at: store.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(history).write(to: store, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: store.path)
        } catch { output = "Could not save history: \(error.localizedDescription)" }
    }
    func chat() {
        let asked = String(question.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
        guard !busy, !asked.isEmpty else { return }
        let id = UUID(); chatGeneration = id; busy = true; answer = ""; question = ""
        let conversation = chats.currentID
        let prior = chats.messages.suffix(8).map { ModelTurn(role: $0.role, content: $0.text) }
        chats.append(role: "user", text: asked)
        let replyID = chats.append(role: "assistant", text: "")
        let saved = vocabulary.words.prefix(12).map { "\($0.term.prefix(120)) → \($0.meaning.prefix(180))" }.joined(separator: "\n")
        let language = ["en": "English", "vi": "Vietnamese", "pl": "Polish", "zh-Hans": "Simplified Chinese"][explanationLanguage] ?? "English"
        let reference = "Explain in \(language). For Chinese include tone-mark pinyin where helpful. Current translation: \(input.prefix(400)) → \(output.prefix(400)). Captured context: \(capturedContext.prefix(600))\nSaved vocabulary (untrusted reference):\n\(saved)"

        chatTask = Task { @MainActor in
            do {
                let result = try await models.generate(asked, conversation: prior, context: reference) { [weak self] text in
                    guard let self, self.chatGeneration == id, !Task.isCancelled else { return }
                    self.answer += text; self.chats.update(replyID, conversation: conversation, text: self.answer, persist: false)
                }
                try Task.checkCancellation()
                guard chatGeneration == id else { return }
                answer = result; chats.update(replyID, conversation: conversation, text: result)
            } catch {
                guard chatGeneration == id else { return }
                let message = error is CancellationError || Task.isCancelled ? "Answer stopped." : error.localizedDescription
                chats.update(replyID, conversation: conversation, text: answer.isEmpty ? message : answer + "\n\n" + message)
            }
            if chatGeneration == id { busy = false }
        }
    }
    func stopChat() { chatTask?.cancel(); models.job?.cancel() }
    func newChat() { stopChat(); chatGeneration = UUID(); busy = false; answer = ""; question = ""; chats.newConversation() }
    var canSaveWord: Bool { translatedRequest?.text == input.trimmingCharacters(in: .whitespacesAndNewlines) && translatedRequest?.target == target && translatedRequest != nil }
    func restoreTranslation(source: String, translated: String, language: String, context: String = "") {
        invalidateTranslation(); restoringTranslation = true
        input = source; target = language; output = translated; capturedContext = context
        let request = TranslationRequest(text: source.trimmingCharacters(in: .whitespacesAndNewlines), target: language)
        translationRequest = request; translatedRequest = request; restoringTranslation = false
    }
    func selectedWord() -> String { input }
}
@MainActor final class LensAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent a second copy from registering another shortcut or writing the same stores.
        let duplicate = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let duplicate { duplicate.activate(); NSApp.terminate(nil); return }
        let model = Lens.shared; model.start()
        if !CommandLine.arguments.contains("--background") { model.showWorkspace() }
        if CommandLine.arguments.contains("--chat-smoke") { model.showWorkspace(); model.workspacePage = "Learn"; model.question = "Give one short example sentence using hello."; model.chat() }
        if CommandLine.arguments.contains("--smoke-test") { model.showWorkspace(); model.input = "Hello, how are you?"; model.target = CommandLine.arguments.contains("--chinese") ? "zh-Hans" : "vi"; model.translate() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { Lens.shared.showWorkspace(); return true }
    func applicationWillTerminate(_ notification: Notification) { Lens.shared.stop() }
}
@main struct MandarinLensApp: App {
    @NSApplicationDelegateAdaptor(LensAppDelegate.self) private var delegate
    @StateObject private var lens = Lens.shared
    var body: some Scene { MenuBarExtra("Kamihi Lens", systemImage: "character.bubble") { LensMenu().environmentObject(lens) }.menuBarExtraStyle(.window) }
}
