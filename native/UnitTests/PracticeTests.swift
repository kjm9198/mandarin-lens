import Testing
import Foundation
@testable import MandarinLens

private func practiceWords() -> [SavedWord] {
    [("学习","Study"),("咖啡","Coffee"),("朋友","Friend"),("谢谢","Thank you"),("你好","Hello"),("美丽","Beautiful")].map {
        SavedWord(term: $0.0,meaning: $0.1,sourceLanguage: "zh-Hans",targetLanguage: "en",category: .everyday)
    }
}
@Test func gamesRejectAmbiguousAnswersAndPreserveToneMarks() {
    var words = practiceWords()
    words.append(SavedWord(term: "学",meaning: "study",sourceLanguage: "zh-Hans",targetLanguage: "en",category: .work))
    words.append(SavedWord(term: "你好",meaning: "Greetings",sourceLanguage: "zh-Hans",targetLanguage: "en",category: .everyday))
    words.append(SavedWord(term: " ",meaning: "Blank",sourceLanguage: "en",targetLanguage: "en",category: .everyday))
    for mode in PracticeMode.allCases {
        let deck = PracticeDeck.eligible(words,mode: mode)
        #expect(deck.count == (mode == .pinyin ? 7 : 6))
        #expect(Set(deck.map { PracticeDeck.answer($0,mode: mode) }).count == deck.count)
    }
    #expect(PracticeDeck.key("má") != PracticeDeck.key("ma"))
    #expect(PracticeDeck.key("nǐ hǎo") == PracticeDeck.key("ni\u{30c} ha\u{30c}o"))
    #expect(PracticeDeck.pieces("谢谢").tiles == ["谢","谢"])
    #expect(PracticeDeck.pieces("Good morning!").tiles == ["Good","morning!"])
    #expect(PracticeDeck.eligible([SavedWord(term: "茶",meaning: "Tea",sourceLanguage: "zh-Hans",targetLanguage: "en",category: .food)],mode: .build).isEmpty)
}
@Test @MainActor func gameChoicesRequireCheckAndCannotAwardTwice() throws {
    for mode in [PracticeMode.meaning,.reverse,.listen,.pinyin] {
        let game = PracticeRound(mode: mode,words: practiceWords())
        let first = try #require(game.current)
        game.advance(); #expect(game.index == 0)
        game.choose("Unknown option"); game.check(); #expect(!game.checked)
        let wrong = try #require(game.choices.first { $0 != PracticeDeck.answer(first,mode: mode) })
        game.choose(wrong); #expect(!game.checked)
        game.check(); game.check()
        #expect(game.checked && !game.correct && game.mistakes == 1)
        game.choose(PracticeDeck.answer(first,mode: mode)); #expect(game.selected == wrong)
        #expect(game.revisit.map(\.id) == [first.id])
        game.advance()
        while let word = game.current {
            game.choose(PracticeDeck.answer(word,mode: mode)); game.check(); game.check(); game.advance()
        }
        #expect(game.finished && game.score == game.rounds.count-1)
    }
}
@Test @MainActor func listeningHintsStayInRevisitAndDoNotCountAsUnassisted() throws {
    let game = PracticeRound(mode: .listen,words: practiceWords())
    let word = try #require(game.current)
    game.reveal(); game.choose(word.term); game.check()
    #expect(game.correct && game.score == 0 && game.assistedIDs == [word.id])
    #expect(game.revisit.count == 1)
}
@Test @MainActor func builderKeepsRepeatedTilesAndHandlesUndo() throws {
    let word = SavedWord(term: "谢谢你",meaning: "Thank you",sourceLanguage: "zh-Hans",targetLanguage: "en",category: .everyday)
    let game = PracticeRound(mode: .build,words: [word])
    for part in ["谢","谢","你"] {
        let tile = try #require(game.bank.indices.first { game.bank[$0] == part && !game.picked.contains($0) })
        game.addPiece(tile); game.addPiece(tile)
    }
    #expect(game.picked.count == 3 && game.builtText == "谢谢你")
    game.undoPiece(); #expect(game.builtText == "谢谢")
    game.clearPieces(); #expect(game.picked.isEmpty)
    for part in ["谢","谢","你"] { game.addPiece(try #require(game.bank.indices.first { game.bank[$0] == part && !game.picked.contains($0) })) }
    game.check(); #expect(game.correct && game.score == 1)
    game.undoPiece(); #expect(game.builtText == word.term)
    game.advance(); #expect(game.finished)
}
@Test @MainActor func matchingBoardsRejectSelfPairsAndFinishAllPairs() throws {
    for mode in [PracticeMode.pairs,.memory] {
        let game = PracticeRound(mode: mode,words: practiceWords())
        let first = game.tiles[0]
        game.flip(first.id); game.flip(first.id); #expect(game.open.count == 1)
        let wrong = try #require(game.tiles.first { $0.wordID != first.wordID && $0.isMeaning != first.isMeaning })
        game.flip(wrong.id); #expect(game.mistakes == 1 && game.open.count == 2 && game.matched.isEmpty)
        let blocked = try #require(game.tiles.first { $0.id != first.id && $0.id != wrong.id })
        game.flip(blocked.id); #expect(game.open.count == 2)
        game.clearOpen(); #expect(game.open.isEmpty)
        for word in game.rounds {
            let tiles = game.tiles.filter { $0.wordID == word.id }
            #expect(tiles.count == 2)
            game.flip(tiles[0].id); game.flip(tiles[1].id)
            game.flip(tiles[0].id); #expect(game.open.isEmpty)
        }
        #expect(game.finished && game.score == game.rounds.count && game.mistakes == 1)
        #expect(game.revisit.count == 2)
        #expect(game.rounds.allSatisfy { $0.intervalDays == 0 })
    }
}
@Test @MainActor func gamesNeverMixLanguagePairsOrMutateLibrary() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = Vocabulary(url: folder.appendingPathComponent("words.json"))
    store.words = practiceWords()
    store.words.append(SavedWord(term: "kawa",meaning: "Coffee",sourceLanguage: "pl",targetLanguage: "en",category: .food))
    #expect(store.persist())
    let before = try Data(contentsOf: store.url)
    let game = PracticeRound(mode: .meaning,words: store.words)
    #expect(game.deck.allSatisfy { PracticeDeck.pairKey($0) == "zh-Hans|en" })
    while let word = game.current { game.choose(word.meaning); game.check(); game.advance() }
    #expect(try Data(contentsOf: store.url) == before)
    #expect(PracticeRound(mode: .meaning,words: []).finished)
}

@Test @MainActor func legacyChineseLanguageCodesShareOnePracticeDeck() {
    var words = practiceWords()
    words[0].sourceLanguage = "ja"; words[0].term = "学"
    words[1].sourceLanguage = "zh"
    let game = PracticeRound(mode: .meaning,words: words)
    #expect(game.deck.count == words.count)
    #expect(Set(game.deck.map(PracticeDeck.pairKey)) == ["zh-Hans|en"])
}
