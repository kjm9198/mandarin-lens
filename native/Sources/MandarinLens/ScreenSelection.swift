import AppKit
import SwiftUI
import Vision
import NaturalLanguage
import ScreenCaptureKit

struct ScreenWord: Equatable, Sendable {
    let text: String
    let context: String
    let bounds: CGRect
    var kind: CaptureKind = .word
    var lineIndex = 0
    var utf16Offset = 0
}
struct OCRPage: Sendable { var words: [ScreenWord]; var lines: [ScreenWord] }
enum SelectionGeometry {
    static func screenRect(_ normalized: CGRect, in screen: CGRect) -> CGRect {
        CGRect(x: screen.minX + normalized.minX * screen.width, y: screen.minY + normalized.minY * screen.height,
               width: normalized.width * screen.width, height: normalized.height * screen.height)
    }
    static func distSq(_ r: CGRect, _ p: CGPoint) -> CGFloat {
        let dx = p.x < r.minX ? r.minX - p.x : (p.x > r.maxX ? p.x - r.maxX : 0)
        let dy = p.y < r.minY ? r.minY - p.y : (p.y > r.maxY ? p.y - r.maxY : 0)
        return dx * dx + dy * dy
    }
    static func word(at point: CGPoint, in words: [ScreenWord]) -> ScreenWord? {
        let direct = words.filter { $0.bounds.insetBy(dx: -6, dy: -6).contains(point) }
        if let best = direct.min(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }) {
            return best
        }
        let nearby = words.filter { distSq($0.bounds, point) <= 36 * 36 }
        if let best = nearby.min(by: { distSq($0.bounds, point) < distSq($1.bounds, point) }) {
            return best
        }
        let extended = words.filter { distSq($0.bounds, point) <= 80 * 80 }
        return extended.min(by: { distSq($0.bounds, point) < distSq($1.bounds, point) })
    }
    static func joined(_ lines: [ScreenWord]) -> String {
        lines.reduce("") { result, line in
            guard !result.isEmpty else { return line.text }
            let chinese = result.last.map { String($0).range(of: "\\p{Han}", options: .regularExpression) != nil } == true && line.text.first.map { String($0).range(of: "\\p{Han}", options: .regularExpression) != nil } == true
            return result + (chinese ? "" : " ") + line.text
        }
    }
    static func sentence(at point: CGPoint, words: [ScreenWord], lines: [ScreenWord]) -> ScreenWord? {
        guard !lines.isEmpty else { return nil }
        let directLine = lines.firstIndex { $0.bounds.insetBy(dx: -8, dy: -8).contains(point) }
        let at: Int
        if let directLine {
            at = directLine
        } else if let nearestLine = lines.indices.filter({ distSq(lines[$0].bounds, point) <= 48 * 48 }).min(by: { distSq(lines[$0].bounds, point) < distSq(lines[$1].bounds, point) }) {
            at = nearestLine
        } else if let hit = word(at: point, in: words), let lineIdx = lines.firstIndex(where: { $0.lineIndex == hit.lineIndex }) {
            at = lineIdx
        } else if let closest = lines.indices.min(by: { distSq(lines[$0].bounds, point) < distSq(lines[$1].bounds, point) }), distSq(lines[closest].bounds, point) <= 120 * 120 {
            at = closest
        } else {
            return nil
        }
        func connected(_ upper: ScreenWord, _ lower: ScreenWord) -> Bool {
            let a = upper.bounds, b = lower.bounds
            let overlap = max(0, min(a.maxX,b.maxX) - max(a.minX,b.minX))
            return abs(a.height-b.height) < max(a.height,b.height) * 0.7 && a.midY > b.midY && a.minY-b.maxY < max(a.height,b.height)*2.0 && (overlap > min(a.width,b.width)*0.3 || abs(a.minX-b.minX) < 32)
        }
        func ends(_ text: String) -> Bool { text.range(of: "[。！？.!?][”’\\\"']*$", options: .regularExpression) != nil }
        var first = at, last = at
        while first > 0 && at-first < 6 && !ends(lines[first-1].text) && connected(lines[first-1],lines[first]) { first -= 1 }
        while last+1 < lines.count && last-at < 6 && !ends(lines[last].text) && connected(lines[last],lines[last+1]) { last += 1 }
        let group = Array(lines[first...last]), text = joined(group)
        let prefix = joined(Array(lines[first..<at]))
        var offset = prefix.utf16.count
        if !prefix.isEmpty { offset = joined(Array(lines[first...at])).utf16.count - lines[at].text.utf16.count }
        let line = lines[at]
        let lineWords = words.filter { $0.lineIndex == line.lineIndex }
        let hitWord = word(at: point, in: lineWords)
        if let hitWord {
            offset += hitWord.utf16Offset
        } else if line.bounds.width > 0 {
            let ratio = max(0, min(1, (point.x - line.bounds.minX) / line.bounds.width))
            offset += Int(round(Double(line.text.utf16.count) * Double(ratio)))
        }
        let tokenizer = NLTokenizer(unit: .sentence); tokenizer.string = text
        let index = String.Index(utf16Offset: min(max(0,offset),max(0,text.utf16.count-1)), in: text)
        let range = tokenizer.tokenRange(at: index)
        let extracted = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = !extracted.isEmpty ? extracted : (line.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? text : line.text)
        guard !value.isEmpty else { return nil }
        let groupBounds = group.dropFirst().reduce(group[0].bounds) { $0.union($1.bounds) }
        return ScreenWord(text: value, context: text, bounds: groupBounds, kind: .sentence)
    }
    static func paragraph(at point: CGPoint, lines: [ScreenWord]) -> ScreenWord? {
        guard !lines.isEmpty else { return nil }
        let at = lines.firstIndex { $0.bounds.insetBy(dx: -8, dy: -8).contains(point) }
            ?? lines.indices.filter({ distSq(lines[$0].bounds, point) <= 32 * 32 }).min(by: { distSq(lines[$0].bounds, point) < distSq(lines[$1].bounds, point) })
        guard let at else { return nil }
        func connected(_ upper: ScreenWord, _ lower: ScreenWord) -> Bool {
            let a = upper.bounds, b = lower.bounds
            let overlap = max(0, min(a.maxX,b.maxX) - max(a.minX,b.minX))
            return abs(a.height-b.height) < max(a.height,b.height) * 0.8 && a.midY > b.midY && a.minY-b.maxY < max(a.height,b.height)*2.0 && (overlap > min(a.width,b.width)*0.2 || abs(a.minX-b.minX) < 36)
        }
        var first = at, last = at
        while first > 0 && at-first < 12 && connected(lines[first-1], lines[first]) { first -= 1 }
        while last+1 < lines.count && last-at < 12 && connected(lines[last], lines[last+1]) { last += 1 }
        let group = Array(lines[first...last])
        let text = group.map(\.text).joined(separator: "\n")
        let bounds = group.dropFirst().reduce(group[0].bounds) { $0.union($1.bounds) }
        return ScreenWord(text: String(text.prefix(16000)), context: String(text.prefix(16000)), bounds: bounds, kind: .area)
    }
    static func area(_ rect: CGRect, words: [ScreenWord]) -> ScreenWord? {
        let chosen = words.filter { rect.contains(CGPoint(x: $0.bounds.midX,y: $0.bounds.midY)) }
        guard !chosen.isEmpty else { return nil }
        let byLine: [Int: [ScreenWord]] = Dictionary(grouping: chosen,by: { $0.lineIndex })
        var grouped: [ScreenWord] = []
        for line in byLine.values {
            let sorted = line.sorted { $0.bounds.minX < $1.bounds.minX }
            let first = sorted[0], last = sorted[sorted.count-1]
            let original = first.context as NSString
            var end = min(original.length,last.utf16Offset+last.text.utf16.count)
            if end < original.length && original.substring(from: end).rangeOfCharacter(from: .letters.union(.decimalDigits)) == nil { end = original.length }
            let start = min(first.utf16Offset,end)
            let text = original.substring(with: NSRange(location: start,length: end-start))
            let bounds = sorted.dropFirst().reduce(first.bounds) { $0.union($1.bounds) }
            grouped.append(ScreenWord(text: text,context: text,bounds: bounds))
        }
        grouped.sort { a,b in
            let separateRows = abs(a.bounds.midY-b.bounds.midY) > min(a.bounds.height,b.bounds.height)*0.5
            return separateRows ? a.bounds.midY > b.bounds.midY : a.bounds.minX < b.bounds.minX
        }
        let text = grouped.map(\.text).joined(separator: "\n")
        return ScreenWord(text: String(text.prefix(16000)), context: String(text.prefix(16000)), bounds: rect, kind: .area)
    }
}
enum SelectionOCR {
    static func words(in image: CGImage, screen: CGRect, request: VNRecognizeTextRequest = VNRecognizeTextRequest()) throws -> [ScreenWord] { try page(in: image,screen: screen,request: request).words }
    static func page(in image: CGImage, screen: CGRect, request: VNRecognizeTextRequest = VNRecognizeTextRequest()) throws -> OCRPage {
        request.recognitionLevel = .accurate; request.usesLanguageCorrection = false; request.automaticallyDetectsLanguage = true
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "vi-VT", "pl-PL"].filter { supported.contains($0) }
        try VNImageRequestHandler(cgImage: image).perform([request])
        var words: [ScreenWord] = [], lines: [ScreenWord] = []
        for (lineIndex, observation) in (request.results ?? []).enumerated() {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            lines.append(ScreenWord(text: text, context: text,bounds: SelectionGeometry.screenRect(observation.boundingBox,in: screen),lineIndex: lineIndex))
            let tokenizer = NLTokenizer(unit: .word); tokenizer.string = text
            if text.range(of: "\\p{Han}", options: .regularExpression) != nil { tokenizer.setLanguage(.simplifiedChinese) }
            var addedOnLine = 0
            let lineRect = SelectionGeometry.screenRect(observation.boundingBox, in: screen)
            let totalLen = max(1, text.utf16.count)
            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
                let token = String(text[range])
                guard token.rangeOfCharacter(from: .letters.union(.decimalDigits)) != nil else { return true }
                let rect: CGRect
                if let box = try? candidate.boundingBox(for: range) {
                    rect = SelectionGeometry.screenRect(box.boundingBox, in: screen)
                } else {
                    let offset = NSRange(range, in: text).location
                    let startRatio = CGFloat(offset) / CGFloat(totalLen)
                    let lenRatio = CGFloat(token.utf16.count) / CGFloat(totalLen)
                    let estX = lineRect.minX + startRatio * lineRect.width
                    let estWidth = max(6, lenRatio * lineRect.width)
                    rect = CGRect(x: estX, y: lineRect.minY, width: estWidth, height: lineRect.height)
                }
                if rect.width > 0 && rect.height > 0 {
                    words.append(ScreenWord(text: token, context: text, bounds: rect, lineIndex: lineIndex, utf16Offset: NSRange(range, in: text).location))
                    addedOnLine += 1
                }
                return true
            }
            if addedOnLine == 0 && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                words.append(ScreenWord(text: text, context: text, bounds: lineRect, lineIndex: lineIndex, utf16Offset: 0))
            }
        }
        return OCRPage(words: words,lines: lines)
    }
}

