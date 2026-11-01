import Testing
import AppKit
import Carbon
@testable import MandarinLens

@Test func shortcutRepeatLatch() {
    var latch = ShortcutLatch()
    let first = latch.press(), repeat1 = latch.press(), repeat2 = latch.press()
    #expect(first); #expect(!repeat1); #expect(!repeat2)
    latch.release(); let next = latch.press(); #expect(next)
}
@Test @MainActor func registrationConflictAndCleanup() {
    let a = GlobalShortcut(), b = GlobalShortcut()
    let first = a.register(choice: "Option–Shift–Space")
    #expect(first == noErr)
    #expect(a.registered)
    #expect(b.register(choice: "Option–Shift–Space") != noErr)
    #expect(!b.registered)
    a.unregister()
    #expect(!a.registered)
    #expect(b.register(choice: "Option–Shift–Space") == noErr)
    b.unregister()
}
@Test func tokenAndSelectionChoice() {
    let text = "hello beautiful world"
    let word = LookupGeometry.wordRange(text, utf16Offset: 9)
    #expect(word.map { (text as NSString).substring(with: $0) } == "beautiful")
    #expect(LookupGeometry.wordRange(text, utf16Offset: 5) == nil)
    let chinese = "我喜欢学习中文。"
    let range = LookupGeometry.wordRange(chinese, utf16Offset: 4)
    #expect(range.map { (chinese as NSString).substring(with: $0) } == "学习")
    #expect(LookupGeometry.preferSelection(CFRange(location: 6, length: 9), pointerOffset: 9))
    #expect(!LookupGeometry.preferSelection(CFRange(location: 6, length: 9), pointerOffset: 1))
    #expect(!LookupGeometry.preferSelection(CFRange(location: 6, length: 9), pointerOffset: 15))
    #expect(LookupGeometry.wordRange("你好😀茶", utf16Offset: 4).map { ("你好😀茶" as NSString).substring(with: $0) } == "茶")
}
@Test func placementAcrossOriginsAndScale() {
    let screens = [CGRect(x: 0,y: 0,width: 1512,height: 982), CGRect(x: -1920,y: -300,width: 1920,height: 1080), CGRect(x: 1512,y: 982,width: 1920,height: 1080)]
    for screen in screens {
        for point in [CGPoint(x: screen.minX,y: screen.minY), CGPoint(x: screen.maxX,y: screen.maxY), CGPoint(x: screen.midX,y: screen.midY)] {
            let frame = LookupGeometry.panelFrame(pointer: point, size: CGSize(width: 340,height: 290), visible: screen)
            #expect(screen.contains(frame))
        }
        let rect = CGRect(x: screen.midX,y: screen.midY,width: 54,height: 22)
        #expect(LookupGeometry.appKitRect(LookupGeometry.appKitRect(rect, primaryTop: 982), primaryTop: 982) == rect)
    }
    // All transforms use logical points; backing scale must never enter AX calculations.
    #expect(LookupGeometry.axPoint(CGPoint(x: -40,y: 1100), primaryTop: 982) == CGPoint(x: -40,y: -118))
}
@Test @MainActor func staleTranslationCannotSaveWrongWord() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let lens = Lens(dataDirectory: root)
    lens.input = "tea"; lens.target = "zh-Hans"; lens.translate()
    let old = try #require(lens.translationRequest)
    lens.input = "coffee"; lens.translate()
    let current = try #require(lens.translationRequest)
    lens.completeTranslation("茶", request: old)
    #expect(!lens.canSaveWord); #expect(lens.history.isEmpty)
    lens.completeTranslation("咖啡", request: current)
    #expect(lens.canSaveWord); #expect(lens.history.count == 1)
    lens.vocabulary.save(term: current.text, meaning: lens.output, target: current.target)
    lens.vocabulary.save(term: current.text, meaning: lens.output, target: current.target)
    #expect(lens.vocabulary.words.count == 1)
    #expect(lens.vocabulary.words[0].term == "coffee" && lens.vocabulary.words[0].meaning == "咖啡")
    let restored = Vocabulary(url: root.appendingPathComponent("words.json"))
    #expect(restored.words.count == 1 && restored.words[0].meaning == "咖啡")
    lens.restoreTranslation(source: "Good morning", translated: "早上好", language: "zh-Hans", context: "Good morning, my friend")
    #expect(lens.canSaveWord && lens.output == "早上好" && lens.capturedContext == "Good morning, my friend")
    lens.completeTranslation("late word response", request: current)
    #expect(lens.output == "早上好")
    lens.output = "咖啡"
    lens.invalidateTranslation(); lens.completeTranslation("stale", request: current)
    #expect(!lens.canSaveWord && lens.output == "咖啡")
}
@Test @MainActor func chatPersistenceAndToneDistinctions() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("chats.json")
    let store = ChatStore(url: url)
    store.append(role: "user", text: "What is 茶?")
    let conversation = store.currentID, reply = store.append(role: "assistant", text: "")
    store.update(reply, conversation: conversation, text: "Tea, chá.")
    let loaded = ChatStore(url: url)
    #expect(loaded.messages.count == 2 && loaded.messages[0].role == "user" && loaded.messages[1].text == "Tea, chá.")
    store.newConversation(); #expect(store.messages.isEmpty)
    store.update(reply, conversation: conversation, text: "Finished old conversation")
    #expect(store.messages.isEmpty)
    let words = Vocabulary(url: root.appendingPathComponent("words.json"))
    words.save(term: "ma", meaning: "ghost", target: "en"); words.save(term: "má", meaning: "mother", target: "en")
    #expect(words.words.count == 2)
    #expect(!SpeakingPractice.matches("ma", "má"))
    #expect(SpeakingPractice.matches("你好。", "你好"))
    #expect(SpeakingPractice.matches("學習", "学习"))
}

