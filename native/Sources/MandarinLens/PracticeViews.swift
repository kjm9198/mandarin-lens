import SwiftUI

struct PracticeView: View {
    @ObservedObject var vocabulary: Vocabulary
    @State private var pair = ""
    @State private var category = "All categories"
    @State private var round: PracticeRound?
    private var pairs: [String] { Array(Set(vocabulary.words.map(PracticeDeck.pairKey))).sorted() }
    private var activePair: String { pairs.contains(pair) ? pair : pairs.first ?? "" }
    private var words: [SavedWord] { vocabulary.words.filter { PracticeDeck.pairKey($0) == activePair && (category == "All categories" || $0.category.rawValue == category) } }
    var body: some View {
        Group {
            if let round {
                PracticeRoundView(round: round,leave: { self.round = nil },replay: { onlyMissed in
                    self.round = PracticeRound(mode: round.mode,words: onlyMissed ? round.revisit : words)
                }).id(round.id)
            } else { hub }
        }
    }
    private var hub: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 26) {
                HStack(alignment: .center,spacing: 24) {
                    VStack(alignment: .leading,spacing: 12) {
                        Label("YOUR WORD PLAYGROUND",systemImage: "gamecontroller").font(.caption.weight(.semibold)).tracking(1.2).foregroundStyle(.teal)
                        Text("Small rounds.\nYour own words.").font(.system(size: 34,weight: .semibold,design: .rounded)).tracking(-0.8).fixedSize(horizontal: false,vertical: true)
                        Text("A few minutes to connect, listen and remember. Pick a game and practise what you’ve discovered.").foregroundStyle(.secondary).lineSpacing(4)
                    }
                    Spacer(minLength: 0)
                }.padding(.vertical,8)
                VStack(alignment: .leading,spacing: 12) {
                    Text("01  Choose your words").font(.headline)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { languagePicker; categoryPicker }
                        VStack(alignment: .leading,spacing: 12) { languagePicker; categoryPicker }
                    }
                    Text("\(words.count) saved entries · games use short, distinct pairs").font(.caption).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading,spacing: 14) {
                    Text("02  Pick your game").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240),spacing: 14)],spacing: 14) {
                        ForEach(PracticeMode.allCases) { mode in
                            let count = PracticeDeck.eligible(words,mode: mode).count
                            Button { round = PracticeRound(mode: mode,words: words) } label: {
                                VStack(alignment: .leading,spacing: 12) {
                                    HStack { Image(systemName: mode.symbol).font(.title2).foregroundStyle(.teal); Spacer(); Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary) }
                                    Text(mode.title).font(.system(size: 18,weight: .semibold,design: .rounded))
                                    Text(mode.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true).frame(maxWidth: .infinity,minHeight: 38,alignment: .topLeading)
                                    Label(count >= mode.minimum ? (mode.isBoard ? "Up to 6 pairs" : "Up to 5 questions") : "Save \(mode.minimum) suitable \(mode == .pinyin ? "Chinese " : "")\(mode.minimum == 1 ? "entry" : "entries") to play",systemImage: count >= mode.minimum ? "play.circle" : "bookmark").font(.caption.weight(.medium)).foregroundStyle(count >= mode.minimum ? Color.teal : .secondary)
                                }.padding(20).frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(PracticeSurfaceStyle()).disabled(count < mode.minimum)
                        }
                    }
                }
                Label("On this Mac · no timer · your review schedule stays yours",systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
                Text("Inspired by Sproutsly’s matching, listening and word-building activities. Practice comes from your dictionary; no AI or model download is needed. Pinyin uses system transliteration.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
            }.padding(28).frame(maxWidth: 860,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading)
        }
    }
    private var languagePicker: some View {
        Picker("Languages",selection: Binding(get: { activePair },set: { pair = $0 })) {
            ForEach(pairs,id: \.self) { key in Text(key.split(separator: "|").map { Locale.current.localizedString(forIdentifier: String($0)) ?? String($0) }.joined(separator: " → ")).tag(key) }
        }.disabled(pairs.isEmpty)
    }
    private var categoryPicker: some View {
        Picker("Category",selection: $category) { Text("All categories").tag("All categories"); ForEach(WordCategory.allCases,id: \.self) { Text($0.rawValue).tag($0.rawValue) } }
    }
}

