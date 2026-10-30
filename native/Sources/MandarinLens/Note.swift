import SwiftUI
import AppKit

private enum LensPage: String, CaseIterable {
    case translate = "Translate", history = "History", learn = "Learn"
    var symbol: String { switch self { case .translate: "character.bubble"; case .history: "clock"; case .learn: "sparkle" } }
}
struct Note: View {
    @EnvironmentObject var lens: Lens
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var scheme
    @State private var page: LensPage = CommandLine.arguments.contains("--chat-smoke") ? .learn : CommandLine.arguments.contains("--history-preview") ? .history : .translate
    @State private var preferences = false
    @State private var search = ""
    @State private var copied = false
    @FocusState private var editing: Bool
    private var accent: Color { scheme == .dark ? Color(red: 0.28, green: 0.80, blue: 0.77) : Color(red: 0.0, green: 0.40, blue: 0.42) }
    private var filtered: [Entry] { lens.history.filter { search.isEmpty || $0.source.localizedCaseInsensitiveContains(search) || $0.translation.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        VStack(spacing: 0) {
            header
            navigation
            Group {
                switch page {
                case .translate: translator
                case .history: history
                case .learn: learning
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .frame(minWidth: 340, minHeight: 380)
        .onChange(of: lens.opacity) { _, value in lens.panel?.alphaValue = reduceTransparency ? 1 : value }
        .onChange(of: reduceTransparency) { _, value in lens.panel?.alphaValue = value ? 1 : lens.opacity }
        .onAppear {
            if reduceTransparency { lens.panel?.alphaValue = 1 }
            if CommandLine.arguments.contains("--settings-preview") { DispatchQueue.main.async { preferences = true } }
        }
        .onExitCommand { lens.armed = false; editing = false }
        .onChange(of: lens.input) { _, _ in page = .translate }
        .translationTask(lens.configuration) { session in
            let source = lens.input, language = lens.target
            do {
                let result = try await session.translate(source)
                if lens.input == source && lens.target == language { lens.record(result.targetText, source: source, language: language) }
            } catch { lens.output = "Translation unavailable: \(error.localizedDescription). Check installed language packs." }
        }
    }
    private var header: some View {
        HStack(spacing: 9) {
            Image(systemName: "character.bubble.fill")
                .font(.system(size: 18, weight: .medium)).foregroundStyle(accent)
                .frame(width: 34, height: 34).background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text("Mandarin Lens").font(.system(size: 14, weight: .semibold))
                Text(lens.armed ? "Ready. Click a word." : "A little understanding, always close.")
                    .font(.system(size: 10)).foregroundStyle(lens.armed ? accent : .secondary)
            }
            Spacer(minLength: 3)
            Button { lens.armed.toggle() } label: { Image(systemName: lens.armed ? "cursorarrow.click.2" : "cursorarrow.click").foregroundStyle(lens.armed ? accent : Color.secondary).frame(width: 24, height: 28) }
                .buttonStyle(.plain).help(lens.armed ? "Cancel word lookup" : "Look up a word").accessibilityLabel(lens.armed ? "Cancel word lookup" : "Look up a word")
            Button { preferences.toggle() } label: { Image(systemName: "slider.horizontal.3").frame(width: 28, height: 28) }
                .buttonStyle(.plain).help("Note settings").accessibilityLabel("Note settings")
                .popover(isPresented: $preferences, arrowEdge: .bottom) { settings }
        }.padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 14)
    }
    private var navigation: some View {
        HStack(spacing: 4) {
            ForEach(LensPage.allCases, id: \.self) { item in
                Button { page = item } label: {
                    Label(item.rawValue, systemImage: item.symbol).font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .foregroundStyle(page == item ? Color.primary : Color.secondary)
                        .background(page == item ? Color(nsColor: .controlBackgroundColor) : .clear, in: RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain).accessibilityAddTraits(page == item ? .isSelected : [])
            }
        }.padding(4).background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16).padding(.bottom, 12)
    }
    private var translator: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { lens.captureSelection() } label: { Label("Selected text", systemImage: "text.cursor") }.help("Select text in another app, then press Control–Shift–T")
                    Spacer()
                    Menu {
                        Button("Word under pointer") { lens.armed = true }
                        Button("Selected text   ⌃⇧T") { lens.captureSelection() }
                        Divider()
                        Button("Screen area…   ⌃⇧S") { lens.captureScreen(entireDisplay: false) }
                        Button("Entire display") { lens.captureScreen(entireDisplay: true) }
                    } label: { Label(lens.capturing ? "Reading screen…" : "Capture", systemImage: "viewfinder") }.menuStyle(.borderlessButton).fixedSize().disabled(lens.capturing)
                }.font(.system(size: 11, weight: .medium)).buttonStyle(.plain).foregroundStyle(accent)
                if lens.input.isEmpty && lens.output != "Select text, then arm lookup and click it." {
                    Text(lens.output).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    caption("AUTO DETECT")
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 10)).foregroundStyle(.tertiary)
                    Menu {
                        Button("English") { lens.target = "en" }
                        Button("Tiếng Việt") { lens.target = "vi" }
                        Button("Polski") { lens.target = "pl" }
                    } label: { HStack(spacing: 5) { Text(languageName(lens.target)); Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold)) }.font(.system(size: 11, weight: .semibold)) }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Translation language")
                }
                ZStack(alignment: .topLeading) {
                    if lens.input.isEmpty { Text("A word, a thought, a sentence…").foregroundStyle(.tertiary).padding(.top, 7).padding(.leading, 4).allowsHitTesting(false) }
                    TextEditor(text: $lens.input).font(.system(size: 16)).scrollContentBackground(.hidden)
                        .frame(height: 76).focused($editing).accessibilityLabel("Text to translate")
                }
                HStack {
                    if !lens.input.isEmpty {
                        Button("Clear") { lens.input = ""; lens.output = "Select text, then arm lookup and click it." }.buttonStyle(.plain).foregroundStyle(.secondary).font(.caption)
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
                        Text("Tap \(lens.trigger) and click a word. Select a sentence with ⌃⇧T, or capture text anywhere on screen.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                        Button(lens.armed ? "Cancel lookup" : "Look up a word") { lens.armed.toggle() }.buttonStyle(.bordered).controlSize(.small)
                    }.padding(.vertical, 14)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { caption("TRANSLATION"); Spacer(); if lens.output == "Translating…" { ProgressView().controlSize(.mini) } }
                        Text(lens.output).font(.system(size: 19, weight: .medium, design: .rounded)).textSelection(.enabled).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading)
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
                            Button { lens.input = entry.source; lens.output = entry.translation; lens.target = entry.language; page = .translate } label: {
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
    private var learning: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if lens.answer.isEmpty {
                        Image(systemName: "sparkle").font(.system(size: 26, weight: .light)).foregroundStyle(accent).padding(.top, 12)
                        Text("Make the words yours.").font(.system(size: 19, weight: .medium, design: .rounded))
                        Text("Ask for a meaning, a natural reply, or a sentence you could use today.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
                        ForEach(["Practise my recent words", "Give me an everyday example", "Explain my latest translation"], id: \.self) { prompt in
                            Button { lens.question = prompt; lens.chat() } label: { HStack { Text(prompt); Spacer(); Image(systemName: "arrow.up.left") }.font(.system(size: 11)).padding(.vertical, 5) }.buttonStyle(.plain).foregroundStyle(accent)
                        }
                    } else {
                        Label("YOUR LANGUAGE COMPANION", systemImage: "sparkle").font(.system(size: 9, weight: .semibold)).tracking(0.7).foregroundStyle(accent)
                        Text(.init(lens.answer)).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                        if lens.busy { ProgressView().controlSize(.small) }
                        Text("AI can make mistakes. Check unfamiliar meanings.").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
            }
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    TextField("Ask about your words…", text: $lens.question, axis: .vertical).lineLimit(1...3).textFieldStyle(.plain).font(.system(size: 12)).onSubmit { lens.chat() }
                    Button { if lens.busy { lens.process?.terminate() } else { lens.chat() } } label: { Image(systemName: lens.busy ? "stop.fill" : "arrow.up").font(.system(size: 11, weight: .bold)).frame(width: 26, height: 26).foregroundStyle(.white).background(accent, in: Circle()) }.buttonStyle(.plain).accessibilityLabel(lens.busy ? "Stop answer" : "Send question").disabled(!lens.busy && lens.question.isEmpty)
                }.padding(10).background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(contrast == .increased ? 0.5 : 0.12)))
                HStack { Text("Uses your 8 most recent translations"); Spacer(); if !lens.answer.isEmpty { Button("New question") { lens.question = ""; lens.answer = "" }.buttonStyle(.plain).disabled(lens.busy) } }.font(.system(size: 9)).foregroundStyle(.secondary)
            }.padding(.horizontal, 16).padding(.bottom, 12)
        }
    }
    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(accent).frame(width: 4, height: 4)
            Text("On this Mac").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "circle.lefthalf.filled").foregroundStyle(.secondary)
            Slider(value: $lens.opacity, in: 0.35...1).controlSize(.mini).frame(width: 70).accessibilityLabel("Note opacity").disabled(reduceTransparency)
            TextField("Opacity", value: Binding(get: { Int((reduceTransparency ? 1 : lens.opacity) * 100) }, set: { lens.opacity = Double(min(100, max(35, $0))) / 100 }), format: .number)
                .font(.system(size: 10)).monospacedDigit().frame(width: 34).textFieldStyle(.roundedBorder).controlSize(.mini).disabled(reduceTransparency).accessibilityLabel("Opacity percentage, 35 to 100")
            Text("%").font(.system(size: 9)).foregroundStyle(.secondary)
        }.padding(.horizontal, 18).padding(.vertical, 10).background(Color.primary.opacity(0.025))
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Make yourself at home.").font(.system(size: 15, weight: .semibold, design: .rounded))
            Picker("Lookup key", selection: $lens.trigger) { ForEach(["Control", "Option", "Command"], id: \.self) { Text($0) } }
            Text("Tap the key, then click a word in another app.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("Note opacity").font(.system(size: 12, weight: .medium))
            Slider(value: $lens.opacity, in: 0.35...1).disabled(reduceTransparency).accessibilityLabel("Note opacity")
            Text(reduceTransparency ? "Reduced Transparency is enabled in macOS." : "Use the footer slider or type a percentage from 35 to 100.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Label("Word lookup access", systemImage: "cursorarrow.click").font(.system(size: 12, weight: .medium))
            Text("Allow Accessibility so Lens can read the word you choose.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button("Allow access…") { lens.permission() }.controlSize(.small)
            Divider()
            Text("Your note stays above other windows. Close it anytime and reopen it from the menu bar.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(20).frame(width: 260)
    }
    private func caption(_ text: String) -> some View { Text(text).font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(.secondary) }
    private func languageName(_ code: String) -> String { code == "vi" ? "Tiếng Việt" : code == "pl" ? "Polski" : "English" }
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
                VStack(alignment: .leading, spacing: 2) { Text("Mandarin Lens").font(.system(size: 13, weight: .semibold)); Text("Your words, always close.").font(.system(size: 10)).foregroundStyle(.secondary) }
            }
            Button { lens.show() } label: { Label("Open floating note", systemImage: "rectangle.on.rectangle").frame(maxWidth: .infinity).padding(.vertical, 4) }.buttonStyle(.borderedProminent).tint(.teal)
            Button { lens.armed.toggle() } label: { HStack { Label(lens.armed ? "Cancel lookup" : "Look up a word", systemImage: "cursorarrow.click"); Spacer(); Text(lens.trigger).font(.caption).foregroundStyle(.secondary) } }.buttonStyle(.plain)
            Menu("Capture text") {
                Button("Selected text   ⌃⇧T") { lens.captureSelection() }
                Button("Screen area…   ⌃⇧S") { lens.captureScreen(entireDisplay: false) }
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
