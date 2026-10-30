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
    let first = a.register(choice: "Control–Option–Space")
    #expect(first == noErr)
    #expect(a.registered)
    #expect(b.register(choice: "Control–Option–Space") != noErr)
    #expect(!b.registered)
    a.unregister()
    #expect(!a.registered)
    #expect(b.register(choice: "Control–Option–Space") == noErr)
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
