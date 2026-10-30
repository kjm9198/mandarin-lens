import Foundation

@main struct FeatureSmoke {
    @MainActor static func main() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("lens-words-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("words.json")
        let words = Vocabulary(url: url)
        words.save(term: "茶", meaning: "tea", target: "en")
        precondition(words.words.count == 1 && words.words[0].category == .food)
        precondition(!words.words[0].pronunciation.isEmpty)
        words.save(term: "茶", meaning: "tea", target: "en")
        precondition(words.words.count == 1)
        words.save(term: "ma", meaning: "ghost", target: "en")
        words.save(term: "má", meaning: "mother", target: "en")
        precondition(words.words.count == 3, "Vietnamese tones must remain distinct")
        let id = words.words[0].id
        words.categorize(id, as: .people)
        words.review(id, remembered: true)
        let restored = Vocabulary(url: url)
        precondition(restored.words.count == 3)
        precondition(restored.words[0].manualCategory && restored.words[0].category == .people)
        precondition(restored.words[0].nextReview > Date())
        precondition(WordTools.tokens("我喜欢喝茶").count > 1)
        let parsed = try WordTools.parseCategories("```json\n{\"a\":\"Food & drink\",\"foreign\":\"Travel\",\"b\":\"Invented\"}\n```", allowedIDs: ["a", "b"])
        precondition(parsed.count == 1 && parsed["a"] == .food)
        do { _ = try WordTools.parseCategories("no JSON", allowedIDs: ["a"]); fatalError("Should reject malformed AI output") } catch { }
        let permissions = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        precondition(permissions?.intValue == 0o600)
        let broken = folder.appendingPathComponent("broken.json")
        let damaged = Data("not-json".utf8); try damaged.write(to: broken)
        let protected = Vocabulary(url: broken); protected.save(term: "test", meaning: "test", target: "en")
        let preserved = try Data(contentsOf: broken); precondition(preserved == damaged)
        print("PASS: corrupt vocabulary file is preserved instead of overwritten")
        print("PASS: save, duplicate prevention, Chinese category/pinyin, Vietnamese tone distinction, persistence, manual category, spaced review, segmentation, untrusted category validation, owner-only permissions")
        let models = LocalModels(); models.discoverFiles()
        precondition(!models.models.isEmpty)
        let localURL = try models.api("models"); precondition(localURL.host == "127.0.0.1")
        models.port = 0
        do { _ = try models.api("models"); fatalError("Invalid port accepted") } catch { }
        models.port = 1234
        print("PASS: installed-model discovery and local-only endpoint validation (\(models.models.filter { !$0.server }.count) MLX folders, \(models.models.count) total entries)")
        if CommandLine.arguments.contains("--cancel") {
            models.selected = "auto"
            let task = Task { try await models.generate("Write 100 example sentences about learning Chinese.") }
            try await Task.sleep(for: .milliseconds(300)); task.cancel()
            do { _ = try await task.value; fatalError("Cancelled generation should not complete") } catch { }
            precondition(!models.busy)
            print("PASS: cancelling local generation releases the inference scheduler")
        }
        if CommandLine.arguments.contains("--multilingual") {
            models.selected = "auto"
            for language in ["Vietnamese", "Polish"] {
                let text = try await models.generate("Explain the Chinese word 谢谢 in \(language) only. Keep it to two short sentences, with one everyday example. Include tone-mark pinyin for 谢谢.")
                print("\(language): \(text)")
            }
        }
        if CommandLine.arguments.contains("--categorize") {
            if let index = words.words.firstIndex(where: { $0.term == "茶" }) { words.words[index].category = .unsorted }
            models.selected = "auto"
            await words.organize(using: models)
            precondition(words.words.first(where: { $0.term == "茶" })?.category == .food, "Real model should categorize tea")
            precondition(words.words.first(where: { $0.id == id })?.manualCategory == true)
            precondition(words.words.first(where: { $0.id == id })?.category == .people)
            print("PASS: real local model batch categorization and manual-category preservation")
            print(words.status)
        }
        if CommandLine.arguments.contains("--api-fixture") {
            models.port = 28078; await models.refreshServer()
            precondition(models.models.contains { $0.id == "api:fixture-only" })
            models.selected = "api:fixture-only"
            let response = try await models.generate("Test only: hello")
            precondition(response == "Local adapter fixture passed.")
            print("PASS: local API model discovery and completion protocol (explicit test fixture, not real LM Studio inference)")
        }
        if CommandLine.arguments.contains("--inference") {
            models.selected = "auto"
            if CommandLine.arguments.contains("--small"), let small = models.models.min(by: { $0.bytes < $1.bytes }) { models.selected = small.id }
            print("Testing real local model: \(models.active?.name ?? "none")")
            let started = Date(); var first: TimeInterval?
            let result = try await models.generate("Explain the Chinese word 银行 in English in two sentences. Include tone-mark pinyin and one short Chinese example with an English translation. Do not repeat yourself.") { _ in if first == nil { first = Date().timeIntervalSince(started) } }
            print("FIRST_TEXT_SECONDS: \(first ?? -1)")
            print("TOTAL_SECONDS: \(Date().timeIntervalSince(started))")
            print("OUTPUT: \(result)")
        }
    }
}
