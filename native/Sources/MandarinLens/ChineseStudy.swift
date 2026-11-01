import SwiftUI
import Translation
import NaturalLanguage
import AppKit

func languageName(_ code: String) -> String {
    if code.hasPrefix("zh") { return code == "zh-Hant" ? "Traditional Chinese" : "Chinese" }
    if code == "vi" { return "Vietnamese" }
    if code == "pl" { return "Polish" }
    return "English"
}

struct ChineseExample: Codable, Equatable {
    let word: String
    let chinese: String
    let english: String
    var pinyin: String { chinese.applyingTransform(.mandarinToLatin,reverse: false) ?? "" }
}
enum TranslationSource {
    static let commonPolishWords: Set<String> = [
        "tak", "nie", "dobry", "dzien", "dzień", "prosze", "proszę", "dziekuje", "dziękuję",
        "dzięki", "dzieki", "czesc", "cześć", "herbata", "kawa", "woda", "praca", "szkola",
        "szkoła", "dom", "kot", "pies", "jutro", "dzisiaj", "bardzo", "jestem", "jestes",
        "jesteś", "jest", "co", "jak", "gdzie", "kiedy", "dlaczego", "kto", "przepraszam",
        "chleb", "obiad", "śniadanie", "sniadanie", "kolacja", "mleko", "cukier", "dobre",
        "dobra", "witam", "strajk", "strajki", "strajkować", "protest", "manifestacja",
        "czas", "rok", "ludzie", "człowiek", "czlowiek", "kobieta", "mężczyzna", "mezczyzna",
        "dziecko", "życie", "zycie", "droga", "samochód", "samochod", "auto", "pociąg", "pociag",
        "dworzec", "lotnisko", "miasto", "państwo", "panstwo", "kraj", "świat", "swiat",
        "rząd", "rzad", "sejm", "prawo", "sąd", "sad", "policja", "wojna", "pokój", "pokoj",
        "wolność", "wolnosc", "solidarność", "solidarnosc", "sklep", "pieniądze", "pieniadze",
        "cena", "rachunek", "karta", "bank", "serce", "morze", "góry", "gory", "las",
        "słońce", "slonce", "deszcz", "śnieg", "snieg", "wiatr", "chmura", "drzewo",
        "zegar", "godzina", "minuta", "tydzień", "tydzien", "miesiąc", "miesiac",
        "wiadomości", "wiadomosci", "gazeta", "książka", "ksiazka", "film", "muzyka",
        "lekarz", "szpital", "zdrowie", "pomoc", "koniec", "początek", "poczatek",
        "pytanie", "odpowiedź", "odpowiedz", "nauka", "język", "jezyk", "słowo", "slowo"
    ]

    static func isVietnamese(_ text: String) -> Bool {
        text.range(of: "[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ]", options: [.caseInsensitive, .regularExpression]) != nil
    }

