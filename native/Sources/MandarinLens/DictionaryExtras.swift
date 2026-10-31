import SwiftUI
import AppKit

struct DictionaryDetail: View {
    let word: SavedWord
    let ask: ()->Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = WordSpeaker()
    @State private var copied = false
    var body: some View {
        ScrollView { VStack(alignment: .leading,spacing: 19) {
            HStack { Label("My dictionary",systemImage: "character.book.closed").font(.caption.weight(.medium)).foregroundStyle(.teal); Spacer(); Button("Done") { dismiss() } }
            Text(word.term).font(.system(size: 38,weight: .semibold,design: .rounded)).textSelection(.enabled)
            if !word.pronunciation.isEmpty { Text(word.pronunciation).font(.title3).foregroundStyle(.teal).textSelection(.enabled).help("System transliteration; pronunciation can depend on context") }
            Text(word.meaning).font(.title3).textSelection(.enabled)
            HStack { Label(word.category.rawValue,systemImage: "tag"); Spacer(); Text(word.created,style: .date) }.font(.caption).foregroundStyle(.secondary)
            if !word.example.isEmpty { Divider(); Text("Where you found it").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Text(word.example).textSelection(.enabled).lineSpacing(4) }
            if let example = word.usageExample { ChineseExampleContent(example: example) }
            HStack(spacing: 12) {
                Button { speaker.speak(word.term,language: word.sourceLanguage) } label: { Label("Listen",systemImage: "speaker.wave.2") }
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(word.term + (word.pronunciation.isEmpty ? "" : " · " + word.pronunciation) + " — " + word.meaning,forType: .string); copied = true } label: { Label(copied ? "Copied" : "Copy entry",systemImage: copied ? "checkmark" : "doc.on.doc") }
                Spacer()
                Button("Example & usage") { dismiss(); ask() }.buttonStyle(.borderedProminent)
            }.controlSize(.small)
            if !speaker.status.isEmpty { Text(speaker.status).font(.caption).foregroundStyle(.secondary) }
        }.padding(26) }.frame(width: 530,height: 610).tint(.teal).onExitCommand { dismiss() }
    }
}
