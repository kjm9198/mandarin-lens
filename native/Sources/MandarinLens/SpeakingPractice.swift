import SwiftUI
import Speech
import AVFoundation

enum LocalSpeech {
    static func transcribe(clip: URL, model: URL, language: String, root: URL, job: LocalJob) async throws -> String {
        let pipe = Pipe(), process = job.process
        process.executableURL = root.appendingPathComponent("mlx-runtime/bin/python")
        process.arguments = [Bundle.main.resourceURL!.appendingPathComponent("speech_worker.py").path, model.path, clip.path, language.hasPrefix("zh") ? "zh" : language]
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["HF_HUB_OFFLINE"] = "1"; environment["TRANSFORMERS_OFFLINE"] = "1"; environment["HF_HUB_DISABLE_TELEMETRY"] = "1"; process.environment = environment
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let timeout = DispatchWorkItem { job.cancel() }; DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: timeout)
                    defer { timeout.cancel() }
                    do {
                        try job.start(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
                        guard data.count < 16000, let json = try JSONSerialization.jsonObject(with: data) as? [String: String] else { throw LocalModelError.message("Offline speech model did not return a result.") }
                        if let error = json["error"] { throw LocalModelError.message("Offline speech: " + error) }
                        guard process.terminationStatus == 0 else { throw LocalModelError.message("Offline recognition stopped. Try again.") }
                        continuation.resume(returning: json["text"] ?? "")
                    } catch { continuation.resume(throwing: error) }
                }
            }
        } onCancel: { job.cancel() }
    }
}
@MainActor final class SpeakingPractice: ObservableObject {
    @Published var transcript = ""
    @Published var status = "Listen, then try saying the word. Recognition checks the words heard, not tones or accent accuracy."
    @Published var recording = false
    @Published var transcribing = false
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timeout: Task<Void, Never>?
    private var generation = UUID()
    private var tapped = false
    private var recorder: AVAudioRecorder?
    private var clipFolder: URL?
    private var localTask: Task<Void, Never>?
    private var localJob: LocalJob?
    private var modelURL: URL?
    private var modelRoot: URL?
    private var language = "en"
    func start(word: SavedWord, models: LocalModels) async {
        stop(); let id = UUID(); generation = id
        let locale = word.sourceLanguage.hasPrefix("zh") ? "zh-CN" : word.sourceLanguage == "vi" ? "vi-VN" : word.sourceLanguage == "pl" ? "pl-PL" : "en-US"
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale))
        let useApple = recognizer?.isAvailable == true && recognizer?.supportsOnDeviceRecognition == true
        guard useApple || models.speechAvailable else { status = "Download the offline speech model below. Apple's on-device recognition is unavailable for this language on this Mac. No audio is sent to a server."; return }
        if useApple {
            let authorization = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
            guard generation == id else { return }
            guard authorization == .authorized else { status = "Allow Speech Recognition for Kamihi Lens in Privacy & Security. Listening remains optional."; return }
        }
        let mic = await AVCaptureDevice.requestAccess(for: .audio)
        guard generation == id else { return }
        guard mic else { status = "Allow Microphone access for Kamihi Lens in Privacy & Security."; return }
        transcript = ""; language = word.sourceLanguage
        do {
            if !useApple {
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("lens-speech-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]); clipFolder = folder
                let recorder = try AVAudioRecorder(url: folder.appendingPathComponent("clip.wav"), settings: [AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 16000, AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsFloatKey: false])
                self.recorder = recorder; modelURL = models.speechModelURL; modelRoot = models.root
                guard recorder.prepareToRecord(), recorder.record() else { throw LocalModelError.message("Could not start microphone recording.") }
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: recorder.url.path)
                recording = true; status = "Listening locally. Choose Finish when you've said the word."
            } else {
                let request = SFSpeechAudioBufferRecognitionRequest(); request.requiresOnDeviceRecognition = true; request.shouldReportPartialResults = true; self.request = request
                let input = engine.inputNode, format = engine.inputNode.outputFormat(forBus: 0)
                guard format.sampleRate > 0, format.channelCount > 0 else { throw LocalModelError.message("No microphone input is available.") }
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in request.append(buffer) }; tapped = true
                engine.prepare(); try engine.start(); recording = true; status = "Listening on this Mac…"
                task = recognizer!.recognitionTask(with: request) { [weak self] result, error in
                    Task { @MainActor in
                        guard let self, self.generation == id else { return }
                        if let result { self.transcript = result.bestTranscription.formattedString; if result.isFinal { self.finish(expected: word.term) } }
                        if let error, self.recording { self.stop(); self.status = "Recognition unavailable: \(error.localizedDescription)" }
                    }
                }
            }
            timeout = Task { try? await Task.sleep(for: .seconds(12)); if !Task.isCancelled, self.generation == id { self.finish(expected: word.term) } }
        } catch { stop(); status = error.localizedDescription }
    }
    func finish(expected: String) {
        if let recorder, let folder = clipFolder, let modelURL, let modelRoot {
            recorder.stop(); self.recorder = nil; recording = false; timeout?.cancel(); timeout = nil
            let id = generation, job = LocalJob(); localJob = job; transcribing = true; status = "Checking the recorded words on this Mac…"
            let language = language
            localTask = Task {
                defer { try? FileManager.default.removeItem(at: folder) }
                do {
                    let text = try await LocalSpeech.transcribe(clip: recorder.url, model: modelURL, language: language, root: modelRoot, job: job)
                    try Task.checkCancellation(); guard generation == id else { return }
                    transcript = text; transcribing = false; status = Self.feedback(text, expected)
                } catch { guard generation == id else { return }; transcribing = false; status = Task.isCancelled ? "Recognition stopped." : error.localizedDescription }
            }
        } else { let heard = transcript; stop(); status = Self.feedback(heard, expected) }
    }
    static func feedback(_ heard: String, _ expected: String) -> String {
        heard.isEmpty ? "No words recognized. Try again closer to the microphone." : matches(heard, expected) ? "Recognized the expected word. This does not verify Mandarin tones or pronunciation quality." : "Heard “\(heard)”. Expected “\(expected)”. Listen once more and try again; recognition can make mistakes."
    }
    static func matches(_ heard: String, _ expected: String) -> Bool {
        func normalized(_ s: String) -> String { (s.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false) ?? s).lowercased().precomposedStringWithCanonicalMapping.filter { !$0.isWhitespace && !$0.isPunctuation } }
        return normalized(heard) == normalized(expected)
    }
    func stop() {
        generation = UUID(); timeout?.cancel(); timeout = nil; localTask?.cancel(); localJob?.cancel(); localTask = nil; localJob = nil
        recorder?.stop(); recorder = nil; if let folder = clipFolder { try? FileManager.default.removeItem(at: folder) }; clipFolder = nil
        engine.stop(); if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
        request?.endAudio(); task?.cancel(); request = nil; task = nil; recording = false; transcribing = false
    }
}
struct SpeakingPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    let word: SavedWord
    @ObservedObject var models: LocalModels
    @StateObject private var practice = SpeakingPractice()
    @StateObject private var speaker = WordSpeaker.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Speaking practice").font(.title2.weight(.semibold))
                Spacer()
                Button("Close") { practice.stop(); dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(word.term).font(.largeTitle)
            Text(word.pronunciation).foregroundStyle(.secondary)
            Text(word.meaning)
            HStack {
                Button(speaker.isPlaying(word.term,language: PracticeDeck.language(word)) ? "Stop" : "Listen") { speaker.speak(word.term, language: PracticeDeck.language(word)) }.disabled(practice.recording)
                Button(practice.recording ? "Finish" : "Try saying it") { if practice.recording { practice.finish(expected: word.term) } else { Task { await practice.start(word: word, models: models) } } }.buttonStyle(.borderedProminent).disabled(practice.transcribing)
            }
            if !models.speechAvailable {
                Button(models.installing ? "Downloading offline speech…" : "Download offline speech · about 500 MB") { Task { await models.installModel("whisper-small-asr-fp16") } }.disabled(models.installing)
                Text(models.status).font(.caption).foregroundStyle(.secondary)
            }
            if practice.transcribing { HStack { ProgressView().controlSize(.small); Button("Stop checking") { practice.stop() } } }
            if practice.recording { ProgressView("Listening…").controlSize(.small) }
            if !practice.transcript.isEmpty { Text("Heard: " + practice.transcript).textSelection(.enabled) }
            Text(practice.status).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !speaker.status.isEmpty { Text(speaker.status).font(.caption).foregroundStyle(.secondary) }
            Text("Optional. Audio recognition is restricted to this device. Temporary recordings are deleted after checking or cancellation. This is word recognition, not an AI pronunciation score.").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 390).onDisappear { practice.stop() }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in practice.stop() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in practice.stop() }
    }
}