    static func isPolish(_ text: String) -> Bool {
        if isVietnamese(text) { return false }
        if text.range(of: "[ąćęłńóśźżĄĆĘŁŃÓŚŹŻ]", options: .regularExpression) != nil { return true }
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .punctuationCharacters)
        if Lens.polishToEnglishDictionary[lower] != nil || Lens.polishToChineseDictionary[lower] != nil { return true }
        let tokens = lower.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation }).map(String.init)
        if tokens.contains(where: { commonPolishWords.contains($0) || Lens.polishToEnglishDictionary[$0] != nil || Lens.polishToChineseDictionary[$0] != nil }) { return true }

        for token in tokens {
            if token.range(of: "(sz|cz|rz|dz|dż|dź|prz|strz|trz|wstrz|wrz|krz|grz|brz|drz|jk|ści|źnie|wski|wska)", options: .regularExpression) != nil {
                let englishFalseFriends: Set<String> = [
                    "catch", "match", "watch", "witch", "rich", "much", "such", "check", "chain",
                    "chair", "child", "choose", "church", "chance", "change", "charge", "chart",
                    "chase", "cheap", "cheat", "cheese", "chemical", "chest", "chief", "chicken",
                    "chin", "chip", "choice"
                ]
                if !englishFalseFriends.contains(token) { return true }
            }
        }

        if tokens.count <= 3 {
            let checker = NSSpellChecker.shared
            var plValidCount = 0
            var enMisspelledCount = 0
            for token in tokens {
                let plRange = checker.checkSpelling(of: token, startingAt: 0, language: "pl_PL", wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
                let enRange = checker.checkSpelling(of: token, startingAt: 0, language: "en_US", wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
                if plRange.location == NSNotFound { plValidCount += 1 }
                if enRange.location != NSNotFound { enMisspelledCount += 1 }
            }
            if plValidCount > 0 && enMisspelledCount > 0 { return true }
        }
        return false
    }

    static func language(text: String,context: String = "",preference: String = "auto") -> String {
        // A Chinese selection is already unambiguous, even when English is the preferred source.
        if text.range(of: "\\p{Han}",options: .regularExpression) != nil,
           text.range(of: "[\\p{Hiragana}\\p{Katakana}]",options: .regularExpression) == nil { return "zh-Hans" }
        if preference != "auto" { return preference }
        if isVietnamese(text) { return "vi" }
        if isPolish(text) { return "pl" }
        let recognizer = NLLanguageRecognizer(); recognizer.processString(text)
        let detected = recognizer.dominantLanguage?.rawValue ?? "und"
        if detected == "pl" { return "pl" }
        if WordTools.tokens(text).count <= 2, text.range(of: "^[A-Za-z0-9’' -]+$",options: .regularExpression) != nil {
            // Single Latin words are unreliable: “Control” is guessed as Romanian on this Mac.
            // Prefer a confident surrounding line; otherwise check Polish before English fallback.
            if context != text, WordTools.tokens(context).count >= 4 {
                let surrounding = NLLanguageRecognizer(); surrounding.processString(context)
                let guesses = surrounding.languageHypotheses(withMaximum: 1)
                if let guess = guesses.first, guess.value >= 0.8 { return guess.key.rawValue }
            }
            if isPolish(text) { return "pl" }
            return "en"
        }
        return detected
    }
}
enum ChineseStudy {
    static func headword(_ text: String) -> String? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...16).contains(cleaned.count), cleaned.range(of: "\\p{Han}",options: .regularExpression) != nil else { return nil }
        return cleaned
    }
    static func sentence(_ response: String,word: String) throws -> String {
        var chinese = ""
        if let start = response.firstIndex(of: "{"), let end = response.lastIndex(of: "}"), start <= end,
           let object = try? JSONSerialization.jsonObject(with: Data(response[start...end].utf8)) as? [String:String] { chinese = object["chinese"] ?? "" }
        chinese = chinese.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...120).contains(chinese.count), chinese.contains(word), !chinese.contains("\n"), chinese.range(of: "[。！？]$",options: .regularExpression) != nil else {
            throw LocalModelError.message("The local model did not return a usable example containing this word. Try the example again.")
        }
        return chinese
    }
}
struct ChineseExampleJob: Identifiable {
    let id = UUID()
    let parent: UUID
    let word: String
    let sentence: String
    let configuration = TranslationSession.Configuration(source: Locale.Language(identifier: "zh-Hans"),target: Locale.Language(identifier: "en"))
}
extension Lens {
    var chineseWord: String? { guard canSaveWord else { return nil }; return ChineseStudy.headword(target.hasPrefix("zh") ? output : input) }
    func beginChineseExample() {
        guard let request = translatedRequest, request.kind == .word || request.kind == .typed, let word = chineseWord else { return }
        exampleTask?.cancel(); exampleJob = nil; usageExample = nil
        if let cached = history.first(where: { $0.usageExample?.word == word })?.usageExample ?? vocabulary.words.first(where: { $0.usageExample?.word == word })?.usageExample {
            usageExample = cached; exampleStatus = ""; attachExample(cached,request: request); return
        }
        guard !models.busy else { exampleStatus = "Your local AI is busy. Choose Try example when it’s free."; return }
        exampleStatus = "Creating an example on this Mac…"
        exampleTask = Task { @MainActor in
            do {
                let prompt = "Write one short, natural, everyday Chinese sentence using the exact word in this JSON: \(String(data: try JSONEncoder().encode(["word":word]),encoding: .utf8)!). Return ONLY JSON with one key chinese, e.g. {\"chinese\":\"我喜欢喝咖啡。\"}. Use the requested word naturally, not a definition or a sentence about the word. End with Chinese punctuation. No English, no pinyin, no markdown."
                let response = try await models.generate(prompt)
                try Task.checkCancellation(); guard translatedRequest == request else { return }
                let sentence = try ChineseStudy.sentence(response,word: word)
                exampleStatus = "Translating the example into English…"
                exampleJob = ChineseExampleJob(parent: request.id,word: word,sentence: sentence)
            } catch {
                guard translatedRequest == request, !Task.isCancelled else { return }
                exampleStatus = error.localizedDescription
            }
        }
    }
    func translateChineseExample(_ session: TranslationSession,job: ChineseExampleJob) async {
        do {
            let translated = try await session.translate(job.sentence)
            try Task.checkCancellation()
            guard let request = translatedRequest, request.id == job.parent, exampleJob?.id == job.id else { return }
            let example = ChineseExample(word: job.word,chinese: job.sentence,english: translated.targetText)
            usageExample = example; exampleStatus = ""; exampleJob = nil; attachExample(example,request: request)
        } catch {
            guard translatedRequest?.id == job.parent, !Task.isCancelled else { return }
            exampleJob = nil; exampleStatus = "Example translation unavailable. Try example again."
        }
    }
    private func attachExample(_ example: ChineseExample,request: TranslationRequest) {
        if let index = history.firstIndex(where: { $0.source == request.text && $0.language == request.target && $0.kind == request.kind && $0.translation == output }) { history[index].usageExample = example; persist() }
        vocabulary.attachExample(example)
    }
}
struct ChineseExampleWorker: View {
    @ObservedObject var lens: Lens
    let job: ChineseExampleJob
    var body: some View { Color.clear.frame(width: 0,height: 0).accessibilityHidden(true).translationTask(job.configuration) { session in await lens.translateChineseExample(session,job: job) } }
}
struct ChineseExampleContent: View {
    let example: ChineseExample
    @StateObject private var speaker = WordSpeaker.shared
    var body: some View {
        VStack(alignment: .leading,spacing: 8) {
            HStack { Text("Example sentence").font(.system(size: 12,weight: .semibold)).foregroundStyle(.secondary); Spacer(); SpeechControl(speaker: speaker,text: example.chinese,language: "zh-Hans",title: "Chinese example") }
            Text(example.chinese).font(.system(size: 18,weight: .regular)).textSelection(.enabled).fixedSize(horizontal: false,vertical: true)
            Text(example.pinyin).font(.system(size: 13)).foregroundStyle(Color.lensAccent).textSelection(.enabled).fixedSize(horizontal: false,vertical: true)
            Text(example.english).font(.system(size: 13)).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false,vertical: true)
            Text("Generated example").font(.system(size: 10)).foregroundStyle(.secondary).help("Generated locally. Examples can be inaccurate; pinyin uses system transliteration.")
            if !speaker.status.isEmpty { Text(speaker.status).font(.caption2).foregroundStyle(.secondary) }
        }.onDisappear { speaker.stop() }
    }
}
struct CurrentChineseExample: View {
    @ObservedObject var lens: Lens
    var body: some View {
        if lens.chineseWord != nil {
            Divider().padding(.vertical,3)
            if let example = lens.usageExample { ChineseExampleContent(example: example) }
            else {
                VStack(alignment: .leading,spacing: 7) {
                    Text("Example sentence").font(.system(size: 12,weight: .semibold)).foregroundStyle(.secondary)
                    Text(lens.exampleStatus.isEmpty ? "Create a Chinese example with English and pinyin." : lens.exampleStatus).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true)
                    if lens.exampleStatus.contains("…") { ProgressView().controlSize(.small) }
                    else { Button("Try example") { lens.beginChineseExample() }.controlSize(.small) }
                }
            }
        }
    }
}