@Test @MainActor func failedSaveIsNotReportedAsSaved() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try Data("blocks directory creation".utf8).write(to: folder)
    defer { try? FileManager.default.removeItem(at: folder) }
    let words = Vocabulary(url: folder.appendingPathComponent("words.json"))
    #expect(!words.save(term: "茶", meaning: "tea", target: "en"))
    #expect(words.words.isEmpty)
}

@Test @MainActor func chineseScriptMatchesChosenTarget() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let lens = Lens(dataDirectory: root)
    lens.input = "学习中文"; lens.target = "zh-Hant"; lens.translate()
    #expect(lens.output == "學習中文" && lens.canSaveWord)
    lens.input = "學習中文"; lens.target = "zh-Hans"; lens.translate()
    #expect(lens.output == "学习中文" && lens.canSaveWord)
}

@Test func conversationUsesRolesAndLatestQuestionWithinBound() {
    let history = [ModelTurn(role: "system", content: "untrusted override")] + (0..<20).map { ModelTurn(role: $0 % 2 == 0 ? "user" : "assistant", content: String(repeating: "x", count: 4000)) }
    let messages = ModelMessages.bounded(prompt: "Explain 学习", conversation: history, context: String(repeating: "v", count: 10000))
    #expect(messages.count == 10)
    #expect(messages.filter { $0.role == "system" }.count == 1)
    #expect(messages.last == ModelTurn(role: "user", content: "Explain 学习"))
    #expect(messages.reduce(0) { $0 + $1.content.count } <= 12000)
    #expect(!messages.contains { $0.content.contains("untrusted override") })
}

