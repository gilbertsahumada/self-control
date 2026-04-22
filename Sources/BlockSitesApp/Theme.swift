import SwiftUI

enum Theme {
    // Desaturated phosphor palette: accent stays bright, body text is off-white
    // with a subtle green cast so long reading doesn't burn the eye.
    static let background = Color(red: 0.025, green: 0.035, blue: 0.025)
    static let surface = Color(red: 0.045, green: 0.06, blue: 0.045)

    /// Body text — readable off-white with a faint green hint.
    static let foreground = Color(red: 0.88, green: 0.94, blue: 0.88)

    /// Accent color for headers, buttons, timer, banner. Desaturated to
    /// avoid the neon glare of saturated green on a dark background.
    static let phosphor = Color(red: 0.6, green: 0.9, blue: 0.68)
    /// Secondary accent; used for section headers and decorative chrome.
    static let phosphorDim = Color(red: 0.65, green: 0.85, blue: 0.72)
    /// Muted comments / hints / tertiary labels.
    static let phosphorMuted = Color(red: 0.5, green: 0.65, blue: 0.55)
    /// Kept for API compatibility but effectively off; glows removed.
    static let phosphorGlow = Color.clear

    static let amber = Color(red: 1.0, green: 0.78, blue: 0.3)
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.4)
    static let dangerDim = Color(red: 1.0, green: 0.35, blue: 0.4).opacity(0.7)

    /// Uses SF Mono on macOS via the system monospaced design — wider and
    /// more open than Menlo, so body copy is easier to read at small sizes.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .monospaced)
    }

    static let monoXS = mono(11)
    static let monoSM = mono(12)
    static let monoMD = mono(14)
    static let monoLG = mono(17, weight: .bold)
}

struct Scanlines: View {
    var body: some View {
        GeometryReader { _ in
            Canvas { ctx, size in
                // Widen line pitch from 3px → 5px and lower opacity from 0.35 → 0.18
                // so content behind the overlay stays readable.
                let lineHeight: CGFloat = 5
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    ctx.fill(Path(rect), with: .color(Color.black.opacity(0.18)))
                    y += lineHeight
                }
            }
        }
        .allowsHitTesting(false)
        .blendMode(.multiply)
    }
}

struct CRTFlicker: View {
    @State private var opacity: Double = 0.01
    var body: some View {
        Color.black
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    opacity = 0.03
                }
            }
    }
}

struct BlinkingCursor: View {
    @State private var visible = true
    var size: CGFloat = 13
    var body: some View {
        Text("█")
            .font(Theme.mono(size, weight: .bold))
            .foregroundColor(Theme.phosphor)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever()) {
                    visible.toggle()
                }
            }
    }
}

struct ASCIIBoxTop: View {
    let title: String
    let width: Int
    var body: some View {
        let label = " \(title) "
        let remaining = max(width - label.count - 4, 2)
        let line = "┌─[\(label)]" + String(repeating: "─", count: remaining) + "┐"
        return Text(line)
            .font(Theme.monoSM)
            .foregroundColor(Theme.phosphorDim)
            .lineLimit(1)
    }
}

struct ASCIIBoxBottom: View {
    let width: Int
    var body: some View {
        let line = "└" + String(repeating: "─", count: max(width - 2, 2)) + "┘"
        return Text(line)
            .font(Theme.monoSM)
            .foregroundColor(Theme.phosphorDim)
            .lineLimit(1)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack(spacing: 0) {
            Text("── [ \(title) ] ")
                .font(Theme.monoSM.weight(.semibold))
                .foregroundColor(Theme.phosphorDim)
            Rectangle()
                .fill(Theme.phosphorMuted)
                .frame(height: 1)
        }
    }
}
