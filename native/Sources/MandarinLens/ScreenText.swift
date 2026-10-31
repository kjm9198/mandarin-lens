import AppKit
import Vision
import ApplicationServices

enum ScreenText {
    enum Failure: LocalizedError {
        case noText
        var errorDescription: String? { "No readable text found. Try a smaller area with clearer text." }
    }
    // Vision performs OCR locally. The image is never retained by this service.
    static func recognize(_ url: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            let handler = VNImageRequestHandler(url: url)
            try handler.perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.noText }
            return text
        }.value
    }
}
