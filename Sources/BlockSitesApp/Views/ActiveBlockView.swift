import SwiftUI
import SelfControlCore

struct ActiveBlockView: View {
    @EnvironmentObject var viewModel: BlockViewModel

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    VStack(alignment: .leading, spacing: 4) {
                        Text("[ COUNTDOWN ]")
                            .font(Theme.monoSmall.weight(.semibold))
                            .foregroundColor(Theme.phosphorDim)
                        Text(formatCountdown(viewModel.remainingSeconds))
                            .font(.system(size: 64, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.phosphor)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .shadow(color: Theme.phosphor.opacity(0.6), radius: 8)
                    }

                    progressBar

                    if let config = viewModel.config {
                        Text("// expires at \(endTimeFormatter.string(from: config.endTime))")
                            .font(Theme.monoSmall)
                            .foregroundColor(Theme.phosphorMuted)
                    }

                    Divider().background(Theme.phosphorMuted)

                    if let config = viewModel.config {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("[ BLOCKED \(config.sites.count) ]")
                                .font(Theme.monoSmall.weight(.semibold))
                                .foregroundColor(Theme.phosphorDim)

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(config.sites, id: \.self) { site in
                                    HStack(spacing: 6) {
                                        Text("✗")
                                            .foregroundColor(Theme.danger)
                                        Text(site)
                                            .font(Theme.mono.weight(.medium))
                                            .foregroundColor(Theme.phosphor)
                                        Spacer()
                                        let count = DomainExpander.subdomainCount(for: site)
                                        Text("+\(count)")
                                            .font(Theme.monoSmall)
                                            .foregroundColor(Theme.phosphorMuted)
                                    }
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.surface)
                            .terminalBox()
                        }
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 4) {
                        Text("//")
                            .foregroundColor(Theme.phosphorMuted)
                        Text("LOCKDOWN ACTIVE. NO EXIT.")
                            .font(Theme.monoSmall)
                            .foregroundColor(Theme.dangerDim)
                    }
                }
                .padding(28)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("●")
                .foregroundColor(Theme.danger)
                .shadow(color: Theme.danger.opacity(0.8), radius: 4)
            Text("LOCKDOWN")
                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                .foregroundColor(Theme.phosphor)
            BlinkingCursor()
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Theme.phosphorMuted)
                    .frame(height: 6)
                Rectangle()
                    .fill(Theme.phosphor)
                    .frame(width: geo.size.width * viewModel.progress, height: 6)
                    .shadow(color: Theme.phosphor.opacity(0.8), radius: 4)
            }
        }
        .frame(height: 6)
    }

    private var endTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
