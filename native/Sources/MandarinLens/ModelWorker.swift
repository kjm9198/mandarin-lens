import Foundation

// All blocking pipe IO stays on a serial queue. Cancellation can terminate it from any thread.
final class ModelWorker: @unchecked Sendable {
    let job = LocalJob()
    let input = Pipe(), output = Pipe()
    private let queue = DispatchQueue(label: "studio.kamihi.lens.inference", qos: .userInitiated)
    init(python: URL, script: URL, model: String) {
        let p = job.process; p.executableURL = python; p.arguments = ["-u", script.path, model]
        p.standardInput = input; p.standardOutput = output; p.standardError = FileHandle.nullDevice
        var env = ProcessInfo.processInfo.environment
        env["HF_HUB_OFFLINE"] = "1"; env["TRANSFORMERS_OFFLINE"] = "1"; env["HF_HUB_DISABLE_TELEMETRY"] = "1"; p.environment = env
    }
    func generate(messages: [ModelTurn], onText: @escaping @MainActor (String) -> Void) async throws -> String {
        let stream = AsyncThrowingStream<String, Error> { continuation in
            queue.async {
                let timeout = DispatchWorkItem { self.job.cancel() }
                DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: timeout)
                defer { timeout.cancel() }
                do {
                    if !self.job.process.isRunning { try self.job.start() }
                    var request = try JSONSerialization.data(withJSONObject: ["messages": messages.map { ["role": $0.role, "content": $0.content] }]); request.append(10)
                    try self.input.fileHandleForWriting.write(contentsOf: request)
                    var pending = Data(), count = 0
                    while true {
                        let chunk = self.output.fileHandleForReading.availableData
                        guard !chunk.isEmpty else { throw LocalModelError.message("Local model stopped. Retry or choose another model.") }
                        pending.append(chunk); count += chunk.count
                        guard count <= 256000 else { self.job.cancel(); throw LocalModelError.message("Model response exceeded the limit.") }
                        while let end = pending.firstIndex(of: 10) {
                            let line = pending[..<end]; pending.removeSubrange(...end)
                            guard let item = try JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
                            if let error = item["error"] as? String { throw LocalModelError.message("Local model: " + error) }
                            if let text = item["delta"] as? String { continuation.yield(text) }
                            if item["done"] as? Bool == true { continuation.finish(); return }
                        }
                    }
                } catch { continuation.finish(throwing: error) }
            }
        }
        return try await withTaskCancellationHandler {
            var result = ""
            for try await delta in stream { try Task.checkCancellation(); result += delta; await onText(delta) }
            try Task.checkCancellation()
            guard !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LocalModelError.message("Model returned no text. Try another model.") }
            return result
        } onCancel: { self.job.cancel() }
    }
}
