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
struct QuickLookup: View {
    @EnvironmentObject var lens: Lens
    var body: some View { QuickLookupContent().environmentObject(lens) }
}
private struct QuickLookupContent: View {
    @EnvironmentObject var lens: Lens
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TARGETED TEXT").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                LanguagePicker(target: $lens.target).labelsHidden().frame(width: 108).accessibilityLabel("Translate into")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    if !lens.input.isEmpty { Text(lens.input).font(.title3.weight(.semibold)).textSelection(.enabled) }
                    if lens.input.range(of: "\\p{Han}", options: .regularExpression) != nil { Text(lens.input.applyingTransform(.mandarinToLatin, reverse: false) ?? "").font(.caption).foregroundStyle(.secondary) }
                    if lens.output == "Translating…" { HStack { ProgressView().controlSize(.small); Text("Translating…").font(.callout) } }
                    else {
                        Text(lens.output).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        if lens.output.range(of: "\\p{Han}", options: .regularExpression) != nil { Text(lens.output.applyingTransform(.mandarinToLatin, reverse: false) ?? "").font(.caption).foregroundStyle(.secondary) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                QuickSave(vocabulary: lens.vocabulary, lens: lens)
                Spacer()
                Button("Retry") { lens.translate() }.disabled(lens.input.isEmpty)
            }.controlSize(.small)
            Divider()
            HStack {
                Button("Open full app") { lens.showWorkspace() }
                Spacer()
                Button("Compact") { lens.showWorkspace(compact: true) }
                Button { lens.dismissLookup() } label: { Image(systemName: "xmark") }.help("Dismiss (Escape)").accessibilityLabel("Dismiss lookup")
            }.font(.caption).buttonStyle(.plain)
        }.padding(14).frame(width: 340, height: 220).background(.background).tint(.teal)
            .modifier(TranslationWork(lens: lens, host: "quick"))
            .onExitCommand { lens.dismissLookup() }
    }
}
private struct QuickSave: View {
    @ObservedObject var vocabulary: Vocabulary
    @ObservedObject var lens: Lens
    @State private var saveError = ""
    private var saved: Bool { vocabulary.words.contains { $0.term.compare(lens.input, options: .caseInsensitive) == .orderedSame && $0.targetLanguage == lens.target } }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
        Button { if !vocabulary.save(term: lens.input, meaning: lens.output, target: lens.target) { saveError = vocabulary.status } else { saveError = "" } } label: { Label(saved ? "Saved" : "Save word", systemImage: saved ? "bookmark.fill" : "bookmark") }
            .disabled(saved || !lens.canSaveWord || lens.capturing).help("Save the exact targeted text and its translation")
        if !saveError.isEmpty { Text(saveError).font(.caption2).foregroundStyle(.red) }
        }
        .onChange(of: lens.input) { _, _ in saveError = "" }
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
                                Text(message.role == "user" ? "You" : "Mandarin Lens").font(.caption.weight(.semibold)).foregroundStyle(message.role == "user" ? Color.secondary : .teal)
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
