import SwiftUI
import AppKit

private enum LensPage: String, CaseIterable {
    case translate = "Translate", words = "My words", history = "History", play = "Play", recap = "Learning recap", learn = "Learn", models = "Local models", settings = "Settings"
    var symbol: String { switch self { case .translate: "character.bubble"; case .words: "bookmark"; case .history: "clock"; case .recap: "text.book.closed"; case .play: "gamecontroller"; case .learn: "sparkle"; case .models: "cpu"; case .settings: "gearshape" } }
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
    @State private var favoritesOnly = false
    @State private var historyLimit = 200
    @State private var tutorial = CommandLine.arguments.contains("--tutorial-preview") || (!UserDefaults.standard.bool(forKey: "onboardingComplete") && !CommandLine.arguments.contains("--skip-tutorial"))
    @State private var showModels = false
    @State private var draftContext: WordDraftContext?
    @State private var copied = false
    @FocusState private var editing: Bool
    private var accent: Color { scheme == .dark ? Color(red: 0.28, green: 0.80, blue: 0.77) : Color(red: 0.0, green: 0.40, blue: 0.42) }
    private var filtered: [Entry] { lens.history.filter { (!favoritesOnly || $0.favorite) && (search.isEmpty || $0.source.localizedCaseInsensitiveContains(search) || $0.translation.localizedCaseInsensitiveContains(search) || $0.pronunciation.localizedCaseInsensitiveContains(search)) } }
    var body: some View {
        VStack(spacing: 0) {
            header
            if !lens.workspaceMode { navigation }
            HStack(spacing: 0) {
                if lens.workspaceMode {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(LensPage.allCases, id: \.self) { item in
                            Button { page = item } label: { Label(item.rawValue, systemImage: item.symbol).frame(maxWidth: .infinity, alignment: .leading).padding(8).contentShape(Rectangle()).background(page == item ? Color.teal.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain).font(.system(size: 13,weight: .medium)).accessibilityAddTraits(page == item ? .isSelected : [])
                        }; Spacer()
                    }.padding(12).frame(width: 184).background(Color.primary.opacity(0.025))
                }
                Group { switch page {
                case .translate: translator
                case .words: WordsView(vocabulary: lens.vocabulary, models: lens.models, play: { page = .play }) { word in
                    lens.restoreTranslation(source: word.term, translated: word.meaning, language: word.targetLanguage, context: word.example,usageExample: word.usageExample)
                    lens.question = "Explain the word \(word.term) (meaning: \(word.meaning)) and give one natural sentence. For Chinese include Hanzi and tone-mark pinyin."; page = .learn; lens.chat()
                }
                case .history: history
                case .learn: ChatView(lens: lens, chats: lens.chats)
                case .models: ModelsView(embedded: true, models: lens.models)
                case .play: PracticeView(vocabulary: lens.vocabulary)
                case .recap: LearningRecapView(lens: lens,recaps: lens.recaps,models: lens.models)
                case .settings: ScrollView { VStack(alignment: .leading,spacing: 12) { Text("Settings").font(.system(size: 28,weight: .semibold,design: .rounded)).padding(.horizontal,20); settings; Button("Replay tutorial") { tutorial = true }.padding(.horizontal,20) }.padding(.vertical,20).frame(maxWidth: 760,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading) }
                } }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .sheet(isPresented: $tutorial) { TutorialView(lens: lens) }
        .sheet(isPresented: $showModels) { ModelsView(models: lens.models) }
        .sheet(item: $draftContext) { context in WordDraftView(lens: lens, vocabulary: lens.vocabulary, term: context.translated, meaning: context.source, source: context.source, translated: context.translated, originalContext: context.context, originalTarget: context.target, meaningTarget: ["en", "vi", "pl", "zh-Hans", "zh-Hant"].contains(WordTools.language(context.source)) ? WordTools.language(context.source) : lens.explanationLanguage) }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .frame(minWidth: lens.workspaceMode ? 760 : 340, minHeight: 380)
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
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Kamihi Lens").font(.system(size: 14, weight: .semibold)).lineLimit(1)
                if lens.workspaceMode { Text("Words · sentences · screen translation").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 3)
            Button(lens.workspaceMode ? "Compact" : "Open full app") { lens.showWorkspace(compact: lens.workspaceMode) }.controlSize(.small)
            if lens.workspaceMode { Button { lens.panel?.toggleFullScreen(nil) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.help("Enter or exit full screen") }
            Button { tutorial = true } label: { Image(systemName: "questionmark.circle").frame(width: 20, height: 28) }.buttonStyle(.plain).help("Tutorial").accessibilityLabel("Open tutorial")
            Button { preferences.toggle() } label: { Image(systemName: "slider.horizontal.3").frame(width: 28, height: 28) }
                .buttonStyle(.plain).help("Note settings").accessibilityLabel("Note settings")
                .popover(isPresented: $preferences, arrowEdge: .bottom) { settings.frame(width: 330) }
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
            Menu { ForEach([LensPage.play,.recap,.models,.settings],id: \.self) { item in Button(item.rawValue) { page = item } } } label: { Image(systemName: "ellipsis").padding(6) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("More sections")
        }.padding(4).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16).padding(.bottom, 12)
    }
    private var translator: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    captureButton("Word",shortcut: "⌥ Space",kind: .word)
                    captureButton("Sentence",shortcut: "⌃ Space",kind: .sentence)
                    captureButton("Screen area",shortcut: "⌃⌥ Space",kind: .area)
                }.padding(.bottom,6)
                if lens.input.isEmpty && lens.output != "Press Option–Space, then click a word anywhere on screen. Or paste text here." {
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
                        Button("Clear") { lens.captureKind = .typed; lens.input = ""; lens.output = "Press Option–Space, then click a word anywhere on screen. Or paste text here." }.buttonStyle(.plain).foregroundStyle(.secondary).font(.caption)
                    }
                    Spacer()
                    Button { editing = false; lens.captureKind = .typed; lens.translate() } label: { Label("Translate", systemImage: "arrow.turn.down.right").font(.system(size: 11, weight: .semibold)).padding(.horizontal, 5).padding(.vertical, 3) }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.return, modifiers: .command).disabled(lens.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Divider()
                if lens.input.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "cursorarrow.click").font(.system(size: 24, weight: .light)).foregroundStyle(accent)
                        Text("Meet your next word.").font(.system(size: 17, weight: .medium, design: .rounded))
                        Text("Select a word for pinyin and meaning, a sentence for context, or drag a screen area. Your result appears near the cursor and stays in History. Save the useful ones to My words.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
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
                        CurrentChineseExample(lens: lens)
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
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                TextField("Find a word, pinyin or translation",text: $search).textFieldStyle(.roundedBorder).accessibilityLabel("Search translation history")
                Button { favoritesOnly.toggle() } label: { Image(systemName: favoritesOnly ? "star.fill" : "star") }.buttonStyle(.bordered).accessibilityLabel("Filter favorite translations")
                Button("Learning recap") { page = .recap }.buttonStyle(.bordered)
            }.padding(.horizontal,22)
            if !lens.historyStatus.isEmpty { Text(lens.historyStatus).font(.caption).foregroundStyle(.red).padding(.horizontal,22) }
            if filtered.isEmpty { empty("A place for every discovery.",detail: favoritesOnly ? "Star a translation to find it here." : "Word, sentence and area results appear here automatically.",symbol: "clock") }
            else {
                ScrollView {
                    LazyVStack(alignment: .leading,spacing: 12) {
                        HStack { Text("\(filtered.count) translations").font(.caption.weight(.medium)).foregroundStyle(.secondary); Spacer(); Text("Kept on this Mac").font(.caption).foregroundStyle(.secondary) }
                        ForEach(Array(filtered.prefix(historyLimit))) { entry in
                            HStack(alignment: .top,spacing: 14) {
                                Image(systemName: entry.kind.symbol).font(.title3).foregroundStyle(accent).frame(width: 30).padding(.top,3)
                                Button { lens.restoreTranslation(source: entry.source,translated: entry.translation,language: entry.language,context: entry.context,usageExample: entry.usageExample); lens.captureKind = entry.kind; page = .translate } label: {
                                    VStack(alignment: .leading,spacing: 7) {
                                        Text(entry.source).font(.system(size: 16,weight: .medium)).foregroundStyle(.primary).lineLimit(3)
                                        if !entry.pronunciation.isEmpty { Text(entry.pronunciation).font(.caption).foregroundStyle(accent).lineLimit(2) }
                                        Text(entry.error ?? entry.translation).font(.callout).foregroundStyle(.secondary).lineLimit(4)
                                        HStack { Text(entry.kind.title); Text("·"); Text(entry.date,style: .date); Text(entry.language.uppercased()) }.font(.caption2).foregroundStyle(.tertiary)
                                    }.frame(maxWidth: .infinity,alignment: .leading)
                                }.buttonStyle(.plain).help("Open translation")
                                Button { lens.toggleFavorite(entry.id) } label: { Image(systemName: entry.favorite ? "star.fill" : "star").foregroundStyle(entry.favorite ? Color.orange : .secondary) }.buttonStyle(.plain).accessibilityLabel(entry.favorite ? "Unstar translation" : "Star translation")
                            }.padding(17).background(Color.primary.opacity(0.035),in: RoundedRectangle(cornerRadius: 13))
                                .contextMenu { Button("Delete translation",role: .destructive) { lens.history.removeAll { $0.id == entry.id }; lens.persist() } }
                        }
                        if filtered.count > historyLimit { Button("Show more history") { historyLimit += 200 }.frame(maxWidth: .infinity).padding() }
                    }.padding(.horizontal,22).padding(.bottom,20)
                }
            }
        }
    }
    private func captureButton(_ title: String,shortcut: String,kind: CaptureKind) -> some View {
        Button { lens.startSelection(kind) } label: { VStack(alignment: .leading,spacing: 7) { Label(title,systemImage: kind.symbol).font(.system(size: 13,weight: .semibold)); Text(shortcut).font(.caption).monospaced().foregroundStyle(.secondary) }.frame(maxWidth: .infinity,alignment: .leading).padding(13).background(accent.opacity(0.07),in: RoundedRectangle(cornerRadius: 11)) }.buttonStyle(.plain)
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
            LanguagePicker(target: $lens.target)
            Picker("Translate from",selection: $lens.sourceChoice) { Text("Automatic · English for short Latin words").tag("auto"); Text("English").tag("en"); Text("Polski").tag("pl"); Text("Tiếng Việt").tag("vi"); Text("中文").tag("zh-Hans") }
            Text("Translation language changes the selected word. AI explanation language changes chat and recaps.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
            Picker("AI explanations in", selection: $lens.explanationLanguage) { Text("English").tag("en"); Text("Tiếng Việt").tag("vi"); Text("Polski").tag("pl"); Text("中文").tag("zh-Hans") }
            Text("Make yourself at home.").font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(lens.shortcutStatus).font(.caption).foregroundStyle(.secondary)
            Text(lens.areaShortcutStatus).font(.caption).foregroundStyle(.secondary)
            Text(lens.sentenceShortcutStatus).font(.caption).foregroundStyle(.secondary)
            Picker("Sentence shortcut",selection: $lens.sentenceShortcutChoice) { Text("Control–Space").tag("Control–Space"); Text("Control–Shift–Space").tag("Control–Shift–Space") }
            Toggle("Keep the result above other apps",isOn: $lens.sticky)
            Text("Select a word, sentence or screen area. A small result shows near your cursor. Escape or the same shortcut dismisses it.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
            Divider()
            Text("Note opacity").font(.system(size: 12, weight: .medium))
            Slider(value: $lens.opacity, in: 0.35...1).disabled(reduceTransparency || contrast == .increased).accessibilityLabel("Note opacity")
            Text(reduceTransparency ? "Reduced Transparency is enabled in macOS." : "Use the footer slider or type a percentage from 35 to 100.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Label("Screen selection", systemImage: "viewfinder").font(.system(size: 12, weight: .medium))
            Text(lens.selectionStatus).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Allow Screen Recording…") { lens.screenPermission() }.controlSize(.small)
            Text("A local snapshot lets you select words in images, videos and other apps. Pixels are released after selection or cancellation. Protected or unreadable content may be unavailable.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Label("Selected-text access", systemImage: "cursorarrow.click").font(.system(size: 12, weight: .medium))
            Text("Allow Accessibility so Lens can read the word you choose.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Allow access…") { lens.permission() }.controlSize(.small)
            Divider()
            Text("This setting only keeps the app window above other apps. The result clears with Escape or the same shortcut.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(20).frame(maxWidth: .infinity,alignment: .leading)
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
                VStack(alignment: .leading, spacing: 2) { Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Kamihi Lens").font(.system(size: 13, weight: .semibold)); Text("Your words, always close.").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            Button { lens.showWorkspace() } label: { Label("Open full app", systemImage: "rectangle.on.rectangle").frame(maxWidth: .infinity).padding(.vertical, 4) }.buttonStyle(.borderedProminent).tint(.teal)
            Button("Open compact window") { lens.showWorkspace(compact: true) }
            Button("Select a word · Option–Space") { lens.startSelection(.word) }
            Button("Select a sentence · Control–Space") { lens.startSelection(.sentence) }
            Button("Translate an area · Control–Option–Space") { lens.startSelection(.area) }
            Text("Choose text anywhere on your screen").font(.caption)
            Text(lens.shortcutStatus).font(.caption2).foregroundStyle(.secondary)
            Text(lens.selectionStatus).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
