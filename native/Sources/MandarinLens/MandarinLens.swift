import SwiftUI
import AppKit
import ApplicationServices
import Translation
import NaturalLanguage
import Combine

enum CaptureKind: String, Codable, CaseIterable, Sendable {
    case word, sentence, area, typed
    var title: String { switch self { case .word: "Word"; case .sentence: "Sentence"; case .area: "Screen area"; case .typed: "Translation" } }
    var symbol: String { switch self { case .word: "character.cursor.ibeam"; case .sentence: "text.alignleft"; case .area: "viewfinder"; case .typed: "character.bubble" } }
}
struct Entry: Codable, Identifiable {
    var id = UUID()
    var source: String
    var translation: String
    var language: String
    var date = Date()
    var kind: CaptureKind = .typed
    var context = ""
    var favorite = false
    var error: String?
    var usageExample: ChineseExample?
    var sourceLanguage: String?
    var sourcePreference: String?
    var quality: String?
    var pronunciation: String { source.range(of: "\\p{Han}", options: .regularExpression) == nil ? "" : source.applyingTransform(.mandarinToLatin, reverse: false) ?? "" }
}
extension Entry {
    enum CodingKeys: String, CodingKey { case id, source, translation, language, date, kind, context, favorite, error, usageExample, sourceLanguage, sourcePreference, quality }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        source = try c.decode(String.self, forKey: .source)
        translation = try c.decode(String.self, forKey: .translation)
        language = try c.decode(String.self, forKey: .language)
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        kind = try c.decodeIfPresent(CaptureKind.self, forKey: .kind) ?? .typed
        context = try c.decodeIfPresent(String.self, forKey: .context) ?? ""
        favorite = try c.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
        error = try c.decodeIfPresent(String.self, forKey: .error)
        usageExample = try c.decodeIfPresent(ChineseExample.self,forKey: .usageExample)
        sourceLanguage = try c.decodeIfPresent(String.self,forKey: .sourceLanguage)
        sourcePreference = try c.decodeIfPresent(String.self,forKey: .sourcePreference)
        quality = try c.decodeIfPresent(String.self,forKey: .quality)
    }
}
@MainActor final class Lens: ObservableObject {
    static let shared: Lens = {
        if CommandLine.arguments.contains("--acceptance-testing"), let index = CommandLine.arguments.firstIndex(of: "--test-data-directory"), index+1 < CommandLine.arguments.count {
            let lens = Lens(dataDirectory: URL(fileURLWithPath: CommandLine.arguments[index+1])); if let targetIndex = CommandLine.arguments.firstIndex(of: "--test-target"), targetIndex+1 < CommandLine.arguments.count { lens.target = CommandLine.arguments[targetIndex+1] }; return lens
        }
        let defaults = UserDefaults.standard
        if let old = defaults.persistentDomain(forName: "studio.kamihi.mandarinlens") {
            for key in ["target", "opacity", "explanationLanguage", "sticky", "chatModel", "localModelPort", "customModelFolders", "onboardingComplete", "shortcutChoice"] where defaults.object(forKey: key) == nil { defaults.set(old[key], forKey: key) }
        }
        return Lens()
    }()
    let notepad: NotepadStore
    let speaker = WordSpeaker.shared
    let updater = UpdateManager.shared
    var notepadPanel: NSPanel?
    var notepadReturnsToWorkspace = true
    @Published var notedTranslationID: UUID?
    let notesShortcut = GlobalShortcut(signature: 0x4B4C4E54)
    @Published var notesShortcutStatus = ""
    let vocabulary: Vocabulary
    let models = LocalModels()
    let chats: ChatStore
    let shortcut = GlobalShortcut()
    let areaShortcut = GlobalShortcut(signature: 0x4B4C4152)
    let sentenceShortcut = GlobalShortcut(signature: 0x4B4C534E)
    @Published var areaShortcutStatus = ""
    @Published var sentenceShortcutStatus = ""
    @Published var sentenceShortcutChoice = UserDefaults.standard.string(forKey: "sentenceShortcutChoice") ?? "Control–Space" { didSet { if savesPreferences { UserDefaults.standard.set(sentenceShortcutChoice, forKey: "sentenceShortcutChoice") }; registerShortcut() } }
    @Published var captureKind: CaptureKind = .typed
    @Published var popupVisible = false
    let recaps: RecapStore
    @Published var recapScope: RecapScope = .week
    @Published var recapDraft = ""
    @Published var recapBusy = false
    @Published var recapStatus = ""
    var recapTask: Task<Void, Never>?
    var recapGeneration = UUID()
    var popup: NSPanel?
    var popupAnchor = CGPoint.zero
    let selection = ScreenSelection()
    @Published var selectionStatus = "Ready · press Option–Space to select a word"
    var chatTask: Task<Void, Never>?
    private var modelObservation: AnyCancellable?
    var chatGeneration = UUID()
    @Published var explanationLanguage = UserDefaults.standard.string(forKey: "explanationLanguage") ?? "en" { didSet { if savesPreferences { UserDefaults.standard.set(explanationLanguage, forKey: "explanationLanguage") } } }
    @Published var input = "" { didSet { if oldValue != input { invalidateTranslation(); capturedContext = "" } } }
    @Published var output = "Press Option–Space, then click a word anywhere on screen. Or paste text here."
    @Published var sourceChoice = UserDefaults.standard.string(forKey: "sourceChoice") ?? "auto" { didSet { if savesPreferences { UserDefaults.standard.set(sourceChoice,forKey: "sourceChoice") }; if oldValue != sourceChoice { invalidateTranslation(); if !input.isEmpty && !restoringTranslation { translate() } } } }
    @Published var translationQuality = UserDefaults.standard.string(forKey: "translationQuality") ?? "fast" { didSet { if savesPreferences { UserDefaults.standard.set(translationQuality,forKey: "translationQuality") }; if oldValue != translationQuality { invalidateTranslation(); if !input.isEmpty && !restoringTranslation { translate() } } } }
    @Published var usageExample: ChineseExample?
    @Published var exampleStatus = ""
    @Published var exampleJob: ChineseExampleJob?
    var exampleTask: Task<Void,Never>?
    @Published var slowSpeech: Bool = WordSpeaker.shared.slowRate { didSet { WordSpeaker.shared.slowRate = slowSpeech } }
    @Published var target = UserDefaults.standard.string(forKey: "target") ?? "zh-Hans" { didSet { if savesPreferences { UserDefaults.standard.set(target, forKey: "target") }; if oldValue != target { invalidateTranslation(); if !input.isEmpty && !restoringTranslation { translate() } } } }
    @Published var secondaryTarget = UserDefaults.standard.string(forKey: "secondaryTarget") ?? "pl" { didSet { if savesPreferences { UserDefaults.standard.set(secondaryTarget, forKey: "secondaryTarget") }; if oldValue != secondaryTarget { invalidateTranslation(); if !input.isEmpty && !restoringTranslation { translate() } } } }
    @Published var secondaryOutput: String = ""
    @Published var secondaryConfiguration: TranslationSession.Configuration?
    @Published var secondaryRequest: TranslationRequest?
    private var secondarySessionSeed = TranslationSession.Configuration()
    @Published var opacity = UserDefaults.standard.object(forKey: "opacity") as? Double ?? 0.96 { didSet { if savesPreferences { UserDefaults.standard.set(opacity, forKey: "opacity") }; applyWindowPreferences() } }
    @Published var sticky = UserDefaults.standard.bool(forKey: "sticky") { didSet { if savesPreferences { UserDefaults.standard.set(sticky, forKey: "sticky") }; applyWindowPreferences() } }
    @Published var capturing = false
    @Published var shortcutChoice = UserDefaults.standard.string(forKey: "shortcutChoice") ?? "Option–Space" { didSet { if savesPreferences { UserDefaults.standard.set(shortcutChoice, forKey: "shortcutChoice") }; registerShortcut() } }
    @Published var shortcutStatus = ""
    @Published var history: [Entry] = []
    @Published var historyStatus = ""
    private var historyRequests: [UUID: UUID] = [:]
    @Published var question = ""
    @Published var answer = ""
    @Published var busy = false
    @Published var areaJobs: [AreaTranslationJob] = []
    var areaPlan: AreaTranslationPlan?
    var areaResults: [Int: String] = [:]
    var completedAreaJobs: Set<UUID> = []
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
    private var historyDamaged = false
    let store: URL
    init(dataDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Mandarin Lens")) {
        savesPreferences = dataDirectory == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Mandarin Lens")
        notepad = NotepadStore(url: dataDirectory.appendingPathComponent("notes.json"))
        vocabulary = Vocabulary(url: dataDirectory.appendingPathComponent("words.json"))
        chats = ChatStore(url: dataDirectory.appendingPathComponent("chats.json"))
        recaps = RecapStore(url: dataDirectory.appendingPathComponent("recaps.json"))
        store = dataDirectory.appendingPathComponent("history.json")
        if FileManager.default.fileExists(atPath: store.path) {
            do { history = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: store)) }
            catch { historyDamaged = true; output = "History could not be read. The original file is preserved." }
        }
        modelObservation = models.$selected.dropFirst().sink { [weak self] _ in self?.stopChat(); self?.recapTask?.cancel() }
        if savesPreferences && !CommandLine.arguments.contains("--acceptance-testing") {
            Task { [weak self] in
                await self?.updater.checkForUpdates(manual: false)
            }
        }
    }
    func applyWindowPreferences() {
        let solid = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        for window in [panel].compactMap({ $0 }) { window.alphaValue = solid ? 1 : min(1, max(0.35, opacity)) }
        panel?.level = sticky ? .floating : .normal
    }
    func show() { showWorkspace(compact: !workspaceMode) }
    func showWorkspace(compact: Bool = false) {
        let hadLookup = popupVisible
        selection.cancel(notify: false)
        dismissPopup(cancelTranslation: false)
        if hadLookup { workspacePage = "Translate" }
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
        panel?.minSize = compact ? NSSize(width: 390,height: 480) : NSSize(width: 760,height: 560)
        panel?.setContentSize(compact ? NSSize(width: 410, height: 570) : NSSize(width: 1060, height: 760))
        applyWindowPreferences(); NSApp.unhide(nil); panel?.center(); panel?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if output == "Translating…", translationRequest?.kind != .area, translationRequest != nil { configurationSeed.invalidate(); configuration = configurationSeed }
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
    func acceptScreenWord(_ word: ScreenWord, showResult: Bool = true) {
        invalidateTranslation()
        input = word.text; capturedContext = word.context; captureKind = word.kind
        popupAnchor = NSEvent.mouseLocation
        if showResult { showPopup() }; translate()
    }
    func startSelection(_ kind: CaptureKind) {
        selection.toggle(mode: kind)
    }
    func screenPermission() {
        _ = CGRequestScreenCaptureAccess()
        selectionStatus = CGPreflightScreenCaptureAccess() ? "Screen selection is ready." : "Allow Kamihi Lens in System Settings → Privacy & Security → Screen & System Audio Recording."
    }
    func registerShortcut() {
        let notes = notesShortcut.register(choice: "Control–Option–N")
        notesShortcutStatus = notes == 0 ? "Control–Option–N · floating notepad" : "Notepad shortcut is unavailable. Use the Notepad tab or menu."
        let status = shortcut.register(choice: "Option–Space")
        shortcutStatus = status == 0 ? "Option–Space · word" : "Option–Space is in use by another app (\(status))."
        let area = areaShortcut.register(choice: "Control–Option–Space")
        areaShortcutStatus = area == 0 ? "Control–Option–Space · screen area" : "Area shortcut unavailable (\(area))."
        let sentence = sentenceShortcut.register(choice: sentenceShortcutChoice)
        sentenceShortcutStatus = sentence == 0 ? "\(sentenceShortcutChoice) · sentence" : "\(sentenceShortcutChoice) is reserved. Choose Control–Shift–Space below, or change the macOS Input Sources shortcut."
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
        selection.onDismiss = { [weak self] in self?.dismissPopup() }
        shortcut.activate = { [weak self] in self?.startSelection(.word) }
        areaShortcut.activate = { [weak self] in self?.startSelection(.area) }
        sentenceShortcut.activate = { [weak self] in self?.startSelection(.sentence) }
        notesShortcut.activate = { [weak self] in self?.toggleNotepad() }
        registerShortcut()
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            if event.type == .keyUp && event.keyCode == 49 { self?.shortcut.releasePressedState(); self?.areaShortcut.releasePressedState(); self?.sentenceShortcut.releasePressedState() }
            if event.type == .keyDown && event.keyCode == 53 {
                if self?.selection.active == true { self?.selection.cancel(); return nil }
                if self?.popupVisible == true { self?.dismissPopup(); return nil }
            }
            return event
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard event.keyCode == 49 else { return }
            Task { @MainActor in self?.shortcut.releasePressedState(); self?.areaShortcut.releasePressedState(); self?.sentenceShortcut.releasePressedState() }
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return }
            Task { @MainActor in
                guard let self else { return }
                if self.selection.active { self.selection.cancel() }
                else if self.popupVisible { self.dismissPopup() }
            }
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown,.rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.popupVisible, !self.sticky else { return }
                self.dismissPopup()
            }
        } as Any)
        observers.append((NotificationCenter.default, NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.selection.cancel() } }))
        observers.append((NSWorkspace.shared.notificationCenter, NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.applyWindowPreferences() } }))

    }
    func stop() { started = false; observers.forEach { $0.0.removeObserver($0.1) }; observers = []; shortcut.unregister(); areaShortcut.unregister(); sentenceShortcut.unregister(); notesShortcut.unregister(); notepad.flush(); speaker.stop(); notepadPanel?.orderOut(nil); recapTask?.cancel(); exampleTask?.cancel(); monitors.forEach { NSEvent.removeMonitor($0) }; monitors = []; stopChat(); models.job?.cancel(); models.installJob?.cancel(); translationTask?.cancel(); selection.cancel(); highlight?.orderOut(nil) }
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
    func swapTranslationLanguages() {
        guard canSaveWord else { return }
        let source = TranslationSource.language(text: input,context: capturedContext,preference: sourceChoice)
        guard source != "und", source != target else { return }
        let previousTarget = target, text = output
        restoringTranslation = true
        input = text; sourceChoice = previousTarget; target = source; captureKind = .typed
        restoringTranslation = false; translate()
    }
    func invalidateTranslation() {
        speaker.stop()
        exampleTask?.cancel(); exampleTask = nil; exampleJob = nil; usageExample = nil; exampleStatus = ""
        areaJobs = []; areaPlan = nil; areaResults = [:]; completedAreaJobs = []
        translationTask?.cancel(); translationTask = nil; translationRequest = nil; translatedRequest = nil; configuration = nil
        secondaryRequest = nil; secondaryConfiguration = nil; secondaryOutput = ""
    }
    static let polishToEnglishDictionary: [String: String] = [
        "strajk": "Strike", "strajki": "Strikes", "strajkować": "To strike",
        "dzień dobry": "Good morning / Hello", "dzien dobry": "Good morning / Hello",
        "dziękuję": "Thank you", "dziekuje": "Thank you", "dzięki": "Thanks", "dzieki": "Thanks",
        "cześć": "Hello / Hi", "czesc": "Hello / Hi", "proszę": "Please / You're welcome", "prosze": "Please / You're welcome",
        "przepraszam": "Excuse me / I'm sorry", "tak": "Yes", "nie": "No",
        "jak się masz": "How are you?", "jak sie masz": "How are you?", "co tam": "What's up?",
        "co słychać": "How are things?", "co slychac": "How are things?",
        "do widzenia": "Goodbye", "dobranoc": "Good night",
        "woda": "Water", "herbata": "Tea", "kawa": "Coffee", "chleb": "Bread", "jedzenie": "Food",
        "praca": "Work / Job", "dom": "Home / House", "szkoła": "School", "szkola": "School",
        "kot": "Cat", "pies": "Dog", "jutro": "Tomorrow", "dzisiaj": "Today", "wczoraj": "Yesterday",
        "miłość": "Love", "milosc": "Love", "przyjaciel": "Friend", "rodzina": "Family",
        "pieniądze": "Money", "pieniadze": "Money", "sklep": "Shop / Store", "pomoc": "Help",
        "czas": "Time", "życie": "Life", "zycie": "Life", "ludzie": "People", "człowiek": "Person", "czlowiek": "Person",
        "droga": "Road / Way", "samochód": "Car", "samochod": "Car", "auto": "Car", "pociąg": "Train", "pociag": "Train",
        "morze": "Sea", "miasto": "City", "państwo": "Country", "panstwo": "Country", "kraj": "Country",
        "świat": "World", "swiat": "World", "pokój": "Room / Peace", "pokoj": "Room / Peace", "wojna": "War",
        "rząd": "Government", "rzad": "Government", "sejm": "Parliament", "protest": "Protest",
        "wolność": "Freedom", "wolnosc": "Freedom", "solidarność": "Solidarity", "solidarnosc": "Solidarity",
        "słońce": "Sun", "slonce": "Sun", "deszcz": "Rain", "śnieg": "Snow", "snieg": "Snow", "wiatr": "Wind",
        "rok": "Year", "tydzień": "Week", "tydzien": "Week", "miesiąc": "Month", "miesiac": "Month",
        "książka": "Book", "ksiazka": "Book", "język": "Language", "jezyk": "Language", "słowo": "Word", "slowo": "Word"
    ]
    static let englishToPolishDictionary: [String: String] = [
        "strike": "Strajk", "strikes": "Strajki",
        "good morning": "Dzień dobry", "hello": "Cześć / Dzień dobry", "hi": "Cześć",
        "thank you": "Dziękuję", "thanks": "Dzięki", "please": "Proszę",
        "excuse me": "Przepraszam", "sorry": "Przepraszam", "yes": "Tak", "no": "Nie",
        "how are you": "Jak się masz?", "how are you?": "Jak się masz?",
        "goodbye": "Do widzenia", "bye": "Do widzenia", "good night": "Dobranoc",
        "water": "Woda", "tea": "Herbata", "coffee": "Kawa", "bread": "Chleb", "food": "Jedzenie",
        "work": "Praca", "home": "Dom", "house": "Dom", "school": "Szkoła",
        "cat": "Kot", "dog": "Pies", "tomorrow": "Jutro", "today": "Dzisiaj", "yesterday": "Wczoraj",
        "love": "Miłość", "friend": "Przyjaciel", "family": "Rodzina", "money": "Pieniądze", "shop": "Sklep", "help": "Pomoc",
        "time": "Czas", "life": "Życie", "people": "Ludzie", "person": "Człowiek", "road": "Droga", "car": "Samochód",
        "city": "Miasto", "country": "Kraj", "world": "Świat", "freedom": "Wolność", "peace": "Pokój", "war": "Wojna"
    ]
    static let polishToChineseDictionary: [String: String] = [
        "strajk": "罢工", "strajki": "罢工",
        "dzień dobry": "早上好", "dzien dobry": "早上好",
        "dziękuję": "谢谢", "dziekuje": "谢谢", "dzięki": "谢谢", "dzieki": "谢谢",
        "cześć": "你好", "czesc": "你好", "proszę": "请", "prosze": "请",
        "przepraszam": "对不起", "tak": "是的", "nie": "不是",
        "woda": "水", "herbata": "茶", "kawa": "咖啡", "chleb": "面包", "jedzenie": "食物",
        "praca": "工作", "dom": "家", "szkoła": "学校", "szkola": "学校",
        "kot": "猫", "pies": "狗", "jutro": "明天", "dzisiaj": "今天", "wczoraj": "昨天",
        "miłość": "爱", "milosc": "爱", "przyjaciel": "朋友", "rodzina": "家人",
        "pieniądze": "钱", "pieniadze": "钱", "sklep": "商店", "pomoc": "帮助",
        "miasto": "城市", "państwo": "国家", "panstwo": "国家", "świat": "世界", "swiat": "世界"
    ]
    static let englishToChineseDictionary: [String: String] = [
        "strike": "罢工", "strikes": "罢工",
        "good morning": "早上好", "hello": "你好", "hi": "你好", "thank you": "谢谢", "thanks": "多谢",
        "please": "请", "excuse me": "不好意思 / 打扰一下", "sorry": "对不起", "yes": "是的", "no": "不是 / 不",
        "how are you": "你好吗？", "how are you?": "你好吗？", "goodbye": "再见", "bye": "拜拜", "good night": "晚安",
        "water": "水", "tea": "茶", "coffee": "咖啡", "bread": "面包", "food": "食物",
        "work": "工作", "home": "家", "house": "房子", "school": "学校", "cat": "猫", "dog": "狗",
        "tomorrow": "明天", "today": "今天", "yesterday": "昨天", "friend": "朋友", "family": "家人"
    ]
    func lookupFallbackTranslation(text: String, source: String?, target: String) -> String? {
        let clean = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .punctuationCharacters)
        if (source == "pl" || TranslationSource.isPolish(text)) && target == "en" {
            return Self.polishToEnglishDictionary[clean]
        }
        if (source == "pl" || TranslationSource.isPolish(text)) && target.hasPrefix("zh") {
            if let zh = Self.polishToChineseDictionary[clean] { return zh }
            if let en = Self.polishToEnglishDictionary[clean]?.lowercased().split(separator: "/").first?.trimmingCharacters(in: .whitespaces),
               let zh = Self.englishToChineseDictionary[en] { return zh }
        }
        if (source == "en") && target == "pl" {
            return Self.englishToPolishDictionary[clean]
        }
        if (source == "en") && target.hasPrefix("zh") {
            return Self.englishToChineseDictionary[clean]
        }
        return nil
    }
    func translateWeb(text: String, source: String, target: String) async -> String? {
        let cleanTarget = target.hasPrefix("zh") ? (target == "zh-Hant" ? "zh-TW" : "zh-CN") : target
        let cleanSource = source.hasPrefix("zh") ? "zh" : (source == "auto" ? "auto" : source)
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=\(cleanSource)&tl=\(cleanTarget)&dt=t&q=\(encoded)") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [Any],
                  let sentences = json.first as? [[Any]] else { return nil }
            let translated = sentences.compactMap { $0.first as? String }.joined()
            let clean = translated.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? nil : clean
        } catch {
            return nil
        }
    }
    func translate() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let request = translationRequest, request.text == text, request.target == target, output == "Translating…" { return }
        translationTask?.cancel(); configuration = nil; areaJobs = []
        var detected = TranslationSource.language(text: text,context: capturedContext,preference: sourceChoice)
        // If detected matches target (e.g. target is English), but the word is Polish (like "strajk"), correct detected to Polish
        if (detected == target || detected == "en") && target == "en" && TranslationSource.isPolish(text) {
            detected = "pl"
        }
        let request = TranslationRequest(text: text, target: target, kind: captureKind, context: capturedContext,sourceLanguage: detected,sourcePreference: sourceChoice,quality: translationQuality)
        translationRequest = request; translatedRequest = nil; output = "Translating…"

        // Handle dual-language translation if secondary target is selected
        if secondaryTarget != "none" && secondaryTarget != target {
            let secReq = TranslationRequest(text: text, target: secondaryTarget, kind: captureKind, context: capturedContext, sourceLanguage: detected, sourcePreference: sourceChoice, quality: translationQuality)
            secondaryRequest = secReq
            secondaryOutput = "Translating…"
            if detected == secondaryTarget {
                completeSecondaryTranslation(text, request: secReq)
            } else if detected == "pl" || secondaryTarget == "pl" {
                Task { [weak self] in
                    guard let self else { return }
                    await Task.yield()
                    if let secDirect = self.lookupFallbackTranslation(text: text, source: detected, target: self.secondaryTarget) {
                        self.completeSecondaryTranslation(secDirect, request: secReq)
                    } else if let secWeb = await self.translateWeb(text: text, source: detected, target: self.secondaryTarget) {
                        self.completeSecondaryTranslation(secWeb, request: secReq)
                    }
                }
            } else {
                let secSource = detected == "und" ? nil : Locale.Language(identifier: detected)
                secondarySessionSeed.source = secSource
                secondarySessionSeed.target = Locale.Language(identifier: secondaryTarget)
                if #available(macOS 26.4, *) { secondarySessionSeed.preferredStrategy = translationQuality == "fast" ? .lowLatency : .highFidelity }
                secondarySessionSeed.invalidate()
                secondaryConfiguration = secondarySessionSeed
            }
        } else {
            secondaryRequest = nil
            secondaryConfiguration = nil
            secondaryOutput = ""
        }

        if let cached = history.first(where: { $0.source == text && $0.kind == captureKind && $0.language == target && $0.sourceLanguage == request.sourceLanguage && ($0.sourcePreference ?? "auto") == request.sourcePreference && ($0.quality ?? "natural") == request.quality && $0.error == nil && !$0.translation.isEmpty }) {
            completeTranslation(cached.translation, request: request); return
        }
        if request.kind == .area { beginAreaTranslation(request); return }

        // Polish language translation: Apple Translation framework does not support Polish on macOS,
        // so we resolve via local dictionary and high-speed web translation fallback.
        if detected == "pl" || target == "pl" {
            translationTask = Task { [weak self] in
                guard let self else { return }
                await Task.yield()
                if let direct = self.lookupFallbackTranslation(text: text, source: detected, target: self.target) {
                    self.completeTranslation(direct, request: request)
                } else if let webResult = await self.translateWeb(text: text, source: detected, target: self.target) {
                    self.completeTranslation(webResult, request: request)
                } else {
                    self.output = "Translation unavailable for this text. Check connection or dictionary."
                    self.recordTranslation(request, result: "", error: self.output)
                }
            }
            return
        }

        // Explicit source detection also handles repeated same-language requests reliably.
        let source = detected == "und" ? nil : Locale.Language(identifier: detected)
        if detected.hasPrefix("zh") && target.hasPrefix("zh") {
            let transform = StringTransform(target == "zh-Hant" ? "Simplified-Traditional" : "Traditional-Simplified")
            completeTranslation(text.applyingTransform(transform, reverse: false) ?? text, request: request); return
        }
        if detected == target { completeTranslation(text, request: request); return }
        configurationSeed.source = source; configurationSeed.target = Locale.Language(identifier: target)
        if #available(macOS 26.4,*) { configurationSeed.preferredStrategy = translationQuality == "fast" ? .lowLatency : .highFidelity }
        configurationSeed.invalidate()
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
            if let fallback = lookupFallbackTranslation(text: request.text, source: request.sourceLanguage, target: request.target) {
                completeTranslation(fallback, request: request)
            } else if let webResult = await translateWeb(text: request.text, source: request.sourceLanguage ?? "auto", target: request.target) {
                completeTranslation(webResult, request: request)
            } else {
                output = "Translation unavailable: \(error.localizedDescription). Retry or install the language pack in the full app."
                if translatedRequest != request { recordTranslation(request,result: "",error: output) }
            }
        }
    }
    func performSecondaryTranslation(_ session: TranslationSession, request: TranslationRequest) async {
        guard secondaryRequest == request else { return }
        do {
            try Task.checkCancellation()
            let result = try await session.translate(request.text)
            try Task.checkCancellation()
            completeSecondaryTranslation(result.targetText, request: request)
        } catch {
            guard secondaryRequest == request, !(error is CancellationError), !Task.isCancelled else { return }
            if let fallback = lookupFallbackTranslation(text: request.text, source: request.sourceLanguage, target: request.target) {
                completeSecondaryTranslation(fallback, request: request)
            } else if let webResult = await translateWeb(text: request.text, source: request.sourceLanguage ?? "auto", target: request.target) {
                completeSecondaryTranslation(webResult, request: request)
            } else {
                secondaryOutput = "Translation unavailable: \(error.localizedDescription)"
            }
        }
    }
    func completeSecondaryTranslation(_ result: String, request: TranslationRequest) {
        guard secondaryRequest == request else { return }
        secondaryOutput = result
    }
    func completeTranslation(_ result: String, request: TranslationRequest) {
        guard translationRequest == request, input.trimmingCharacters(in: .whitespacesAndNewlines) == request.text, target == request.target else { return }
        guard translatedRequest != request else { return }
        output = result; translatedRequest = request
        recordTranslation(request,result: result)
        if !CommandLine.arguments.contains("--disable-study-examples") { beginChineseExample() }
    }
    func failAreaTranslation(_ request: TranslationRequest,error: Error) {
        guard translationRequest == request else { return }
        areaJobs = []; output = "Area translation unavailable: \(error.localizedDescription). Retry or install the required language packs in the full app."
        recordTranslation(request,result: "",error: output)
    }
    private func recordTranslation(_ request: TranslationRequest,result: String,error: String? = nil) {
        if let id = historyRequests[request.id], let index = history.firstIndex(where: { $0.id == id }) {
            history[index].translation = result; history[index].error = error
        } else {
            let entry = Entry(source: request.text,translation: result,language: request.target,kind: request.kind,context: request.context,error: error,sourceLanguage: request.sourceLanguage,sourcePreference: request.sourcePreference,quality: request.quality)
            historyRequests[request.id] = entry.id; history.insert(entry,at: 0)
        }
        persist()
    }
    func persist() {
        guard !historyDamaged else { historyStatus = "History could not be read; the original file was preserved."; return }
        do {
            try FileManager.default.createDirectory(at: store.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(history).write(to: store, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: store.path)
            historyStatus = ""
        } catch { historyStatus = "Could not save history: \(error.localizedDescription)" }
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
    func restoreTranslation(source: String, translated: String, language: String, context: String = "", usageExample: ChineseExample? = nil) {
        invalidateTranslation(); restoringTranslation = true
        input = source; target = language; output = translated; capturedContext = context
        let request = TranslationRequest(text: source.trimmingCharacters(in: .whitespacesAndNewlines), target: language)
        translationRequest = request; translatedRequest = request; self.usageExample = usageExample; restoringTranslation = false
    }
    func selectedWord() -> String { input }
}
@MainActor final class LensAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent a second copy from registering another shortcut or writing the same stores.
        let duplicate = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let duplicate { duplicate.activate(); NSApp.terminate(nil); return }
        if CommandLine.arguments.contains("--acceptance-testing"), let index = CommandLine.arguments.firstIndex(of: "--appearance-preview"), index+1 < CommandLine.arguments.count {
            NSApp.appearance = NSAppearance(named: CommandLine.arguments[index+1] == "light" ? .aqua : .darkAqua)
        }
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
