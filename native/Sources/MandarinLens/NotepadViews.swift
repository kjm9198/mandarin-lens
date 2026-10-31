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
private enum NoteEditorMode: String, CaseIterable { case write = "Write", preview = "Preview", recall = "Recall" }
private struct NotepadEditor: View {
    @ObservedObject var lens: Lens
    @ObservedObject var notes: NotepadStore
    let noteID: UUID
    @State private var mode = NoteEditorMode.write
    @State private var revealed = false
    @FocusState private var writing: Bool
    private var note: LensNote? { notes.notes.first { $0.id == noteID } }
    var body: some View {
        if let note {
            VStack(alignment: .leading,spacing: 14) {
                if note.deletedAt != nil {
                    Text("This note is in Recently deleted.").font(.system(size: 13)).foregroundStyle(.secondary)
                    Button("Restore note") { notes.restore(note.id) }.buttonStyle(LensButtonStyle(prominent: true))
                    ScrollView { NoteMarkdown(text: note.body) }
                } else {
                    HStack(spacing: 12) {
                        Picker("Note view",selection: $mode) { Text("Write").tag(NoteEditorMode.write); Text("Preview").tag(NoteEditorMode.preview); if note.body.contains("## Translation\n") { Text("Recall").tag(NoteEditorMode.recall) } }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 230)
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
                    if mode == .write {
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
                .onAppear { writing = true }
                .onChange(of: noteID) { _,_ in mode = .write; revealed = false; writing = true }
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
                } else if line.hasPrefix("## ") { Text(String(line.dropFirst(3))).font(.system(size: 18,weight: .semibold)).padding(.top,8).textSelection(.enabled) }
                else if line.hasPrefix("# ") { Text(String(line.dropFirst(2))).font(.system(size: 24,weight: .semibold)).padding(.top,10).textSelection(.enabled) }
                else { Text((try? AttributedString(markdown: line)) ?? AttributedString(line)).font(.system(size: 14)).lineSpacing(4).textSelection(.enabled).frame(minHeight: line.isEmpty ? 8 : nil) }
            }
        }.frame(maxWidth: .infinity,alignment: .leading)
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
        var body = "## Original\n"+input+"\n\n## Translation\n"+output
        if output.range(of: "\\p{Han}",options: .regularExpression) != nil { body += "\n\n"+(output.applyingTransform(.mandarinToLatin,reverse: false) ?? "") }
        if let example = usageExample { body += "\n\n## Example sentence\n"+example.chinese+"\n\n"+example.pinyin+"\n\n"+example.english }
        if !capturedContext.isEmpty && capturedContext != input { body += "\n\n## Source context\n"+capturedContext }
        if notepad.create(title: title,body: body) != nil { notedTranslationID = request.id }
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
