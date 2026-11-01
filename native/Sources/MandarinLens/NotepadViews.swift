import SwiftUI
import AppKit

struct NotepadView: View {
    @ObservedObject var lens: Lens
    @ObservedObject var notes: NotepadStore
    var floating = false
    @State private var search = ""
    @State private var showTrash = false
    @State private var focus = false
    @State private var showList = false
    private var filtered: [LensNote] { (showTrash ? notes.trash : notes.active).filter { search.isEmpty || $0.displayTitle.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        GeometryReader { geometry in
            let columns = geometry.size.width >= 650 && !focus
            VStack(alignment: .leading,spacing: 18) {
                if !floating { LensPageHeading(title: "Notepad",detail: "Capture a thought, keep a translation, or practise writing.") }
                HStack(spacing: 10) {
                    if !columns { Button { showList.toggle(); focus = false } label: { Image(systemName: "sidebar.left") }.buttonStyle(LensButtonStyle(small: true)).accessibilityLabel("Show note list") }
                    Button { create(.blank) } label: { Label("New note",systemImage: "plus") }.buttonStyle(LensButtonStyle(prominent: true,small: true)).keyboardShortcut("n",modifiers: .command).disabled(!notes.canEdit)
                    Menu("Templates") { ForEach([NoteTemplate.checklist,.journal,.prompt],id: \.self) { template in Button(template.rawValue) { create(template) } } }.fixedSize().font(.system(size: 12)).disabled(!notes.canEdit)
                    Spacer(minLength: 0)
                    if !floating { Button { lens.showNotepad() } label: { Image(systemName: "rectangle.on.rectangle") }.buttonStyle(LensButtonStyle(small: true)).accessibilityLabel("Open floating notepad").help(lens.notesShortcutStatus) }
                    Button { focus.toggle(); showList = false } label: { Image(systemName: focus ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") }.buttonStyle(LensButtonStyle(small: true)).accessibilityLabel(focus ? "Leave writing focus" : "Focus on writing")
                }
                if !notes.canEdit { Text(notes.status).font(.system(size: 12)).foregroundStyle(.red).fixedSize(horizontal: false,vertical: true) }
                HStack(alignment: .top,spacing: 20) {
                    if columns || (showList && !focus) {
                        VStack(alignment: .leading,spacing: 12) {
                            LensSearchField(placeholder: "Search notes",text: $search)
                            HStack { Text(showTrash ? "Recently deleted" : "\(notes.active.count) \(notes.active.count == 1 ? "note" : "notes")").font(.system(size: 11)).foregroundStyle(.secondary); Spacer(); Button { let next = !showTrash; notes.selectedID = (next ? notes.trash : notes.active).first?.id; showTrash = next } label: { Image(systemName: showTrash ? "arrow.left" : "trash") }.buttonStyle(.plain).accessibilityLabel(showTrash ? "Back to notes" : "Recently deleted notes") }
                            ScrollView {
                                LazyVStack(spacing: 5) {
                                    ForEach(filtered) { note in
                                        Button { notes.selectedID = note.id; if !columns { showList = false } } label: {
                                            VStack(alignment: .leading,spacing: 6) {
                                                HStack { Text(note.displayTitle).font(.system(size: 13,weight: .medium)).lineLimit(1); Spacer(minLength: 0); if note.pinned { Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(Color.lensAccent) } }
                                                Text(note.body.isEmpty ? "Start writing…" : note.preview).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                                            }.padding(11).frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
                                        }.buttonStyle(LensRowStyle(selected: notes.selectedID == note.id)).accessibilityLabel(note.displayTitle)
                                    }
                                }
                                if filtered.isEmpty { Text(showTrash ? "No deleted notes" : search.isEmpty ? "No notes yet" : "No matching notes").font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical,24) }
                            }
                        }.frame(width: columns ? 210 : nil).frame(maxWidth: columns ? 210 : .infinity)
                    }
                    if columns || !showList || focus {
                        if let note = notes.selected { NotepadEditor(lens: lens,notes: notes,noteID: note.id) }
                        else if showTrash { LensEmptyState(title: "Recently deleted",detail: "Choose a note to restore it. Your deleted notes stay on this Mac.",symbol: "trash") }
                        else { VStack { LensEmptyState(title: "A place for your next thought",detail: "Create a blank note, choose a template, or keep a translation from its Notepad button.",symbol: "note.text"); Button("Create a note") { create(.blank) }.buttonStyle(LensButtonStyle(prominent: true)).disabled(!notes.canEdit); Spacer() }.frame(maxWidth: .infinity,alignment: .leading) }
                    }
                }.frame(maxHeight: .infinity)
            }.padding(floating ? 20 : 26).background(Color.lensCanvas)
        }.tint(.lensAccent).onDisappear { notes.flush() }.onChange(of: notes.selected?.deletedAt) { previous,current in if previous != nil && current == nil && notes.selected != nil { showTrash = false } }
    }
    private func create(_ template: NoteTemplate) { if notes.create(template) != nil { showTrash = false; showList = false; search = "" } }
}
private enum NoteEditorMode: String, CaseIterable {
    case cards = "Cards"
    case write = "Write"
    case preview = "Preview"
    case recall = "Recall"
}

struct NoteStructuredSections {
    var original: String = ""
    var translation: String = ""
    var pinyin: String = ""
    var secondTranslation: String = ""
    var secondLanguage: String = ""
    var secondPinyin: String = ""
    var exampleSentence: (chinese: String, pinyin: String, english: String)? = nil
    var sourceContext: String = ""
    var myNotes: String = ""
    var extraSections: [(title: String, body: String)] = []

    var isTranslationNote: Bool {
        !original.isEmpty || !translation.isEmpty
    }

    static func parse(body: String) -> NoteStructuredSections {
        var sections = NoteStructuredSections()
        let rawSections = body.components(separatedBy: "\n## ")
        for (idx, raw) in rawSections.enumerated() {
            let sectionText = (idx == 0 && raw.hasPrefix("## ")) ? String(raw.dropFirst(3)) : raw
            let lines = sectionText.components(separatedBy: "\n")
            guard let headerLine = lines.first else { continue }
            let title = headerLine.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
            let contentLines = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanContent = contentLines.replacingOccurrences(of: "\n---\n", with: "\n").trimmingCharacters(in: CharacterSet(charactersIn: "-\n \t"))

            let lowerTitle = title.lowercased()
            if lowerTitle.hasPrefix("original") {
                sections.original = cleanContent
            } else if lowerTitle.hasPrefix("translation") {
                let parts = cleanContent.components(separatedBy: "\n\n")
                sections.translation = parts.first ?? ""
                if parts.count > 1 {
                    sections.pinyin = parts.dropFirst().joined(separator: "\n\n")
                }
            } else if lowerTitle.hasPrefix("second translation") {
                if let open = title.firstIndex(of: "("), let close = title.firstIndex(of: ")"), open < close {
                    sections.secondLanguage = String(title[title.index(after: open)..<close])
                } else {
                    sections.secondLanguage = "2nd Language"
                }
                let parts = cleanContent.components(separatedBy: "\n\n")
                sections.secondTranslation = parts.first ?? ""
                if parts.count > 1 {
                    sections.secondPinyin = parts.dropFirst().joined(separator: "\n\n")
                }
            } else if lowerTitle.hasPrefix("source context") || lowerTitle.hasPrefix("context") {
                sections.sourceContext = cleanContent
            } else if lowerTitle.hasPrefix("example sentence") || lowerTitle.hasPrefix("example") {
                let parts = cleanContent.components(separatedBy: "\n\n")
                let chinese = parts.indices.contains(0) ? parts[0] : ""
                let pinyin = parts.indices.contains(1) ? parts[1] : ""
                let english = parts.indices.contains(2) ? parts[2] : ""
                sections.exampleSentence = (chinese, pinyin, english)
            } else if lowerTitle.hasPrefix("my notes") || lowerTitle.hasPrefix("notes") {
                sections.myNotes = cleanContent
            } else if !title.isEmpty && !cleanContent.isEmpty {
                sections.extraSections.append((title, cleanContent))
            }
        }
        return sections
    }

    func serialize(originalBody: String) -> String {
        var body = "## Original\n\(original)\n\n## Translation\n\(translation)"
        if !pinyin.isEmpty {
            body += "\n\n\(pinyin)"
        }
        if !secondTranslation.isEmpty {
            body += "\n\n---\n## Second Translation (\(secondLanguage))\n\(secondTranslation)"
            if !secondPinyin.isEmpty {
                body += "\n\n\(secondPinyin)"
            }
        }
        if let ex = exampleSentence {
            body += "\n\n---\n## Example sentence\n\(ex.chinese)\n\n\(ex.pinyin)\n\n\(ex.english)"
        }
        if !sourceContext.isEmpty {
            body += "\n\n---\n## Source context\n\(sourceContext)"
        }
        for extra in extraSections {
            body += "\n\n---\n## \(extra.title)\n\(extra.body)"
        }
        if !myNotes.isEmpty {
            body += "\n\n---\n## My Notes\n\(myNotes)"
        }
        return body
    }
}

private struct NoteCardsView: View {
    @ObservedObject var lens: Lens
    let note: LensNote
    let onUpdateBody: (String) -> Void
    @State private var sections: NoteStructuredSections
    @State private var myNotesText: String
    @State private var copiedOriginal = false
    @State private var copiedTranslation = false
    @State private var copiedSecond = false

    init(lens: Lens, note: LensNote, onUpdateBody: @escaping (String) -> Void) {
        self.lens = lens
        self.note = note
        self.onUpdateBody = onUpdateBody
        let parsed = NoteStructuredSections.parse(body: note.body)
        _sections = State(initialValue: parsed)
        _myNotesText = State(initialValue: parsed.myNotes)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Card 1: Original Text
                cardContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        cardHeader(title: "ORIGINAL", icon: "character.textbox", color: .secondary) {
                            HStack(spacing: 6) {
                                Button {
                                    let lang = TranslationSource.language(text: sections.original, preference: lens.sourceChoice)
                                    lens.speaker.speak(sections.original, language: lang)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 11))
                                }
                                .buttonStyle(LensButtonStyle(small: true))
                                .help("Listen to original")

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(sections.original, forType: .string)
                                    copiedOriginal = true
                                } label: {
                                    Image(systemName: copiedOriginal ? "checkmark" : "doc.on.doc").font(.system(size: 11))
                                }
                                .buttonStyle(LensButtonStyle(small: true))
                                .help("Copy original text")
                            }
                        }

