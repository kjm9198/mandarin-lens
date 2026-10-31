import Foundation
import Combine

enum PracticeMode: String, CaseIterable, Identifiable {
    case meaning, reverse, listen, build, pairs, memory, pinyin
    var id: String { rawValue }
    var title: String {
        switch self {
        case .meaning: "Meaning finder"
        case .reverse: "Reverse recall"
        case .listen: "Listen & choose"
        case .build: "Word builder"
        case .pairs: "Meaning map"
        case .memory: "Memory match"
        case .pinyin: "Pinyin path"
        }
    }
    var symbol: String {
        switch self {
        case .meaning: "text.magnifyingglass"
        case .reverse: "arrow.left.arrow.right"
        case .listen: "headphones"
        case .build: "square.stack.3d.up"
        case .pairs: "point.topleft.down.to.point.bottomright.curvepath"
        case .memory: "rectangle.grid.3x2"
        case .pinyin: "character.phonetic"
        }
    }
    var detail: String {
        switch self {
        case .meaning: "Find the meaning behind each word."
        case .reverse: "Start with the meaning. Recall the word."
        case .listen: "Listen, then choose the word you heard."
        case .build: "Put letters, characters or phrase tiles in order."
        case .pairs: "Connect words and meanings, two at a time."
        case .memory: "Turn over cards and remember each pair."
        case .pinyin: "Connect Chinese words with tone-mark pinyin."
        }
    }
    var isBoard: Bool { self == .pairs || self == .memory }
    var minimum: Int { self == .build ? 1 : 2 }
}

