// Explicit native UI acceptance driver. Only operates the named app/window; no permission changes.
import AppKit
import ApplicationServices
import Darwin
func fail(_ message: String) -> Never { fputs(message + "\n", stderr); exit(1) }
let args = CommandLine.arguments
func value(_ key: String) -> String? { guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }; return args[i+1] }
func attr(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
 if key == kAXValueAttribute { var subrole: CFTypeRef?; _ = AXUIElementCopyAttributeValue(e,kAXSubroleAttribute as CFString,&subrole); if subrole as? String == kAXSecureTextFieldSubrole { return nil } }
 var v: CFTypeRef?; _ = AXUIElementCopyAttributeValue(e,key as CFString,&v); return v }
func children(_ e: AXUIElement)->[AXUIElement] { attr(e,kAXChildrenAttribute) as? [AXUIElement] ?? [] }
func all(_ e: AXUIElement,_ depth:Int=0)->[AXUIElement] { guard depth < 15 else {return []};return [e]+children(e).flatMap { all($0,depth+1) } }
guard AXIsProcessTrusted(), let bundle = value("--app"), let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundle }) else { fail("App missing or Accessibility not granted to this driver") }
if args.contains("--quit") { let requested=running.terminate(); for _ in 0..<100 { if running.isTerminated || kill(running.processIdentifier,0) != 0 { print("QUIT verified"); exit(0) }; RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }; fail(requested ? "Quit requested but process still running" : "Quit rejected") }
if args.contains("--screens") {
 let top=NSScreen.screens.first?.frame.maxY ?? 0
 let screens=NSScreen.screens.enumerated().map { index,s in ["index":index,"scale":s.backingScaleFactor,"visible":["X":s.visibleFrame.minX,"Y":top-s.visibleFrame.maxY,"Width":s.visibleFrame.width,"Height":s.visibleFrame.height]] as [String:Any] }
 let data=try JSONSerialization.data(withJSONObject:screens,options:[.sortedKeys]);print(String(decoding:data,as:UTF8.self));exit(0)
}
var lastPointer: CGPoint?
if args.contains("--frames") {
 let frames=(CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],0) as? [[String:Any]] ?? []).filter { $0[kCGWindowOwnerPID as String] as? Int == Int(running.processIdentifier) }.map { item in ["title":item[kCGWindowName as String] ?? "", "bounds":item[kCGWindowBounds as String] ?? [:], "alpha":item[kCGWindowAlpha as String] ?? 0, "layer":item[kCGWindowLayer as String] ?? 0] }
 let json=try JSONSerialization.data(withJSONObject:frames,options:[.sortedKeys]);print(String(decoding:json,as:UTF8.self));exit(0)
}
let app=AXUIElementCreateApplication(running.processIdentifier)
if args.contains("--activate") { running.activate(); for _ in 0..<30 { if running.isActive { break }; usleep(20000) } }
func findWindow() -> AXUIElement? {
 let windows=attr(app,kAXWindowsAttribute) as? [AXUIElement] ?? []
 return windows.first {
  guard let requested=value("--window") else { return true }
  let title=attr($0,kAXTitleAttribute) as? String ?? ""
  return title == requested || title.hasPrefix(requested + " ")
 }
}
var window=findWindow()
if window == nil && !args.contains("--absent-ok") {
 for _ in 0..<40 { usleep(20000); window=findWindow(); if window != nil { break } }
}
if window == nil && (args.contains("--dump") || value("--click") != nil || value("--text") != nil || value("--point") != nil) { fail("Named window is not available") }
if let window {
 let nodes=all(window)
 if let text=value("--type") {
  let fields=nodes.filter { [kAXTextAreaRole,kAXTextFieldRole].contains(attr($0,kAXRoleAttribute) as? String ?? "") }
  guard let field=fields.first(where: { value("--field") == nil || attr($0,kAXDescriptionAttribute) as? String == value("--field") }) else { fail("Field missing") }
  running.activate()
  for _ in 0..<50 { if NSWorkspace.shared.frontmostApplication?.processIdentifier == running.processIdentifier { break }; RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
  _ = AXUIElementSetAttributeValue(field,kAXFocusedAttribute as CFString,kCFBooleanTrue)
  RunLoop.current.run(until: Date().addingTimeInterval(0.03))
  guard NSWorkspace.shared.frontmostApplication?.processIdentifier == running.processIdentifier, (attr(field,kAXFocusedAttribute) as? NSNumber)?.boolValue == true else { fail("Target chat field is not verified focused; no keyboard input sent") }
  guard (attr(field,kAXValueAttribute) as? String ?? "").isEmpty else { fail("A draft is present; it was preserved and no keyboard input was sent") }
  let event=CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:true)!
  let utf16=Array(text.utf16); event.keyboardSetUnicodeString(stringLength:utf16.count,unicodeString:utf16); event.post(tap:.cghidEventTap)
  CGEvent(keyboardEventSource:nil,virtualKey:0,keyDown:false)?.post(tap:.cghidEventTap)
 }
 if let text=value("--text") {
  let fields=nodes.filter { [kAXTextAreaRole,kAXTextFieldRole].contains(attr($0,kAXRoleAttribute) as? String ?? "") }
  let field=fields.first { value("--field") == nil || attr($0,kAXDescriptionAttribute) as? String == value("--field") }
  guard let field else { fail("Field missing") }
  print("SET",AXUIElementSetAttributeValue(field,kAXValueAttribute as CFString,text as CFString).rawValue)
 }
 if let label=value("--click") {
  guard let node=(args.contains("--last") ? nodes.last(where: { e in [kAXTitleAttribute,kAXDescriptionAttribute,kAXValueAttribute].contains { attr(e,$0) as? String == label } }) : nodes.first(where: { e in [kAXTitleAttribute,kAXDescriptionAttribute,kAXValueAttribute].contains { attr(e,$0) as? String == label } })) else { fail("Control missing: \(label)") }
  print("PRESS",AXUIElementPerformAction(node,kAXPressAction as CFString).rawValue)
 }
 if let label=value("--point-element") {
  guard let node=nodes.first(where: { e in [kAXTitleAttribute,kAXDescriptionAttribute].contains { attr(e,$0) as? String == label } }), let rawPosition=attr(node,kAXPositionAttribute),let rawSize=attr(node,kAXSizeAttribute) else { fail("Element unavailable") }
  var p=CGPoint.zero,s=CGSize.zero
  _ = AXValueGetValue(unsafeBitCast(rawPosition,to:AXValue.self),.cgPoint,&p);_ = AXValueGetValue(unsafeBitCast(rawSize,to:AXValue.self),.cgSize,&s)
  let point=CGPoint(x:p.x+s.width/2,y:p.y+s.height/2);lastPointer=point;CGWarpMouseCursorPosition(point)
  CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:point,mouseButton:.left)?.post(tap:.cghidEventTap)
  print("POINT_ELEMENT",label,point)
 }
 if let term=value("--point") {
  guard let field=nodes.first(where: { attr($0,kAXRoleAttribute) as? String == kAXTextAreaRole }),let text=attr(field,kAXValueAttribute) as? String else { fail("No text area") }
  let range=(text as NSString).range(of:term); guard range.location != NSNotFound else { fail("Term missing") }
  var query=CFRange(location:range.location,length:range.length)
  let rangeValue=AXValueCreate(.cfRange,&query)!
  if args.contains("--select") { print("SELECT",AXUIElementSetAttributeValue(field,kAXSelectedTextRangeAttribute as CFString,rangeValue).rawValue) }
  else if !args.contains("--keep-selection") { var empty=CFRange(location:0,length:0); _ = AXUIElementSetAttributeValue(field,kAXSelectedTextRangeAttribute as CFString,AXValueCreate(.cfRange,&empty)!) }
  var raw:CFTypeRef?;_ = AXUIElementCopyParameterizedAttributeValue(field,kAXBoundsForRangeParameterizedAttribute as CFString,rangeValue,&raw)
  guard let raw,CFGetTypeID(raw)==AXValueGetTypeID() else {fail("No exact bounds")}
  var rect=CGRect.zero;_ = AXValueGetValue(unsafeBitCast(raw,to:AXValue.self),.cgRect,&rect)
  let point=CGPoint(x:rect.midX,y:rect.midY)
  print("TARGET",term,"UTF16",range,"AX_BOUNDS",rect,"POINTER",point)
  lastPointer=point
  CGWarpMouseCursorPosition(point)
  CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:point,mouseButton:.left)?.post(tap:.cghidEventTap)
 }
 if let position=value("--position") {
  let coords=position.split(separator:",").compactMap {Double($0)}
  var p=CGPoint(x:coords[0],y:coords[1]);print("POSITION",AXUIElementSetAttributeValue(window,kAXPositionAttribute as CFString,AXValueCreate(.cgPoint,&p)!).rawValue)
 }
 if args.contains("--dump") {
  for e in nodes {
   let role=attr(e,kAXRoleAttribute) as? String ?? "?"
   print(role,[kAXTitleAttribute,kAXDescriptionAttribute,kAXValueAttribute].compactMap {attr(e,$0) as? String}.joined(separator:" | "))
  }
 }
}
if args.contains("--mouse-click") {
 guard let point=lastPointer else { fail("A controlled --point or --point-element is required before clicking") }
 var hit:AXUIElement?;_ = AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(),Float(point.x),Float(point.y),&hit)
 var hitPID:pid_t=0;if let hit { _ = AXUIElementGetPid(hit,&hitPID) }
 guard hitPID == running.processIdentifier else { fail("The controlled target is occluded; no click sent") }
 CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:point,mouseButton:.left)?.post(tap:.cghidEventTap)
 CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:point,mouseButton:.left)?.post(tap:.cghidEventTap)
}
if args.contains("--shortcut") || args.contains("--escape") || args.contains("--option-only") {
 let code:CGKeyCode=args.contains("--escape") ? 53 : args.contains("--option-only") ? 58 : 49
 let flags:CGEventFlags=args.contains("--escape") ? [] : .maskAlternate
 let down=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:true)!,up=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:false)!
 down.flags=flags;up.flags=args.contains("--option-only") ? [] : flags
 if args.contains("--shortcut") {
  let modifier=CGEvent(keyboardEventSource:nil,virtualKey:58,keyDown:true)!;modifier.flags = .maskAlternate;modifier.post(tap:.cghidEventTap);usleep(20000)
 }
 down.post(tap:.cghidEventTap)
 if args.contains("--repeat") { for _ in 0..<12 {let repeatEvent=CGEvent(keyboardEventSource:nil,virtualKey:code,keyDown:true)!;repeatEvent.flags=flags;repeatEvent.setIntegerValueField(.keyboardEventAutorepeat,value:1);repeatEvent.post(tap:.cghidEventTap)} }
 up.post(tap:.cghidEventTap)
 if args.contains("--shortcut") { usleep(20000);CGEvent(keyboardEventSource:nil,virtualKey:58,keyDown:false)?.post(tap:.cghidEventTap) }
}
print("FRONTMOST",NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")