                        Text(sections.original.isEmpty ? "No original text" : sections.original)
                            .font(.system(size: 17, weight: .regular))
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Card 2: Translation
                cardContainer {
                    VStack(alignment: .leading, spacing: 12) {
                        cardHeader(title: "TRANSLATION (\(languageName(lens.target).uppercased()))", icon: "globe", color: Color.lensAccent) {
                            HStack(spacing: 6) {
                                Button {
                                    lens.speaker.speak(sections.translation, language: lens.target)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 11))
                                }
                                .buttonStyle(LensButtonStyle(small: true))
                                .help("Listen to translation")

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(sections.translation, forType: .string)
                                    copiedTranslation = true
                                } label: {
                                    Image(systemName: copiedTranslation ? "checkmark" : "doc.on.doc").font(.system(size: 11))
                                }
                                .buttonStyle(LensButtonStyle(small: true))
                                .help("Copy translation")
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(sections.translation.isEmpty ? "No translation" : sections.translation)
                                .font(.system(size: sections.translation.range(of: "\\p{Han}", options: .regularExpression) != nil ? 28 : 20, weight: .semibold))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)

                            if !sections.pinyin.isEmpty {
                                Text(sections.pinyin)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Color.lensAccent)
                                    .textSelection(.enabled)
                            }
                        }

                        // Secondary Translation (if available)
                        if !sections.secondTranslation.isEmpty {
                            Divider().padding(.vertical, 4)

                            cardHeader(title: "SECOND TRANSLATION (\(sections.secondLanguage.uppercased()))", icon: "character.bubble.fill", color: .teal) {
                                HStack(spacing: 6) {
                                    Button {
                                        let lang = sections.secondLanguage.lowercased().contains("pol") ? "pl" : "en"
                                        lens.speaker.speak(sections.secondTranslation, language: lang)
                                    } label: {
                                        Image(systemName: "speaker.wave.2.fill").font(.system(size: 11))
                                    }
                                    .buttonStyle(LensButtonStyle(small: true))

                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(sections.secondTranslation, forType: .string)
                                        copiedSecond = true
                                    } label: {
                                        Image(systemName: copiedSecond ? "checkmark" : "doc.on.doc").font(.system(size: 11))
                                    }
                                    .buttonStyle(LensButtonStyle(small: true))
                                }
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(sections.secondTranslation)
                                    .font(.system(size: 19, weight: .medium))
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)

                                if !sections.secondPinyin.isEmpty {
                                    Text(sections.secondPinyin)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.lensAccent)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }

                // Card 3: Example Sentence (if present)
                if let ex = sections.exampleSentence {
                    cardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            cardHeader(title: "EXAMPLE SENTENCE", icon: "text.quote", color: .secondary) {
                                Button {
                                    lens.speaker.speak(ex.chinese, language: "zh-Hans")
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 11))
                                }
                                .buttonStyle(LensButtonStyle(small: true))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(ex.chinese).font(.system(size: 17, weight: .medium)).textSelection(.enabled)
                                if !ex.pinyin.isEmpty {
                                    Text(ex.pinyin).font(.system(size: 13)).foregroundStyle(Color.lensAccent).textSelection(.enabled)
                                }
                                if !ex.english.isEmpty {
                                    Text(ex.english).font(.system(size: 13)).foregroundStyle(.secondary).textSelection(.enabled)
                                }
                            }
                        }
                    }
                }

                // Card 4: Source Context (if present)
                if !sections.sourceContext.isEmpty {
                    cardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            cardHeader(title: "SOURCE CONTEXT", icon: "viewfinder", color: .secondary) { EmptyView() }

                            HStack(alignment: .top, spacing: 10) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color.lensAccent)
                                    .frame(width: 3)
                                Text(sections.sourceContext)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Card 5: Personal Study Notes
                cardContainer {
                    VStack(alignment: .leading, spacing: 10) {
                        cardHeader(title: "MY NOTES", icon: "pencil.and.outline", color: Color.lensAccent) {
                            HStack(spacing: 6) {
                                Button("+ Checklist") {
                                    if !myNotesText.hasSuffix("\n") && !myNotesText.isEmpty { myNotesText += "\n" }
                                    myNotesText += "- [ ] "
                                    saveNotes()
                                }
                                .buttonStyle(LensButtonStyle(small: true))

                                Button("+ Bullet") {
                                    if !myNotesText.hasSuffix("\n") && !myNotesText.isEmpty { myNotesText += "\n" }
                                    myNotesText += "- "
                                    saveNotes()
                                }
                                .buttonStyle(LensButtonStyle(small: true))
                            }
                        }

                        TextEditor(text: $myNotesText)
                            .font(.system(size: 14))
                            .lineSpacing(4)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 110)
                            .padding(8)
                            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lensLine.opacity(0.4), lineWidth: 1))
                            .onChange(of: myNotesText) { _, _ in
                                saveNotes()
                            }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .onChange(of: note.body) { _, newBody in
            let parsed = NoteStructuredSections.parse(body: newBody)
            sections = parsed
            if myNotesText != parsed.myNotes {
                myNotesText = parsed.myNotes
            }
        }
    }

    private func saveNotes() {
        sections.myNotes = myNotesText
        let serialized = sections.serialize(originalBody: note.body)
        onUpdateBody(serialized)
    }

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.lensSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.lensLine.opacity(0.6), lineWidth: 1))
    }

    private func cardHeader<Trailing: View>(title: String, icon: String, color: Color, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(color)
            }
            Spacer()
            trailing()
        }
    }
}

