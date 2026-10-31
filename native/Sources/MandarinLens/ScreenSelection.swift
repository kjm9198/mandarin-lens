import AppKit
import SwiftUI
import Vision
import NaturalLanguage
import ScreenCaptureKit

struct ScreenWord: Equatable, Sendable {
    let text: String
    let context: String
    let bounds: CGRect
}
enum SelectionGeometry {
    static func screenRect(_ normalized: CGRect, in screen: CGRect) -> CGRect {
        CGRect(x: screen.minX + normalized.minX * screen.width, y: screen.minY + normalized.minY * screen.height,
               width: normalized.width * screen.width, height: normalized.height * screen.height)
    }
    static func word(at point: CGPoint, in words: [ScreenWord]) -> ScreenWord? {
        // Do not guess the nearest word in blank space.
        words.filter { $0.bounds.insetBy(dx: -2, dy: -2).contains(point) }
            .min { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
    }
}
enum SelectionOCR {
    static func words(in image: CGImage, screen: CGRect, request: VNRecognizeTextRequest = VNRecognizeTextRequest()) throws -> [ScreenWord] {
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.automaticallyDetectsLanguage = true
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "vi-VN", "pl-PL"].filter { supported.contains($0) }
        try VNImageRequestHandler(cgImage: image).perform([request])
        var words: [ScreenWord] = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string
            let tokenizer = NLTokenizer(unit: .word); tokenizer.string = text
            if text.range(of: "\\p{Han}", options: .regularExpression) != nil { tokenizer.setLanguage(.simplifiedChinese) }
            tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
                let token = String(text[range])
                guard token.rangeOfCharacter(from: .letters.union(.decimalDigits)) != nil,
                      let box = try? candidate.boundingBox(for: range) else { return true }
                let rect = SelectionGeometry.screenRect(box.boundingBox, in: screen)
                if rect.width > 0 && rect.height > 0 { words.append(ScreenWord(text: token, context: text, bounds: rect)) }
                return true
            }
        }
        return words
    }
}

@MainActor final class ScreenSelection {
    private(set) var active = false
    private(set) var selected: ScreenWord?
    private var generation = UUID()
    private var panels: [NSPanel] = []
    private var views: [SelectionSurface] = []
    private var words: [ScreenWord] = []
    private var pendingClick: CGPoint?
    private var keyboardIndex: Int?
    private var job: Task<Void, Never>?
    private let escape = GlobalShortcut(signature: 0x4B4C4553)
    var onSelect: ((ScreenWord) -> Void)?
    var onStatus: ((String) -> Void)?
    var onHighlight: ((CGRect?) -> Void)?

