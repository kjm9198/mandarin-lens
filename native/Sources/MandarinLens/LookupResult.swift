import SwiftUI
import AppKit

@MainActor private final class LookupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
extension Lens {
    func showPopup() {
        translationHost = "lookup"; popupVisible = true
        if popup == nil {
            let p = LookupPanel(contentRect: .zero,styleMask: [.borderless,.nonactivatingPanel],backing: .buffered,defer: false)
            p.title = "Kamihi Lens result"; p.level = .statusBar; p.hidesOnDeactivate = false; p.isReleasedWhenClosed = false
            p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true; p.animationBehavior = .none
            p.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
            p.contentView = NSHostingView(rootView: LookupResult().environmentObject(self)); popup = p
        }
        let screen = NSScreen.screens.first { $0.frame.contains(popupAnchor) } ?? NSScreen.main
        guard let screen else { return }
        let size = CGSize(width: 370,height: captureKind == .area ? 410 : 510)
        popup?.setContentSize(size)
        popup?.setFrame(LookupGeometry.panelFrame(pointer: popupAnchor,size: size,visible: screen.visibleFrame),display: true)
        NSApp.unhideWithoutActivation(); popup?.orderFrontRegardless()
    }
    func dismissPopup(cancelTranslation: Bool = true) {
        popup?.orderOut(nil); popupVisible = false
        if cancelTranslation && translationHost == "lookup" { invalidateTranslation() }
    }
    func saveCurrentWord() {
        guard canSaveWord else { return }
        if target.hasPrefix("zh"), let chinese = ChineseStudy.headword(output) {
            _ = vocabulary.save(term: chinese,meaning: input,target: TranslationSource.language(text: input,context: capturedContext,preference: sourceChoice),sourceLanguage: target,context: capturedContext,usageExample: usageExample)
        } else { _ = vocabulary.save(term: input,meaning: output,target: target,context: capturedContext,usageExample: usageExample) }
    }
    func lookupCharacter(_ character: String) {
        let context = capturedContext.isEmpty ? input : capturedContext
        invalidateTranslation(); input = character; capturedContext = context; captureKind = .word
        translate()
    }
    func toggleFavorite(_ id: UUID) {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return }
        history[index].favorite.toggle(); persist()
    }
}
struct LookupResult: View {
    @EnvironmentObject var lens: Lens
    @Environment(\.colorSchemeContrast) private var contrast
    @StateObject private var speaker = WordSpeaker()
    @State private var copied = false
    private var chinese: String {
        if lens.input.range(of: "\\p{Han}",options: .regularExpression) != nil { return lens.input }
        return lens.canSaveWord && lens.output.range(of: "\\p{Han}",options: .regularExpression) != nil ? lens.output : ""
    }
    var body: some View {
        VStack(alignment: .leading,spacing: 14) {
            HStack {
                Label(lens.captureKind.title,systemImage: lens.captureKind.symbol).font(.caption.weight(.semibold)).foregroundStyle(.teal)
                Spacer()
                LanguagePicker(target: $lens.target).labelsHidden().frame(width: 110).controlSize(.small).accessibilityLabel("Translate into")
                Button { lens.selection.cancel() } label: { Image(systemName: "xmark").frame(width: 24,height: 24) }.buttonStyle(.plain).accessibilityLabel("Dismiss result").help("Escape")
            }
            ScrollView {
                VStack(alignment: .leading,spacing: 10) {
                    Text(lens.input).font(lens.captureKind == .word && !lens.target.hasPrefix("zh") ? .system(size: 27,weight: .semibold) : .system(size: 17,weight: .medium)).textSelection(.enabled).fixedSize(horizontal: false,vertical: true)
                    if lens.output == "Translating…" { HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Translating…").foregroundStyle(.secondary) }.font(.callout) }
                    else { Text(lens.output).font(.system(size: lens.target.hasPrefix("zh") && lens.captureKind == .word ? 29 : 18)).textSelection(.enabled).fixedSize(horizontal: false,vertical: true) }
                    if !chinese.isEmpty && lens.captureKind != .area { Text(chinese.applyingTransform(.mandarinToLatin,reverse: false) ?? "").font(.system(size: 15,weight: .medium)).foregroundStyle(.teal).textSelection(.enabled) }
                    CurrentChineseExample(lens: lens)
                    if lens.captureKind == .word, !chinese.isEmpty, chinese.count <= 8 {
                        DisclosureGroup("Explore characters") { HStack(spacing: 8) {
                            ForEach(Array(chinese.enumerated()),id: \.offset) { _, character in
                                if String(character).range(of: "\\p{Han}",options: .regularExpression) != nil {
                                    Button { lens.lookupCharacter(String(character)) } label: {
                                        VStack(spacing: 4) { Text(String(character)).font(.title2); Text(String(character).applyingTransform(.mandarinToLatin,reverse: false) ?? "").font(.caption2).foregroundStyle(.secondary) }.padding(.horizontal,9).padding(.vertical,7).background(.quaternary,in: RoundedRectangle(cornerRadius: 9))
                                    }.buttonStyle(.plain).help("Look up this character")
                                }
                            }
                        } }.font(.caption).padding(.top,3)
                    }
                }.frame(maxWidth: .infinity,alignment: .leading)
            }
            LookupActions(lens: lens,vocabulary: lens.vocabulary,speaker: speaker,copied: $copied)
            HStack {
                Button("Open Kamihi Lens") { lens.showWorkspace() }.buttonStyle(.plain).font(.caption.weight(.medium)).foregroundStyle(.teal)
                Spacer()
                Text(lens.historyStatus.isEmpty ? "Saved in History" : "History not saved").font(.caption2).foregroundStyle(.secondary).opacity(lens.canSaveWord ? 1 : 0).accessibilityHidden(!lens.canSaveWord)
                if !lens.canSaveWord && lens.output != "Translating…" { Button("Retry") { lens.translate() }.font(.caption) }
            }
        }.padding(17).frame(width: 370,height: lens.captureKind == .area ? 410 : 510)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(nsColor: .windowBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(contrast == .increased ? 0.5 : 0.12),lineWidth: 1))
            .tint(.teal).modifier(TranslationWork(lens: lens,host: "lookup"))
            .onChange(of: lens.input) { _,_ in copied = false }
            .onExitCommand { lens.selection.cancel() }
    }
}
private struct LookupActions: View {
    @ObservedObject var lens: Lens
    @ObservedObject var vocabulary: Vocabulary
    @ObservedObject var speaker: WordSpeaker
    @Binding var copied: Bool
    private var saved: Bool {
        let translatedChinese = lens.target.hasPrefix("zh") && ChineseStudy.headword(lens.output) != nil
        let term = translatedChinese ? lens.output : lens.input
        let target = translatedChinese ? TranslationSource.language(text: lens.input,context: lens.capturedContext,preference: lens.sourceChoice) : lens.target
        return vocabulary.words.contains { $0.term.compare(term,options: .caseInsensitive) == .orderedSame && $0.targetLanguage == target }
    }
    var body: some View {
        VStack(alignment: .leading,spacing: 6) {
            HStack(spacing: 10) {
                Button { speaker.speak(lens.chineseWord ?? lens.input,language: lens.chineseWord != nil ? "zh-Hans" : TranslationSource.language(text: lens.input,context: lens.capturedContext,preference: lens.sourceChoice)) } label: { Image(systemName: "speaker.wave.2") }.accessibilityLabel("Listen to selected text").help("Listen")
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lens.output,forType: .string); copied = true } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }.disabled(!lens.canSaveWord).accessibilityLabel("Copy translation").help("Copy translation")
                Spacer()
                Button { lens.saveCurrentWord() } label: { Label(saved ? "Saved" : (lens.captureKind == .word ? "Save word" : "Save phrase"),systemImage: saved ? "bookmark.fill" : "bookmark") }.disabled(saved || !lens.canSaveWord).buttonStyle(.borderedProminent)
            }.controlSize(.small)
            if vocabulary.status.hasPrefix("Could not") { Text(vocabulary.status).font(.caption2).foregroundStyle(.red) }
            if !speaker.status.isEmpty { Text(speaker.status).font(.caption2).foregroundStyle(.secondary) }
        }
    }
}
