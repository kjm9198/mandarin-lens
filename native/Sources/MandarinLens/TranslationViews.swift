import SwiftUI

struct TranslationWork: ViewModifier {
    @ObservedObject var lens: Lens
    let host: String
    func body(content: Content) -> some View {
        let capturedRequest = lens.translationRequest
        return content.translationTask(lens.translationHost == host ? lens.configuration : nil) { session in
            guard lens.translationHost == host, let request = capturedRequest else { return }
            await lens.performTranslation(session, request: request)
        }
    }
}
struct LanguagePicker: View {
    @Binding var target: String
    var body: some View {
        Picker("Translate into", selection: $target) { Text("English").tag("en"); Text("中文").tag("zh-Hans"); Text("繁體中文").tag("zh-Hant"); Text("Tiếng Việt").tag("vi"); Text("Polski").tag("pl") }
    }
}
struct ChatView: View {
    @ObservedObject var lens: Lens
    @ObservedObject var chats: ChatStore
    @State private var models = false
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Menu("Chat history") {
                    ForEach(chats.conversations) { chat in Button(chat.title) { lens.stopChat(); lens.chatGeneration = UUID(); lens.busy = false; chats.currentID = chat.id } }
                }.disabled(lens.busy)
                Spacer()
                Button("New chat") { lens.newChat() }.disabled(lens.busy)
            }.controlSize(.small)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if chats.messages.isEmpty { Text("Ask about a word, practise a reply, or explore a Chinese example.").foregroundStyle(.secondary).padding(.vertical, 20) }
                        ForEach(chats.messages) { message in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(message.role == "user" ? "You" : "Kamihi Lens").font(.caption.weight(.semibold)).foregroundStyle(message.role == "user" ? Color.secondary : .teal)
                                if message.text.isEmpty && lens.busy { HStack { ProgressView().controlSize(.small); Text("Preparing local model…").font(.callout).foregroundStyle(.secondary) } }
                                else {
                                    Group {
                                        if message.role == "user" { Text(message.text) }
                                        else { Text(.init(message.text.isEmpty ? "Response interrupted. Send another message to try again." : message.text)) }
                                    }.font(.body).textSelection(.enabled).lineSpacing(4)
                                }
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(message.role == "user" ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 10)).id(message.id)
                        }
                        Color.clear.frame(height: 1).id("end")
                    }
                }.onChange(of: chats.messages.last?.text) { _, _ in proxy.scrollTo("end", anchor: .bottom) }
            }
            if !chats.status.isEmpty { Text(chats.status).font(.caption).foregroundStyle(.secondary) }
            HStack(alignment: .bottom) {
                TextField("Ask about your words…", text: $lens.question, axis: .vertical).lineLimit(1...5).textFieldStyle(.roundedBorder).onSubmit { lens.chat() }.accessibilityLabel("Chat message")
                Button(lens.busy ? "Stop" : "Send") { if lens.busy { lens.stopChat() } else { lens.chat() } }.disabled(!lens.busy && lens.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).keyboardShortcut(.return, modifiers: .command)
            }
            HStack { Button("Local models & downloads…") { models = true }; Spacer(); Text("Local AI can make mistakes.").foregroundStyle(.secondary) }.font(.caption)
        }.padding(.horizontal, 18).padding(.bottom, 12).sheet(isPresented: $models) { ModelsView(models: lens.models) }
    }
}