private struct NotepadEditor: View {
    @ObservedObject var lens: Lens
    @ObservedObject var notes: NotepadStore
    let noteID: UUID
    @State private var mode = NoteEditorMode.cards
    @State private var revealed = false
    @FocusState private var writing: Bool
    private var note: LensNote? { notes.notes.first { $0.id == noteID } }

    private var hasTranslationSections: Bool {
        guard let note else { return false }
        return note.body.contains("## Original") || note.body.contains("## Translation")
    }

    var body: some View {
        if let note {
            VStack(alignment: .leading,spacing: 14) {
                if note.deletedAt != nil {
                    Text("This note is in Recently deleted.").font(.system(size: 13)).foregroundStyle(.secondary)
                    Button("Restore note") { notes.restore(note.id) }.buttonStyle(LensButtonStyle(prominent: true))
                    ScrollView { NoteMarkdown(text: note.body) }
                } else {
                    HStack(spacing: 12) {
                        Picker("Note view",selection: $mode) {
                            if hasTranslationSections {
                                Text("Cards").tag(NoteEditorMode.cards)
                            }
                            Text("Write").tag(NoteEditorMode.write)
                            Text("Preview").tag(NoteEditorMode.preview)
                            if note.body.contains("## Translation\n") {
                                Text("Recall").tag(NoteEditorMode.recall)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: hasTranslationSections ? 290 : 230)

                        Spacer(minLength: 0)
                        Button { notes.pin(note.id) } label: { Image(systemName: note.pinned ? "pin.fill" : "pin") }.buttonStyle(.plain).foregroundStyle(note.pinned ? Color.lensAccent : .secondary).accessibilityLabel(note.pinned ? "Unpin note" : "Pin note")
                        Menu {
                            Button("Copy note") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(note.body,forType: .string) }
                            Button("Export Markdown…") { notes.export(note.id) }
                            Button("Translate note") { lens.translateNote(note) }.disabled(note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Divider()
                            Button("Append checklist") { notes.append(NoteTemplate.checklist.text,to: note.id) }
                            Button("Append writing prompt") { notes.append(NoteTemplate.prompt.text,to: note.id) }
                            Divider()
                            Button("Move to Recently deleted",role: .destructive) { notes.moveToTrash(note.id) }
                        } label: { Image(systemName: "ellipsis").frame(width: 28,height: 28) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Note actions")
                    }
                    TextField("Untitled note",text: Binding(get: { notes.notes.first { $0.id == noteID }?.title ?? "" },set: { notes.update(noteID,title: $0) })).textFieldStyle(.plain).font(.system(size: 23,weight: .semibold)).accessibilityLabel("Note title")
                    Divider().overlay(Color.lensLine.opacity(0.3))

                    if mode == .cards && hasTranslationSections {
                        NoteCardsView(lens: lens, note: note) { newBody in
                            notes.update(noteID, body: newBody)
                        }
                    } else if mode == .write {
                        TextEditor(text: Binding(get: { notes.notes.first { $0.id == noteID }?.body ?? "" },set: { notes.update(noteID,body: $0) })).font(.system(size: 15)).lineSpacing(5).scrollContentBackground(.hidden).accessibilityLabel("Note text").focused($writing).frame(maxWidth: .infinity,maxHeight: .infinity)
                    } else if mode == .preview {
                        ScrollView { NoteMarkdown(text: note.body,toggle: { notes.toggleTask(note.id,line: $0) }).frame(maxWidth: .infinity,alignment: .leading) }
                    } else {
                        let parts = note.body.components(separatedBy: "## Translation\n")
                        ScrollView { VStack(alignment: .leading,spacing: 20) { Text("Recall the translation before revealing it.").font(.system(size: 12)).foregroundStyle(.secondary); NoteMarkdown(text: parts.first ?? ""); Button(revealed ? "Hide translation" : "Reveal translation") { revealed.toggle() }.buttonStyle(LensButtonStyle(prominent: true)); if revealed { NoteMarkdown(text: "## Translation\n"+parts.dropFirst().joined(separator: "## Translation\n")) } }.frame(maxWidth: .infinity,alignment: .leading) }
                    }
                }
                HStack { Text(notes.status).lineLimit(2); if notes.status.hasPrefix("Could not") { Button("Retry save") { notes.flush() } }; Spacer(); Text("\(note.wordCount) words").monospacedDigit() }.font(.system(size: 10)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity,maxHeight: .infinity,alignment: .topLeading)
                .onAppear {
                    if hasTranslationSections {
                        mode = .cards
                    } else {
                        mode = .write
                    }
                    writing = mode == .write
                }
                .onChange(of: noteID) { _,_ in
                    if hasTranslationSections {
                        mode = .cards
                    } else {
                        mode = .write
                    }
                    revealed = false
                    writing = mode == .write
                }
                .onChange(of: mode) { _,value in writing = value == .write }
        }
    }
}

private struct NoteMarkdown: View {
    let text: String
    var toggle: ((Int)->Void)?
    var body: some View {
        LazyVStack(alignment: .leading,spacing: 10) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()),id: \.offset) { index,line in
                if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") {
                    Button { toggle?(index) } label: { HStack(alignment: .top,spacing: 9) { Image(systemName: line.hasPrefix("- [x]") ? "checkmark.square.fill" : "square").foregroundStyle(Color.lensAccent); Text(String(line.dropFirst(6))).strikethrough(line.hasPrefix("- [x]")); Spacer(minLength: 0) }.frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle()) }.buttonStyle(.plain).disabled(toggle == nil).accessibilityLabel("Task \(index+1): "+String(line.dropFirst(6)))
                } else if line.trimmingCharacters(in: .whitespaces) == "---" || line.trimmingCharacters(in: .whitespaces) == "***" {
                    Divider().overlay(Color.lensLine.opacity(0.4)).padding(.vertical, 6)
                } else if line.hasPrefix("## ") {
                    let sectionTitle = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    HStack(spacing: 6) {
                        Image(systemName: iconForSection(sectionTitle))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.lensAccent)
                        Text(sectionTitle)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .padding(.top, 12)
                    .textSelection(.enabled)
                } else if line.hasPrefix("# ") {
                    Text(String(line.dropFirst(2))).font(.system(size: 24,weight: .semibold)).padding(.top,10).textSelection(.enabled)
                } else {
                    Text((try? AttributedString(markdown: line)) ?? AttributedString(line)).font(.system(size: 14)).lineSpacing(4).textSelection(.enabled).frame(minHeight: line.isEmpty ? 8 : nil)
                }
            }
        }.frame(maxWidth: .infinity,alignment: .leading)
    }

    private func iconForSection(_ title: String) -> String {
        let lower = title.lowercased()
        if lower.hasPrefix("original") { return "character.textbox" }
        if lower.hasPrefix("second translation") { return "character.bubble.fill" }
        if lower.hasPrefix("translation") { return "globe" }
        if lower.hasPrefix("source context") || lower.hasPrefix("context") { return "viewfinder" }
        if lower.hasPrefix("example") { return "text.quote" }
        if lower.hasPrefix("my notes") || lower.hasPrefix("notes") { return "pencil.and.outline" }
        return "bookmark.fill"
    }
}

