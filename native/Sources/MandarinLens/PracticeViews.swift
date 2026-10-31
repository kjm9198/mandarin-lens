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
            VStack(alignment: .leading,spacing: 24) {
                LensPageHeading(title: "Play",detail: "Short practice rounds using the words in your dictionary.")
                VStack(alignment: .leading,spacing: 14) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 20) { languagePicker; categoryPicker }
                        VStack(alignment: .leading,spacing: 14) { languagePicker; categoryPicker }
                    }
                    Text("\(words.count) saved entries · one language pair per round").font(.system(size: 11)).foregroundStyle(.secondary)
                }.lensSurface(padding: 16)
                Text("Pick a game").font(.system(size: 14,weight: .semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250),spacing: 12)],spacing: 12) {
                    ForEach(PracticeMode.allCases) { mode in
                        let count = PracticeDeck.eligible(words,mode: mode).count
                        Button { round = PracticeRound(mode: mode,words: words) } label: {
                            HStack(alignment: .top,spacing: 14) {
                                Image(systemName: mode.symbol).font(.system(size: 20,weight: .regular)).foregroundStyle(Color.lensAccent).frame(width: 38,height: 38).background(Color.lensAccent.opacity(0.08),in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading,spacing: 7) {
                                    Text(mode.title).font(.system(size: 15,weight: .semibold))
                                    Text(mode.detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true).lineSpacing(2)
                                    Text(count >= mode.minimum ? (mode.isBoard ? "Up to 6 pairs" : "Up to 5 questions") : "Needs \(mode.minimum) suitable \(mode == .pinyin ? "Chinese " : "")\(mode.minimum == 1 ? "entry" : "entries")").font(.system(size: 10)).foregroundStyle(.secondary)
                                }.frame(maxWidth: .infinity,alignment: .leading)
                                Image(systemName: "chevron.right").font(.system(size: 10,weight: .medium)).foregroundStyle(.secondary).padding(.top,5)
                            }.padding(18).frame(maxWidth: .infinity,minHeight: 124,alignment: .topLeading).contentShape(Rectangle())
                        }.buttonStyle(PracticeSurfaceStyle()).disabled(count < mode.minimum)
                    }
                }
                Label("No timer. Your review schedule stays unchanged.",systemImage: "clock").font(.system(size: 11)).foregroundStyle(.secondary)
                Text("Games use short, distinct saved pairs. Pinyin uses system transliteration.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
            }.padding(24).frame(maxWidth: 900,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading)
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
    func makeBody(configuration: Configuration) -> some View { Surface(configuration: configuration) }
    private struct Surface: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isEnabled) private var enabled
        @Environment(\.colorSchemeContrast) private var contrast
        @State private var hover = false
        var body: some View { configuration.label.foregroundStyle(.primary).background(configuration.isPressed ? Color.lensAccent.opacity(0.12) : Color.lensSurface,in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(hover ? Color.lensAccent.opacity(0.8) : contrast == .increased ? Color.primary.opacity(0.65) : Color.lensLine.opacity(0.55),lineWidth: 1)).opacity(enabled ? 1 : 0.5).onHover { hover = $0 } }
    }
}
private struct PracticeChoiceStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View { Choice(configuration: configuration,selected: selected) }
    private struct Choice: View {
        let configuration: ButtonStyle.Configuration
        let selected: Bool
        @Environment(\.colorSchemeContrast) private var contrast
        @State private var hover = false
        var body: some View { configuration.label.foregroundStyle(.primary).background(selected || configuration.isPressed ? Color.lensAccent.opacity(0.12) : hover ? Color.primary.opacity(0.04) : Color.lensSurface,in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.lensAccent : contrast == .increased ? Color.primary.opacity(0.65) : Color.lensLine.opacity(0.6),lineWidth: selected ? 2 : 1)).onHover { hover = $0 } }
    }
}
struct PracticeRoundView: View {
    @ObservedObject var round: PracticeRound
    let leave: ()->Void
    let replay: (Bool)->Void
    @StateObject private var speaker = WordSpeaker()
    @State private var transcript = false
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 18) {
                HStack { Button(action: leave) { Label("All games",systemImage: "arrow.left") }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Color.lensAccent); Spacer(); Text(round.mode.title).font(.system(size: 12,weight: .medium)).foregroundStyle(.secondary) }
                if !round.finished { HStack(spacing: 14) { ProgressView(value: round.progress).tint(.lensAccent).accessibilityLabel("Practice progress"); Text(round.mode.isBoard ? "\(round.matched.count)/\(round.rounds.count)" : "\(round.index+1) of \(round.rounds.count)").font(.system(size: 11,design: .monospaced)).foregroundStyle(.secondary).fixedSize() } }
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading,spacing: 22) {
                    if round.finished { result }
                    else if round.mode.isBoard { board }
                    else if let word = round.current { question(word) }
                    if !speaker.status.isEmpty { Text(speaker.status).font(.system(size: 12)).foregroundStyle(.secondary) }
                }.padding(24).frame(maxWidth: 720,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading)
            }
            if !round.finished { roundFooter }
        }.tint(.lensAccent).onDisappear { speaker.stop() }
    }
    private var roundFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 14) {
                if round.mode.isBoard {
                    Text("\(round.matched.count) of \(round.rounds.count) pairs found").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    if round.open.count == 2 { Button("Try another pair") { round.clearOpen() }.buttonStyle(LensButtonStyle(prominent: true)) }
                } else if round.checked {
                    Label(round.correct ? "Correct" : "Review the answer",systemImage: round.correct ? "checkmark.circle" : "arrow.counterclockwise").font(.system(size: 12,weight: .medium)).foregroundStyle(Color.lensAccent)
                    Spacer()
                    Button(round.index+1 == round.rounds.count ? "See result" : "Continue") { transcript = false; round.advance() }.buttonStyle(LensButtonStyle(prominent: true)).keyboardShortcut(.return,modifiers: .command)
                } else {
                    Text("Choose, then check.").font(.system(size: 12)).foregroundStyle(.secondary); Spacer()
                    Button("Check answer") { round.check() }.buttonStyle(LensButtonStyle(prominent: true)).disabled(round.mode == .build ? round.picked.isEmpty : round.selected == nil).keyboardShortcut(.return,modifiers: .command)
                }
            }.padding(.horizontal,24).padding(.vertical,16)
        }.background(Color.lensCanvas)
    }
    @ViewBuilder private func question(_ word: SavedWord) -> some View {
        VStack(alignment: .leading,spacing: 16) {
            Text(instruction).font(.system(size: 23,weight: .semibold)).fixedSize(horizontal: false,vertical: true)
            if round.mode == .listen {
                HStack(spacing: 14) {
                    Button { speaker.speak(word.term,language: PracticeDeck.language(word)) } label: { Label("Listen to the word",systemImage: "speaker.wave.2.fill").padding(12) }.buttonStyle(LensButtonStyle(prominent: true))
                    Button("Show text") { transcript = true; round.reveal() }.disabled(transcript || round.checked)
                }
                if transcript { Text(word.term).font(.title2); Text("Hint used · included in your revisit list").font(.caption).foregroundStyle(.secondary) }
            } else {
                Text(round.mode == .reverse || round.mode == .build ? word.meaning : word.term).font(.system(size: round.mode == .reverse || round.mode == .build ? 27 : 46,weight: .medium)).fixedSize(horizontal: false,vertical: true)
                if round.mode == .meaning && !word.pronunciation.isEmpty { Text(word.pronunciation).font(.title3).foregroundStyle(.secondary) }
                if round.mode != .build { Button { speaker.speak(word.term,language: PracticeDeck.language(word)); if round.mode == .reverse { round.reveal() } } label: { Label("Listen",systemImage: "speaker.wave.2") }.buttonStyle(.plain).font(.callout).foregroundStyle(Color.lensAccent) }
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
                            if round.selected == answer { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lensAccent) }
                            if round.checked && answer == PracticeDeck.answer(word,mode: round.mode) { Label("Answer",systemImage: "checkmark").font(.caption).foregroundStyle(Color.lensAccent) }
                        }.padding(14).frame(maxWidth: .infinity,minHeight: 48,alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(PracticeChoiceStyle(selected: round.selected == answer)).disabled(round.checked).accessibilityAddTraits(round.selected == answer ? .isSelected : [])
                }
            }
        }
        if round.checked {
            VStack(alignment: .leading,spacing: 9) {
                Text(round.correct ? "Correct" : "Correct answer").font(.system(size: 12,weight: .semibold)).foregroundStyle(Color.lensAccent)
                Text(word.term+(word.pronunciation.isEmpty ? "" : " · "+word.pronunciation)+" — "+word.meaning).font(.system(size: 15)).textSelection(.enabled).fixedSize(horizontal: false,vertical: true)
                if round.assistedIDs.contains(word.id) { Text("Hint used · saved for another look").font(.system(size: 11)).foregroundStyle(.secondary) }
            }.frame(maxWidth: .infinity,alignment: .leading).lensSurface(padding: 17)
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
            Text(round.builtText.isEmpty ? "Your answer goes here" : round.builtText).font(.title2).foregroundStyle(round.builtText.isEmpty ? .secondary : .primary).padding(20).frame(maxWidth: .infinity,minHeight: 76,alignment: .leading).background(Color.lensAccent.opacity(0.07),in: RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Built answer: " + round.builtText)
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
            Text(round.mode == .memory ? "Find the matching pairs" : "Match each word to its meaning").font(.system(size: 27,weight: .semibold))
            Text(round.mode == .memory ? "Turn over two cards. Match a word with its meaning." : "Choose a word, then its meaning. You can also start with a meaning.").foregroundStyle(.secondary)
            Text("\(round.matched.count) of \(round.rounds.count) pairs found").font(.caption.weight(.medium)).foregroundStyle(Color.lensAccent)
            if round.mode == .memory {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))],spacing: 12) { ForEach(Array(round.tiles.enumerated()),id: \.element.id) { index,tile in memoryTile(tile,number: index+1) } }
            } else {
                HStack(alignment: .top,spacing: 14) {
                    VStack(spacing: 10) { ForEach(round.tiles.filter { !$0.isMeaning }) { tile in pairTile(tile) } }.frame(maxWidth: .infinity)
                    VStack(spacing: 10) { ForEach(round.tiles.filter(\.isMeaning)) { tile in pairTile(tile) } }.frame(maxWidth: .infinity)
                }
            }
            if !round.feedback.isEmpty { Label(round.feedback,systemImage: round.open.count == 2 ? "arrow.counterclockwise" : "checkmark.circle").font(.callout).fixedSize(horizontal: false,vertical: true) }
        }
    }
    private func pairTile(_ tile: PracticeTile) -> some View {
        Button { round.flip(tile.id) } label: {
            HStack { Text(tile.text).font(.system(size: 17,weight: .medium)).fixedSize(horizontal: false,vertical: true); Spacer(minLength: 0); if round.matched.contains(tile.wordID) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lensAccent) } }.padding(14).frame(maxWidth: .infinity,minHeight: 70,alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(PracticeChoiceStyle(selected: round.open.contains(tile.id))).disabled(round.matched.contains(tile.wordID) || round.open.count == 2).accessibilityAddTraits(round.open.contains(tile.id) ? .isSelected : [])
    }
    private func memoryTile(_ tile: PracticeTile,number: Int) -> some View {
        let shown = round.open.contains(tile.id) || round.matched.contains(tile.wordID)
        return Button { round.flip(tile.id) } label: {
            VStack(spacing: 8) {
                if shown {
                    HStack { Text(tile.isMeaning ? "Meaning" : "Word").font(.caption2).foregroundStyle(.secondary); Spacer(); if round.matched.contains(tile.wordID) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lensAccent) } }
                    Text(tile.text).font(.system(size: 18,weight: .medium)).fixedSize(horizontal: false,vertical: true).frame(maxHeight: .infinity)
                } else { Image(systemName: "viewfinder").font(.title2).foregroundStyle(Color.lensAccent); Text(String(number)).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            }.padding(14).frame(maxWidth: .infinity,minHeight: 108).contentShape(Rectangle())
        }.buttonStyle(PracticeChoiceStyle(selected: round.open.contains(tile.id))).disabled(round.matched.contains(tile.wordID) || round.open.count == 2).accessibilityLabel(shown ? "Card \(number), \(tile.isMeaning ? "meaning" : "word"): \(tile.text)" : "Card \(number), face down")
    }
    private var result: some View {
        VStack(alignment: .leading,spacing: 22) {
            Image(systemName: "checkmark.seal").font(.system(size: 48,weight: .light)).foregroundStyle(Color.lensAccent).accessibilityHidden(true)
            Text("Round complete").font(.system(size: 28,weight: .semibold))
            Text(round.mode.isBoard ? "\(round.matched.count) pairs found · \(round.mistakes) \(round.mistakes == 1 ? "retry" : "retries")" : "\(round.score) of \(round.rounds.count) found without hints").font(.title3)
            if !round.revisit.isEmpty {
                Text("Words to revisit").font(.headline)
                ForEach(round.revisit) { word in Text(word.term + (word.pronunciation.isEmpty ? "" : " · " + word.pronunciation) + " — " + word.meaning).fixedSize(horizontal: false,vertical: true) }
                if PracticeDeck.eligible(round.revisit,mode: round.mode).count >= round.mode.minimum { Button("Revisit these words") { replay(true) }.buttonStyle(LensButtonStyle(prominent: true)) }
                else { Text("These words will appear again when you replay.").font(.caption).foregroundStyle(.secondary) }
            } else { Text("All answers completed. Replay this round or choose another game.").foregroundStyle(.secondary) }
            HStack { Button("Play again") { replay(false) }.buttonStyle(LensButtonStyle(prominent: true)); Button("Choose another game",action: leave) }
            Text("Practice only · your saved words and review dates are unchanged.").font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical,14)
    }
}
