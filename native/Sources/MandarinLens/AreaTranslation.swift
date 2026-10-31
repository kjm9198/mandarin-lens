import SwiftUI
import Translation

struct AreaLine: Sendable { let index: Int; let text: String }
struct AreaTranslationJob: Identifiable {
    let id = UUID()
    let parent: UUID
    let source: String
    let target: String
    let lines: [AreaLine]
    let configuration: TranslationSession.Configuration
    init(parent: UUID,source: String,target: String,lines: [AreaLine]) {
        self.parent = parent; self.source = source; self.target = target; self.lines = lines
        configuration = .init(source: source == "und" ? nil : Locale.Language(identifier: source),target: Locale.Language(identifier: target))
    }
}
struct AreaTranslationPlan {
    let lines: [String]
    var immediate: [Int: String] = [:]
    var jobs: [AreaTranslationJob] = []
    init(request: TranslationRequest) {
        lines = request.text.components(separatedBy: "\n")
        var groups: [String: [AreaLine]] = [:]
        for (index,line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || line.rangeOfCharacter(from: .letters) == nil { immediate[index] = line; continue }
            let language = line.range(of: "\\p{Han}",options: .regularExpression) != nil ? "zh-Hans" : TranslationSource.language(text: line)
            if language == request.target { immediate[index] = line }
            else if language.hasPrefix("zh") && request.target.hasPrefix("zh") {
                let transform = StringTransform(request.target == "zh-Hant" ? "Simplified-Traditional" : "Traditional-Simplified")
                immediate[index] = line.applyingTransform(transform,reverse: false) ?? line
            } else { groups[language,default: []].append(AreaLine(index: index,text: line)) }
        }
        jobs = groups.sorted { $0.key < $1.key }.map { AreaTranslationJob(parent: request.id,source: $0.key,target: request.target,lines: $0.value) }
    }
    func combined(_ results: [Int: String]) -> String? {
        guard lines.indices.allSatisfy({ results[$0] != nil }) else { return nil }
        return lines.indices.map { results[$0] ?? "" }.joined(separator: "\n")
    }
}
struct AreaTranslationWorker: View {
    @ObservedObject var lens: Lens
    let job: AreaTranslationJob
    var body: some View {
        Color.clear.frame(width: 0,height: 0).accessibilityHidden(true)
            .translationTask(job.configuration) { session in await lens.performAreaTranslation(session,job: job) }
    }
}
extension Lens {
    func beginAreaTranslation(_ request: TranslationRequest) {
        let plan = AreaTranslationPlan(request: request)
        areaPlan = plan; areaResults = plan.immediate; completedAreaJobs = []
        if let result = plan.combined(areaResults) { completeTranslation(result,request: request); return }
        areaJobs = plan.jobs
    }
    func performAreaTranslation(_ session: TranslationSession,job: AreaTranslationJob) async {
        guard let request = translationRequest, request.id == job.parent, areaJobs.contains(where: { $0.id == job.id }) else { return }
        do {
            try Task.checkCancellation()
            let batch = job.lines.map { TranslationSession.Request(sourceText: $0.text,clientIdentifier: String($0.index)) }
            let responses = try await session.translations(from: batch)
            try Task.checkCancellation(); guard translationRequest?.id == job.parent, !completedAreaJobs.contains(job.id) else { return }
            guard responses.count == job.lines.count else { throw LocalModelError.message("An area translation returned incomplete text. Retry the area.") }
            for (line,response) in zip(job.lines,responses) { areaResults[line.index] = response.targetText }
            completedAreaJobs.insert(job.id)
            if let result = areaPlan?.combined(areaResults) { completeTranslation(result,request: request); areaJobs = [] }
        } catch {
            guard translationRequest?.id == job.parent, !(error is CancellationError), !Task.isCancelled else { return }
            failAreaTranslation(request,error: error)
        }
    }
}
