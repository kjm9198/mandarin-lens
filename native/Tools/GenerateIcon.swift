import AppKit
let folder = URL(fileURLWithPath: CommandLine.arguments[1],isDirectory: true)
try FileManager.default.createDirectory(at: folder,withIntermediateDirectories: true)
for size in [16,32,64,128,256,512,1024] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: size,pixelsHigh: size,bitsPerSample: 8,samplesPerPixel: 4,hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: 0,bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let scale = CGFloat(size)/1024
    NSAffineTransform(scale: scale).concat()
    let shape = NSBezierPath(roundedRect: NSRect(x: 36,y: 36,width: 952,height: 952),xRadius: 214,yRadius: 214)
    NSGradient(starting: NSColor(red: 0.04,green: 0.66,blue: 0.63,alpha: 1),ending: NSColor(red: 0.02,green: 0.27,blue: 0.34,alpha: 1))!.draw(in: shape,angle: -70)
    NSColor.white.withAlphaComponent(0.92).setStroke()
    let frame = NSBezierPath(); frame.lineWidth = 34; frame.lineCapStyle = .round; frame.lineJoinStyle = .round
    for (x,y,dx,dy) in [(CGFloat(240),CGFloat(250),CGFloat(1),CGFloat(1)),(784,250,-1,1),(240,774,1,-1),(784,774,-1,-1)] {
        frame.move(to: NSPoint(x: x,y: y+dy*90)); frame.line(to: NSPoint(x: x,y: y)); frame.line(to: NSPoint(x: x+dx*90,y: y))
    }
    frame.stroke()
    let text = "K" as NSString
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 360,weight: .semibold),.foregroundColor: NSColor.white]
    let measured = text.size(withAttributes: attributes)
    text.draw(at: NSPoint(x: (1024-measured.width)/2,y: (1024-measured.height)/2+12),withAttributes: attributes)
    NSGraphicsContext.restoreGraphicsState()
    let png = bitmap.representation(using: .png,properties: [:])!
    let names: [String]
    switch size {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png","icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png","icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png","icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names { try png.write(to: folder.appendingPathComponent(name)) }
}
extension NSAffineTransform {
    convenience init(scale: CGFloat) { self.init(); self.scale(by: scale) }
}
