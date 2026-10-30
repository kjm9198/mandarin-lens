import SwiftUI
import AppKit

private enum LensPage: String, CaseIterable {
    case translate = "Translate", words = "My words", history = "History", learn = "Learn", models = "Local models", settings = "Settings"
    var symbol: String { switch self { case .translate: "character.bubble"; case .words: "bookmark"; case .history: "clock"; case .learn: "sparkle"; case .models: "cpu"; case .settings: "gearshape" } }
}
struct Note: View {
    @EnvironmentObject var lens: Lens
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme
    private var page: LensPage {
        get { LensPage(rawValue: lens.workspacePage) ?? .translate }
        nonmutating set { lens.workspacePage = newValue.rawValue }
    }
    @State private var preferences = false
    @State private var search = ""
    @State private var tutorial = CommandLine.arguments.contains("--tutorial-preview") || (!UserDefaults.standard.bool(forKey: "onboardingComplete") && !CommandLine.arguments.contains("--skip-tutorial"))
    @State private var showModels = false
    @State private var draftContext: WordDraftContext?
    @State private var copied = false
    @FocusState private var editing: Bool
    private var accent: Color { scheme == .dark ? Color(red: 0.28, green: 0.80, blue: 0.77) : Color(red: 0.0, green: 0.40, blue: 0.42) }
    private var filtered: [Entry] { lens.history.filter { search.isEmpty || $0.source.localizedCaseInsensitiveContains(search) || $0.translation.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        VStack(spacing: 0) {
            header
            if !lens.workspaceMode { navigation }
            HStack(spacing: 0) {
                if lens.workspaceMode {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(LensPage.allCases, id: \.self) { item in
                            Button { page = item } label: { Label(item.rawValue, systemImage: item.symbol).frame(maxWidth: .infinity, alignment: .leading).padding(8).background(page == item ? Color.teal.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain)
                        }; Spacer()
                    }.padding(12).frame(width: 170).background(Color.primary.opacity(0.025))
                }
                Group { switch page {
                case .translate: translator
                case .words: WordsView(vocabulary: lens.vocabulary, models: lens.models) { word in
                    lens.restoreTranslation(source: word.term, translated: word.meaning, language: word.targetLanguage, context: word.example)
                    lens.question = "Explain the word \(word.term) (meaning: \(word.meaning)) and give one natural sentence. For Chinese include Hanzi and tone-mark pinyin."; page = .learn; lens.chat()
                }
                case .history: history
                case .learn: ChatView(lens: lens, chats: lens.chats)
                case .models: ScrollView { ModelsView(embedded: true, models: lens.models) }
                case .settings: ScrollView { settings; Button("Replay tutorial") { tutorial = true }.padding() }
                } }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .sheet(isPresented: $tutorial) { TutorialView(lens: lens) }
        .sheet(isPresented: $showModels) { ModelsView(models: lens.models) }
        .sheet(item: $draftContext) { context in WordDraftView(lens: lens, vocabulary: lens.vocabulary, term: context.translated, meaning: context.source, source: context.source, translated: context.translated, originalContext: context.context, originalTarget: context.target, meaningTarget: ["en", "vi", "pl", "zh-Hans", "zh-Hant"].contains(WordTools.language(context.source)) ? WordTools.language(context.source) : lens.explanationLanguage) }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .frame(minWidth: 340, minHeight: 380)
        .onAppear {
            lens.applyWindowPreferences()
            if CommandLine.arguments.contains("--models-preview") { showModels = true }
            if CommandLine.arguments.contains("--words-preview") { page = .words }
            if CommandLine.arguments.contains("--settings-preview") { DispatchQueue.main.async { preferences = true } }
        }
        .onExitCommand { editing = false }
        .modifier(TranslationWork(lens: lens, host: "workspace"))
    }
    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "character.bubble.fill")
                .font(.system(size: 18, weight: .medium)).foregroundStyle(accent)
                .frame(width: 34, height: 34).background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Mandarin Lens").font(.system(size: 14, weight: .semibold))
                Text("Chinese · Vietnamese · Polish")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 3)
            Button(lens.workspaceMode ? "Compact" : "Open full app") { lens.showWorkspace(compact: lens.workspaceMode) }.controlSize(.small)
            if lens.workspaceMode { Button { lens.panel?.toggleFullScreen(nil) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("Enter or exit full screen") }
            Button { tutorial = true } label: { Image(systemName: "questionmark.circle").frame(width: 20, height: 28) }.buttonStyle(.plain).help("Tutorial").accessibilityLabel("Open tutorial")
            Button { preferences.toggle() } label: { Image(systemName: "slider.horizontal.3").frame(width: 28, height: 28) }
                .buttonStyle(.plain).help("Note settings").accessibilityLabel("Note settings")
                .popover(isPresented: $preferences, arrowEdge: .bottom) { settings }
        }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 14)
    }
    private var navigation: some View {
        HStack(spacing: 4) {
            ForEach([LensPage.translate, .words, .history, .learn], id: \.self) { item in
                Button { page = item } label: {
                    Text(item.rawValue).font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .foregroundStyle(page == item ? Color.primary : Color.secondary)
                        .background(page == item ? Color(nsColor: .controlBackgroundColor) : .clear, in: RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain).accessibilityLabel(item.rawValue).accessibilityAddTraits(page == item ? .isSelected : [])
            }
        }.padding(4).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16).padding(.bottom, 12)
    }
    private var translator: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { lens.captureSelection() } label: { Label("Selected text", systemImage: "text.cursor") }.help("Select text in another app, then use the shortcut while pointing inside it")
                    Spacer()
                    Menu {
                        Text("Point at a word, then press \(lens.shortcutChoice)")
                        Button("Capture selected text") { lens.captureSelection() }
                        Divider()
                        Button("Screen area…") { lens.captureScreen(entireDisplay: false) }
                        Button("Entire display") { lens.captureScreen(entireDisplay: true) }
                    } label: { Label(lens.capturing ? "Reading screen…" : "Capture", systemImage: "viewfinder") }.menuStyle(.borderlessButton).fixedSize().disabled(lens.capturing)
                }.font(.system(size: 11, weight: .medium)).buttonStyle(.plain).foregroundStyle(accent)
                if lens.input.isEmpty && lens.output != "Point at a word and press Option–Space, or paste text here." {
                    Text(lens.output).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    caption("AUTO DETECT")
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                    Menu {
                        Button("中文 · Simplified") { lens.target = "zh-Hans" }
                        Button("繁體中文 · Traditional") { lens.target = "zh-Hant" }
                        Button("English") { lens.target = "en" }
                        Button("Tiếng Việt") { lens.target = "vi" }
                        Button("Polski") { lens.target = "pl" }
                    } label: { HStack(spacing: 5) { Text(languageName(lens.target)); Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }.font(.system(size: 11, weight: .semibold)) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Translation language")
                }
                ZStack(alignment: .topLeading) {
                    if lens.input.isEmpty { Text("A word, a thought, a sentence…").foregroundStyle(.tertiary).padding(.top, 7).padding(.leading, 4).allowsHitTesting(false) }
                    TextEditor(text: $lens.input).font(.system(size: 16)).scrollContentBackground(.hidden)
                        .frame(height: 56).focused($editing).accessibilityLabel("Text to translate")
                }
                if lens.input.range(of: "\\p{Han}", options: .regularExpression) != nil {
                    Text(lens.input.applyingTransform(.mandarinToLatin, reverse: false) ?? "").font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled).help("System pinyin; pronunciation depends on context")
                }
                HStack {
                    if !lens.input.isEmpty {
                        Button("Clear") { lens.input = ""; lens.output = "Point at a word and press Option–Space, or paste text here." }.buttonStyle(.plain).foregroundStyle(.secondary).font(.caption)
                    }
                    Spacer()
                    Button { editing = false; lens.translate() } label: { Label("Translate", systemImage: "arrow.turn.down.right").font(.system(size: 11, weight: .semibold)).padding(.horizontal, 5).padding(.vertical, 3) }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command).disabled(lens.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Divider()
                if lens.input.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "cursorarrow.click").font(.system(size: 24, weight: .light)).foregroundStyle(accent)
                        Text("Meet your next word.").font(.system(size: 17, weight: .medium, design: .rounded))
                        Text("Point at a word in another app and press \(lens.shortcutChoice). Select a sentence and point inside it to capture the selection. Screen area OCR is available from Capture.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                        Button("Shortcut settings") { page = .settings }.buttonStyle(.bordered).controlSize(.small)
                    }.padding(.vertical, 14)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            caption("TRANSLATION"); Spacer()
                            if lens.output == "Translating…" { ProgressView().controlSize(.mini) }
                            if lens.canSaveWord { Button { draftContext = WordDraftContext(source: lens.input, translated: lens.output, target: lens.target, context: lens.capturedContext) } label: { Label("Save word", systemImage: "bookmark") }.font(.system(size: 11, weight: .medium)).buttonStyle(.plain).foregroundStyle(accent).accessibilityLabel("Save word") }
                        }
                        Text(lens.output).font(.system(size: 19, weight: .medium, design: .rounded)).textSelection(.enabled).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading)
                        if lens.output.range(of: "\\p{Han}", options: .regularExpression) != nil {
                            Text(lens.output.applyingTransform(.mandarinToLatin, reverse: false) ?? "").font(.system(size: 12)).foregroundStyle(.secondary).textSelection(.enabled).help("System pinyin; pronunciation depends on context")
                        }
                        if lens.output != "Translating…" {
                            HStack(spacing: 14) {
                                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lens.output, forType: .string); copied = true } label: { Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") }
                                Button { lens.question = "Give one everyday example sentence using: \(lens.input). Explain in \(languageName(lens.target))."; page = .learn; lens.chat() } label: { Label("Use in a sentence", systemImage: "sparkle") }
                            }.font(.system(size: 10, weight: .medium)).buttonStyle(.plain).foregroundStyle(accent).padding(.top, 5)
                        }
                    }.padding(.vertical, 6).onChange(of: lens.output) { _, _ in copied = false }
                }
            }.padding(.horizontal, 20).padding(.bottom, 14)
        }
    }
    private var history: some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Find a word or translation", text: $search).textFieldStyle(.plain).accessibilityLabel("Search translation history")
            }.font(.system(size: 12)).padding(9).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8)).padding(.horizontal, 16)
            if filtered.isEmpty { empty("Your words, kept close.", detail: search.isEmpty ? "Translations you make will appear here." : "Try a different word.", symbol: "clock") }
            else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        HStack { caption("RECENT WORDS"); Spacer(); Text("\(filtered.count)").font(.caption).foregroundStyle(.secondary) }.padding(.bottom, 7)
                        ForEach(filtered) { entry in
                            Button { lens.restoreTranslation(source: entry.source, translated: entry.translation, language: entry.language); page = .translate } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 5) { Text(entry.source).font(.system(size: 13, weight: .medium)).foregroundStyle(.primary); Text(entry.translation).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2) }
                                    Spacer(minLength: 4)
                                    Text(entry.language.uppercased()).font(.system(size: 9, weight: .semibold)).foregroundStyle(accent).padding(.top, 2)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12).contentShape(Rectangle())
                            }.buttonStyle(.plain).help("Open translation")
                                .contextMenu { Button("Delete translation", role: .destructive) { lens.history.removeAll { $0.id == entry.id }; lens.persist() } }
                            Divider()
                        }
                    }.padding(.horizontal, 20)
                }
            }
        }
    }
    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(accent).frame(width: 4, height: 4)
            Text("On this Mac").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "circle.lefthalf.filled").foregroundStyle(.secondary)
            Slider(value: $lens.opacity, in: 0.35...1).controlSize(.mini).frame(width: 70).accessibilityLabel("Note opacity").disabled(reduceTransparency || contrast == .increased)
            TextField("Opacity", value: Binding(get: { Int((reduceTransparency ? 1 : lens.opacity) * 100) }, set: { lens.opacity = Double(min(100, max(35, $0))) / 100 }), format: .number)
                .font(.system(size: 10)).monospacedDigit().frame(width: 34).textFieldStyle(.roundedBorder).controlSize(.mini).disabled(reduceTransparency || contrast == .increased).accessibilityLabel("Opacity percentage, 35 to 100")
            Text("%").font(.system(size: 9)).foregroundStyle(.secondary)
        }.padding(.horizontal, 18).padding(.vertical, 10).background(Color.primary.opacity(0.025))
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button("Choose your local model…") { preferences = false; showModels = true }.controlSize(.small)
            Picker("Explain in", selection: $lens.explanationLanguage) { Text("English").tag("en"); Text("Tiếng Việt").tag("vi"); Text("Polski").tag("pl"); Text("中文").tag("zh-Hans") }
            Text("Make yourself at home.").font(.system(size: 15, weight: .semibold, design: .rounded))
            Picker("Global shortcut", selection: $lens.shortcutChoice) { ForEach(["Option–Space", "Control–Option–Space", "Option–Shift–Space"], id: \.self) { Text($0) } }
            Text(lens.shortcutStatus).font(.caption).foregroundStyle(.secondary)
            Toggle("Keep floating windows above other apps", isOn: $lens.sticky)
            Text("Point at text, then press the shortcut. Modifier keys alone never open Lens.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("Note opacity").font(.system(size: 12, weight: .medium))
            Slider(value: $lens.opacity, in: 0.35...1).disabled(reduceTransparency || contrast == .increased).accessibilityLabel("Note opacity")
            Text(reduceTransparency ? "Reduced Transparency is enabled in macOS." : "Use the footer slider or type a percentage from 35 to 100.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Label("Word lookup access", systemImage: "cursorarrow.click").font(.system(size: 12, weight: .medium))
            Text("Allow Accessibility so Lens can read the word you choose.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Allow access…") { lens.permission() }.controlSize(.small)
            Divider()
            Text("When enabled, the compact window stays above other apps and quick lookup stays open after outside clicks. Escape always dismisses quick lookup.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(20).frame(width: 260)
    }
    private func caption(_ text: String) -> some View { Text(text).font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(.secondary) }
    private func languageName(_ code: String) -> String { code.hasPrefix("zh") ? (code == "zh-Hant" ? "繁體中文" : "中文") : code == "vi" ? "Tiếng Việt" : code == "pl" ? "Polski" : "English" }
    private func empty(_ title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) { Image(systemName: symbol).font(.system(size: 25, weight: .light)).foregroundStyle(accent); Text(title).font(.system(size: 18, weight: .medium, design: .rounded)); Text(detail).font(.system(size: 12)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(24)
    }
}

struct LensMenu: View {
    @EnvironmentObject var lens: Lens
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "character.bubble.fill").font(.title2).foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) { Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Mandarin Lens").font(.system(size: 13, weight: .semibold)); Text("Your words, always close.").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            Button { lens.showWorkspace() } label: { Label("Open full app", systemImage: "rectangle.on.rectangle").frame(maxWidth: .infinity).padding(.vertical, 4) }.buttonStyle(.borderedProminent).tint(.teal)
            Button("Open compact window") { lens.showWorkspace(compact: true) }
            Text("Point at a word → \(lens.shortcutChoice)").font(.caption)
            Text(lens.shortcutStatus).font(.caption2).foregroundStyle(.secondary)
            Menu("Capture text") {
                Button("Capture selected text") { lens.captureSelection() }
                Button("Screen area…") { lens.captureScreen(entireDisplay: false) }
                Button("Entire display") { lens.captureScreen(entireDisplay: true) }
            }
            Divider()
            HStack {
                Text("\(lens.history.count) saved translations").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }.padding(16).frame(width: 252)
    }
}