    func toggle() {
        if active { cancel(); return }
        guard CGPreflightScreenCaptureAccess() else {
            onStatus?("Allow Screen Recording in Kamihi Lens → Settings to select words in images and other apps.")
            return
        }
        escape.activate = { [weak self] in self?.cancel() }
        guard escape.register(choice: "Escape") == 0 else {
            onStatus?("Escape is reserved by another app. Close that shortcut conflict and try selection again.")
            return
        }
        active = true; selected = nil; words = []; pendingClick = nil; keyboardIndex = nil
        generation = UUID(); let id = generation
        let screens = NSScreen.screens
        guard !screens.isEmpty else { active = false; escape.unregister(); onStatus?("No display is available for selection."); return }
        let pointerScreen = screens.firstIndex { $0.frame.contains(NSEvent.mouseLocation) } ?? 0
        let displayOrder = [pointerScreen] + screens.indices.filter { $0 != pointerScreen }
        for screen in screens {
            let panel = SelectionPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.title = "Kamihi Lens selection \(panels.count + 1)"
            panel.animationBehavior = .none
            panel.becomesKeyOnlyIfNeeded = false
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.level = .screenSaver; panel.hidesOnDeactivate = false; panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            let view = SelectionSurface(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.onMove = { [weak self] point in self?.hover(point) }
            view.onClick = { [weak self] point in self?.choose(point) }
            view.setAccessibilityElement(true)
            view.setAccessibilityRole(.group)
            view.setAccessibilityLabel("Screen text selection")
            view.setAccessibilityHelp("Click a word, or use arrow keys then Return. Escape cancels.")
            view.onCancel = { [weak self] in self?.cancel() }
            view.onStep = { [weak self] step in self?.stepWord(step) }
            view.onConfirm = { [weak self] in self?.confirmWord() }
            panel.contentView = view; panel.setFrame(screen.frame, display: true)
            panel.makeFirstResponder(view); panel.orderFrontRegardless(); panels.append(panel); views.append(view)
        }
        if let index = screens.firstIndex(where: { $0.frame.contains(NSEvent.mouseLocation) }) { panels[index].makeKey() }
        onStatus?("Selection mode · click a word · Escape or the shortcut cancels")
        let excludedIDs = Set(panels.map { CGWindowID($0.windowNumber) })
        job = Task { @MainActor [weak self] in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let self, self.active, self.generation == id else { return }
                // Capture once per activation. Pixels are held in memory only until a word is chosen or cancelled.
                for index in displayOrder {
                    let screen = screens[index]
                    try Task.checkCancellation()
                    guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
                          let display = content.displays.first(where: { $0.displayID == displayID }) else { continue }
                    let filter = SCContentFilter(display: display, excludingWindows: content.windows.filter { excludedIDs.contains($0.windowID) })
                    filter.includeMenuBar = true
                    let config = SCStreamConfiguration()
                    config.width = Int(screen.frame.width * screen.backingScaleFactor)
                    config.height = Int(screen.frame.height * screen.backingScaleFactor)
                    config.showsCursor = false
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    guard self.active, self.generation == id else { return }
                    self.views[index].image = NSImage(cgImage: image, size: screen.frame.size)
                    let frame = screen.frame
                    let request = VNRecognizeTextRequest()
                    let found = try await withTaskCancellationHandler {
                        try Task.checkCancellation()
                        return try await Task.detached(priority: .userInitiated) { try SelectionOCR.words(in: image, screen: frame, request: request) }.value
                    } onCancel: { request.cancel() }
                    guard self.active, self.generation == id else { return }
                    self.words.append(contentsOf: found)
                    if let point = self.pendingClick, frame.contains(point) { self.choose(point) }
                    else { self.hover(NSEvent.mouseLocation) }
                    if self.selected != nil { return }
                }
                guard self.active, self.generation == id else { return }
                self.onStatus?(self.words.isEmpty ? "No readable words on this screen. Escape or the shortcut cancels." : "Selection mode · click a word · Escape or the shortcut cancels")
            } catch {
                guard let self, self.active, self.generation == id else { return }
                self.onStatus?("Screen text unavailable: \(error.localizedDescription). Check Screen Recording in Settings.")
                self.cancel(clearStatus: false)
            }
        }
    }
    private func hover(_ point: CGPoint) {
        guard active, selected == nil else { return }
        keyboardIndex = nil
        preview(SelectionGeometry.word(at: point, in: words))
    }
    private func preview(_ word: ScreenWord?) {
        for view in views {
            view.preview = word?.bounds; view.needsDisplay = true
            view.setAccessibilityValue(word?.text ?? "Move to a word, or use the arrow keys")
        }
    }
    private func stepWord(_ step: Int) {
        guard active, selected == nil, !words.isEmpty else { return }
        let index = keyboardIndex.map { ($0 + step + words.count) % words.count } ?? (step > 0 ? 0 : words.count - 1)
        keyboardIndex = index; preview(words[index])
    }
    private func confirmWord() {
        guard let index = keyboardIndex, words.indices.contains(index) else { return }
        let rect = words[index].bounds
        choose(CGPoint(x: rect.midX,y: rect.midY))
    }
    private func choose(_ point: CGPoint) {
        guard active, selected == nil else { return }
        guard let word = SelectionGeometry.word(at: point, in: words) else {
            pendingClick = point; return
        }
        selected = word; pendingClick = nil; generation = UUID(); job?.cancel(); job = nil
        // Return normal clicks to the source app; only a click-through outline stays visible.
        panels.forEach { $0.orderOut(nil) }; panels = []; views = []; words = []
        onSelect?(word); onHighlight?(word.bounds)
        onStatus?("Selected “\(word.text)” · open Kamihi Lens to translate · Escape or the shortcut clears the highlight")
    }
    func cancel(clearStatus: Bool = true) {
        let wasActive = active
        generation = UUID(); job?.cancel(); job = nil; escape.unregister()
        active = false; selected = nil; pendingClick = nil; words = []; keyboardIndex = nil
        panels.forEach { $0.orderOut(nil) }; panels = []; views = []
        onHighlight?(nil)
        if clearStatus && wasActive { onStatus?("Ready · press the shortcut to select a word") }
    }
}
private final class SelectionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
private final class SelectionSurface: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var preview: CGRect?
    var onMove: ((CGPoint) -> Void)?
    var onClick: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?
    var onStep: ((Int) -> Void)?
    var onConfirm: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self))
    }
    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }
    override func mouseMoved(with event: NSEvent) { onMove?(NSEvent.mouseLocation) }
    override func mouseDown(with event: NSEvent) { onClick?(NSEvent.mouseLocation) }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onCancel?()
        case 123, 126: onStep?(-1)
        case 124, 125: onStep?(1)
        case 48: onStep?(event.modifierFlags.contains(.shift) ? -1 : 1)
        case 36, 76: onConfirm?()
        default: break
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        image?.draw(in: bounds)
        guard let preview, let window else { return }
        let local = window.convertFromScreen(preview).insetBy(dx: -2, dy: -1)
        let path = NSBezierPath(roundedRect: local, xRadius: 3, yRadius: 3)
        let contrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        NSColor.controlAccentColor.withAlphaComponent(contrast ? 0.24 : 0.13).setFill(); path.fill()
        NSColor.controlAccentColor.withAlphaComponent(contrast ? 1 : 0.8).setStroke(); path.lineWidth = contrast ? 2 : 1; path.stroke()
    }
}

struct SelectionHighlight: SwiftUI.View {
    @SwiftUI.Environment(\.colorSchemeContrast) private var contrast
    var body: some SwiftUI.View {
        SwiftUI.RoundedRectangle(cornerRadius: 3)
            .fill(SwiftUI.Color.accentColor.opacity(contrast == .increased ? 0.24 : 0.13))
            .overlay(SwiftUI.RoundedRectangle(cornerRadius: 3).stroke(SwiftUI.Color.accentColor.opacity(contrast == .increased ? 1 : 0.8), lineWidth: contrast == .increased ? 2 : 1))
    }
}
