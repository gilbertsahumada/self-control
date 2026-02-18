import SwiftUI
import BlockSitesCore

struct ActiveBlockView: View {
    @EnvironmentObject var viewModel: BlockViewModel

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 20)

                    // Lock icon + header
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)

                    Text("Sites Blocked")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    // Blocked sites list
                    if let config = viewModel.config {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(config.sites, id: \.self) { site in
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    Text(site)
                                        .fontWeight(.medium)
                                    Spacer()
                                    let count = DomainExpander.subdomainCount(for: site)
                                    Text("+ \(count) subdomains")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(10)
                    }

                    Spacer(minLength: 20)

                    // Countdown timer
                    Text(formatCountdown(viewModel.remainingSeconds))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    // Progress bar
                    ProgressView(value: viewModel.progress)
                        .progressViewStyle(.linear)
                        .tint(.red)

                    // End time
                    if let config = viewModel.config {
                        let formatter = endTimeFormatter
                        Text("Ends at \(formatter.string(from: config.endTime))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 20)

                    Text("Cannot be undone until the timer expires")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(24)
                .frame(minHeight: geometry.size.height)
            }
        }
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
