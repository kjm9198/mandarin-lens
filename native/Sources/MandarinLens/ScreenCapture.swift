import AppKit
import ApplicationServices

extension Lens {
    func captureSelection() {
        capture(selectionOnly: true)
    }
    func captureScreen(entireDisplay: Bool) {
        guard !capturing else { return }
        guard CGPreflightScreenCaptureAccess() else {
            _ = CGRequestScreenCaptureAccess()
            output = "Allow Screen Recording for Kamihi Lens in System Settings → Privacy & Security, then try Capture again."
            show(); return
        }
        capturing = true
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mandarin-lens-\(UUID().uuidString).png")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // Select only the display containing the pointer, never every connected display.
        let display = (NSScreen.screens.firstIndex { $0.frame.contains(NSEvent.mouseLocation) } ?? 0) + 1
        p.arguments = entireDisplay ? ["-x", "-D", String(display), url.path] : ["-x", "-i", "-s", url.path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        panel?.orderOut(nil)
        NSApp.hide(nil)
        Task { @MainActor in
            defer { try? FileManager.default.removeItem(at: url); capturing = false; show() }
            // Let the note disappear before capturing pixels.
            try? await Task.sleep(for: .milliseconds(300))
            do {
                let status: Int32 = try await withCheckedThrowingContinuation { continuation in
                    p.terminationHandler = { process in continuation.resume(returning: process.terminationStatus) }
                    do { try p.run() } catch { continuation.resume(throwing: error) }
                }
                guard status == 0, FileManager.default.fileExists(atPath: url.path) else { return } // Escape cancels.
                let text = try await ScreenText.recognize(url)
                input = String(text.prefix(16000))
                show(); translate()
            } catch { output = "Screen capture: \(error.localizedDescription)" }
        }
    }
}
