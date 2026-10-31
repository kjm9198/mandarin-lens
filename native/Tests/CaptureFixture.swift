import AppKit
@MainActor final class CaptureFixtureDelegate: NSObject, NSApplicationDelegate {
    var windows: [NSWindow] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        var targets: [[String: Any]] = []
        let top = NSScreen.screens.first!.frame.maxY
        for (index,screen) in NSScreen.screens.enumerated() {
            let full = CommandLine.arguments.contains("--full-display")
            let size = full ? screen.frame.size : CGSize(width: 850,height: 330)
            let origin = full ? screen.frame.origin : CGPoint(x: screen.visibleFrame.minX+35,y: screen.visibleFrame.maxY-430)
            let frame = CGRect(origin: origin,size: size)
            let window = NSWindow(contentRect: frame,styleMask: full ? [.borderless] : [.titled,.closable],backing: .buffered,defer: false)
            window.title = "Kamihi capture fixture \(index)"; window.isReleasedWhenClosed = false
            window.level = .floating; window.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
            let image = NSImage(size: size); image.lockFocus(); NSColor.white.setFill(); CGRect(origin: .zero,size: size).fill()
            let english = CommandLine.arguments.contains("--control") ? ("Control the volume, please.","Control") : ("Beautiful coffee, every day.","coffee")
            let rows: [(String,CGFloat,String)] = [("我喜欢学习中文。",size.height-95,"学习"),(english.0,size.height-170,english.1),("我们一起喝咖啡。",size.height-245,"咖啡")]
            for (line,y,term) in rows {
                let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 30),.foregroundColor: NSColor.black]
                (line as NSString).draw(at: CGPoint(x: 40,y: y),withAttributes: attrs)
                let range = (line as NSString).range(of: term)
                let prefix = (line as NSString).substring(to: range.location)
                let x = 40+(prefix as NSString).size(withAttributes: attrs).width
                let width = (term as NSString).size(withAttributes: attrs).width
                let p = window.convertToScreen(CGRect(x: x+width/2,y: y+17,width: 0,height: 0)).origin
                targets.append(["screen":index,"word":term,"sentence":line,"x":p.x,"y":top-p.y])
            }
            image.unlockFocus()
            let view = NSImageView(frame: CGRect(origin: .zero,size: size)); view.image = image; view.imageScaling = .scaleNone; view.setAccessibilityLabel("Controlled raster text")
            window.contentView = view; windows.append(window); window.makeKeyAndOrderFront(nil)
            let content = window.convertToScreen(CGRect(x: 25,y: size.height-265,width: min(size.width-50,680),height: 225))
            targets.append(["screen":index,"area":["x":content.minX,"y":top-content.maxY,"width":content.width,"height":content.height]])
        }
        try! JSONSerialization.data(withJSONObject: targets,options: [.prettyPrinted,.sortedKeys]).write(to: URL(fileURLWithPath: "/tmp/kamihi-4-targets.json"))
        NSApp.activate(ignoringOtherApps: true)
    }
}
@main struct FixtureMain {
    @MainActor static func main() { let app = NSApplication.shared; app.setActivationPolicy(.regular); let delegate = CaptureFixtureDelegate(); app.delegate = delegate; withExtendedLifetime(delegate) { app.run() } }
}
