import SwiftUI
import SelfControlCore

struct ActiveBlockView: View {
    @EnvironmentObject var viewModel: BlockViewModel

    private let banner = """
 ██       ██████   ██████ ██   ██ ██████   ██████  ██     ██ ███    ██
 ██      ██    ██ ██      ██  ██  ██   ██ ██    ██ ██     ██ ████   ██
 ██      ██    ██ ██      █████   ██   ██ ██    ██ ██  █  ██ ██ ██  ██
 ██      ██    ██ ██      ██  ██  ██   ██ ██    ██ ██ ███ ██ ██  ██ ██
 ███████  ██████   ██████ ██   ██ ██████   ██████   ███ ███  ██   ████
"""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(banner)
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.85, blue: 0.3),
                                    Color(red: 1.0, green: 0.5, blue: 0.25),
                                    Color(red: 1.0, green: 0.3, blue: 0.35),
                                    Color(red: 0.75, green: 0.15, blue: 0.2)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Theme.danger.opacity(0.6), radius: 3)
                        .lineSpacing(-2)
                        .fixedSize(horizontal: true, vertical: true)

                    HStack(spacing: 6) {
                        Text("[")
                            .foregroundColor(Theme.phosphorDim)
                        BlinkDot()
                        Text("ACTIVE]")
                            .foregroundColor(Theme.danger)
                        Text("system locked")
                            .foregroundColor(Theme.phosphorDim)
                        Spacer()
                        Text("pid:1337")
                            .foregroundColor(Theme.phosphorMuted)
                    }
                    .font(Theme.monoSM)

                    Divider().background(Theme.phosphorMuted)

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "COUNTDOWN")
                        Text(formatCountdown(viewModel.remainingSeconds))
                            .font(Theme.mono(68, weight: .bold))
                            .foregroundColor(Theme.phosphor)
                            .shadow(color: Theme.phosphorGlow, radius: 10)
                            .shadow(color: Theme.phosphorGlow, radius: 4)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)

                        asciiProgressBar

                        if let config = viewModel.config {
                            HStack {
                                Text("> expires:")
                                    .foregroundColor(Theme.phosphorDim)
                                Text(endTimeFormatter.string(from: config.endTime))
                                    .foregroundColor(Theme.phosphor)
                                Spacer()
                                Text("progress: \(Int(viewModel.progress * 100))%")
                                    .foregroundColor(Theme.phosphorDim)
                            }
                            .font(Theme.monoSM)
                        }
                    }

                    if let config = viewModel.config {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "BLOCKED [\(config.sites.count)]")
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(config.sites.enumerated()), id: \.element) { idx, site in
                                    HStack(spacing: 8) {
                                        Text(String(format: "%02d.", idx + 1))
                                            .foregroundColor(Theme.phosphorMuted)
                                        Text("[BLOCKED]")
                                            .foregroundColor(Theme.danger)
                                        Text(site)
                                            .foregroundColor(Theme.phosphor)
                                        Spacer()
                                        let count = DomainExpander.subdomainCount(for: site)
                                        Text("+\(count)")
                                            .foregroundColor(Theme.phosphorMuted)
                                    }
                                    .font(Theme.monoSM)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface)
                            .overlay(Rectangle().stroke(Theme.phosphorMuted, lineWidth: 1))
                        }
                    }

                    Spacer(minLength: 8)

                    Text("// kernel panic prevention engaged — no exit")
                        .font(Theme.monoXS)
                        .foregroundColor(Theme.amber.opacity(0.6))
                }
                .padding(24)
            }

            statusBar
        }
    }

    private var asciiProgressBar: some View {
        GeometryReader { geo in
            let cellWidth: CGFloat = 10
            let count = Int(geo.size.width / cellWidth)
            let filled = Int(Double(count) * viewModel.progress)
            let str = String(repeating: "█", count: filled) + String(repeating: "░", count: max(count - filled, 0))
            Text(str)
                .font(Theme.mono(14, weight: .bold))
                .foregroundColor(Theme.phosphor)
                .shadow(color: Theme.phosphorGlow, radius: 3)
                .lineLimit(1)
        }
        .frame(height: 20)
    }

    private var statusBar: some View {
        HStack(spacing: 0) {
            Text(" LOCKED ")
                .font(Theme.monoSM.weight(.bold))
                .foregroundColor(Theme.background)
                .padding(.horizontal, 4)
                .background(Theme.danger)
            Text(" \(Int(viewModel.progress * 100))% ")
                .font(Theme.monoSM)
                .foregroundColor(Theme.phosphor)
                .background(Theme.surface)
            Text(" remain:\(formatCountdown(viewModel.remainingSeconds)) ")
                .font(Theme.monoSM)
                .foregroundColor(Theme.phosphorDim)
            Spacer()
            Text("tty0 ")
                .font(Theme.monoSM)
                .foregroundColor(Theme.phosphorMuted)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Theme.surface)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.phosphorMuted), alignment: .top)
    }

    private var endTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

struct BlinkDot: View {
    @State private var on = true
    var body: some View {
        Text("●")
            .foregroundColor(Theme.danger)
            .shadow(color: Theme.danger.opacity(0.8), radius: 4)
            .opacity(on ? 1 : 0.3)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever()) {
                    on.toggle()
                }
            }
    }
}