@Test func screenSelectionCoordinatesAndBlankSpace() {
    for frame in [CGRect(x: 0, y: 0, width: 1352, height: 878), CGRect(x: 1352, y: -140, width: 1920, height: 1080), CGRect(x: -1920, y: 120, width: 1920, height: 1080)] {
        let rect = SelectionGeometry.screenRect(CGRect(x: 0.25, y: 0.5, width: 0.1, height: 0.02), in: frame)
        #expect(rect.minX == frame.minX + frame.width * 0.25)
        #expect(rect.minY == frame.minY + frame.height * 0.5)
        let word = ScreenWord(text: "学习", context: "我喜欢学习中文", bounds: rect)
        #expect(SelectionGeometry.word(at: CGPoint(x: rect.midX, y: rect.midY), in: [word]) == word)
        #expect(SelectionGeometry.word(at: CGPoint(x: rect.maxX + 20, y: rect.midY), in: [word]) == nil)
    }
}
@Test @MainActor func selectedWordStartsTranslationWithoutOpeningWorkspace() {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let lens = Lens(dataDirectory: root)
    lens.target = "en"
    lens.acceptScreenWord(ScreenWord(text: "学习",context: "我喜欢学习中文。",bounds: CGRect(x: 30,y: 40,width: 44,height: 24)),showResult: false)
    #expect(lens.input == "学习" && lens.capturedContext == "我喜欢学习中文。")
    #expect(lens.panel == nil)
    #expect(lens.translationRequest?.text == "学习")
    #expect(lens.translationRequest?.kind == .word)
    #expect(!lens.canSaveWord && lens.history.isEmpty)
    if let request = lens.translationRequest { lens.completeTranslation("Study",request: request) }
    #expect(lens.canSaveWord && lens.history.count == 1)
    #expect(lens.history.first?.context == "我喜欢学习中文。")
}
@Test @MainActor func rasterWordsHaveIndividualBounds() throws {
    let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1400, pixelsHigh: 400, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    NSColor.white.setFill(); CGRect(x: 0,y: 0,width: 1400,height: 400).fill()
    ("beautiful coffee" as NSString).draw(at: CGPoint(x: 60,y: 260), withAttributes: [.font: NSFont.systemFont(ofSize: 48), .foregroundColor: NSColor.black])
    ("我喜欢学习中文" as NSString).draw(at: CGPoint(x: 60,y: 120), withAttributes: [.font: NSFont.systemFont(ofSize: 48), .foregroundColor: NSColor.black])
    NSGraphicsContext.restoreGraphicsState()
    let image = try #require(bitmap.cgImage)
    let frame = CGRect(x: -700,y: 100,width: 700,height: 200)
    let words = try SelectionOCR.words(in: image, screen: frame)
    let beautiful = try #require(words.first { $0.text == "beautiful" })
    let coffee = try #require(words.first { $0.text == "coffee" })
    let chinese = try #require(words.first { $0.text == "学习" })
    #expect(beautiful.bounds.maxX < coffee.bounds.minX)
    #expect(beautiful.bounds.minY > chinese.bounds.maxY)
    #expect(frame.contains(chinese.bounds))
    #expect(SelectionGeometry.word(at: CGPoint(x: coffee.bounds.midX,y: coffee.bounds.midY), in: words)?.text == "coffee")
}

