import AppKit
import NaturalLanguage
import ApplicationServices
import Carbon

struct TranslationRequest: Equatable {
    let id = UUID()
    let text: String
    let target: String
    var kind: CaptureKind = .typed
    var context: String = ""
    var sourceLanguage: String?
    var sourcePreference = "auto"
    var quality = "fast"
}
struct CapturedTarget: Sendable {
    let text: String
    let context: String
    let bounds: CGRect?
}
enum LookupGeometry {
    // AX uses global points, top-left of the primary display; AppKit uses bottom-left.
    static func axPoint(_ point: CGPoint, primaryTop: CGFloat) -> CGPoint { CGPoint(x: point.x, y: primaryTop - point.y) }
    static func appKitRect(_ rect: CGRect, primaryTop: CGFloat) -> CGRect { CGRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height) }
    static func panelFrame(pointer: CGPoint, size: CGSize, visible: CGRect) -> CGRect {
        let width = min(size.width, visible.width - 16), height = min(size.height, visible.height - 16)
        let x = min(max(pointer.x + 14, visible.minX + 8), visible.maxX - width - 8)
        let preferredY = pointer.y - height - 16
        let y = preferredY < visible.minY + 8 ? min(pointer.y + 20, visible.maxY - height - 8) : preferredY
        return CGRect(x: x, y: min(max(y, visible.minY + 8), visible.maxY - height - 8), width: width, height: height)
    }
    static func wordRange(_ text: String, utf16Offset: Int) -> NSRange? {
        guard utf16Offset >= 0, utf16Offset < text.utf16.count else { return nil }
        let tokenizer = NLTokenizer(unit: .word); tokenizer.string = text
        if text.range(of: "\\p{Han}", options: .regularExpression) != nil { tokenizer.setLanguage(.simplifiedChinese) }
        let index = String.Index(utf16Offset: utf16Offset, in: text)
        let range = tokenizer.tokenRange(at: index)
        guard range.contains(index), !text[range].trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).isEmpty else { return nil }
        return NSRange(range, in: text)
    }
    static func preferSelection(_ range: CFRange, pointerOffset: Int) -> Bool { range.length > 0 && pointerOffset >= range.location && pointerOffset < range.location + range.length }
}
enum TargetCapture {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    static func parameter(_ element: AXUIElement, _ name: String, _ value: CFTypeRef) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyParameterizedAttributeValue(element, name as CFString, value, &result) == .success ? result : nil
    }
    static func range(_ value: CFTypeRef?) -> CFRange? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange(); guard AXValueGetValue(unsafeBitCast(value, to: AXValue.self), .cfRange, &range) else { return nil }; return range
    }
    static func protected(_ element: AXUIElement) -> Bool {
        var current: AXUIElement? = element
        for _ in 0..<12 {
            guard let node = current else { break }
            if (attribute(node, kAXSubroleAttribute) as? String) == kAXSecureTextFieldSubrole { return true }
            guard let parent = attribute(node, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            current = unsafeBitCast(parent, to: AXUIElement.self)
        }
        return false
    }
    static func string(_ element: AXUIElement, _ range: CFRange) -> String? {
        var range = range; guard let query = AXValueCreate(.cfRange, &range) else { return nil }
        return parameter(element, kAXStringForRangeParameterizedAttribute, query) as? String
    }
    static func bounds(_ element: AXUIElement, _ range: CFRange) -> CGRect? {
        var range = range; guard let query = AXValueCreate(.cfRange, &range), let value = parameter(element, kAXBoundsForRangeParameterizedAttribute, query), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(unsafeBitCast(value, to: AXValue.self), .cgRect, &rect), rect.width > 0, rect.height > 0, rect.width < 10000, rect.height < 10000 else { return nil }; return rect
    }
    static func capture(point: CGPoint, primaryTop: CGFloat, pid: pid_t, selectionOnly: Bool = false) throws -> CapturedTarget {
        guard AXIsProcessTrusted() else { throw LocalModelError.message("Allow Kamihi Lens in System Settings → Privacy & Security → Accessibility. Paste text works without access.") }
        let app = AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(app, 0.35)
        var found: AXUIElement?
        let axPoint = LookupGeometry.axPoint(point, primaryTop: primaryTop)
        if selectionOnly {
            if let raw = attribute(app, kAXFocusedUIElementAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID() { found = unsafeBitCast(raw, to: AXUIElement.self) }
        } else {
            let system = AXUIElementCreateSystemWide(); AXUIElementSetMessagingTimeout(system, 0.35)
            _ = AXUIElementCopyElementAtPosition(system, Float(axPoint.x), Float(axPoint.y), &found)
            if let found {
                var actualPID: pid_t = 0; _ = AXUIElementGetPid(found, &actualPID)
                guard actualPID != ProcessInfo.processInfo.processIdentifier else { throw LocalModelError.message("Point at text in another application, or type in the full app.") }
            }
        }
        guard let first = found else { throw LocalModelError.message("This app exposes no text here. Select text and use Capture selected text, paste it, or explicitly choose Screen area OCR.") }
        AXUIElementSetMessagingTimeout(first, 0.35)
        guard !protected(first) else { throw LocalModelError.message("Protected text cannot be captured.") }
        var element = first
        for _ in 0..<4 {
            guard !protected(element) else { throw LocalModelError.message("Protected text cannot be captured.") }
            var queryPoint = axPoint
            let position = AXValueCreate(.cgPoint, &queryPoint)!
            let hit = range(parameter(element, kAXRangeForPositionParameterizedAttribute, position))
            let selection = range(attribute(element, kAXSelectedTextRangeAttribute))
            if let selection, selection.length <= 4000, (selectionOnly || hit.map { LookupGeometry.preferSelection(selection, pointerOffset: $0.location) } == true),
               let text = string(element, selection) ?? attribute(element, kAXSelectedTextAttribute) as? String, !text.isEmpty {
                let rect = bounds(element, selection).map { LookupGeometry.appKitRect($0, primaryTop: primaryTop) }
                return CapturedTarget(text: text, context: text, bounds: rect)
            }
            if !selectionOnly, let hit, hit.location >= 0 {
                let total = (attribute(element, kAXNumberOfCharactersAttribute) as? NSNumber)?.intValue ?? (hit.location + 128)
                let start = max(0, hit.location - 128), length = max(0, min(256, total - start))
                if let fragment = string(element, CFRange(location: start, length: length)), let token = LookupGeometry.wordRange(fragment, utf16Offset: hit.location - start) {
                    let range = CFRange(location: start + token.location, length: token.length)
                    let rect = bounds(element, range).map { LookupGeometry.appKitRect($0, primaryTop: primaryTop) }
                    // Reject nearest-word guesses outside the actual glyph bounds.
                    if let rect, !rect.insetBy(dx: -3, dy: -3).contains(point) { throw LocalModelError.message("The pointer is outside readable text. Point directly at a word, or select text explicitly.") }
                    return CapturedTarget(text: (fragment as NSString).substring(with: token), context: fragment, bounds: rect)
                }
            }
            guard let parent = attribute(element, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            element = unsafeBitCast(parent, to: AXUIElement.self)
        }
        throw LocalModelError.message("No accurately targeted word is available. Select text, paste it, or choose Screen area OCR. No screen was captured.")
    }
}

struct ShortcutLatch {
    private(set) var held = false
    mutating func press() -> Bool { if held { return false }; held = true; return true }
    mutating func release() { held = false }
}
@MainActor final class GlobalShortcut {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var latch = ShortcutLatch()
    private let signature: OSType
    init(signature: OSType = 0x4D4C454E) { self.signature = signature }
    var activate: (() -> Void)?
    var registered = false
    func register(choice: String) -> OSStatus {
        unregister()
        var specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)), EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let context = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let shortcut = Unmanaged<GlobalShortcut>.fromOpaque(context).takeUnretainedValue()
                var key = EventHotKeyID()
                guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &key) == noErr,
                      key.signature == shortcut.signature else { return OSStatus(eventNotHandledErr) }
                if GetEventKind(event) == UInt32(kEventHotKeyReleased) { shortcut.latch.release() }
                else if shortcut.latch.press() { shortcut.activate?() }
                return noErr
            }
        }, 2, &specs, context, &handler)
        guard handlerStatus == noErr else { return handlerStatus }
        let flags = choice == "Escape" ? UInt32(0) : choice == "Control–Space" ? UInt32(controlKey) : choice == "Control–Shift–Space" ? UInt32(controlKey | shiftKey) : (choice == "Control–Option–Space" || choice == "Control–Option–N") ? UInt32(controlKey | optionKey) : choice == "Option–Shift–Space" ? UInt32(optionKey | shiftKey) : UInt32(optionKey)
        let status = RegisterEventHotKey(UInt32(choice == "Escape" ? kVK_Escape : choice == "Control–Option–N" ? kVK_ANSI_N : kVK_Space), flags, EventHotKeyID(signature: signature, id: 1), GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
        registered = status == noErr
        if !registered { unregister() }
        return status
    }
    func releasePressedState() { latch.release() }
    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }; reference = nil
        if let handler { RemoveEventHandler(handler) }; handler = nil; latch.release(); registered = false
    }
}
