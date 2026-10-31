import SwiftUI
import AppKit

struct WordDraftContext: Identifiable {
    let id = UUID()
    let source: String
    let translated: String
    let target: String
    var context = ""
    var usageExample: ChineseExample?
}
struct WordDraftView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lens: Lens
    @ObservedObject var vocabulary: Vocabulary
    @State var term: String
    @State var meaning: String
    let source: String
    let translated: String
    var originalContext = ""
    var originalUsageExample: ChineseExample?
    let originalTarget: String
    @State var meaningTarget: String
    @State private var fromTranslation = true
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Save to My words").font(.system(size: 19, weight: .semibold))
            Text("Choose a word or phrase and confirm its meaning.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker("Choose from", selection: $fromTranslation) { Text("Translation").tag(true); Text("Original").tag(false) }.pickerStyle(.segmented)
                .onChange(of: fromTranslation) { _, value in term = value ? translated : source; meaning = value ? source : translated; meaningTarget = value ? (["en", "vi", "pl", "zh-Hans", "zh-Hant"].contains(TranslationSource.language(text: source,context: originalContext,preference: lens.sourceChoice)) ? TranslationSource.language(text: source,context: originalContext,preference: lens.sourceChoice) : lens.explanationLanguage) : originalTarget }
            if source.count > 0 {
                ScrollView(.horizontal) { HStack { ForEach(WordTools.tokens(fromTranslation ? translated : source), id: \.self) { token in Button(token) { term = token; meaning = token == lens.input && lens.canSaveWord ? lens.output : "" }.controlSize(.small) } } }.frame(height: 30)
            }
            TextField("Word or phrase", text: $term).textFieldStyle(.roundedBorder)
            TextField("Meaning", text: $meaning, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
            Picker("Meaning in", selection: $meaningTarget) { Text("English").tag("en"); Text("Tiếng Việt").tag("vi"); Text("Polski").tag("pl"); Text("中文").tag("zh-Hans"); Text("繁體中文").tag("zh-Hant") }
            if vocabulary.status.hasPrefix("Could not") { Text(vocabulary.status).font(.caption).foregroundStyle(.red) }
            HStack {
                Button("Translate this word") { lens.input = term; lens.target = meaningTarget; lens.translate() }.disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save word") { if vocabulary.save(term: term, meaning: meaning, target: meaningTarget,context: originalContext,usageExample: (originalUsageExample ?? lens.usageExample).flatMap { $0.word == term ? $0 : nil }) { dismiss() } }.buttonStyle(LensButtonStyle(prominent: true)).disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.controlSize(.small)
        }.padding(26).frame(width: 390).background(Color.lensCanvas).tint(.lensAccent)
        .onChange(of: term) { _, value in
            if value == translated { meaning = source }
            else if value == source { meaning = translated }
            else { meaning = lens.input == value && lens.canSaveWord ? lens.output : "" }
        }
        .onDisappear { lens.restoreTranslation(source: source, translated: translated, language: originalTarget, context: originalContext,usageExample: originalUsageExample ?? (lens.usageExample?.word == translated ? lens.usageExample : nil)) }
        .onChange(of: lens.output) { _, _ in if lens.input == term && lens.canSaveWord { meaning = lens.output } }
    }
}
struct WordsView: View {
    @ObservedObject var vocabulary: Vocabulary
    @ObservedObject var models: LocalModels
    var play: () -> Void
    var ask: (SavedWord) -> Void
    @State private var search = ""
    @State private var category = "All"
    @State private var practice = false
    @State private var speakingWord: SavedWord?
    @State private var dictionaryWord: SavedWord?
    @State private var reveal = false
    @StateObject private var speaker = WordSpeaker()
    @State private var organizeTask: Task<Void,Never>?
    private var filtered: [SavedWord] { vocabulary.words.filter { (category == "All" || $0.category.rawValue == category) && (search.isEmpty || $0.term.localizedCaseInsensitiveContains(search) || $0.meaning.localizedCaseInsensitiveContains(search) || $0.pronunciation.localizedCaseInsensitiveContains(search)) } }
    private var due: SavedWord? { vocabulary.words.first { $0.nextReview <= Date() } }
    var body: some View {
        VStack(alignment: .leading,spacing: 20) {
            LensPageHeading(title: "My words",detail: "Your saved Chinese words, meanings and examples.")
            HStack(spacing: 10) {
                LensSearchField(placeholder: "Search words, pinyin or meanings",text: $search)
                Menu { ForEach(["All"]+WordCategory.allCases.map(\.rawValue),id: \.self) { item in Button(item) { category = item } } } label: { Image(systemName: "line.3.horizontal.decrease").frame(width: 30,height: 30) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Filter by category")
                Menu {
                    Button("Surprise me") { dictionaryWord = filtered.randomElement() }.disabled(filtered.isEmpty)
                    Button("Export words…") { vocabulary.exportWords() }
                    Divider()
                    Button(vocabulary.organizing ? "Stop categorizing" : "Categorize all") { if vocabulary.organizing { organizeTask?.cancel(); models.job?.cancel() } else { organizeTask = Task { await vocabulary.organize(using: models) } } }.disabled(vocabulary.words.isEmpty || (models.busy && !vocabulary.organizing))
                } label: { Image(systemName: "ellipsis").frame(width: 25,height: 30) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Word library actions")
            }
            HStack(spacing: 12) { Text("\(filtered.count) \(filtered.count == 1 ? "word" : "words")\(category == "All" ? "" : " · "+category)").font(.system(size: 12)).foregroundStyle(.secondary); Spacer(); Button(action: play) { Label("Play games",systemImage: "gamecontroller") }.buttonStyle(LensButtonStyle(small: true)); Button(practice ? "Back to words" : "Review") { practice.toggle(); reveal = false }.buttonStyle(LensButtonStyle(prominent: true,small: true)).disabled(vocabulary.words.isEmpty) }
            if !speaker.status.isEmpty { Text(speaker.status).font(.system(size: 12)).foregroundStyle(.secondary) }
            if !vocabulary.status.isEmpty { Text(vocabulary.status).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true) }
            ScrollView {
                if practice { review }
                else if filtered.isEmpty { LensEmptyState(title: search.isEmpty ? "No saved words yet" : "No matching words",detail: search.isEmpty ? "Select and translate a word, then choose Save word." : "Try another word, meaning or pinyin spelling.",symbol: "character.book.closed") }
                else {
                    LazyVStack(spacing: 0) {
                        ForEach(filtered) { word in
                            HStack(alignment: .center,spacing: 16) {
                                Button { dictionaryWord = word } label: {
                                    HStack(alignment: .top,spacing: 20) {
                                        VStack(alignment: .leading,spacing: 7) { Text(word.term).font(.system(size: 25,weight: .medium)).lineLimit(2); if !word.pronunciation.isEmpty { Text(word.pronunciation).font(.system(size: 13)).foregroundStyle(Color.lensAccent) } }.frame(minWidth: 80,alignment: .leading)
                                        VStack(alignment: .leading,spacing: 7) { Text(word.meaning).font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(3); Text(word.category.rawValue).font(.system(size: 10)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity,alignment: .leading)
                                    }.padding(.vertical,17).frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel(word.term).help("Open dictionary entry")
                                Button { speaker.speak(word.term,language: PracticeDeck.language(word)) } label: { Image(systemName: "speaker.wave.2").frame(width: 28,height: 30) }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Speak word")
                                Menu {
                                    Button("Example & usage") { ask(word) }
                                    Button("Speak & practise") { speakingWord = word }
                                    Menu("Category") { ForEach(WordCategory.allCases,id: \.self) { item in Button(item.rawValue) { vocabulary.categorize(word.id,as: item) } } }
                                } label: { Image(systemName: "ellipsis").frame(width: 20,height: 30) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Actions for \(word.term)")
                            }.contextMenu { Button("Open dictionary entry") { dictionaryWord = word }; Button("Delete word",role: .destructive) { vocabulary.words.removeAll { $0.id == word.id }; vocabulary.persist() } }
                            Divider().overlay(Color.lensLine.opacity(0.2))
                        }
                    }
                }
            }
        }.padding(24).frame(maxWidth: 940,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading)
        .onDisappear { organizeTask?.cancel(); speaker.stop() }
        .sheet(item: $dictionaryWord) { word in DictionaryDetail(word: word) { ask(word) } }
        .sheet(item: $speakingWord) { word in SpeakingPracticeView(word: word,models: models) }
    }
    @ViewBuilder private var review: some View {
        if let word = due {
            VStack(alignment: .leading,spacing: 24) {
                Text("Review").font(.system(size: 12,weight: .medium)).foregroundStyle(.secondary)
                Text(word.term).font(.system(size: 44,weight: .medium))
                if !word.pronunciation.isEmpty { Text(word.pronunciation).font(.system(size: 17)).foregroundStyle(Color.lensAccent) }
                if reveal { Text(word.meaning).font(.system(size: 21)); HStack { Button("Again") { vocabulary.review(word.id,remembered: false); reveal = false }.buttonStyle(LensButtonStyle()); Button("Remembered") { vocabulary.review(word.id,remembered: true); reveal = false }.buttonStyle(LensButtonStyle(prominent: true)) } }
                else { Button("Reveal meaning") { reveal = true }.buttonStyle(LensButtonStyle(prominent: true)) }
            }.frame(maxWidth: .infinity,alignment: .leading).lensSurface(padding: 26)
        } else { LensEmptyState(title: "Review complete",detail: "No words are due right now.",symbol: "checkmark.circle") }
    }
}
struct TutorialView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lens: Lens
    @State private var step = 0
    private let titles = ["Choose your languages", "Select text on screen", "Build your dictionary", "Use local AI"]
    private let symbols = ["character.book.closed", "viewfinder", "bookmark", "desktopcomputer"]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("KAMIHI LENS · \(step + 1) OF 4").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary); Spacer(); Button("Skip") { finish() }.buttonStyle(.plain) }
            Image(systemName: symbols[step]).font(.system(size: 38, weight: .light)).foregroundStyle(Color.lensAccent)
            Text(titles[step]).font(.system(size: 25, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
            Group {
                switch step {
                case 0:
                    Text("Choose a translation language. AI explanations can use a different language.")
                    Picker("Translate into", selection: $lens.target) { Text("中文 · Simplified").tag("zh-Hans"); Text("繁體中文 · Traditional").tag("zh-Hant"); Text("Tiếng Việt").tag("vi"); Text("Polski").tag("pl"); Text("English").tag("en") }
                    Picker("Explain in", selection: $lens.explanationLanguage) { Text("English").tag("en"); Text("Tiếng Việt").tag("vi"); Text("Polski").tag("pl"); Text("中文").tag("zh-Hans") }
                case 1:
                    Text("Option–Space selects a word with pinyin and meaning. Control–Space selects a sentence. Control–Option–Space lets you drag a screen area; Space uses the whole display. A small result appears near your cursor. Escape clears it.")
                    Text("Allow Screen Recording in Settings for screen selection. Recognition stays on this Mac. Accessibility is only needed for Capture selected text. Paste works without either permission.").foregroundStyle(.secondary)
                case 2:
                    Text("Choose Save word after translating. Pick a single word from the sentence, translate its meaning, then save. Your words get suggested categories immediately.")
                    Text("Categorize all uses your chosen local AI. You can change a category yourself; manual choices stay put. Review reveals meanings one at a time.").foregroundStyle(.secondary)
                default:
                    Text("Open Choose model to use downloaded MLX models or a local LM Studio / Bionic server. No remote AI endpoint is used.")
                    Text("On a 16 GB Mac, start small. Bigger models may take longer and need more memory. The question-mark button brings this guide back anytime.").foregroundStyle(.secondary)
                }
            }.font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            HStack { if step > 0 { Button("Back") { step -= 1 } }; Spacer(); Button(step == 3 ? "Let's try a word" : "Continue") { if step == 3 { finish() } else { step += 1 } }.buttonStyle(LensButtonStyle(prominent: true)) }
        }.padding(24).frame(width: 330, height: 390).tint(.lensAccent)
    }
    private func finish() { UserDefaults.standard.set(true, forKey: "onboardingComplete"); dismiss() }
}
