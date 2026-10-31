// Controlled, image-only screen-selection fixture. No text controls or private content.
import AppKit
@MainActor final class FixtureDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        var targets: [[String: Any]] = []
        let primaryTop = NSScreen.screens.first!.frame.maxY
        for (index, screen) in NSScreen.screens.enumerated() {
            let size = CGSize(width: 650, height: 240)
            let frame = CGRect(x: screen.visibleFrame.minX + 40, y: screen.visibleFrame.maxY - 310, width: size.width, height: size.height)
            let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Raster words \(index)"; window.isReleasedWhenClosed = false
            window.level = .floating; window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let image = NSImage(size: size); image.lockFocus()
            NSColor.white.setFill(); CGRect(origin: .zero, size: size).fill()
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 32), .foregroundColor: NSColor.black]
            for (line, y, term) in [("beautiful coffee", CGFloat(150), "coffee"), ("我喜欢学习中文", CGFloat(70), "学习")] {
                (line as NSString).draw(at: CGPoint(x: 35,y: y), withAttributes: attributes)
                let range = (line as NSString).range(of: term)
                let prefix = (line as NSString).substring(to: range.location)
                let x = 35 + (prefix as NSString).size(withAttributes: attributes).width
                let width = (term as NSString).size(withAttributes: attributes).width
                let point = window.convertToScreen(CGRect(x: x + width / 2,y: y + 18,width: 0,height: 0)).origin
                targets.append(["screen": index,"word": term,"x": point.x,"y": primaryTop - point.y])
            }
            image.unlockFocus()
            let view = NSImageView(frame: CGRect(origin: .zero,size: size)); view.image = image; view.imageScaling = .scaleNone
            view.setAccessibilityLabel("Controlled image-only text")
            window.contentView = view; windows.append(window); window.makeKeyAndOrderFront(nil)
        }
        try! JSONSerialization.data(withJSONObject: targets, options: [.prettyPrinted,.sortedKeys]).write(to: URL(fileURLWithPath: "/tmp/kamihi-selection-targets.json"))
        NSApp.activate(ignoringOtherApps: true)
    }
}
@main struct Main {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = FixtureDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
