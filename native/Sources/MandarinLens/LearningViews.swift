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
    @StateObject private var speaker = WordSpeaker.shared
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
                                Button { speaker.speak(word.term,language: PracticeDeck.language(word)) } label: { Image(systemName: speaker.isPlaying(word.term,language: PracticeDeck.language(word)) ? "stop.fill" : "play.fill").frame(width: 28,height: 30) }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel(speaker.isPlaying(word.term,language: PracticeDeck.language(word)) ? "Stop word audio" : "Speak word")
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
    @State private var hasScreenRecording = CGPreflightScreenCaptureAccess()
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var permissionTimer: Timer?

    private func checkPermissions() {
        hasScreenRecording = CGPreflightScreenCaptureAccess()
        hasAccessibility = AXIsProcessTrusted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                Text("STEP \(step + 1) OF 3")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.lensAccent)
                Spacer()
                Button("Skip Tour") { finish() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 12)

            // Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case 0:
                        welcomeStep
                    case 1:
                        permissionsStep
                    default:
                        setupStep
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 8)
            }

            Divider()

            // Footer Navigation
            HStack {
                // Page Dots
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(step == i ? Color.lensAccent : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }

                Spacer()

                if step > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) { step -= 1 }
                    }
                    .buttonStyle(LensButtonStyle(small: true))
                }

                Button {
                    if step == 2 {
                        finish()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
                    }
                } label: {
                    Text(step == 2 ? "Get Started" : "Continue")
                }
                .buttonStyle(LensButtonStyle(prominent: true, small: true))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(Color.lensCanvas)
        }
        .frame(width: 530, height: 560)
        .background(Color.lensSurface)
        .onAppear {
            checkPermissions()
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                checkPermissions()
            }
        }
        .onDisappear {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.lensAccent.opacity(0.14))
                    Image(systemName: "viewfinder")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(Color.lensAccent)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to Kamihi Lens")
                        .font(.system(size: 24, weight: .bold))
                    Text("Fast, private, on-device translation and screen capture.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 14) {
                featureCard(
                    icon: "viewfinder",
                    color: Color.lensAccent,
                    title: "Instant Screen Selection",
                    description: "Press ⌥ Space to click any word, ⌃ Space for sentences, or drag across any area. Zero lag, 100% on-device."
                )

                featureCard(
                    icon: "character.bubble.fill",
                    color: .teal,
                    title: "Bilingual & Polish Translation",
                    description: "Simultaneous dual translation into Chinese, Polish and English with pinyin pronunciation and slower audio playback."
                )

                featureCard(
                    icon: "note.text.badge.plus",
                    color: .orange,
                    title: "Separated Study Notepad",
                    description: "Keep translations neatly partitioned into original text, translation, context, and study notes."
                )
            }
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Permissions Setup")
                    .font(.system(size: 22, weight: .bold))
                Text("Kamihi Lens operates entirely locally on your Mac. macOS requires these permissions to read text on your screen.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            // Screen Recording Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "display")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.lensAccent)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Screen Recording")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            if hasScreenRecording {
                                Label("Granted", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.green)
                            } else {
                                Label("Required", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.orange)
                            }
                        }

                        Text("Enables instant OCR when you press ⌥ Space, ⌃ Space, or select an area. Your screen content is never uploaded or shared.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                }

                if !hasScreenRecording {
                    HStack {
                        Spacer()
                        Button("Allow Screen Recording…") {
                            _ = CGRequestScreenCaptureAccess()
                            checkPermissions()
                        }
                        .buttonStyle(LensButtonStyle(prominent: true, small: true))
                    }
                }
            }
            .padding(14)
            .background(Color.lensCanvas, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lensLine.opacity(0.6), lineWidth: 1))

            // Accessibility Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "hand.point.up.braille.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Accessibility")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            if hasAccessibility {
                                Label("Granted", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.green)
                            } else {
                                Label("Optional", systemImage: "info.circle")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text("Optional: Used for reading text selections with 'Capture selected text' in apps that support accessibility.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                }

                if !hasAccessibility {
                    HStack {
                        Spacer()
                        Button("Allow Accessibility…") {
                            lens.permission()
                            checkPermissions()
                        }
                        .buttonStyle(LensButtonStyle(small: true))
                    }
                }
            }
            .padding(14)
            .background(Color.lensCanvas, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lensLine.opacity(0.6), lineWidth: 1))
        }
    }

    private var setupStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Languages & Shortcuts")
                    .font(.system(size: 22, weight: .bold))
                Text("Select your preferred translation languages and review quick shortcuts.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                HStack {
                    Text("Translate into (Primary)").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("Translate into", selection: $lens.target) {
                        Text("中文 · Simplified").tag("zh-Hans")
                        Text("Polski").tag("pl")
                        Text("English").tag("en")
                        Text("Tiếng Việt").tag("vi")
                        Text("繁體中文 · Traditional").tag("zh-Hant")
                    }
                    .labelsHidden()
                }

                HStack {
                    Text("+ 2nd Language (Simultaneous)").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Picker("2nd Language", selection: $lens.secondaryTarget) {
                        Text("Polski").tag("pl")
                        Text("中文 · Simplified").tag("zh-Hans")
                        Text("English").tag("en")
                        Text("None").tag("none")
                    }
                    .labelsHidden()
                }

                Toggle("Slower speech pronunciation (easier to understand)", isOn: $lens.slowSpeech)
                    .font(.system(size: 12))
            }
            .padding(14)
            .background(Color.lensCanvas, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lensLine.opacity(0.6), lineWidth: 1))

            // Shortcuts Guide
            VStack(alignment: .leading, spacing: 10) {
                Text("Global Shortcuts").font(.system(size: 13, weight: .semibold))
                HStack {
                    Text("Word capture").font(.system(size: 12))
                    Spacer()
                    LensKeycap(text: "⌥ Space")
                }
                HStack {
                    Text("Sentence capture").font(.system(size: 12))
                    Spacer()
                    LensKeycap(text: lens.sentenceShortcutChoice == "Control–Shift–Space" ? "⌃⇧ Space" : "⌃ Space")
                }
                HStack {
                    Text("Section capture").font(.system(size: 12))
                    Spacer()
                    LensKeycap(text: "⌃⌥ Space")
                }
                HStack {
                    Text("Floating Notepad").font(.system(size: 12))
                    Spacer()
                    LensKeycap(text: "⌃⌥N")
                }
            }
            .padding(14)
            .background(Color.lensCanvas, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lensLine.opacity(0.6), lineWidth: 1))
        }
    }

    private func featureCard(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lensCanvas, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.lensLine.opacity(0.6), lineWidth: 1))
    }

    private func finish() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        dismiss()
    }
}
