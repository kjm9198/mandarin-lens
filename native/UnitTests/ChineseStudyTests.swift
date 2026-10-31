import Foundation
import Testing
@testable import MandarinLens

@Test func isolatedEnglishWordsDoNotBecomeUnsupportedLanguages() {
    #expect(TranslationSource.language(text: "Control") == "en")
    #expect(TranslationSource.language(text: "Control",context: "Sentence shortcut Control Space") == "en")
    #expect(TranslationSource.language(text: "coffee") == "en")
    #expect(TranslationSource.language(text: "kawa",preference: "pl") == "pl")
    #expect(TranslationSource.language(text: "cześć") == "pl")
    #expect(TranslationSource.language(text: "dzień dobry") == "pl")
    #expect(TranslationSource.language(text: "dziękuję") == "pl")
    #expect(TranslationSource.language(text: "herbata") == "pl")
    #expect(TranslationSource.language(text: "xin chào") == "vi")
    #expect(TranslationSource.language(text: "学习",preference: "en") == "zh-Hans")
}

@Test @MainActor func polishTranslationsAndDualTargetSupport() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let lens = Lens(dataDirectory: root)
    
    // Polish to English translation fallback
    #expect(TranslationSource.isPolish("strajk") == true)
    #expect(TranslationSource.language(text: "strajk") == "pl")
    #expect(lens.lookupFallbackTranslation(text: "strajk", source: "pl", target: "en") == "Strike")
    #expect(lens.lookupFallbackTranslation(text: "strajk", source: "pl", target: "zh-Hans") == "罢工")
    #expect(lens.lookupFallbackTranslation(text: "dzień dobry", source: "pl", target: "en") != nil)
    #expect(lens.lookupFallbackTranslation(text: "dziękuję", source: "pl", target: "en") == "Thank you")
    #expect(lens.lookupFallbackTranslation(text: "herbata", source: "pl", target: "en") == "Tea")

    // English to Polish fallback
    #expect(lens.lookupFallbackTranslation(text: "good morning", source: "en", target: "pl") == "Dzień dobry")
    #expect(lens.lookupFallbackTranslation(text: "thank you", source: "en", target: "pl") == "Dziękuję")

    // Dual target translation (English -> Chinese + Polish)
    lens.sourceChoice = "en"
    lens.target = "zh-Hans"
    lens.secondaryTarget = "pl"
    lens.input = "good morning"
    lens.translate()

    let primaryReq = try #require(lens.translationRequest)
    let secondaryReq = try #require(lens.secondaryRequest)
    #expect(primaryReq.target == "zh-Hans")
    #expect(secondaryReq.target == "pl")

    lens.completeTranslation("早上好", request: primaryReq)
    lens.completeSecondaryTranslation("Dzień dobry", request: secondaryReq)

    #expect(lens.output == "早上好")
    #expect(lens.secondaryOutput == "Dzień dobry")

    // Slower speech rate verification
    #expect(lens.speaker.slowRate == true)
    #expect(lens.speaker.rateMultiplier == 0.55)
}
@Test func examplesMustUseTheSelectedChineseWord() throws {
    #expect(try ChineseStudy.sentence("```json\n{\"chinese\":\"请控制你的声音。\"}\n```",word: "控制") == "请控制你的声音。")
    #expect(throws: (any Error).self) { try ChineseStudy.sentence("{\"chinese\":\"我喜欢咖啡。\"}",word: "控制") }
    #expect(throws: (any Error).self) { try ChineseStudy.sentence("{\"chinese\":\"控制\"}",word: "控制") }
    #expect(throws: (any Error).self) { try ChineseStudy.sentence("unstructured incomplete answer",word: "控制") }
    let example = ChineseExample(word: "学习",chinese: "我喜欢学习中文。",english: "I like learning Chinese.")
    #expect(example.pinyin.contains("xué xí"))
    #expect(try JSONDecoder().decode(ChineseExample.self,from: JSONEncoder().encode(example)) == example)
}
@Test @MainActor func chineseResultsSaveAsChineseDictionaryHeadwordsAndKeepExamples() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let lens = Lens(dataDirectory: root)
    lens.sourceChoice = "auto"; lens.target = "zh-Hans"; lens.captureKind = .word
    lens.input = "Control"; lens.capturedContext = "Control the volume"; lens.translate()
    let request = try #require(lens.translationRequest)
    lens.completeTranslation("控制",request: request)
    lens.saveCurrentWord()
    let saved = try #require(lens.vocabulary.words.first)
    #expect(saved.term == "控制" && saved.meaning == "Control" && saved.targetLanguage == "en")
    #expect(saved.pronunciation == "kòng zhì")
    let example = ChineseExample(word: "控制",chinese: "请控制你的声音。",english: "Please control your voice.")
    lens.vocabulary.attachExample(example)
    let restored = Vocabulary(url: root.appendingPathComponent("words.json"))
    #expect(restored.words.first?.usageExample == example)
    #expect(restored.words.first?.nextReview == saved.nextReview)
    let legacy = Data("[{\"term\":\"茶\",\"meaning\":\"Tea\",\"sourceLanguage\":\"zh-Hans\",\"targetLanguage\":\"en\",\"category\":\"Food & drink\",\"manualCategory\":false,\"example\":\"\",\"created\":0,\"nextReview\":0,\"intervalDays\":0,\"id\":\"00000000-0000-0000-0000-000000000001\"}]".utf8)
    #expect(try JSONDecoder().decode([SavedWord].self,from: legacy)[0].usageExample == nil)
}

@Test @MainActor func changingSourceNeverReusesThePreviousLanguageTranslation() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let lens = Lens(dataDirectory: root)
    lens.target = "zh-Hans"; lens.sourceChoice = "en"; lens.input = "kawa"; lens.translate()
    let english = try #require(lens.translationRequest)
    lens.completeTranslation("English fixture",request: english)
    lens.sourceChoice = "pl"
    #expect(lens.translationRequest?.sourceLanguage == "pl")
    #expect(lens.translationRequest?.id != english.id && !lens.canSaveWord)
    #expect(lens.output == "Translating…")
    lens.completeTranslation("stale",request: english)
    #expect(!lens.canSaveWord)
}
