import SwiftUI
import AppKit

struct WordDraftContext: Identifiable {
    let id = UUID()
    let source: String
    let translated: String
    let target: String
    var context = ""
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
    let originalTarget: String
    @State var meaningTarget: String
    @State private var fromTranslation = true
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Keep a word, learn a little.").font(.system(size: 19, weight: .semibold, design: .rounded))
            Text("Choose one word or keep a useful phrase. Each saved item gets a suggested category.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Picker("Choose from", selection: $fromTranslation) { Text("Translation").tag(true); Text("Original").tag(false) }.pickerStyle(.segmented)
                .onChange(of: fromTranslation) { _, value in term = value ? translated : source; meaning = value ? source : translated; meaningTarget = value ? (["en", "vi", "pl", "zh-Hans", "zh-Hant"].contains(WordTools.language(source)) ? WordTools.language(source) : lens.explanationLanguage) : originalTarget }
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
                Button("Save word") { if vocabulary.save(term: term, meaning: meaning, target: meaningTarget) { dismiss() } }.buttonStyle(.borderedProminent).disabled(term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.controlSize(.small)
        }.padding(22).frame(width: 340).tint(.teal)
        .onChange(of: term) { _, value in
            if value == translated { meaning = source }
            else if value == source { meaning = translated }
            else { meaning = lens.input == value && lens.canSaveWord ? lens.output : "" }
        }
        .onDisappear { lens.restoreTranslation(source: source, translated: translated, language: originalTarget, context: originalContext) }
        .onChange(of: lens.output) { _, _ in if lens.input == term && lens.canSaveWord { meaning = lens.output } }
    }
}
struct WordsView: View {
    @ObservedObject var vocabulary: Vocabulary
    @ObservedObject var models: LocalModels
    var ask: (SavedWord) -> Void
    @State private var search = ""
    @State private var category = "All"
    @State private var practice = false
    @State private var speakingWord: SavedWord?
    @State private var reveal = false
    @StateObject private var speaker = WordSpeaker()
    @State private var organizeTask: Task<Void, Never>?
    private var filtered: [SavedWord] { vocabulary.words.filter { (category == "All" || $0.category.rawValue == category) && (search.isEmpty || $0.term.localizedCaseInsensitiveContains(search) || $0.meaning.localizedCaseInsensitiveContains(search)) } }
    private var due: SavedWord? { vocabulary.words.first { $0.nextReview <= Date() } }
    var body: some View {
        VStack(spacing: 9) {
            HStack {
                TextField("Search My words", text: $search).textFieldStyle(.roundedBorder).font(.system(size: 12))
                Menu { ForEach(["All"] + WordCategory.allCases.map(\.rawValue), id: \.self) { item in Button(item) { category = item } } } label: { Image(systemName: "line.3.horizontal.decrease.circle") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Filter by category")
            }.padding(.horizontal, 16)
            HStack {
                Menu { Button("Export words…") { vocabulary.exportWords() } } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Word library actions")
                Text("\(vocabulary.words.count) saved · \(category)").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button(practice ? "Back to words" : "Review") { practice.toggle(); reveal = false }.disabled(vocabulary.words.isEmpty)
                Button(vocabulary.organizing ? "Stop" : "Categorize all") {
                    if vocabulary.organizing { organizeTask?.cancel(); models.job?.cancel() }
                    else { organizeTask = Task { await vocabulary.organize(using: models) } }
                }.disabled(vocabulary.words.isEmpty || (models.busy && !vocabulary.organizing))
            }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.teal).padding(.horizontal, 18)
            if !speaker.status.isEmpty { Text(speaker.status).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 18) }
            if !vocabulary.status.isEmpty { Text(vocabulary.status).font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 18).fixedSize(horizontal: false, vertical: true) }
            ScrollView {
                if practice { review }
                else if filtered.isEmpty {
                    VStack(alignment: .leading, spacing: 12) { Image(systemName: "bookmark").font(.title).foregroundStyle(.teal); Text("Your own little dictionary.").font(.system(size: 19, weight: .medium, design: .rounded)); Text("Translate a word, then choose Save word. Tap a word in a sentence to keep just that word.").font(.caption).foregroundStyle(.secondary) }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered) { word in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(word.term).font(.system(size: 19, weight: .medium)); Button { speaker.speak(word.term, language: word.sourceLanguage) } label: { Image(systemName: "speaker.wave.2").font(.system(size: 11)) }.buttonStyle(.plain).accessibilityLabel("Speak word"); Spacer(); Text(word.sourceLanguage.hasPrefix("zh") ? "中文" : word.sourceLanguage.uppercased()).font(.system(size: 9)).foregroundStyle(.secondary) }
                                if !word.pronunciation.isEmpty { Text(word.pronunciation).font(.system(size: 12)).foregroundStyle(.teal).help("System transliteration; pronunciation can depend on context") }
                                Text(word.meaning).font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled)
                                HStack {
                                    Menu(word.category.rawValue) { ForEach(WordCategory.allCases, id: \.self) { item in Button(item.rawValue) { vocabulary.categorize(word.id, as: item) } } }.menuStyle(.borderlessButton).fixedSize().font(.system(size: 10))
                                    Spacer()
                                    Button("Speak & practise") { speakingWord = word }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.teal)
                                    Button("Example & usage") { ask(word) }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.teal)
                                }
                            }.padding(.vertical, 12).contextMenu { Button("Delete word", role: .destructive) { vocabulary.words.removeAll { $0.id == word.id }; vocabulary.persist() } }
                            Divider()
                        }
                    }.padding(.horizontal, 20)
                }
            }
        }.onDisappear { organizeTask?.cancel() }
            .sheet(item: $speakingWord) { word in SpeakingPracticeView(word: word, models: models) }
    }
    @ViewBuilder private var review: some View {
        if let word = due {
            VStack(alignment: .leading, spacing: 18) {
                Label("A MOMENT TO REMEMBER", systemImage: "rectangle.on.rectangle").font(.system(size: 9, weight: .semibold)).foregroundStyle(.teal)
                Text(word.term).font(.system(size: 30, weight: .medium, design: .rounded))
                if !word.pronunciation.isEmpty { Text(word.pronunciation).foregroundStyle(.secondary) }
                if reveal {
                    Text(word.meaning).font(.title3)
                    HStack { Button("Again") { vocabulary.review(word.id, remembered: false); reveal = false }; Button("Remembered") { vocabulary.review(word.id, remembered: true); reveal = false }.buttonStyle(.borderedProminent) }
                } else { Button("Reveal meaning") { reveal = true }.buttonStyle(.bordered) }
            }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
        } else { Text("You're caught up. Come back for a little practice tomorrow.").font(.body).foregroundStyle(.secondary).padding(24) }
    }
}
struct ModelsView: View {
    var embedded = false
    @ObservedObject var models: LocalModels
    @Environment(\.dismiss) var dismiss
    @State private var token = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Choose your local AI").font(.system(size: 19, weight: .semibold, design: .rounded)); Spacer(); if !embedded { Button("Done") { dismiss() } } }
            Text("Chat and categorization run on this Mac. Translation uses Apple's installed language packs.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Button { models.selected = "auto" } label: { HStack { Image(systemName: models.selected == "auto" ? "checkmark.circle.fill" : "circle"); VStack(alignment: .leading) { Text("Automatic").fontWeight(.semibold); Text("\(models.automatic?.displayName ?? "No installed model")").font(.caption).lineLimit(2) }; Spacer() } }.buttonStyle(.plain)
                    Text("Automatic uses the smallest installed MLX model for faster replies. Larger models may improve quality but need more time and memory.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Divider()
                    ForEach(models.models) { model in
                        Button { models.selected = model.id } label: {
                            HStack(alignment: .top) { Image(systemName: models.selected == model.id ? "checkmark.circle.fill" : "circle"); VStack(alignment: .leading, spacing: 4) { Text(model.displayName).font(.system(size: 12, weight: .medium)).fixedSize(horizontal: false, vertical: true).help(model.name); Text(model.detail).font(.system(size: 10)).foregroundStyle(.secondary); if model.heavy { Text("Larger model · allow memory headroom").font(.system(size: 10)).foregroundStyle(.secondary) } } }
                        }.buttonStyle(.plain).padding(.vertical, 5)
                    }
                }.padding(.vertical, 4)
            }.frame(height: 240)
            HStack { Button("Find installed models") { Task { await models.scanFiles(); await models.refreshServer() } }; Button("Choose model folder…") { models.addFolder() } }.controlSize(.small)
            Divider()
            Text("Download a local model").font(.headline)
            HStack {
                Button("Download 2B · about 2 GB") { Task { await models.installModel("Qwen3.5-2B-4bit") } }
                Button("Download 4B · about 3 GB") { Task { await models.installModel("Qwen3.5-4B-4bit") } }
            }.controlSize(.small).disabled(models.installing)
            if models.installing { HStack { ProgressView().controlSize(.small); Button("Cancel download") { models.installJob?.cancel() } } }
            Button(models.speechAvailable ? "Offline speech model installed" : "Download offline speech · about 500 MB") { Task { await models.installModel("whisper-small-asr-fp16") } }.disabled(models.installing || models.speechAvailable).controlSize(.small)
            Text("Downloads use Hugging Face. Your questions and vocabulary are never sent there. Existing downloads resume when retried.").font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack { Text("LM Studio / Bionic port").font(.caption); TextField("1234", value: $models.port, format: .number.grouping(.never)).textFieldStyle(.roundedBorder).frame(width: 70); Button("Connect") { Task { await models.refreshServer() } } }.controlSize(.small)
            HStack { SecureField("Optional local API token", text: $token).textFieldStyle(.roundedBorder); Button("Save") { models.saveToken(token); token = "" } }.controlSize(.small)
            Text(models.status).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Only 127.0.0.1 is accepted. API tokens stay in Keychain. Custom GGUF models need your local server; MLX folders run directly.").font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(20).frame(width: 360).tint(.teal)
    }
}
struct TutorialView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var lens: Lens
    @State private var step = 0
    private let titles = ["A word is a good beginning.", "Catch the text you need.", "Keep it. Make it yours.", "Your Mac. Your models."]
    private let symbols = ["character.book.closed", "viewfinder", "bookmark", "desktopcomputer"]
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("MANDARIN LENS · \(step + 1) OF 4").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary); Spacer(); Button("Skip") { finish() }.buttonStyle(.plain) }
            Image(systemName: symbols[step]).font(.system(size: 38, weight: .light)).foregroundStyle(.teal)
            Text(titles[step]).font(.system(size: 25, weight: .semibold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
            Group {
                switch step {
                case 0:
                    Text("Learn Chinese, explore Vietnamese, or help someone with Polish. Start with one useful word.")
                    Picker("Translate into", selection: $lens.target) { Text("中文 · Simplified").tag("zh-Hans"); Text("繁體中文 · Traditional").tag("zh-Hant"); Text("Tiếng Việt").tag("vi"); Text("Polski").tag("pl"); Text("English").tag("en") }
                    Picker("Explain in", selection: $lens.explanationLanguage) { Text("English").tag("en"); Text("Tiếng Việt").tag("vi"); Text("Polski").tag("pl"); Text("中文").tag("zh-Hans") }
                case 1:
                    Text("Point at a word and press Option–Space. For a sentence, select it and point inside the selection. Escape dismisses lookup. Use Open full app for your dictionary and chat. For images, explicitly choose Capture → Screen area.")
                    Text("Allow Accessibility or Screen Recording only when you use those features. Paste works without either permission.").foregroundStyle(.secondary)
                case 2:
                    Text("Choose Save word after translating. Pick a single word from the sentence, translate its meaning, then save. Your words get suggested categories immediately.")
                    Text("Categorize all uses your chosen local AI. You can change a category yourself; manual choices stay put. Review reveals meanings one at a time.").foregroundStyle(.secondary)
                default:
                    Text("Open Choose model to use downloaded MLX models or a local LM Studio / Bionic server. No remote AI endpoint is used.")
                    Text("On a 16 GB Mac, start small. Bigger models may take longer and need more memory. The question-mark button brings this guide back anytime.").foregroundStyle(.secondary)
                }
            }.font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            HStack { if step > 0 { Button("Back") { step -= 1 } }; Spacer(); Button(step == 3 ? "Let's try a word" : "Continue") { if step == 3 { finish() } else { step += 1 } }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(width: 330, height: 390).tint(.teal)
    }
    private func finish() { UserDefaults.standard.set(true, forKey: "onboardingComplete"); dismiss() }
}
