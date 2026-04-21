import SwiftUI

enum Theme {
    static let background = Color(red: 0.02, green: 0.03, blue: 0.02)
    static let surface = Color(red: 0.04, green: 0.06, blue: 0.04)
    static let phosphor = Color(red: 0.2, green: 1.0, blue: 0.35)
    static let phosphorDim = Color(red: 0.2, green: 1.0, blue: 0.35).opacity(0.55)
    static let phosphorMuted = Color(red: 0.2, green: 1.0, blue: 0.35).opacity(0.25)
    static let danger = Color(red: 1.0, green: 0.2, blue: 0.3)
    static let dangerDim = Color(red: 1.0, green: 0.2, blue: 0.3).opacity(0.6)

    static let mono = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
    static let monoLarge = Font.system(.title2, design: .monospaced)
}

struct TerminalBox: ViewModifier {
    var color: Color = Theme.phosphorMuted
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(color, lineWidth: 1)
            )
    }
}

extension View {
    func terminalBox(color: Color = Theme.phosphorMuted) -> some View {
        modifier(TerminalBox(color: color))
    }
}

struct BlinkingCursor: View {
    @State private var visible = true
    var body: some View {
        Text("▊")
            .foregroundColor(Theme.phosphor)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    visible.toggle()
                }
            }
    }
}
