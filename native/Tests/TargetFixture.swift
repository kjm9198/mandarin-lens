// Native acceptance fixture. Contains synthetic protected content; tests never read its value.
import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.regular)
if CommandLine.arguments.contains("--edges") {
    var retained: [NSWindow] = []
    let screens = NSScreen.screens
    let cases: [(String, Int, Bool, Bool)] = [("primary top left",0,false,true),("primary bottom right",0,true,false),("external top right",1,true,true),("external bottom right",1,true,false)]
    for (title,index,right,top) in cases where index < screens.count {
        let visible = screens[index].visibleFrame
        let frame = NSRect(x: right ? visible.maxX-500 : visible.minX, y: top ? visible.maxY-150 : visible.minY, width:500,height:150)
        let w = NSWindow(contentRect:frame,styleMask:[.titled,.closable],backing:.buffered,defer:false)
        w.title=title;w.level = .floating;w.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];w.isReleasedWhenClosed=false
        let text=NSTextView(frame:w.contentView!.bounds);text.string="beautiful coffee\n我喜欢学习中文。";text.font = .systemFont(ofSize:20);text.isEditable=false
        w.contentView=text;w.setFrame(frame,display:true);w.orderFrontRegardless();retained.append(w)
    }
    app.activate(ignoringOtherApps:true);withExtendedLifetime(retained) { app.run() };exit(0)
}

let window = NSWindow(contentRect: NSRect(x: 150,y: 250,width: 600,height: 330),styleMask:[.titled,.closable],backing:.buffered,defer:false)
window.title = "Lens Target Fixture"
let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 20; stack.translatesAutoresizingMaskIntoConstraints = false
let label = NSTextField(labelWithString: "Controlled native targeting checks");label.font = .systemFont(ofSize:22,weight:.semibold)
let secure = NSSecureTextField();secure.stringValue = "synthetic-fixture-only";secure.placeholderString = "Protected field";secure.setAccessibilityLabel("Protected field");secure.widthAnchor.constraint(equalToConstant:450).isActive = true
let image = NSImage(size:NSSize(width:450,height:100));image.lockFocus();NSColor.windowBackgroundColor.setFill();NSBezierPath(rect:NSRect(x:0,y:0,width:450,height:100)).fill();("This text is pixels, not accessible text." as NSString).draw(at:NSPoint(x:12,y:45),withAttributes:[.font:NSFont.systemFont(ofSize:18),.foregroundColor:NSColor.labelColor]);image.unlockFocus()
let imageView = NSImageView(image:image);imageView.setAccessibilityLabel("Image-only area")
[label,secure,imageView].forEach {stack.addArrangedSubview($0)}
window.contentView!.addSubview(stack)
NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:24),stack.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:24)])
window.makeKeyAndOrderFront(nil);app.activate(ignoringOtherApps:true);app.run()
