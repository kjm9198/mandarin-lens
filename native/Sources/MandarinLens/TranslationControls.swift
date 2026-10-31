import SwiftUI
import Translation

enum TranslationEngine {
    static func configuration(source: String?,target: String,quality: String = "fast") -> TranslationSession.Configuration {
        let source = source.flatMap { $0 == "und" ? nil : Locale.Language(identifier: $0) }
        if #available(macOS 26.4,*) { return .init(source: source,target: Locale.Language(identifier: target),preferredStrategy: quality == "fast" ? .lowLatency : .highFidelity) }
        return .init(source: source,target: Locale.Language(identifier: target))
    }
    static func availability(quality: String) -> LanguageAvailability {
        if #available(macOS 26.4,*) { return .init(preferredStrategy: quality == "fast" ? .lowLatency : .highFidelity) }
        return .init()
    }
}
struct SourceLanguagePicker: View {
    @Binding var source: String
    var body: some View {
        Picker("Translate from",selection: $source) {
            Text("Auto detect").tag("auto")
            Text("English").tag("en")
            Text("Polski").tag("pl")
            Text("Tiếng Việt").tag("vi")
            Text("中文").tag("zh-Hans")
            Text("繁體中文").tag("zh-Hant")
        }
    }
}
private struct LanguagePreparation: Identifiable {
    let id = UUID()
    let configuration: TranslationSession.Configuration
    init(source: String,target: String,quality: String) {
        configuration = TranslationEngine.configuration(source: source,target: target,quality: quality)
    }
}
struct TranslationLanguageBar: View {
    @ObservedObject var lens: Lens
    @State private var availability: LanguageAvailability.Status?
    @State private var preparation: LanguagePreparation?
    @State private var preparationError = ""
    private var source: String? {
        guard lens.sourceChoice == "auto" else { return lens.sourceChoice }
        guard !lens.input.isEmpty else { return nil }
        let detected = TranslationSource.language(text: lens.input,context: lens.capturedContext)
        return detected == "und" ? nil : detected
    }
    private var pair: String { (source ?? "auto")+"|"+lens.target+"|"+lens.translationQuality }
    var body: some View {
        VStack(alignment: .leading,spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading,spacing: 4) { Text("From").font(.system(size: 10)).foregroundStyle(.secondary); SourceLanguagePicker(source: $lens.sourceChoice).labelsHidden().accessibilityLabel("Translate from") }.frame(maxWidth: .infinity,alignment: .leading)
                Button { lens.swapTranslationLanguages() } label: { Image(systemName: "arrow.left.arrow.right").frame(width: 24,height: 30) }.buttonStyle(.plain).foregroundStyle(Color.lensAccent).disabled(!lens.canSaveWord || source == lens.target || source == nil).accessibilityLabel("Swap languages").help("Translate the result back into the source language")
                VStack(alignment: .leading,spacing: 4) { Text("To").font(.system(size: 10)).foregroundStyle(.secondary); LanguagePicker(target: $lens.target).labelsHidden().accessibilityLabel("Translate into") }.frame(maxWidth: .infinity,alignment: .leading)
            }.controlSize(.small)
            HStack(alignment: .firstTextBaseline,spacing: 7) {
                Image(systemName: "bolt").foregroundStyle(Color.lensAccent)
                Menu {
                    Picker("Translation mode",selection: $lens.translationQuality) { Text("Natural wording").tag("natural"); Text("Fast response").tag("fast") }
                } label: { Text(lens.translationQuality == "fast" ? "Apple · Fast" : "Apple · Natural").fontWeight(.medium) }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Translation mode").help("Natural requests more fluent Apple Intelligence translations on supported Macs and languages, with system fallback. Fast uses traditional translation models. Qwen is used separately for study examples and tutoring.")
                Spacer(minLength: 0)
                if preparation != nil { ProgressView().controlSize(.mini); Text("Preparing…") }
                else if availability == .installed { Label("Ready offline",systemImage: "checkmark.circle").foregroundStyle(Color.lensAccent) }
                else if availability == .supported, let source {
                    Button("Prepare languages") { preparationError = ""; preparation = LanguagePreparation(source: source,target: lens.target,quality: lens.translationQuality) }.buttonStyle(.plain).foregroundStyle(Color.lensAccent)
                } else if availability == .unsupported && source != lens.target { Text("Pair unavailable").foregroundStyle(.secondary) }
                else { Text("On this Mac").foregroundStyle(.secondary) }
            }.font(.system(size: 11))
            if lens.sourceChoice == "auto", !lens.input.isEmpty, WordTools.tokens(lens.input).count <= 2, lens.input.range(of: "^[A-Za-z0-9’' -]+$",options: .regularExpression) != nil { Text("For a short Polish or Vietnamese word, choose its language under From.").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true) }
            if !preparationError.isEmpty { Text(preparationError).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true) }
        }.lensSurface(padding: 14)
        .task(id: pair+"|"+String(lens.canSaveWord)) {
            availability = nil; preparation = nil; preparationError = ""
            guard let source, source != lens.target else { return }
            if source.hasPrefix("zh") && lens.target.hasPrefix("zh") { availability = .installed; return }
            let result = await TranslationEngine.availability(quality: lens.translationQuality).status(from: Locale.Language(identifier: source),to: Locale.Language(identifier: lens.target))
            guard !Task.isCancelled else { return }; availability = result
        }
        .background {
            if let preparation {
                Color.clear.frame(width: 0,height: 0).translationTask(preparation.configuration) { session in
                    do { try await session.prepareTranslation(); guard self.preparation?.id == preparation.id, !Task.isCancelled else { return }; availability = .installed; self.preparation = nil }
                    catch { guard self.preparation?.id == preparation.id, !Task.isCancelled else { return }; preparationError = "Languages could not be prepared. Check your connection and try again."; self.preparation = nil }
                }.id(preparation.id).accessibilityHidden(true)
            }
        }
    }
}
