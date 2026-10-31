import AppKit
import Combine
import UniformTypeIdentifiers

struct LensNote: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = ""
    var body = ""
    var created = Date()
    var modified = Date()
    var pinned = false
    var deletedAt: Date?
    var displayTitle: String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let first = body.split(separator: "\n").first.map(String.init)?.trimmingCharacters(in: CharacterSet(charactersIn: "# ")) ?? ""
        return first.isEmpty ? "Untitled note" : String(first.prefix(60))
    }
    var preview: String { let original = body.components(separatedBy: "## Translation\n").first ?? body; return String(original.prefix(100)).replacingOccurrences(of: "\n",with: " ") }
    var wordCount: Int { WordTools.tokens(body).count }
}
enum NoteTemplate: String, CaseIterable {
    case blank = "Blank note", checklist = "Checklist", journal = "Daily journal", prompt = "Writing prompt"
    var title: String { switch self { case .blank: ""; case .checklist: "Today’s checklist"; case .journal: "Daily journal"; case .prompt: "Writing practice" } }
    var text: String { switch self {
    case .blank: ""
    case .checklist: "- [ ] Review a word\n- [ ] Write one sentence\n- [ ] Say it aloud\n"
    case .journal: "## Today\n\n\n## A word I used\n\n\n## Tomorrow\n\n"
    case .prompt: "## Writing prompt\n\n"+(Self.prompts.randomElement() ?? Self.prompts[0])+"\n\n## My answer\n\n"
    } }
    private static let prompts = ["Describe your ideal weekend in three sentences.","Write a café order and a polite follow-up question.","Tell a friend about a small thing you enjoyed today.","Describe a place without naming it. Can someone guess it?","Write a three-line conversation using your newest saved word."]
}
@MainActor final class NotepadStore: ObservableObject {
    @Published private(set) var notes: [LensNote] = []
    @Published var selectedID: UUID?
    @Published private(set) var status = "Saved on this Mac"
    private let url: URL
    private var damaged = false
    private var dirty = false
    private var saveTask: Task<Void,Never>?
    var canEdit: Bool { !damaged }
    var active: [LensNote] { notes.filter { $0.deletedAt == nil }.sorted { $0.pinned != $1.pinned ? $0.pinned : $0.modified > $1.modified } }
    var trash: [LensNote] { notes.filter { $0.deletedAt != nil }.sorted { $0.modified > $1.modified } }
    var selected: LensNote? { notes.first { $0.id == selectedID } }
    init(url: URL) {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do { notes = try JSONDecoder().decode([LensNote].self,from: Data(contentsOf: url)) }
            catch { damaged = true; status = "Notes could not be read. The original file is preserved." }
        }
        selectedID = active.first?.id
    }
    @discardableResult func create(_ template: NoteTemplate = .blank,title: String? = nil,body: String? = nil) -> UUID? {
        guard !damaged else { return nil }
        let note = LensNote(title: title ?? template.title,body: body ?? template.text)
        dirty = true; notes.insert(note,at: 0); selectedID = note.id; flush(); return note.id
    }
    func update(_ id: UUID,title: String? = nil,body: String? = nil) {
        guard !damaged, let i = notes.firstIndex(where: { $0.id == id && $0.deletedAt == nil }) else { return }
        if let title { notes[i].title = title }; if let body { notes[i].body = body }; notes[i].modified = Date()
        dirty = true; status = "Saving…"; saveTask?.cancel()
        saveTask = Task { [weak self] in do { try await Task.sleep(for: .milliseconds(350)); try Task.checkCancellation(); self?.flush() } catch {} }
    }
    func pin(_ id: UUID) { guard let i = notes.firstIndex(where: { $0.id == id }), !damaged else { return }; notes[i].pinned.toggle(); dirty = true; flush() }
    func moveToTrash(_ id: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == id }), !damaged else { return }
        dirty = true; notes[i].deletedAt = Date(); notes[i].modified = Date(); if selectedID == id { selectedID = active.first?.id }; flush()
    }
    func restore(_ id: UUID) { guard let i = notes.firstIndex(where: { $0.id == id }), !damaged else { return }; dirty = true; notes[i].deletedAt = nil; notes[i].modified = Date(); selectedID = id; flush() }
    func append(_ text: String,to id: UUID) { guard let note = notes.first(where: { $0.id == id }) else { return }; update(id,body: note.body+(note.body.isEmpty ? "" : "\n\n")+text) }
    func toggleTask(_ id: UUID,line: Int) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        var lines = note.body.components(separatedBy: "\n"); guard lines.indices.contains(line) else { return }
        if lines[line].hasPrefix("- [ ] ") { lines[line] = "- [x] "+lines[line].dropFirst(6) }
        else if lines[line].hasPrefix("- [x] ") { lines[line] = "- [ ] "+lines[line].dropFirst(6) }
        else { return }; update(id,body: lines.joined(separator: "\n"))
    }
    func flush() {
        saveTask?.cancel(); saveTask = nil; guard !damaged, dirty else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),withIntermediateDirectories: true,attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(notes).write(to: url,options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600],ofItemAtPath: url.path); dirty = false; status = "Saved on this Mac"
        } catch { status = "Could not save this note. Keep this window open and try again." }
    }
    func export(_ id: UUID) {
        guard let note = notes.first(where: { $0.id == id }) else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]; panel.nameFieldStringValue = String(note.displayTitle.prefix(80)).replacingOccurrences(of: "/",with: "-")+".md"
        guard panel.runModal() == .OK, let target = panel.url else { return }
        do { try ("# "+note.displayTitle+"\n\n"+note.body).write(to: target,atomically: true,encoding: .utf8) }
        catch { status = "Could not export this note. Try another location." }
    }
}
