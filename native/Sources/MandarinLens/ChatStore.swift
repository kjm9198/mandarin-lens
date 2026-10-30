import Foundation
struct ChatMessage: Identifiable, Codable { var id = UUID(); let role: String; var text: String }
struct ChatConversation: Identifiable, Codable { var id = UUID(); var title = "New conversation"; var messages: [ChatMessage] = []; var updated = Date() }
@MainActor final class ChatStore: ObservableObject {
    @Published var conversations: [ChatConversation] = []
    @Published var currentID: UUID
    @Published var status = ""
    let url: URL
    private var damaged = false
    var messages: [ChatMessage] { conversations.first { $0.id == currentID }?.messages ?? [] }
    init(url: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Mandarin Lens/chats.json")) {
        self.url = url
        var loaded: [ChatConversation] = []
        if FileManager.default.fileExists(atPath: url.path) {
            do { loaded = try JSONDecoder().decode([ChatConversation].self, from: Data(contentsOf: url)) }
            catch { damaged = true; status = "Chat history could not be read. The original file is preserved." }
        }
        if loaded.isEmpty { loaded = [ChatConversation()] }
        conversations = loaded; currentID = loaded[0].id
    }
    func newConversation() { let chat = ChatConversation(); conversations.insert(chat, at: 0); currentID = chat.id; save() }
    @discardableResult func append(role: String, text: String) -> UUID {
        let message = ChatMessage(role: role, text: text)
        guard let i = conversations.firstIndex(where: { $0.id == currentID }) else { return message.id }
        conversations[i].messages.append(message)
        if role == "user" && conversations[i].messages.count == 1 { conversations[i].title = String(text.prefix(60)) }
        conversations[i].updated = Date(); save(); return message.id
    }
    func update(_ id: UUID, conversation: UUID, text: String, persist: Bool = true) {
        guard let i = conversations.firstIndex(where: { $0.id == conversation }), let j = conversations[i].messages.firstIndex(where: { $0.id == id }) else { return }
        conversations[i].messages[j].text = String(text.prefix(16000)); if persist { save() }
    }
    func save() {
        guard !damaged else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(conversations).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { status = "Could not save chat history: \(error.localizedDescription)" }
    }
}
