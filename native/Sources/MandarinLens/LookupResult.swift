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
        let size = CGSize(width: 400,height: 500)
        popup?.setContentSize(size)
        popup?.setFrame(LookupGeometry.panelFrame(pointer: popupAnchor,size: size,visible: screen.visibleFrame),display: true)
        NSApp.unhideWithoutActivation(); popup?.orderFrontRegardless()
    }
    func dismissPopup(cancelTranslation: Bool = true) {
        clearHighlight()
        speaker.stop(); popup?.orderOut(nil); popupVisible = false
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
    @State private var copied = false
    private var chinese: String {
        if lens.input.range(of: "\\p{Han}",options: .regularExpression) != nil { return lens.input }
        return lens.canSaveWord && lens.output.range(of: "\\p{Han}",options: .regularExpression) != nil ? lens.output : ""
    }
    var body: some View {
        VStack(alignment: .leading,spacing: 16) {
            HStack {
                Label(lens.captureKind.title,systemImage: lens.captureKind.symbol).font(.system(size: 11,weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                LanguagePicker(target: $lens.target).labelsHidden().frame(width: 110).controlSize(.small).accessibilityLabel("Translate into")
                Button { lens.selection.cancel() } label: { Image(systemName: "xmark").frame(width: 24,height: 24) }.buttonStyle(.plain).accessibilityLabel("Dismiss result").help("Escape")
            }
            ScrollView {
                VStack(alignment: .leading,spacing: 10) {
                    Text("Original").font(.system(size: 10,weight: .medium)).foregroundStyle(.secondary)
                    Text(lens.input).font(lens.captureKind == .word && !lens.target.hasPrefix("zh") ? .system(size: 36,weight: .medium) : .system(size: 15,weight: .regular)).textSelection(.enabled).fixedSize(horizontal: false,vertical: true)
                    Text("Translation").font(.system(size: 10,weight: .medium)).foregroundStyle(.secondary).padding(.top,4)
                    if lens.output == "Translating…" { HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Translating…").foregroundStyle(.secondary) }.font(.callout) }
                    else { Text(lens.output).font(.system(size: lens.target.hasPrefix("zh") && lens.captureKind == .word ? 38 : 19)).textSelection(.enabled).fixedSize(horizontal: false,vertical: true) }
                    if !chinese.isEmpty && lens.captureKind != .area { Text(chinese.applyingTransform(.mandarinToLatin,reverse: false) ?? "").font(.system(size: 15,weight: .medium)).foregroundStyle(Color.lensAccent).textSelection(.enabled) }
                    if lens.secondaryTarget != "none" && lens.secondaryTarget != lens.target && !lens.secondaryOutput.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Also translated into \(languageName(lens.secondaryTarget))").font(.system(size: 10,weight: .medium)).foregroundStyle(.secondary).padding(.top, 4)
                            if lens.secondaryOutput == "Translating…" {
                                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Translating…").foregroundStyle(.secondary) }.font(.caption)
                            } else {
                                Text(lens.secondaryOutput).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.lensAccent).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    CurrentChineseExample(lens: lens)
                }.frame(maxWidth: .infinity,alignment: .leading)
            }
            Divider().overlay(Color.lensLine.opacity(0.3))
            LookupActions(lens: lens,vocabulary: lens.vocabulary,notepad: lens.notepad,speaker: lens.speaker,copied: $copied)
            HStack {
                Button("Open Kamihi Lens") { lens.showWorkspace() }.buttonStyle(.plain).font(.system(size: 11,weight: .medium)).foregroundStyle(Color.lensAccent)
                if let chinese = lens.chineseWord, chinese.count <= 8 {
                    Menu { ForEach(Array(chinese.enumerated()),id: \.offset) { _,character in
                        if String(character).range(of: "\\p{Han}",options: .regularExpression) != nil { Button(String(character)+" · "+(String(character).applyingTransform(.mandarinToLatin,reverse: false) ?? "")) { lens.lookupCharacter(String(character)) } }
                    } } label: { Text("字").frame(width: 24,height: 24) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Explore characters")
                }
                Spacer()
                Text(lens.historyStatus.isEmpty ? "Saved in History" : "History not saved").font(.caption2).foregroundStyle(.secondary).opacity(lens.canSaveWord ? 1 : 0).accessibilityHidden(!lens.canSaveWord)
                if !lens.canSaveWord && lens.output != "Translating…" { Button("Retry") { lens.translate() }.font(.caption) }
            }
        }.padding(20).frame(width: 400,height: 500)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.lensCanvas))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(contrast == .increased ? Color.primary.opacity(0.65) : Color.lensLine,lineWidth: 1))
            .tint(.lensAccent).modifier(TranslationWork(lens: lens,host: "lookup"))
            .onChange(of: lens.input) { _,_ in copied = false; lens.speaker.stop() }.onChange(of: lens.target) { _,_ in lens.speaker.stop() }.onDisappear { lens.speaker.stop() }
            .onExitCommand { lens.selection.cancel() }
    }
}
private struct LookupActions: View {
    @ObservedObject var lens: Lens
    @ObservedObject var vocabulary: Vocabulary
    @ObservedObject var notepad: NotepadStore
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
            HStack(spacing: 8) {
                let source = TranslationSource.language(text: lens.input,context: lens.capturedContext,preference: lens.sourceChoice)
                let originalPlaying = speaker.isPlaying(lens.input,language: source)
                let translationPlaying = speaker.isPlaying(lens.output,language: lens.target)
                Button { speaker.speak(lens.input,language: source) } label: { LensActionLabel(title: originalPlaying ? "Stop" : "Original",symbol: originalPlaying ? "stop.fill" : "play.fill") }.buttonStyle(LensActionStyle()).accessibilityLabel(originalPlaying ? "Stop original audio" : "Listen to original")
                Button { speaker.speak(lens.output,language: lens.target) } label: { LensActionLabel(title: translationPlaying ? "Stop" : "Translated",symbol: translationPlaying ? "stop.fill" : "play.fill") }.buttonStyle(LensActionStyle()).disabled(!lens.canSaveWord).accessibilityLabel(translationPlaying ? "Stop translation audio" : "Listen to translation")
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lens.output,forType: .string); copied = true } label: { LensActionLabel(title: copied ? "Copied" : "Copy",symbol: copied ? "checkmark" : "doc.on.doc") }.buttonStyle(LensActionStyle()).disabled(!lens.canSaveWord).accessibilityLabel("Copy translation")
                Button { lens.saveCurrentWord() } label: { LensActionLabel(title: saved ? "Saved" : "Save",symbol: saved ? "bookmark.fill" : "bookmark") }.buttonStyle(LensActionStyle(prominent: true)).disabled(saved || !lens.canSaveWord).accessibilityLabel(saved ? "Saved word" : lens.captureKind == .word ? "Save word" : "Save phrase")
                let noted = lens.notedTranslationID == lens.translatedRequest?.id && lens.notedTranslationID != nil && notepad.status == "Saved on this Mac"
                Button { lens.saveTranslationToNote() } label: { LensActionLabel(title: noted ? "Noted" : "Notepad",symbol: noted ? "checkmark" : "note.text.badge.plus") }.buttonStyle(LensActionStyle()).disabled(noted || !lens.canSaveWord).accessibilityLabel(noted ? "Added to Notepad" : "Save translation to Notepad")
            }
            if notepad.status.hasPrefix("Could not") { Text(notepad.status).font(.caption2).foregroundStyle(.red) }
            if vocabulary.status.hasPrefix("Could not") { Text(vocabulary.status).font(.caption2).foregroundStyle(.red) }
            if !speaker.status.isEmpty { Text(speaker.status).font(.caption2).foregroundStyle(.secondary) }
        }
    }
}
