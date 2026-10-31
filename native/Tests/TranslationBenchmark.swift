// Run on macOS 26.4+: xcrun swiftc -parse-as-library native/Tests/TranslationBenchmark.swift -o /tmp/kamihi-translation-benchmark
// Uses only public fixture text and already installed language models; never downloads assets.
import Foundation
import Translation

@main struct TranslationBenchmark {
    static func main() async throws {
        guard #available(macOS 26.4,*) else { print("Requires macOS 26.4"); return }
        let samples: [String:[String]] = [
            "en": ["Please reserve a table for two at seven o'clock tonight.","I can't come tomorrow. Could we meet on Friday instead?"],
            "pl": ["Proszę zarezerwować stolik dla dwóch osób na dziś na godzinę dziewiętnastą.","Nie mogę przyjść jutro. Czy możemy spotkać się w piątek?"],
            "vi": ["Vui lòng đặt bàn cho hai người lúc bảy giờ tối nay.","Ngày mai tôi không thể đến. Thay vào đó, chúng ta có thể gặp nhau vào thứ Sáu không?"],
            "zh-Hans": ["请预订今晚七点的两人桌。","我明天不能来。我们可以改在星期五见面吗？"],
            "zh-Hant": ["請預訂今晚七點的兩人桌。","我明天不能來。我們可以改在星期五見面嗎？"]
        ]
        var rows: [[String:Any]] = []
        for quality in (CommandLine.arguments.contains("--fast-only") ? ["fast"] : ["natural","fast"]) {
            let strategy: TranslationSession.Strategy = quality == "fast" ? .lowLatency : .highFidelity
            let availability = LanguageAvailability(preferredStrategy: strategy)
            for source in samples.keys.sorted() {
                for target in samples.keys.sorted() where source != target {
                    let from = Locale.Language(identifier: source), to = Locale.Language(identifier: target)
                    let status = await availability.status(from: from,to: to)
                    guard status == .installed else { rows.append(["source":source,"target":target,"mode":quality,"status":"not installed","availability":String(describing: status)]); continue }
                    let session = TranslationSession(installedSource: from,target: to,preferredStrategy: strategy)
                    for (index,text) in samples[source]!.enumerated() {
                        let start = Date()
                        do {
                            let response = try await session.translate(text)
                            rows.append(["source":source,"target":target,"mode":quality,"sample":index,"input":text,"output":response.targetText,"milliseconds":Int(Date().timeIntervalSince(start)*1000),"status":"translated"])
                        } catch { rows.append(["source":source,"target":target,"mode":quality,"sample":index,"error":error.localizedDescription,"status":"error"]) }
                    }
                }
            }
        }
        let data = try JSONSerialization.data(withJSONObject: ["engine":"Apple Translation","note":"Mode requests a strategy; Apple may fall back based on device and language. Timing includes framework inference only, not OCR, model downloads or app UI. Fixtures are a smoke test, not a quality certification.","results":rows],options:[.prettyPrinted,.sortedKeys])
        print(String(decoding: data,as: UTF8.self))
    }
}
