import SwiftUI
import AppKit

// A shared palette follows macOS appearance; surfaces stay opaque for readable Chinese text.
extension Color {
    private static func adaptive(_ light: (CGFloat,CGFloat,CGFloat),_ dark: (CGFloat,CGFloat,CGFloat)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let v = appearance.bestMatch(from: [.darkAqua,.aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: v.0,green: v.1,blue: v.2,alpha: 1)
        })
    }
    static let lensAccent = adaptive((0.00,0.38,0.33),(0.39,0.83,0.74))
    static let lensCanvas = adaptive((0.97,0.97,0.955),(0.085,0.098,0.104))
    static let lensSidebar = adaptive((0.94,0.95,0.93),(0.065,0.077,0.082))
    static let lensSurface = adaptive((1,1,0.99),(0.115,0.131,0.137))
    static let lensLine = adaptive((0.84,0.87,0.83),(0.23,0.27,0.28))
}
struct LensSurface: ViewModifier {
    var padding: CGFloat = 20
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content.padding(padding).background(Color.lensSurface,in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(contrast == .increased ? Color.primary.opacity(0.65) : Color.lensLine.opacity(0.55),lineWidth: 1))
    }
}
extension View { func lensSurface(padding: CGFloat = 20) -> some View { modifier(LensSurface(padding: padding)) } }
struct LensPageHeading: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading,spacing: 7) {
            Text(title).font(.system(size: 27,weight: .semibold)).tracking(-0.6)
            if !detail.isEmpty { Text(detail).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false,vertical: true).lineSpacing(3) }
        }.frame(maxWidth: .infinity,alignment: .leading)
    }
}
struct LensKeycap: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 11,weight: .medium,design: .monospaced)).foregroundStyle(.secondary).padding(.horizontal,7).padding(.vertical,4).background(Color.primary.opacity(0.045),in: RoundedRectangle(cornerRadius: 5)).overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.lensLine.opacity(0.55),lineWidth: 1)).fixedSize() }
}
struct LensBrand: View {
    var compact = false
    var body: some View {
        HStack(spacing: 10) {
            ZStack { RoundedRectangle(cornerRadius: 10).fill(Color.lensAccent.opacity(0.12)); Image(systemName: "viewfinder").font(.system(size: 26,weight: .light)).foregroundStyle(Color.lensAccent); Text("K").font(.system(size: 14,weight: .semibold)).foregroundStyle(Color.lensAccent) }.frame(width: 38,height: 38).accessibilityHidden(true)
            if !compact { VStack(alignment: .leading,spacing: 3) { Text("Kamihi Lens").font(.system(size: 14,weight: .semibold)); Text("Chinese study").font(.system(size: 11)).foregroundStyle(.secondary) } }
        }
    }
}
struct LensButtonStyle: ButtonStyle {
    var prominent = false
    var small = false
    func makeBody(configuration: Configuration) -> some View { LensButtonBody(configuration: configuration,prominent: prominent,small: small) }
    private struct LensButtonBody: View {
        let configuration: ButtonStyle.Configuration
        let prominent: Bool
        let small: Bool
        @Environment(\.isEnabled) private var enabled
        @Environment(\.colorScheme) private var scheme
        @Environment(\.colorSchemeContrast) private var contrast
        @State private var hover = false
        var body: some View {
            configuration.label.font(.system(size: small ? 12 : 13,weight: .medium))
                .padding(.horizontal,small ? 10 : 13).padding(.vertical,small ? 7 : 10)
                .foregroundStyle(prominent ? (scheme == .dark ? Color.lensSidebar : .white) : Color.primary)
                .background(prominent ? Color.lensAccent.opacity(configuration.isPressed ? 0.75 : 1) : Color.primary.opacity(configuration.isPressed ? 0.11 : hover ? 0.07 : 0.035),in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(prominent ? .clear : contrast == .increased ? Color.primary.opacity(0.65) : Color.lensLine.opacity(0.6),lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 8)).opacity(enabled ? 1 : 0.45).onHover { hover = $0 }
        }
    }
}
struct LensRowStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View { Row(configuration: configuration,selected: selected) }
    private struct Row: View {
        let configuration: ButtonStyle.Configuration
        let selected: Bool
        @State private var hover = false
        var body: some View { configuration.label.background(selected ? Color.lensAccent.opacity(0.12) : Color.primary.opacity(configuration.isPressed ? 0.09 : hover ? 0.045 : 0),in: RoundedRectangle(cornerRadius: 8)).contentShape(Rectangle()).onHover { hover = $0 } }
    }
}
struct LensSearchField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(.secondary)
            TextField(placeholder,text: $text).textFieldStyle(.plain).font(.system(size: 13)).accessibilityLabel(placeholder)
            if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("Clear search") }
        }.padding(.horizontal,12).frame(height: 36).background(Color.lensSurface,in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lensLine.opacity(0.7),lineWidth: 1))
    }
}
struct LensEmptyState: View {
    let title: String
    let detail: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading,spacing: 13) {
            Image(systemName: symbol).font(.system(size: 27,weight: .light)).foregroundStyle(Color.lensAccent).padding(.bottom,3)
            Text(title).font(.system(size: 20,weight: .semibold))
            Text(detail).font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4).fixedSize(horizontal: false,vertical: true)
        }.padding(.vertical,30).frame(maxWidth: .infinity,alignment: .leading)
    }
}

struct LensActionLabel: View {
    let title: String
    let symbol: String
    var body: some View { VStack(spacing: 6) { Image(systemName: symbol).font(.system(size: 15,weight: .medium)); Text(title).font(.system(size: 10,weight: .medium)).lineLimit(1).minimumScaleFactor(0.85) }.frame(maxWidth: .infinity,minHeight: 52).contentShape(Rectangle()) }
}
struct LensActionStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View { ActionBody(configuration: configuration,prominent: prominent) }
    private struct ActionBody: View {
        let configuration: ButtonStyle.Configuration
        let prominent: Bool
        @Environment(\.isEnabled) private var enabled
        @Environment(\.colorScheme) private var scheme
        @Environment(\.colorSchemeContrast) private var contrast
        @State private var hover = false
        var body: some View {
            configuration.label.frame(maxWidth: .infinity)
                .foregroundStyle(prominent ? (scheme == .dark ? Color.lensSidebar : .white) : Color.primary)
                .background(prominent ? Color.lensAccent : Color.primary.opacity(configuration.isPressed ? 0.12 : hover ? 0.07 : 0.035),in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(contrast == .increased ? Color.primary.opacity(0.65) : Color.lensLine.opacity(0.7),lineWidth: 1))
                .opacity(enabled ? 1 : 0.45).onHover { hover = $0 }
        }
    }
}