extension Lens {
    func toggleNotepad() {
        if notepadPanel?.isVisible == true { hideNotepad() }
        else { showNotepad(restoreWorkspace: false) }
    }
    func hideNotepad() {
        notepadPanel?.endEditing(for: nil); notepadPanel?.makeFirstResponder(nil)
        notepad.flush(); notepadPanel?.orderOut(nil)
        if notepadReturnsToWorkspace, panel?.isVisible == true { panel?.makeKeyAndOrderFront(nil) }
        else { NSApp.hide(nil) }
    }
    func showNotepad(restoreWorkspace: Bool = true) {
        notepadReturnsToWorkspace = restoreWorkspace
        if notepad.selected == nil || notepad.selected?.deletedAt != nil { notepad.selectedID = notepad.active.first?.id; if notepad.selectedID == nil { notepad.create() } }
        if notepadPanel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 240,y: 180,width: 590,height: 620),styleMask: [.titled,.closable,.resizable,.miniaturizable],backing: .buffered,defer: false)
            panel.title = "Kamihi Notepad"; panel.isReleasedWhenClosed = false; panel.hidesOnDeactivate = false; panel.level = .floating; panel.minSize = NSSize(width: 390,height: 440)
            panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView: NotepadView(lens: self,notes: notepad,floating: true).onExitCommand { [weak self] in self?.hideNotepad() })
            panel.center(); notepadPanel = panel
        }
        NSApp.setActivationPolicy(.regular); NSApp.unhide(nil); notepadPanel?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func saveTranslationToNote() {
        guard canSaveWord, let request = translatedRequest else { return }
        if notedTranslationID == request.id { notepad.flush(); return }
        let title = String(input.split(separator: "\n").first.map(String.init)?.prefix(60) ?? "Translation")
        var body = "## Original\n\(input)\n\n## Translation\n\(output)"
        if output.range(of: "\\p{Han}", options: .regularExpression) != nil {
            body += "\n\n" + (output.applyingTransform(.mandarinToLatin, reverse: false) ?? "")
        }
        if secondaryTarget != "none" && secondaryTarget != target && !secondaryOutput.isEmpty && secondaryOutput != "Translating…" {
            body += "\n\n---\n## Second Translation (\(languageName(secondaryTarget)))\n\(secondaryOutput)"
            if secondaryOutput.range(of: "\\p{Han}", options: .regularExpression) != nil {
                body += "\n\n" + (secondaryOutput.applyingTransform(.mandarinToLatin, reverse: false) ?? "")
            }
        }
        if let example = usageExample {
            body += "\n\n---\n## Example sentence\n\(example.chinese)\n\n\(example.pinyin)\n\n\(example.english)"
        }
        if !capturedContext.isEmpty && capturedContext != input {
            body += "\n\n---\n## Source context\n\(capturedContext)"
        }
        body += "\n\n---\n## My Notes\n- "
        if notepad.create(title: title, body: body) != nil { notedTranslationID = request.id }
    }
    func translateNote(_ note: LensNote) {
        speaker.stop(); input = String(note.body.prefix(16000)); captureKind = .typed; showWorkspace(); workspacePage = "Translate"; translate()
    }
}

struct CaptureNoteButton: View {
    @ObservedObject var lens: Lens
    @ObservedObject var notes: NotepadStore
    private var captured: Bool { lens.notedTranslationID == lens.translatedRequest?.id && lens.notedTranslationID != nil && notes.status == "Saved on this Mac" }
    var body: some View {
        Button { lens.saveTranslationToNote() } label: { LensActionLabel(title: captured ? "Noted" : "Notepad",symbol: captured ? "checkmark" : "note.text.badge.plus") }.buttonStyle(LensActionStyle()).disabled(captured || !lens.canSaveWord).accessibilityLabel(captured ? "Added to Notepad" : "Save translation to Notepad").help(notes.status)
    }
}