private struct PracticeSurfaceStyle: ButtonStyle {
    @Environment(\.colorSchemeContrast) private var contrast
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(.primary)
            .background(Color.primary.opacity(configuration.isPressed ? 0.09 : 0.035),in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(contrast == .increased ? 0.6 : 0.12),lineWidth: 1))
    }
}
private struct PracticeChoiceStyle: ButtonStyle {
    var selected = false
    @Environment(\.colorSchemeContrast) private var contrast
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(.primary)
            .background(selected ? Color.teal.opacity(0.14) : Color.primary.opacity(configuration.isPressed ? 0.1 : 0.035),in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.teal : Color.primary.opacity(contrast == .increased ? 0.6 : 0.16),lineWidth: selected ? 2 : 1))
    }
}
struct PracticeRoundView: View {
    @ObservedObject var round: PracticeRound
    let leave: ()->Void
    let replay: (Bool)->Void
    @StateObject private var speaker = WordSpeaker()
    @State private var transcript = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 24) {
                HStack {
                    Button(action: leave) { Label("All games",systemImage: "arrow.left") }.buttonStyle(.plain).foregroundStyle(.teal)
                    Spacer()
                    Label(round.mode.title,systemImage: round.mode.symbol).font(.callout.weight(.medium))
                }
                ProgressView(value: round.finished ? 1 : round.progress).tint(.teal).accessibilityLabel("Practice progress")
                if round.finished { result }
                else if round.mode.isBoard { board }
                else if let word = round.current { question(word) }
                if !speaker.status.isEmpty { Text(speaker.status).font(.caption).foregroundStyle(.secondary) }
            }.padding(28).frame(maxWidth: 730,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading)
        }.tint(.teal).onDisappear { speaker.stop() }
    }
    @ViewBuilder private func question(_ word: SavedWord) -> some View {
        Text("\(round.index+1) of \(round.rounds.count)").font(.caption.weight(.medium)).foregroundStyle(.secondary)
        VStack(alignment: .leading,spacing: 16) {
            Text(instruction).font(.system(size: 25,weight: .semibold,design: .rounded)).fixedSize(horizontal: false,vertical: true)
            if round.mode == .listen {
                HStack(spacing: 14) {
                    Button { speaker.speak(word.term,language: PracticeDeck.language(word)) } label: { Label("Listen to the word",systemImage: "speaker.wave.2.fill").padding(12) }.buttonStyle(.borderedProminent)
                    Button("Show text") { transcript = true; round.reveal() }.disabled(transcript || round.checked)
                }
                if transcript { Text(word.term).font(.title2); Text("Hint used · included in your revisit list").font(.caption).foregroundStyle(.secondary) }
            } else {
                Text(round.mode == .reverse || round.mode == .build ? word.meaning : word.term).font(.system(size: 34,weight: .medium,design: .rounded)).fixedSize(horizontal: false,vertical: true)
                if round.mode == .meaning && !word.pronunciation.isEmpty { Text(word.pronunciation).font(.title3).foregroundStyle(.secondary) }
                if round.mode != .build { Button { speaker.speak(word.term,language: PracticeDeck.language(word)); if round.mode == .reverse { round.reveal() } } label: { Label("Listen",systemImage: "speaker.wave.2") }.buttonStyle(.plain).font(.callout).foregroundStyle(.teal) }
            }
        }.padding(.vertical,8)
        if round.mode == .build { builder }
        else {
            VStack(spacing: 10) {
                ForEach(Array(round.choices.enumerated()),id: \.offset) { index,answer in
                    Button { round.choose(answer) } label: {
                        HStack(spacing: 14) {
                            Text(String(index+1)).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 22)
                            Text(answer).font(.system(size: 17,weight: .medium)).fixedSize(horizontal: false,vertical: true)
                            Spacer(minLength: 0)
                            if round.selected == answer { Image(systemName: "checkmark.circle.fill").foregroundStyle(.teal) }
                            if round.checked && answer == PracticeDeck.answer(word,mode: round.mode) { Label("Answer",systemImage: "checkmark").font(.caption).foregroundStyle(.teal) }
                        }.padding(17).frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(PracticeChoiceStyle(selected: round.selected == answer)).disabled(round.checked).accessibilityAddTraits(round.selected == answer ? .isSelected : [])
                }
            }
        }
        if round.checked {
            VStack(alignment: .leading,spacing: 9) {
                Label(round.feedback,systemImage: round.correct ? "checkmark.circle" : "arrow.counterclockwise").font(.headline)
                Text(word.term + (word.pronunciation.isEmpty ? "" : " · " + word.pronunciation) + " — " + word.meaning).textSelection(.enabled).fixedSize(horizontal: false,vertical: true)
                Button(round.index+1 == round.rounds.count ? "See result" : "Continue") { transcript = false; round.advance() }.buttonStyle(.borderedProminent).keyboardShortcut(.return,modifiers: .command)
            }.padding(18).frame(maxWidth: .infinity,alignment: .leading).background(Color.teal.opacity(0.08),in: RoundedRectangle(cornerRadius: 14)).accessibilityElement(children: .contain)
        } else {
            HStack { Text("Take your time.").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Check answer") { round.check() }.buttonStyle(.borderedProminent).disabled(round.mode == .build ? round.picked.isEmpty : round.selected == nil).keyboardShortcut(.return,modifiers: .command) }
        }
    }
    private var instruction: String {
        switch round.mode {
        case .meaning: "What does this mean?"
        case .reverse: "Which word belongs here?"
        case .listen: "Which word did you hear?"
        case .build: "Build the word or phrase."
        case .pinyin: "Which pinyin matches?"
        default: "Find the matching pairs."
        }
    }
    private var builder: some View {
        VStack(alignment: .leading,spacing: 16) {
            Text(round.builtText.isEmpty ? "Your answer goes here" : round.builtText).font(.title2).foregroundStyle(round.builtText.isEmpty ? .secondary : .primary).padding(20).frame(maxWidth: .infinity,minHeight: 76,alignment: .leading).background(Color.teal.opacity(0.07),in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Built answer: " + round.builtText)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58))],spacing: 10) {
                ForEach(Array(round.bank.enumerated()),id: \.offset) { index,text in
                    Button { round.addPiece(index) } label: { Text(text).font(.title3).padding(13).frame(maxWidth: .infinity).contentShape(Rectangle()) }.buttonStyle(PracticeChoiceStyle()).disabled(round.checked || round.picked.contains(index)).accessibilityLabel("Tile \(index+1): \(text)")
                }
            }
            HStack { Button("Undo") { round.undoPiece() }; Button("Start over") { round.clearPieces() } }.controlSize(.small).disabled(round.checked || round.picked.isEmpty)
        }
    }
    private var board: some View {
        VStack(alignment: .leading,spacing: 18) {
            Text(round.mode == .memory ? "A word. A meaning. A pair." : "Connect the words you know.").font(.system(size: 27,weight: .semibold,design: .rounded))
            Text(round.mode == .memory ? "Turn over two cards. Match a word with its meaning." : "Choose a word, then its meaning. You can also start with a meaning.").foregroundStyle(.secondary)
            Text("\(round.matched.count) of \(round.rounds.count) pairs found").font(.caption.weight(.medium)).foregroundStyle(.teal)
            if round.mode == .memory {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))],spacing: 12) { ForEach(Array(round.tiles.enumerated()),id: \.element.id) { index,tile in memoryTile(tile,number: index+1) } }
            } else {
                HStack(alignment: .top,spacing: 14) {
                    VStack(spacing: 10) { ForEach(round.tiles.filter { !$0.isMeaning }) { tile in pairTile(tile) } }.frame(maxWidth: .infinity)
                    VStack(spacing: 10) { ForEach(round.tiles.filter(\.isMeaning)) { tile in pairTile(tile) } }.frame(maxWidth: .infinity)
                }
            }
            if !round.feedback.isEmpty { Label(round.feedback,systemImage: round.open.count == 2 ? "arrow.counterclockwise" : "checkmark.circle").font(.callout).fixedSize(horizontal: false,vertical: true) }
            if round.open.count == 2 { Button("Try another pair") { round.clearOpen() }.buttonStyle(.borderedProminent) }
        }
    }
    private func pairTile(_ tile: PracticeTile) -> some View {
        Button { round.flip(tile.id) } label: {
            HStack { Text(tile.text).font(.system(size: 17,weight: .medium)).fixedSize(horizontal: false,vertical: true); Spacer(minLength: 0); if round.matched.contains(tile.wordID) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.teal) } }.padding(14).frame(maxWidth: .infinity,minHeight: 70,alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(PracticeChoiceStyle(selected: round.open.contains(tile.id))).disabled(round.matched.contains(tile.wordID) || round.open.count == 2).accessibilityAddTraits(round.open.contains(tile.id) ? .isSelected : [])
    }
    private func memoryTile(_ tile: PracticeTile,number: Int) -> some View {
        let shown = round.open.contains(tile.id) || round.matched.contains(tile.wordID)
        return Button { round.flip(tile.id) } label: {
            VStack(spacing: 8) {
                if shown {
                    HStack { Text(tile.isMeaning ? "Meaning" : "Word").font(.caption2).foregroundStyle(.secondary); Spacer(); if round.matched.contains(tile.wordID) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.teal) } }
                    Text(tile.text).font(.system(size: 18,weight: .medium,design: .rounded)).fixedSize(horizontal: false,vertical: true).frame(maxHeight: .infinity)
                } else { Image(systemName: "sparkle").font(.title2).foregroundStyle(.teal); Text(String(number)).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            }.padding(14).frame(maxWidth: .infinity,minHeight: 108).contentShape(Rectangle())
        }.buttonStyle(PracticeChoiceStyle(selected: round.open.contains(tile.id))).disabled(round.matched.contains(tile.wordID) || round.open.count == 2).accessibilityLabel(shown ? "Card \(number), \(tile.isMeaning ? "meaning" : "word"): \(tile.text)" : "Card \(number), face down")
    }
    private var result: some View {
        VStack(alignment: .leading,spacing: 22) {
            Image(systemName: "checkmark.seal").font(.system(size: 48,weight: .light)).foregroundStyle(.teal).accessibilityHidden(true)
            Text("A little more familiar.").font(.system(size: 32,weight: .semibold,design: .rounded))
            Text(round.mode.isBoard ? "\(round.matched.count) pairs found · \(round.mistakes) \(round.mistakes == 1 ? "retry" : "retries")" : "\(round.score) of \(round.rounds.count) found without hints").font(.title3)
            if !round.revisit.isEmpty {
                Text("Worth another look").font(.headline)
                ForEach(round.revisit) { word in Text(word.term + (word.pronunciation.isEmpty ? "" : " · " + word.pronunciation) + " — " + word.meaning).fixedSize(horizontal: false,vertical: true) }
                if PracticeDeck.eligible(round.revisit,mode: round.mode).count >= round.mode.minimum { Button("Revisit these words") { replay(true) }.buttonStyle(.borderedProminent) }
                else { Text("These words will appear again when you replay.").font(.caption).foregroundStyle(.secondary) }
            } else { Text("Every pair connected. Keep discovering words, or try another way to play.").foregroundStyle(.secondary) }
            HStack { Button("Play again") { replay(false) }.buttonStyle(.borderedProminent); Button("Choose another game",action: leave) }
            Text("Practice only · your saved words and review dates are unchanged.").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical,14)
    }
}