@MainActor final class ScreenSelection {
    private(set) var active = false
    private(set) var selected: ScreenWord?
    private(set) var mode: CaptureKind = .word
    private var generation = UUID()
    private var panels: [NSPanel] = []
    private var views: [SelectionSurface] = []
    private var words: [ScreenWord] = [], lines: [ScreenWord] = []
    private var pendingClick: CGPoint?, pendingRegion: CGRect?
    private var keyboardIndex: Int?
    private var job: Task<Void, Never>?
    private let escape = GlobalShortcut(signature: 0x4B4C4553)
    var onSelect: ((ScreenWord) -> Void)?
    var onStatus: ((String) -> Void)?
    var onHighlight: ((CGRect?) -> Void)?
    var onDismiss: (() -> Void)?
    func toggle(mode: CaptureKind = .word) {
        if active { let same = self.mode == mode; cancel(); if same { return } }
        guard CGPreflightScreenCaptureAccess() else { onStatus?("Allow Screen Recording in Kamihi Lens → Settings to select screen text."); return }
        escape.activate = { [weak self] in self?.cancel() }
        guard escape.register(choice: "Escape") == 0 else { onStatus?("Escape is reserved by another app. Resolve the shortcut conflict and try again."); return }
        self.mode = mode; active = true; selected = nil; words = []; lines = []; pendingClick = nil; pendingRegion = nil; keyboardIndex = nil
        for panel in panels {
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }
        panels = []; views = []
        generation = UUID(); let id = generation
        let screens = NSScreen.screens
        guard !screens.isEmpty else { cancel(); return }
        let pointerScreen = screens.firstIndex { $0.frame.contains(NSEvent.mouseLocation) } ?? 0
        let displayOrder = [pointerScreen] + screens.indices.filter { $0 != pointerScreen }
        for screen in screens {
            let panel = SelectionPanel(contentRect: screen.frame,styleMask: [.borderless,.nonactivatingPanel],backing: .buffered,defer: false)
            panel.title = "Kamihi Lens selection \(panels.count+1)"; panel.animationBehavior = .none; panel.becomesKeyOnlyIfNeeded = false
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.level = .screenSaver; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.stationary]
            let view = SelectionSurface(frame: CGRect(origin: .zero,size: screen.frame.size)); view.mode = mode
            view.onMove = { [weak self] point in self?.hover(point) }; view.onClick = { [weak self] point in self?.choose(point) }
            view.onRegion = { [weak self] rect in self?.chooseArea(rect) }; view.onCancel = { [weak self] in self?.cancel() }
            view.onMode = { [weak self] mode in self?.switchMode(mode) }
            view.onStep = { [weak self] step in self?.stepWord(step) }; view.onConfirm = { [weak self] in self?.confirmWord() }
            view.setAccessibilityElement(true); view.setAccessibilityRole(.group); view.setAccessibilityLabel("\(mode.title) selection")
            view.setAccessibilityHelp(mode == .area ? "Drag an area. Space selects this display. Escape cancels." : "Click text, or use arrows then Return. Escape cancels.")
            panel.contentView = view; panel.setFrame(screen.frame,display: true); panel.makeFirstResponder(view); panel.orderFrontRegardless()
            panels.append(panel); views.append(view)
        }
        panels[pointerScreen].makeKey(); onStatus?("\(mode.title) selection · Escape cancels")
        let excludedIDs = Set(panels.map { CGWindowID($0.windowNumber) })
        job = Task { @MainActor [weak self] in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly: true)
                guard let self, self.active, self.generation == id else { return }
                for index in displayOrder {
                    let screen = screens[index]; try Task.checkCancellation()
                    guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                          let display = content.displays.first(where: { $0.displayID == displayID }) else { continue }
                    let filter = SCContentFilter(display: display,excludingWindows: content.windows.filter { excludedIDs.contains($0.windowID) }); filter.includeMenuBar = true
                    let config = SCStreamConfiguration(); config.width = Int(screen.frame.width*screen.backingScaleFactor); config.height = Int(screen.frame.height*screen.backingScaleFactor); config.showsCursor = false
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter,configuration: config)
                    guard self.active, self.generation == id else { return }
                    self.views[index].image = NSImage(cgImage: image,size: screen.frame.size)
                    let frame = screen.frame, request = VNRecognizeTextRequest()
                    var page = try await withTaskCancellationHandler {
                        try Task.checkCancellation()
                        return try await Task.detached(priority: .userInitiated) { try SelectionOCR.page(in: image,screen: frame,request: request) }.value
                    } onCancel: { request.cancel() }
                    guard self.active, self.generation == id else { return }
                    let base = self.lines.count
                    for i in page.words.indices { page.words[i].lineIndex += base }
                    for i in page.lines.indices { page.lines[i].lineIndex += base }
                    self.words += page.words; self.lines += page.lines
                    if let rect = self.pendingRegion, frame.contains(CGPoint(x: rect.midX,y: rect.midY)) { self.chooseArea(rect) }
                    else if let point = self.pendingClick, frame.contains(point) { self.choose(point) }
                    else { self.hover(NSEvent.mouseLocation) }
                    if self.selected != nil { return }
                }
                guard self.active, self.generation == id else { return }
                if self.words.isEmpty { self.hint("No readable text · Escape cancels") }
            } catch {
                guard let self, self.active, self.generation == id else { return }
                self.onStatus?("Screen text unavailable: \(error.localizedDescription)"); self.cancel(clearStatus: false)
            }
        }
    }
    private func switchMode(_ kind: CaptureKind) {
        guard active, selected == nil else { return }
        mode = kind; pendingClick = nil; pendingRegion = nil; keyboardIndex = nil
        for view in views {
            view.mode = kind; view.preview = nil; view.status = ""
            view.setAccessibilityLabel("\(kind.title) selection")
            view.setAccessibilityHelp("Choose Word, Sentence or Section. Click text or drag a section. Escape cancels.")
            view.needsDisplay = true; view.window?.makeFirstResponder(view)
        }
        onStatus?("\(kind.title) selection · Escape cancels")
    }
    private func hint(_ text: String) { onStatus?(text); for view in views { view.status = text; view.needsDisplay = true } }
    private func target(_ point: CGPoint) -> ScreenWord? {
        mode == .sentence ? SelectionGeometry.sentence(at: point,words: words,lines: lines) : SelectionGeometry.word(at: point,in: words)
    }
    private func hover(_ point: CGPoint) { guard active, selected == nil, mode != .area else { return }; keyboardIndex = nil; preview(target(point)) }
    private func preview(_ word: ScreenWord?) { for view in views { view.preview = word?.bounds; view.needsDisplay = true; view.setAccessibilityValue(word?.text ?? "Choose text") } }
    private func stepWord(_ step: Int) {
        guard active, selected == nil, !words.isEmpty, mode != .area else { return }
        let index = keyboardIndex.map { ($0+step+words.count)%words.count } ?? (step > 0 ? 0 : words.count-1)
        keyboardIndex = index; let rect = words[index].bounds; preview(target(CGPoint(x: rect.midX,y: rect.midY)))
    }
    private func confirmWord() { guard let index = keyboardIndex, words.indices.contains(index) else { return }; let r = words[index].bounds; choose(CGPoint(x: r.midX,y: r.midY)) }
    private func choose(_ point: CGPoint) {
        guard active, selected == nil else { return }
        if mode == .area {
            if let paragraph = SelectionGeometry.paragraph(at: point, lines: lines) {
                finish(paragraph)
                return
            }
        }
        if let word = target(point) {
            finish(word)
            return
        }
        if job != nil {
            pendingClick = point
            return
        }
        if mode == .sentence, let closestLine = lines.min(by: { SelectionGeometry.distSq($0.bounds, point) < SelectionGeometry.distSq($1.bounds, point) }), SelectionGeometry.distSq(closestLine.bounds, point) <= 120 * 120 {
            finish(ScreenWord(text: closestLine.text, context: closestLine.text, bounds: closestLine.bounds, kind: .sentence))
            return
        } else if let closestWord = words.min(by: { SelectionGeometry.distSq($0.bounds, point) < SelectionGeometry.distSq($1.bounds, point) }), SelectionGeometry.distSq(closestWord.bounds, point) <= 120 * 120 {
            finish(closestWord)
            return
        }
        cancel()
    }
    private func chooseArea(_ rect: CGRect) {
        guard active, selected == nil else { return }
        guard let result = SelectionGeometry.area(rect,words: words) else { pendingRegion = rect; hint("No text here yet · try another area or wait a moment"); return }
        finish(result)
    }
    private func finish(_ result: ScreenWord) {
        selected = result; active = false; escape.unregister()
        pendingClick = nil; pendingRegion = nil; generation = UUID(); job?.cancel(); job = nil
        for panel in panels {
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }
        panels = []; views = []; words = []; lines = []
        onHighlight?(result.bounds); onSelect?(result); onStatus?("\(result.kind.title) translated near your cursor · Escape dismisses")
    }
    func cancel(clearStatus: Bool = true, notify: Bool = true) {
        let wasActive = active
        generation = UUID(); job?.cancel(); job = nil; escape.unregister(); active = false; selected = nil
        pendingClick = nil; pendingRegion = nil; words = []; lines = []; keyboardIndex = nil
        for panel in panels {
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
        }
        panels = []; views = []; onHighlight?(nil)
        if notify && wasActive { onDismiss?() }
        if clearStatus && wasActive { onStatus?("Ready · choose a word, sentence or screen area") }
    }
}
private final class SelectionPanel: NSPanel { override var canBecomeKey: Bool { true }; override var canBecomeMain: Bool { false } }
private final class SelectionSurface: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var mode: CaptureKind = .word { didSet { refreshToolbar() } }
    private var dragging = false
    private lazy var toolbar = NSHostingView(rootView: toolbarView)
    private var toolbarView: SelectionToolbar { SelectionToolbar(mode: mode,select: { [weak self] in self?.onMode?($0) },cancel: { [weak self] in self?.onCancel?() }) }
    private func refreshToolbar() { toolbar.rootView = toolbarView }
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); addSubview(toolbar) }
    required init?(coder: NSCoder) { nil }
    override func layout() { super.layout(); let width = min(610,bounds.width-32); toolbar.frame = CGRect(x: (bounds.width-width)/2,y: bounds.height-116,width: width,height: 88) }
    var onMode: ((CaptureKind)->Void)?
    var preview: CGRect?, anchor: CGPoint?
    var status = ""
    var onMove: ((CGPoint)->Void)?, onClick: ((CGPoint)->Void)?, onRegion: ((CGRect)->Void)?
    var onCancel: (()->Void)?, onStep: ((Int)->Void)?, onConfirm: (()->Void)?
    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds,cursor: .crosshair) }
    override func updateTrackingAreas() { super.updateTrackingAreas(); trackingAreas.forEach(removeTrackingArea); addTrackingArea(NSTrackingArea(rect: bounds,options: [.mouseMoved,.activeAlways,.inVisibleRect,.cursorUpdate],owner: self)) }
    private func point(_ event: NSEvent) -> CGPoint { window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation }
    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }
    override func mouseMoved(with event: NSEvent) { onMove?(point(event)) }
    override func mouseDown(with event: NSEvent) {
        anchor = point(event); dragging = false; preview = nil; needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) {
        guard let anchor, let frame = window?.frame else { return }
        let p = point(event)
        guard abs(p.x-anchor.x) > 6 || abs(p.y-anchor.y) > 6 else { return }
        dragging = true
        preview = CGRect(x: min(p.x,anchor.x),y: min(p.y,anchor.y),width: abs(p.x-anchor.x),height: abs(p.y-anchor.y)).intersection(frame); needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        defer { anchor = nil; dragging = false }
        if dragging, let rect = preview, rect.width > 6, rect.height > 6 { onRegion?(rect) }
        else { onClick?(point(event)) }
    }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 18: onMode?(.word)
        case 19: onMode?(.sentence)
        case 20: onMode?(.area)
        case 53: onCancel?()
        case 123,126: onStep?(-1)
        case 124,125: onStep?(1)
        case 48: onStep?(event.modifierFlags.contains(.shift) ? -1 : 1)
        case 36,76: if mode == .area, let frame = preview ?? window?.frame { onRegion?(frame) } else { onConfirm?() }
        case 49: if mode == .area && event.modifierFlags.intersection([.command,.control,.option]).isEmpty, let frame = window?.frame { onRegion?(frame) }
        default: break
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        image?.draw(in: bounds)
        if let preview, let window {
            let rect = window.convertFromScreen(preview).insetBy(dx: -2,dy: -1)
            let path = NSBezierPath(roundedRect: rect,xRadius: 3,yRadius: 3)
            if mode == .area || dragging {
                let outside = NSBezierPath(rect: bounds); outside.append(NSBezierPath(rect: rect)); outside.windingRule = .evenOdd
                NSColor.black.withAlphaComponent(0.18).setFill(); outside.fill()
            } else { NSColor.controlAccentColor.withAlphaComponent(0.13).setFill(); path.fill() }
            NSColor.controlAccentColor.setStroke(); path.lineWidth = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 2 : 1; path.stroke()
        }
        guard !status.isEmpty else { return }
        let message = status
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12,weight: .medium),.foregroundColor: NSColor.labelColor]
        let size = (message as NSString).size(withAttributes: attrs)
        let rect = CGRect(x: max(12,(bounds.width-size.width-24)/2),y: 24,width: min(bounds.width-24,size.width+24),height: 32)
        NSColor.windowBackgroundColor.setFill(); NSBezierPath(roundedRect: rect,xRadius: 10,yRadius: 10).fill()
        (message as NSString).draw(at: CGPoint(x: rect.minX+12,y: rect.minY+8),withAttributes: attrs)
    }
}
private struct SelectionToolbar: View {
    let mode: CaptureKind
    let select: (CaptureKind)->Void
    let cancel: ()->Void
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach([CaptureKind.word,.sentence,.area],id: \.self) { kind in
                    Button { select(kind) } label: { Label(kind == .area ? "Section" : kind.title,systemImage: kind.symbol).frame(maxWidth: .infinity,minHeight: 30).contentShape(Rectangle()) }.buttonStyle(LensRowStyle(selected: mode == kind)).accessibilityAddTraits(mode == kind ? .isSelected : [])
                }
                Button(action: cancel) { Image(systemName: "xmark").frame(width: 28,height: 30) }.buttonStyle(.plain).accessibilityLabel("Cancel selection")
            }.font(.system(size: 12,weight: .medium))
            Text(mode == .area ? "Drag around a paragraph or section · Space: whole display · Esc: cancel" : mode == .sentence ? "Click anywhere in a sentence · Or drag a section · Esc: cancel" : "Click a word · Or drag a section · Esc: cancel").font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(12).background(Color.lensCanvas,in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.lensLine,lineWidth: 1)).tint(.lensAccent)
    }
}
struct SelectionHighlight: View {
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View { RoundedRectangle(cornerRadius: 3).fill(Color.accentColor.opacity(contrast == .increased ? 0.24 : 0.13)).overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.accentColor,lineWidth: contrast == .increased ? 2 : 1)) }
}