@Test func wrappedSentenceAndRegionPreservePunctuation() throws {
    let lines = [
        ScreenWord(text: "I like learning",context: "I like learning",bounds: CGRect(x: 20,y: 100,width: 140,height: 20),lineIndex: 0),
        ScreenWord(text: "Chinese every day.",context: "Chinese every day.",bounds: CGRect(x: 20,y: 74,width: 170,height: 20),lineIndex: 1),
        ScreenWord(text: "Another sentence.",context: "Another sentence.",bounds: CGRect(x: 20,y: 48,width: 170,height: 20),lineIndex: 2)
    ]
    let words = [
        ScreenWord(text: "learning",context: lines[0].text,bounds: CGRect(x: 80,y: 100,width: 80,height: 20),lineIndex: 0,utf16Offset: 7),
        ScreenWord(text: "Chinese",context: lines[1].text,bounds: CGRect(x: 20,y: 74,width: 70,height: 20),lineIndex: 1,utf16Offset: 0),
        ScreenWord(text: "day",context: lines[1].text,bounds: CGRect(x: 140,y: 74,width: 30,height: 20),lineIndex: 1,utf16Offset: 14),
        ScreenWord(text: "Another",context: lines[2].text,bounds: CGRect(x: 20,y: 48,width: 70,height: 20),lineIndex: 2,utf16Offset: 0)
    ]
    let result = try #require(SelectionGeometry.sentence(at: CGPoint(x: 100,y: 110),words: words,lines: lines))
    #expect(result.text == "I like learning Chinese every day.")
    #expect(result.kind == .sentence)
    #expect(!result.text.contains("Another"))
    let area = try #require(SelectionGeometry.area(CGRect(x: 10,y: 70,width: 190,height: 55),words: words))
    #expect(area.text == "learning\nChinese every day.")
    #expect(area.kind == .area)
    #expect(SelectionGeometry.area(CGRect(x: 400,y: 400,width: 30,height: 30),words: words) == nil)
}
@Test func legacyHistoryAndRecapSampling() throws {
    let old = Data("[{\"source\":\"学习\",\"translation\":\"Study\",\"language\":\"en\",\"date\":0}]".utf8)
    let entries = try JSONDecoder().decode([Entry].self,from: old)
    #expect(entries.count == 1 && entries[0].kind == .typed && !entries[0].favorite)
    #expect(entries[0].pronunciation == "xué xí")
    let now = Date()
    var sample = (0..<50).map { index in Entry(source: String(repeating: "词",count: 400)+"\(index)",translation: String(repeating: "meaning ",count: 100),language: "en",date: now,kind: .word) }
    sample[0].favorite = true
    sample[1].error = "Fixture failure"
    sample[2].date = now.addingTimeInterval(-9*86400)
    let digest = LearningDigest.entries(sample,scope: .week,now: now)
    #expect(digest.count > 0 && digest.count <= 20)
    #expect(!digest.contains { $0.id == sample[1].id || $0.id == sample[2].id })
    let context = LearningDigest.context(digest)
    #expect(context.count <= 3600)
    #expect(digest.enumerated().allSatisfy { context.contains("[\($0.offset+1)]") })
    #expect(LearningDigest.entries(sample,scope: .favorites,now: now).map(\.id) == [sample[0].id])
}
@Test @MainActor func cacheEveryCaptureHistoryAndDictionaryContext() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let lens = Lens(dataDirectory: root)
    lens.history = (0..<510).map { Entry(source: "older \($0)",translation: "meaning",language: "en") }
    lens.target = "en"; lens.input = "学习"; lens.captureKind = .word; lens.capturedContext = "我喜欢学习中文。"; lens.translate()
    let first = try #require(lens.translationRequest)
    lens.completeTranslation("Study",request: first)
    #expect(lens.history.count == 511)
    lens.completeTranslation("Study",request: first)
    #expect(lens.history.count == 511)
    lens.invalidateTranslation(); lens.translate()
    #expect(lens.canSaveWord && lens.output == "Study")
    #expect(lens.history.count == 512)
    #expect(lens.history[0].kind == .word)
    lens.saveCurrentWord()
    #expect(lens.vocabulary.words.first?.example == "我喜欢学习中文。")
    let reloaded = Lens(dataDirectory: root)
    #expect(reloaded.history.count == 512)
    lens.toggleFavorite(lens.history[0].id)
    #expect(lens.history[0].favorite)
    let recaps = RecapStore(url: root.appendingPathComponent("recaps.json"))
    recaps.save(StudyRecap(scope: .favorites,sourceIDs: [lens.history[0].id],text: "Controlled recap"))
    #expect(RecapStore(url: root.appendingPathComponent("recaps.json")).items.count == 1)
}
@Test @MainActor func damagedHistoryAndRecapArePreserved() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
    let damaged = Data("broken-fixture".utf8)
    try damaged.write(to: root.appendingPathComponent("history.json"))
    try damaged.write(to: root.appendingPathComponent("recaps.json"))
    let lens = Lens(dataDirectory: root); lens.persist()
    lens.recaps.save(StudyRecap(scope: .today,sourceIDs: [],text: "Must not overwrite"))
    #expect(try Data(contentsOf: root.appendingPathComponent("history.json")) == damaged)
    #expect(try Data(contentsOf: root.appendingPathComponent("recaps.json")) == damaged)
}

@Test func mixedLanguageAreaPlanTranslatesForeignLinesAndKeepsOrder() throws {
    let request = TranslationRequest(text: "我喜欢学习中文。\nBeautiful coffee, every day.\n我们一起喝咖啡。",target: "en",kind: .area)
    let plan = AreaTranslationPlan(request: request)
    #expect(plan.jobs.count == 1)
    #expect(plan.jobs[0].source == "zh-Hans")
    #expect(plan.jobs[0].lines.map(\.index) == [0,2])
    #expect(plan.immediate[1] == "Beautiful coffee, every day.")
    #expect(plan.combined(plan.immediate) == nil)
    var results = plan.immediate
    results[2] = "Let's drink coffee together."
    results[0] = "I like learning Chinese."
    #expect(plan.combined(results) == "I like learning Chinese.\nBeautiful coffee, every day.\nLet's drink coffee together.")
    let polish = AreaTranslationPlan(request: TranslationRequest(text: request.text,target: "pl",kind: .area))
    #expect(Set(polish.jobs.map(\.source)) == ["en","zh-Hans"])
    #expect(polish.jobs.allSatisfy { $0.parent != request.id })
}