enum PracticeDeck {
    static func key(_ text: String) -> String { text.precomposedStringWithCanonicalMapping.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ") }
    static func language(_ word: SavedWord) -> String {
        if word.sourceLanguage == "zh-Hant" { return "zh-Hant" }
        if word.sourceLanguage.hasPrefix("zh") || (word.sourceLanguage == "ja" && WordTools.language(word.term).hasPrefix("zh")) { return "zh-Hans" }
        return word.sourceLanguage
    }
    static func pairKey(_ word: SavedWord) -> String { language(word) + "|" + word.targetLanguage }
    static func pieces(_ text: String) -> (tiles: [String], separator: String) {
        let words = text.split(whereSeparator: \.isWhitespace).map(String.init)
        return words.count > 1 ? (words," ") : (text.map(String.init),"")
    }
    static func eligible(_ words: [SavedWord], mode: PracticeMode) -> [SavedWord] {
        var terms = Set<String>(), answers = Set<String>()
        return words.filter { word in
            let term = key(word.term), meaning = key(word.meaning)
            guard !term.isEmpty, !meaning.isEmpty, word.term.count <= 120, word.meaning.count <= 180 else { return false }
            if mode == .build {
                let count = pieces(word.term).tiles.count
                guard (2...16).contains(count) else { return false }
            }
            let answer = mode == .pinyin ? key(word.pronunciation) : meaning
            guard !answer.isEmpty, !terms.contains(term), !answers.contains(answer) else { return false }
            terms.insert(term); answers.insert(answer); return true
        }
    }
    static func answer(_ word: SavedWord, mode: PracticeMode) -> String {
        switch mode { case .reverse,.listen: word.term; case .pinyin: word.pronunciation; default: word.meaning }
    }
}
struct PracticeTile: Identifiable {
    let id: String
    let wordID: UUID
    let isMeaning: Bool
    let text: String
}

@MainActor final class PracticeRound: ObservableObject, Identifiable {
    let id = UUID()
    let mode: PracticeMode
    let deck: [SavedWord]
    let rounds: [SavedWord]
    let tiles: [PracticeTile]
    @Published private(set) var index = 0
    @Published private(set) var score = 0
    @Published private(set) var mistakes = 0
    @Published private(set) var missedIDs: Set<UUID> = []
    @Published private(set) var assistedIDs: Set<UUID> = []
    @Published private(set) var selected: String?
    @Published private(set) var checked = false
    @Published private(set) var correct = false
    @Published private(set) var choices: [String] = []
    @Published private(set) var bank: [String] = []
    @Published private(set) var picked: [Int] = []
    @Published private(set) var matched: Set<UUID> = []
    @Published private(set) var open: [String] = []
    @Published private(set) var feedback = ""
    private var separator = ""
    var current: SavedWord? { rounds.indices.contains(index) ? rounds[index] : nil }
    var finished: Bool { mode.isBoard ? matched.count == rounds.count : index >= rounds.count }
    var builtText: String { picked.map { bank[$0] }.joined(separator: separator) }
    var revisit: [SavedWord] { rounds.filter { missedIDs.contains($0.id) || assistedIDs.contains($0.id) } }
    var progress: Double { Double(mode.isBoard ? matched.count : index) / Double(max(1,rounds.count)) }
    init(mode: PracticeMode, words: [SavedWord]) {
        self.mode = mode
        // A game always uses one language pair, even when a caller supplies a mixed library.
        let pair = words.first.map(PracticeDeck.pairKey)
        deck = PracticeDeck.eligible(words.filter { PracticeDeck.pairKey($0) == pair },mode: mode)
        rounds = Array(deck.shuffled().prefix(mode.isBoard ? 6 : 5))
        tiles = rounds.flatMap { word in
            [PracticeTile(id: word.id.uuidString+":word",wordID: word.id,isMeaning: false,text: word.term),
             PracticeTile(id: word.id.uuidString+":meaning",wordID: word.id,isMeaning: true,text: word.meaning)]
        }.shuffled()
        prepare()
    }
    func choose(_ answer: String) { guard !checked, choices.contains(answer) else { return }; selected = answer }
    func reveal() { guard let word = current, !checked else { return }; assistedIDs.insert(word.id) }
    func check() {
        guard !checked, let word = current, mode == .build ? !picked.isEmpty : selected != nil else { return }
        checked = true
        correct = mode == .build ? PracticeDeck.key(builtText) == PracticeDeck.key(word.term) : selected == PracticeDeck.answer(word,mode: mode)
        if correct && !assistedIDs.contains(word.id) { score += 1 }
        if !correct { mistakes += 1; missedIDs.insert(word.id) }
        feedback = correct ? (assistedIDs.contains(word.id) ? "Found it with a hint." : "You found it.") : "A good one to revisit."
    }
    func advance() { guard checked else { return }; index += 1; prepare() }
    func addPiece(_ i: Int) { guard !checked, bank.indices.contains(i), !picked.contains(i) else { return }; picked.append(i) }
    func undoPiece() { guard !checked, !picked.isEmpty else { return }; picked.removeLast() }
    func clearPieces() { guard !checked else { return }; picked = [] }
    private func prepare() {
        selected = nil; checked = false; correct = false; picked = []; feedback = ""
        guard let word = current else { return }
        let answer = PracticeDeck.answer(word,mode: mode)
        choices = (Array(deck.filter { $0.id != word.id }.map { PracticeDeck.answer($0,mode: mode) }.shuffled().prefix(3))+[answer]).shuffled()
        let pieces = PracticeDeck.pieces(word.term); bank = pieces.tiles.shuffled(); separator = pieces.separator
        if bank == pieces.tiles && Set(bank).count > 1 { bank = Array(bank.dropFirst())+[bank[0]] }
    }
    func flip(_ id: String) {
        guard !finished, open.count < 2, let tile = tiles.first(where: { $0.id == id }), !matched.contains(tile.wordID), !open.contains(id) else { return }
        if mode == .pairs, let first = open.first.flatMap({ id in tiles.first { $0.id == id } }), first.isMeaning == tile.isMeaning { open = [id]; feedback = ""; return }
        guard open.count < 2 else { return }
        feedback = ""; open.append(id)
        guard open.count == 2, let first = tiles.first(where: { $0.id == open[0] }) else { return }
        if first.wordID == tile.wordID && first.isMeaning != tile.isMeaning {
            matched.insert(tile.wordID); score += 1; open = []; feedback = "A pair found."
        } else {
            mistakes += 1; missedIDs.formUnion([first.wordID,tile.wordID]); feedback = "These are different. Take a look, then try another pair."
        }
    }
    func clearOpen() { open = []; feedback = "" }
}
