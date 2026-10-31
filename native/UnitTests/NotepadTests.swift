import Foundation
import Testing
@testable import MandarinLens

@Test @MainActor func notesKeepUnicodeEditsPinsAndRecoverDeletedContent() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("notes.json"), store = NotepadStore(url: root.appendingPathComponent("notes.json"))
    let first = try #require(store.create(title: "中文 café",body: "你好\nCảm ơn\nDziękuję"))
    let second = try #require(store.create(.journal))
    store.pin(first); store.update(first,body: "你好\nCảm ơn\nDziękuję\nLatest edit"); store.flush()
    #expect(store.active.first?.id == first)
    store.moveToTrash(first)
    store.update(first,body: "Must not overwrite a deleted note")
    #expect(store.trash.first?.body.hasSuffix("Latest edit") == true)
    store.restore(first)
    let reopened = NotepadStore(url: url)
    #expect(reopened.active.first?.id == first && reopened.active.first?.pinned == true)
    #expect(reopened.active.count == 2 && reopened.notes.first(where: { $0.id == second }) != nil)
}
@Test @MainActor func rapidNoteChangesFlushLatestTextAndTasksRoundTrip() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appendingPathComponent("notes.json"), store = NotepadStore(url: root.appendingPathComponent("notes.json"))
    let id = try #require(store.create(.checklist))
    store.update(id,title: "First"); store.update(id,title: "Latest")
    store.toggleTask(id,line: 0); store.flush()
    let reopened = NotepadStore(url: url)
    #expect(reopened.selected?.title == "Latest")
    #expect(reopened.selected?.body.hasPrefix("- [x] Review a word\n- [ ] Write one sentence") == true)
    reopened.toggleTask(id,line: 0); reopened.flush()
    #expect(NotepadStore(url: url).selected?.body.hasPrefix("- [ ] Review a word") == true)
}
@Test @MainActor func damagedNotesArePreservedAndFailedSaveCanRetry() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
    let damaged = root.appendingPathComponent("damaged.json"), original = Data("not valid JSON".utf8)
    try original.write(to: damaged)
    let unreadable = NotepadStore(url: damaged)
    #expect(unreadable.create() == nil); unreadable.flush()
    #expect(try Data(contentsOf: damaged) == original)
    let blocker = root.appendingPathComponent("blocker")
    try Data("file".utf8).write(to: blocker)
    let target = blocker.appendingPathComponent("notes.json"), store = NotepadStore(url: target)
    let id = try #require(store.create(title: "Keep me",body: "Unsaved content"))
    #expect(store.status.hasPrefix("Could not"))
    #expect(store.selected?.id == id && store.selected?.body == "Unsaved content")
    try FileManager.default.removeItem(at: blocker); store.flush()
    #expect(store.status == "Saved on this Mac" && NotepadStore(url: target).selected?.body == "Unsaved content")
}
@Test @MainActor func translationNotesKeepBothLanguagesExampleAndAvoidDoubleCapture() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let lens = Lens(dataDirectory: root)
    lens.sourceChoice = "en"; lens.input = "Control"; lens.capturedContext = "Control the volume, please."; lens.target = "zh-Hans"; lens.translate()
    lens.completeTranslation("控制",request: try #require(lens.translationRequest))
    lens.usageExample = ChineseExample(word: "控制",chinese: "请控制你的声音。",english: "Please control your voice.")
    lens.saveTranslationToNote(); lens.saveTranslationToNote()
    #expect(lens.notepad.notes.count == 1)
    let note = try #require(lens.notepad.selected)
    #expect(note.body.contains("## Original\nControl\n\n## Translation\n控制"))
    #expect(note.body.contains("kòng zhì") && note.body.contains("Please control your voice.") && note.body.contains("Control the volume, please."))
    #expect(!note.preview.contains("控制"))
    #expect(lens.input == "Control" && lens.output == "控制")
}
