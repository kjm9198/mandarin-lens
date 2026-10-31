import SwiftUI
import AppKit

struct DictionaryDetail: View {
    let word: SavedWord
    let ask: ()->Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speaker = WordSpeaker.shared
    @State private var copied = false
    var body: some View {
        VStack(spacing: 0) {
            HStack { Label("My dictionary",systemImage: "character.book.closed").font(.system(size: 12,weight: .medium)).foregroundStyle(.secondary); Spacer(); Button("Done") { dismiss() }.buttonStyle(LensButtonStyle(small: true)) }.padding(22)
            Divider()
            ScrollView {
                VStack(alignment: .leading,spacing: 22) {
                    VStack(alignment: .leading,spacing: 12) { Text(word.term).font(.system(size: 46,weight: .medium)).textSelection(.enabled); if !word.pronunciation.isEmpty { Text(word.pronunciation).font(.system(size: 19)).foregroundStyle(Color.lensAccent).textSelection(.enabled).help("System transliteration; pronunciation depends on context") }; Text(word.meaning).font(.system(size: 21)).textSelection(.enabled) }
                    HStack { Label(word.category.rawValue,systemImage: "tag"); Spacer(); Text(word.created,style: .date) }.font(.system(size: 11)).foregroundStyle(.secondary)
                    if let example = word.usageExample { Divider(); ChineseExampleContent(example: example) }
                    if !word.example.isEmpty { DisclosureGroup("Source context") { Text(word.example).font(.system(size: 13)).foregroundStyle(.secondary).textSelection(.enabled).lineSpacing(4).padding(.top,10) }.font(.system(size: 12)).foregroundStyle(.secondary) }
                    if !speaker.status.isEmpty { Text(speaker.status).font(.system(size: 12)).foregroundStyle(.secondary) }
                }.padding(28).frame(maxWidth: .infinity,alignment: .leading)
            }
            Divider()
            HStack(spacing: 10) {
                Button { speaker.speak(word.term,language: PracticeDeck.language(word)) } label: { Label(speaker.isPlaying(word.term,language: PracticeDeck.language(word)) ? "Stop" : "Listen",systemImage: speaker.isPlaying(word.term,language: PracticeDeck.language(word)) ? "stop.fill" : "play.fill") }.buttonStyle(LensButtonStyle(small: true))
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(word.term+(word.pronunciation.isEmpty ? "" : " · "+word.pronunciation)+" — "+word.meaning,forType: .string); copied = true } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }.buttonStyle(LensButtonStyle(small: true)).accessibilityLabel(copied ? "Copied" : "Copy entry")
                Spacer()
                Button("Example & usage") { dismiss(); ask() }.buttonStyle(LensButtonStyle(prominent: true,small: true))
            }.padding(20)
        }.frame(width: 530,height: 600).background(Color.lensCanvas).tint(.lensAccent).onExitCommand { dismiss() }.onDisappear { speaker.stop() }
    }
}
