import AppKit

@main struct OCRSmoke {
    @MainActor static func main() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lens-ocr-test-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        func image(_ text: String) throws {
            let image = NSImage(size: NSSize(width: 1200, height: 240))
            image.lockFocus()
            NSColor.white.setFill(); NSRect(x: 0, y: 0, width: 1200, height: 240).fill()
            (text as NSString).draw(at: NSPoint(x: 40, y: 120), withAttributes: [.font: NSFont.systemFont(ofSize: 36), .foregroundColor: NSColor.black])
            image.unlockFocus()
            let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
            try bitmap.representation(using: .png, properties: [:])!.write(to: url)
        }
        try image("Hello friend. Please translate this sentence.")
        let text = try await ScreenText.recognize(url)
        guard text.contains("Please translate this sentence") else { fatalError("Expected sentence not recognized: \(text)") }
        print("PASS: local OCR recognizes a controlled sentence")
        try image("")
        do { _ = try await ScreenText.recognize(url); fatalError("Blank image should fail") }
        catch ScreenText.Failure.noText { print("PASS: blank image returns no-text error") }
    }
}