@Test func sectionRespectsExplicitSourceAndRejoinsWrappedSentences() throws {
    let polish = AreaTranslationPlan(request: TranslationRequest(text: "kawa\nherbata",target: "en",kind: .area,sourceLanguage: "pl",sourcePreference: "pl"))
    #expect(polish.immediate.isEmpty)
    #expect(polish.jobs.count == 1 && polish.jobs[0].source == "pl")
    #expect(polish.jobs[0].lines.map(\.text) == ["kawa","herbata"])
    let wrapped = AreaTranslationPlan(request: TranslationRequest(text: "I would like to book a table\nfor two people at seven.\n\n• Keep the receipt\n• Bring your ticket",target: "vi",kind: .area,sourcePreference: "en"))
    #expect(wrapped.jobs[0].lines.map(\.text) == ["I would like to book a table for two people at seven.","• Keep the receipt","• Bring your ticket"])
    #expect(wrapped.combined([0:"Đặt bàn cho hai người lúc bảy giờ.",2:"",3:"Giữ hóa đơn",4:"Mang vé"]) == "Đặt bàn cho hai người lúc bảy giờ.\n\nGiữ hóa đơn\nMang vé")
}
@Test @MainActor func changingTranslationModeInvalidatesCacheAndSwapUsesDetectedSource() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let lens = Lens(dataDirectory: root)
    lens.sourceChoice = "pl"; lens.target = "en"; lens.translationQuality = "fast"; lens.input = "kawa"; lens.translate()
    let fast = try #require(lens.translationRequest)
    lens.completeTranslation("coffee",request: fast)
    lens.translationQuality = "natural"
    #expect(lens.translationRequest?.quality == "natural" && lens.output == "Translating…")
    lens.completeTranslation("stale fast",request: fast)
    #expect(lens.output == "Translating…")
    lens.completeTranslation("coffee",request: try #require(lens.translationRequest))
    lens.swapTranslationLanguages()
    #expect(lens.input == "coffee" && lens.sourceChoice == "en" && lens.target == "pl")
    #expect(lens.translationRequest?.sourceLanguage == "en")
}

@Test func sentenceSelectionAllowsClickingOnSpacesOrPunctuation() throws {
    let line = ScreenWord(text: "Hello world, this is a test.", context: "Hello world, this is a test.", bounds: CGRect(x: 50, y: 100, width: 250, height: 24), lineIndex: 0)
    let words = [
        ScreenWord(text: "Hello", context: line.text, bounds: CGRect(x: 50, y: 100, width: 45, height: 24), lineIndex: 0, utf16Offset: 0),
        ScreenWord(text: "world", context: line.text, bounds: CGRect(x: 100, y: 100, width: 45, height: 24), lineIndex: 0, utf16Offset: 6),
        ScreenWord(text: "this", context: line.text, bounds: CGRect(x: 155, y: 100, width: 35, height: 24), lineIndex: 0, utf16Offset: 13),
        ScreenWord(text: "is", context: line.text, bounds: CGRect(x: 195, y: 100, width: 20, height: 24), lineIndex: 0, utf16Offset: 18),
        ScreenWord(text: "test", context: line.text, bounds: CGRect(x: 235, y: 100, width: 40, height: 24), lineIndex: 0, utf16Offset: 23)
    ]
    // Clicking on comma and space between "world," and "this" (around x: 148, y: 110)
    let hitPunctuation = try #require(SelectionGeometry.sentence(at: CGPoint(x: 148, y: 110), words: words, lines: [line]))
    #expect(hitPunctuation.text == "Hello world, this is a test.")
    #expect(hitPunctuation.kind == .sentence)

    // Paragraph selection on single click in section mode
    let para = try #require(SelectionGeometry.paragraph(at: CGPoint(x: 148, y: 110), lines: [line]))
    #expect(para.text == "Hello world, this is a test.")
    #expect(para.kind == .area)
}
