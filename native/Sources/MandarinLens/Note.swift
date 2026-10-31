import SwiftUI
import AppKit

private enum LensPage: String, CaseIterable {
    case notepad = "Notepad", translate = "Translate", words = "My words", history = "History", play = "Play", recap = "Learning recap", learn = "Learn", models = "Local models", settings = "Settings"
    var symbol: String { switch self { case .notepad: "note.text"; case .translate: "character.bubble"; case .words: "character.book.closed"; case .history: "clock"; case .play: "gamecontroller"; case .recap: "text.book.closed"; case .learn: "bubble.left.and.bubble.right"; case .models: "cpu"; case .settings: "slider.horizontal.3" } }
}
struct Note: View {
    @EnvironmentObject var lens: Lens
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
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
    private var filtered: [Entry] { lens.history.filter { (!favoritesOnly || $0.favorite) && (search.isEmpty || $0.source.localizedCaseInsensitiveContains(search) || $0.translation.localizedCaseInsensitiveContains(search) || $0.pronunciation.localizedCaseInsensitiveContains(search)) } }
    var body: some View {
        HStack(spacing: 0) {
            if lens.workspaceMode { sidebar }
            VStack(spacing: 0) {
                toolbar
                if !lens.workspaceMode { compactNavigation }
                Rectangle().fill(Color.lensLine.opacity(0.5)).frame(height: 1)
                Group { switch page {
                case .notepad: NotepadView(lens: lens,notes: lens.notepad)
                case .translate: translator
                case .words: WordsView(vocabulary: lens.vocabulary,models: lens.models,play: { page = .play }) { word in
                    lens.restoreTranslation(source: word.term,translated: word.meaning,language: word.targetLanguage,context: word.example,usageExample: word.usageExample)
                    lens.question = "Explain the word \(word.term) (meaning: \(word.meaning)) and give one natural sentence. For Chinese include Hanzi and tone-mark pinyin."; page = .learn; lens.chat()
                }
                case .history: history
                case .play: PracticeView(vocabulary: lens.vocabulary)
                case .recap: LearningRecapView(lens: lens,recaps: lens.recaps,models: lens.models)
                case .learn: ChatView(lens: lens,chats: lens.chats)
                case .models: ModelsView(embedded: true,models: lens.models)
                case .settings: settingsPage
                } }.frame(maxWidth: .infinity,maxHeight: .infinity)
            }
        }.background(Color.lensCanvas).tint(.lensAccent)
        .frame(minWidth: lens.workspaceMode ? 760 : 340,minHeight: 380)
        .sheet(isPresented: $tutorial) { TutorialView(lens: lens) }
        .sheet(isPresented: $showModels) { ModelsView(models: lens.models) }
        .sheet(item: $draftContext) { context in WordDraftView(lens: lens,vocabulary: lens.vocabulary,term: context.translated,meaning: context.source,source: context.source,translated: context.translated,originalContext: context.context,originalUsageExample: context.usageExample,originalTarget: context.target,meaningTarget: ["en","vi","pl","zh-Hans","zh-Hant"].contains(TranslationSource.language(text: context.source,context: context.context,preference: lens.sourceChoice)) ? TranslationSource.language(text: context.source,context: context.context,preference: lens.sourceChoice) : lens.explanationLanguage) }
        .onAppear {
            lens.applyWindowPreferences()
            if CommandLine.arguments.contains("--models-preview") { showModels = true }
            if CommandLine.arguments.contains("--words-preview") { page = .words }
            if CommandLine.arguments.contains("--settings-preview") { preferences = true }
        }.onExitCommand { editing = false }.modifier(TranslationWork(lens: lens,host: "workspace"))
    }
    private var sidebar: some View {
        VStack(alignment: .leading,spacing: 0) {
            LensBrand().padding(.horizontal,20).padding(.top,24).padding(.bottom,30)
            sidebarGroup("Workspace",items: [.translate,.history,.notepad])
            sidebarGroup("Study",items: [.words,.play,.recap,.learn]).padding(.top,24)
            Spacer(minLength: 20)
            sidebarGroup(nil,items: [.models,.settings])
            HStack(spacing: 7) { Circle().fill(Color.lensAccent).frame(width: 5,height: 5); Text("On this Mac"); Spacer(); Text("4.3").monospacedDigit() }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal,20).padding(.vertical,20)
        }.frame(width: 196).background(Color.lensSidebar).overlay(alignment: .trailing) { Rectangle().fill(Color.lensLine.opacity(0.45)).frame(width: 1) }
    }
    private func sidebarGroup(_ title: String?,items: [LensPage]) -> some View {
        VStack(alignment: .leading,spacing: 4) {
            if let title { Text(title).font(.system(size: 10,weight: .medium)).foregroundStyle(.secondary).padding(.horizontal,14).padding(.bottom,6) }
            ForEach(items,id: \.self) { item in
                Button { page = item } label: {
                    HStack(spacing: 10) { Image(systemName: item.symbol).font(.system(size: 15,weight: .regular)).foregroundStyle(page == item ? Color.lensAccent : .secondary).frame(width: 22); Text(item.rawValue).font(.system(size: 13,weight: page == item ? .semibold : .regular)); Spacer(minLength: 0) }.padding(.horizontal,12).frame(maxWidth: .infinity,minHeight: 38,alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(LensRowStyle(selected: page == item)).accessibilityLabel(item.rawValue).accessibilityAddTraits(page == item ? .isSelected : [])
            }
        }.padding(.horizontal,10)
    }
    private var toolbar: some View {
        HStack(spacing: 12) {
            if !lens.workspaceMode { LensBrand(compact: true) }
            Text(page.rawValue).font(.system(size: 13,weight: .medium)).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button { lens.showWorkspace(compact: lens.workspaceMode) } label: { Label(lens.workspaceMode ? "Compact" : "Open full app",systemImage: lens.workspaceMode ? "rectangle.compress.vertical" : "arrow.up.left.and.arrow.down.right") }.buttonStyle(LensButtonStyle(small: true))
            Button { tutorial = true } label: { Image(systemName: "questionmark.circle").frame(width: 28,height: 30) }.buttonStyle(.plain).foregroundStyle(.secondary).help("Tutorial").accessibilityLabel("Open tutorial")
            Button { preferences.toggle() } label: { Image(systemName: "slider.horizontal.3").frame(width: 28,height: 30) }.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Display options").popover(isPresented: $preferences) { quickPreferences }
        }.padding(.horizontal,20).frame(height: lens.workspaceMode ? 54 : 62)
    }
    private var compactNavigation: some View {
        HStack(spacing: 2) {
            ForEach([LensPage.translate,.words,.history,.learn],id: \.self) { item in Button { page = item } label: { Text(item.rawValue).font(.system(size: 11,weight: .medium)).frame(maxWidth: .infinity,minHeight: 32).contentShape(Rectangle()) }.buttonStyle(LensRowStyle(selected: page == item)).accessibilityLabel(item.rawValue) }
            Menu { ForEach([LensPage.notepad,.play,.recap,.models,.settings],id: \.self) { item in Button(item.rawValue) { page = item } } } label: { Image(systemName: "ellipsis").frame(width: 25,height: 30) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("More sections")
        }.padding(.horizontal,16).padding(.bottom,10)
    }
    private var translator: some View {
        GeometryReader { geometry in
        ScrollView {
            VStack(alignment: .leading,spacing: lens.workspaceMode ? 24 : 16) {
                if lens.workspaceMode || lens.input.isEmpty { LensPageHeading(title: "Translate into \(languageName(lens.target))",detail: "Click a sentence, drag a section, or paste text below.") }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) { captureButton("Word",shortcut: "⌥ Space",kind: .word); captureButton("Sentence",shortcut: lens.sentenceShortcutChoice == "Control–Shift–Space" ? "⌃⇧ Space" : "⌃ Space",kind: .sentence); captureButton("Section",shortcut: "⌃⌥ Space",kind: .area) }
                    VStack(spacing: 8) { captureButton("Word",shortcut: "⌥ Space",kind: .word); captureButton("Sentence",shortcut: lens.sentenceShortcutChoice == "Control–Shift–Space" ? "⌃⇧ Space" : "⌃ Space",kind: .sentence); captureButton("Section",shortcut: "⌃⌥ Space",kind: .area) }
                }
                if lens.workspaceMode { Text("Sentence: click anywhere in it. Section: drag around several lines. You can switch modes while selecting.").font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true) }
                TranslationLanguageBar(lens: lens)
                if lens.workspaceMode {
                    if geometry.size.width >= 620 {
                        let column = (min(1050,geometry.size.width)-72)/2
                        HStack(alignment: .top,spacing: 16) { sourcePane.frame(width: column); resultPane.frame(width: column) }
                    } else { VStack(spacing: 16) { sourcePane; resultPane } }
                } else {
                    if lens.input.isEmpty { sourcePane }
                    else { DisclosureGroup("Original · \(String(lens.input.prefix(28)))") { sourcePane.padding(.top,10) }.font(.system(size: 12)).foregroundStyle(.secondary) }
                    resultPane
                }
                if !lens.capturedContext.isEmpty && lens.capturedContext != lens.input { DisclosureGroup("Source context") { Text(lens.capturedContext).font(.system(size: 13)).foregroundStyle(.secondary).textSelection(.enabled).padding(.top,8) }.font(.system(size: 12)).foregroundStyle(.secondary) }
                HStack(spacing: 8) { Image(systemName: "lock").font(.system(size: 10)); Text("Screen recognition and translation stay on your Mac.") }.font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(lens.workspaceMode ? 28 : 20).frame(maxWidth: 1050,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading)
        }
        }
    }
    private var sourcePane: some View {
        VStack(alignment: .leading,spacing: 18) {
            HStack { Text("Original").font(.system(size: 12,weight: .semibold)); Spacer(); Text(lens.sourceChoice == "auto" ? "Auto detect" : languageName(lens.sourceChoice)).font(.system(size: 11)).foregroundStyle(.secondary); SpeechControl(speaker: lens.speaker,text: lens.input,language: TranslationSource.language(text: lens.input,context: lens.capturedContext,preference: lens.sourceChoice),title: "original").disabled(lens.input.isEmpty) }
            ZStack(alignment: .topLeading) {
                if lens.input.isEmpty { Text("Enter a word or sentence").font(.system(size: 17)).foregroundStyle(.tertiary).padding(.top,7).padding(.leading,4).allowsHitTesting(false) }
                TextEditor(text: $lens.input).font(.system(size: 19)).scrollContentBackground(.hidden).scrollIndicators(.hidden).frame(height: lens.workspaceMode ? 145 : 64).focused($editing).accessibilityLabel("Text to translate")
            }
            HStack {
                if !lens.input.isEmpty { Button("Clear") { lens.captureKind = .typed; lens.input = ""; lens.output = "Press Option–Space, then click a word anywhere on screen. Or paste text here." }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary) }
                Spacer()
                Button { editing = false; lens.captureKind = .typed; lens.translate() } label: { Label("Translate",systemImage: "arrow.turn.down.left") }.buttonStyle(LensButtonStyle(prominent: true,small: true)).keyboardShortcut(.return,modifiers: .command).disabled(lens.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.frame(maxWidth: .infinity,alignment: .leading).lensSurface()
    }
    private var resultPane: some View {
        VStack(alignment: .leading,spacing: lens.workspaceMode ? 18 : 12) {
            HStack { Text("Translation").font(.system(size: 12,weight: .semibold)); Spacer(); Text(languageName(lens.target)).font(.system(size: 11)).foregroundStyle(.secondary); SpeechControl(speaker: lens.speaker,text: lens.output,language: lens.target,title: "translation").disabled(!lens.canSaveWord) }
            if lens.input.isEmpty {
                VStack(alignment: .leading,spacing: 12) { Text("字").font(.system(size: 44,weight: .light)).foregroundStyle(Color.lensAccent); Text("Your translation appears here.").font(.system(size: 13)).foregroundStyle(.secondary); Text("Chinese words include pinyin and an example.").font(.system(size: 12)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity,minHeight: 188,alignment: .topLeading).padding(.top,8)
            } else {
                if lens.output == "Translating…" { HStack { ProgressView().controlSize(.small); Text("Translating…").font(.system(size: 14)).foregroundStyle(.secondary) }.frame(minHeight: 100) }
                else {
                    Text(lens.output).font(.system(size: lens.target.hasPrefix("zh") && lens.output.count < 16 ? 38 : 22,weight: .medium)).textSelection(.enabled).fixedSize(horizontal: false,vertical: true).lineSpacing(5)
                    if lens.output.range(of: "\\p{Han}",options: .regularExpression) != nil { Text(lens.output.applyingTransform(.mandarinToLatin,reverse: false) ?? "").font(.system(size: 15)).foregroundStyle(Color.lensAccent).textSelection(.enabled) }
                }
                CurrentChineseExample(lens: lens)
                if lens.canSaveWord {
                    HStack(spacing: 12) {
                        Button { draftContext = WordDraftContext(source: lens.input,translated: lens.output,target: lens.target,context: lens.capturedContext,usageExample: lens.usageExample) } label: { LensActionLabel(title: "Save",symbol: "bookmark") }.buttonStyle(LensActionStyle(prominent: true)).accessibilityLabel("Save word")
                        Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lens.output,forType: .string); copied = true } label: { LensActionLabel(title: copied ? "Copied" : "Copy",symbol: copied ? "checkmark" : "doc.on.doc") }.buttonStyle(LensActionStyle()).accessibilityLabel(copied ? "Copied" : "Copy translation")
                        CaptureNoteButton(lens: lens,notes: lens.notepad)
                    }
                } else if lens.output != "Translating…" { Button("Retry") { lens.translate() }.buttonStyle(LensButtonStyle(small: true)) }
            }
        }.frame(maxWidth: .infinity,alignment: .leading).lensSurface().onChange(of: lens.output) { _,_ in copied = false }
    }
    private func captureButton(_ title: String,shortcut: String,kind: CaptureKind) -> some View {
        Button { lens.startSelection(kind) } label: { HStack(spacing: lens.workspaceMode ? 9 : 6) { Image(systemName: kind.symbol).font(.system(size: lens.workspaceMode ? 14 : 12)).foregroundStyle(Color.lensAccent); Text(title).font(.system(size: 12,weight: .medium)).lineLimit(1).fixedSize(); Spacer(minLength: 4); if lens.workspaceMode { LensKeycap(text: shortcut) } }.padding(lens.workspaceMode ? 10 : 8).frame(minWidth: lens.workspaceMode ? 140 : 76,maxWidth: .infinity).contentShape(Rectangle()) }.buttonStyle(LensRowStyle()).overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.lensLine.opacity(0.6),lineWidth: 1)).help(kind == .area ? "Drag a rectangle around a paragraph or section. Space selects the whole display." : kind == .sentence ? "Click anywhere in a sentence, including one that wraps across lines." : "Click a word. You can also drag to select a section.")
    }
    private var history: some View {
        VStack(alignment: .leading,spacing: 20) {
            LensPageHeading(title: "Translation history",detail: "Words, sentences and screen areas you’ve translated.")
            HStack(spacing: 10) { LensSearchField(placeholder: "Search words, pinyin or translations",text: $search); Button { favoritesOnly.toggle() } label: { Image(systemName: favoritesOnly ? "star.fill" : "star") }.buttonStyle(LensButtonStyle()).accessibilityLabel("Filter favorite translations") }
            if !lens.historyStatus.isEmpty { Text(lens.historyStatus).font(.caption).foregroundStyle(.red) }
            if filtered.isEmpty { LensEmptyState(title: favoritesOnly ? "No favorites yet" : "No translations yet",detail: favoritesOnly ? "Star a translation to find it here." : "Select a word with Option–Space to get started.",symbol: "clock"); Spacer() }
            else {
                HStack { Text("\(filtered.count) translations"); Spacer(); Button("Learning recap") { page = .recap }.foregroundStyle(Color.lensAccent) }.font(.system(size: 12)).foregroundStyle(.secondary).buttonStyle(.plain)
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filtered.prefix(historyLimit))) { entry in
                            HStack(alignment: .top,spacing: 16) {
                                Image(systemName: entry.kind.symbol).font(.system(size: 16)).foregroundStyle(.secondary).frame(width: 24).padding(.top,4)
                                Button { lens.restoreTranslation(source: entry.source,translated: entry.translation,language: entry.language,context: entry.context,usageExample: entry.usageExample); lens.captureKind = entry.kind; page = .translate } label: {
                                    VStack(alignment: .leading,spacing: 7) {
                                        Text(entry.source).font(.system(size: 16,weight: .medium)).lineLimit(2)
                                        Text(entry.error ?? entry.translation).font(.system(size: 14)).foregroundStyle(.secondary).lineLimit(3)
                                        if !entry.pronunciation.isEmpty { Text(entry.pronunciation).font(.system(size: 12)).foregroundStyle(Color.lensAccent).lineLimit(2) }
                                        HStack(spacing: 7) { Text(entry.kind.title); Text("·"); Text(entry.date,style: .date); Text("·"); Text(languageName(entry.language)) }.font(.system(size: 10)).foregroundStyle(.secondary)
                                    }.frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).help("Open translation")
                                Button { lens.toggleFavorite(entry.id) } label: { Image(systemName: entry.favorite ? "star.fill" : "star").foregroundStyle(entry.favorite ? Color.lensAccent : .secondary).frame(width: 26,height: 26) }.buttonStyle(.plain).accessibilityLabel(entry.favorite ? "Unstar translation" : "Star translation")
                            }.padding(.vertical,17).contextMenu { Button("Delete translation",role: .destructive) { lens.history.removeAll { $0.id == entry.id }; lens.persist() } }
                            Divider().overlay(Color.lensLine.opacity(0.2))
                        }
                        if filtered.count > historyLimit { Button("Show more history") { historyLimit += 200 }.buttonStyle(LensButtonStyle()).padding() }
                    }
                }
            }
        }.padding(lens.workspaceMode ? 28 : 20).frame(maxWidth: 940,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading)
    }
    private var settingsPage: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 28) {
                LensPageHeading(title: "Settings",detail: "Translation, shortcuts and how Lens appears on your Mac.")
                settingsSection("Languages") {
                    LanguagePicker(target: $lens.target)
                    SourceLanguagePicker(source: $lens.sourceChoice)
                    Text("Automatic uses surrounding text, or English for short Latin words.").font(.system(size: 11)).foregroundStyle(.secondary)
                    Picker("AI explanations in",selection: $lens.explanationLanguage) { Text("English").tag("en"); Text("Tiếng Việt").tag("vi"); Text("Polski").tag("pl"); Text("中文").tag("zh-Hans") }
                }
                settingsSection("Screen selection") {
                    shortcutRow("Word",key: "⌥ Space",status: lens.shortcutStatus)
                    shortcutRow("Screen area",key: "⌃⌥ Space",status: lens.areaShortcutStatus)
                    Picker("Sentence shortcut",selection: $lens.sentenceShortcutChoice) { Text("Control–Space").tag("Control–Space"); Text("Control–Shift–Space").tag("Control–Shift–Space") }
                    Text(lens.sentenceShortcutStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(lens.notesShortcutStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("Escape or the same shortcut clears the result.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                settingsSection("Appearance") { appearanceControls }
                settingsSection("Permissions") {
                    permissionRow("Screen Recording",detail: "Read visible words in images, videos and other apps.",action: "Allow Screen Recording…") { lens.screenPermission() }
                    Divider()
                    permissionRow("Accessibility",detail: "Read existing text selections with Capture selected text.",action: "Allow access…") { lens.permission() }
                    Text(lens.selectionStatus).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                HStack { Button("Choose your local model…") { showModels = true }; Spacer(); Button("Replay tutorial") { tutorial = true } }.font(.system(size: 12)).buttonStyle(.plain).foregroundStyle(Color.lensAccent)
            }.padding(28).frame(maxWidth: 760,alignment: .leading).frame(maxWidth: .infinity,alignment: .topLeading)
        }
    }
    private func settingsSection<Content: View>(_ title: String,@ViewBuilder content: ()->Content) -> some View {
        VStack(alignment: .leading,spacing: 14) { Text(title).font(.system(size: 14,weight: .semibold)); content() }.frame(maxWidth: .infinity,alignment: .leading).lensSurface()
    }
    private var appearanceControls: some View {
        VStack(alignment: .leading,spacing: 16) {
            Toggle("Keep the result above other apps",isOn: $lens.sticky).font(.system(size: 12))
            HStack { Text("Window opacity").font(.system(size: 12)); Spacer(); Text("\(Int(lens.opacity*100))%").font(.system(size: 11,design: .monospaced)).foregroundStyle(.secondary) }
            Slider(value: $lens.opacity,in: 0.35...1).disabled(reduceTransparency || contrast == .increased).accessibilityLabel("Note opacity")
            if reduceTransparency || contrast == .increased { Text("macOS accessibility settings keep the window opaque.").font(.system(size: 11)).foregroundStyle(.secondary) }
        }
    }
    private var quickPreferences: some View {
        VStack(alignment: .leading,spacing: 20) { Text("Display options").font(.system(size: 15,weight: .semibold)); appearanceControls; Divider(); Button("All settings") { preferences = false; page = .settings }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Color.lensAccent) }.padding(22).frame(width: 300).background(Color.lensCanvas)
    }
    private func shortcutRow(_ title: String,key: String,status: String) -> some View { HStack { Text(title).font(.system(size: 12)); Spacer(); LensKeycap(text: key) }.help(status) }
    private func permissionRow(_ title: String,detail: String,action: String,perform: @escaping ()->Void) -> some View {
        VStack(alignment: .leading,spacing: 8) { Text(title).font(.system(size: 13,weight: .medium)); Text(detail).font(.system(size: 12)).foregroundStyle(.secondary); Button(action,action: perform).buttonStyle(LensButtonStyle(small: true)) }
    }
    private func languageName(_ code: String) -> String { code.hasPrefix("zh") ? (code == "zh-Hant" ? "Traditional Chinese" : "Chinese") : code == "vi" ? "Vietnamese" : code == "pl" ? "Polish" : "English" }
}
struct LensMenu: View {
    @EnvironmentObject var lens: Lens
    var body: some View {
        VStack(alignment: .leading,spacing: 18) {
            LensBrand()
            Button { lens.showWorkspace() } label: { Label("Open Kamihi Lens",systemImage: "rectangle.on.rectangle").frame(maxWidth: .infinity) }.buttonStyle(LensButtonStyle(prominent: true))
            VStack(spacing: 3) {
                menuAction("Select a word",shortcut: "⌥ Space",kind: .word)
                menuAction("Select a sentence",shortcut: lens.sentenceShortcutChoice == "Control–Shift–Space" ? "⌃⇧ Space" : "⌃ Space",kind: .sentence)
                menuAction("Select a section",shortcut: "⌃⌥ Space",kind: .area)
            }
            Button("Open Notepad") { lens.showNotepad(restoreWorkspace: false) }.buttonStyle(LensButtonStyle(small: true))
            Divider()
            Button("Open compact window") { lens.showWorkspace(compact: true) }.buttonStyle(.plain).font(.system(size: 12))
            Menu("Capture text") { Button("Capture selected text") { lens.captureSelection() }; Button("Screen area…") { lens.captureScreen(entireDisplay: false) }; Button("Entire display") { lens.captureScreen(entireDisplay: true) } }.font(.system(size: 12))
            Text(lens.selectionStatus).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
            Divider()
            HStack { Text("\(lens.history.count) translations").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary) }
        }.padding(20).frame(width: 282).background(Color.lensCanvas).tint(.lensAccent)
    }
    private func menuAction(_ title: String,shortcut: String,kind: CaptureKind) -> some View {
        Button { lens.startSelection(kind) } label: { HStack { Text(title).font(.system(size: 12)); Spacer(); LensKeycap(text: shortcut) }.padding(.vertical,7).padding(.horizontal,5).contentShape(Rectangle()) }.buttonStyle(LensRowStyle())
    }
}
