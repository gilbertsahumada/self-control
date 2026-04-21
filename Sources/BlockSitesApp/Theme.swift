import SwiftUI

enum Theme {
    static let background = Color(red: 0.015, green: 0.025, blue: 0.015)
    static let surface = Color(red: 0.03, green: 0.05, blue: 0.03)
    static let phosphor = Color(red: 0.45, green: 1.0, blue: 0.55)
    static let phosphorDim = Color(red: 0.45, green: 1.0, blue: 0.55).opacity(0.65)
    static let phosphorMuted = Color(red: 0.45, green: 1.0, blue: 0.55).opacity(0.3)
    static let phosphorGlow = Color(red: 0.45, green: 1.0, blue: 0.55).opacity(0.5)
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.2)
    static let danger = Color(red: 1.0, green: 0.3, blue: 0.35)
    static let dangerDim = Color(red: 1.0, green: 0.3, blue: 0.35).opacity(0.7)

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Menlo", size: size).weight(weight)
    }

    static let monoXS = mono(10)
    static let monoSM = mono(11)
    static let monoMD = mono(13)
    static let monoLG = mono(16, weight: .bold)
}

struct Scanlines: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                let lineHeight: CGFloat = 3
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    ctx.fill(Path(rect), with: .color(Color.black.opacity(0.35)))
                    y += lineHeight
                }
            }
        }
        .allowsHitTesting(false)
        .blendMode(.multiply)
    }
}

struct CRTFlicker: View {
    @State private var opacity: Double = 0.02
    var body: some View {
        Color.black
            .opacity(opacity)
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
                    opacity = 0.06
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
