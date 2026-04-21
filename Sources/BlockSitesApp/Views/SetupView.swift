import SwiftUI
import SelfControlCore

struct SetupView: View {
    @EnvironmentObject var viewModel: BlockViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                section(title: "[ TARGETS ]") {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 8) {
                        ForEach(PopularSite.allSites) { site in
                            siteToggle(site)
                        }
                    }
                }

                section(title: "[ CUSTOM DOMAINS ]") {
                    HStack(spacing: 6) {
                        Text(">")
                            .foregroundColor(Theme.phosphorDim)
                        TextField("", text: $viewModel.customSitesText, prompt: Text("example.com, another.com").foregroundColor(Theme.phosphorMuted))
                            .textFieldStyle(.plain)
                            .font(Theme.mono)
                            .foregroundColor(Theme.phosphor)
                    }
                    .padding(10)
                    .background(Theme.surface)
                    .terminalBox()
                }

                section(title: "[ DURATION ]") {
                    HStack(spacing: 16) {
                        durationField(label: "HRS", value: $viewModel.hours, range: 0...24)
                        durationField(label: "MIN", value: $viewModel.minutes, range: 0...59)
                        Spacer()
                    }
                }

                if let error = viewModel.errorMessage {
                    Text("! \(error)")
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.danger)
                }

                startButton

                HStack(spacing: 4) {
                    Text("//")
                        .foregroundColor(Theme.phosphorMuted)
                    Text("NO ABORT. NO OVERRIDE. TIMER IS LAW.")
                        .font(Theme.monoSmall)
                        .foregroundColor(Theme.phosphorDim)
                }
            }
            .padding(28)
        }
        .alert("CONFIRM BLOCK", isPresented: $viewModel.showConfirmation) {
            Button("ABORT", role: .cancel) {}
            Button("EXECUTE", role: .destructive) {
                viewModel.startBlocking()
            }
        } message: {
            let sites = viewModel.allSitesToBlock
            let duration = TimeFormatter.formatDurationShort(viewModel.totalDurationSeconds)
            Text("Lockdown \(sites.count) target(s) for \(duration).\n\nIrreversible until timer expires.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("$")
                    .foregroundColor(Theme.phosphorDim)
                Text("selfcontrol")
                    .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                    .foregroundColor(Theme.phosphor)
                BlinkingCursor()
            }
            Text("// distraction suppressor v1.0")
                .font(Theme.monoSmall)
                .foregroundColor(Theme.phosphorMuted)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.monoSmall.weight(.semibold))
                .foregroundColor(Theme.phosphorDim)
            content()
        }
    }

    private func durationField(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.monoSmall)
                .foregroundColor(Theme.phosphorDim)
            HStack(spacing: 0) {
                Button(action: { if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 } }) {
                    Text("-")
                        .font(Theme.mono.weight(.bold))
                        .foregroundColor(Theme.phosphor)
                        .frame(width: 26, height: 30)
                }
                .buttonStyle(.plain)
                Text(String(format: "%02d", value.wrappedValue))
                    .font(Theme.mono.weight(.bold))
                    .foregroundColor(Theme.phosphor)
                    .frame(width: 36, height: 30)
                    .background(Theme.surface)
                Button(action: { if value.wrappedValue < range.upperBound { value.wrappedValue += 1 } }) {
                    Text("+")
                        .font(Theme.mono.weight(.bold))
                        .foregroundColor(Theme.phosphor)
                        .frame(width: 26, height: 30)
                }
                .buttonStyle(.plain)
            }
            .terminalBox()
        }
    }

    private var startButton: some View {
        Button(action: { viewModel.showConfirmation = true }) {
            HStack {
                if viewModel.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.background)
                } else {
                    Text("▶ EXECUTE LOCKDOWN")
                        .font(Theme.mono.weight(.bold))
                        .foregroundColor(Theme.background)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                (viewModel.canStartBlocking && !viewModel.isProcessing) ? Theme.phosphor : Theme.phosphorMuted
            )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.canStartBlocking || viewModel.isProcessing)
    }

    private func siteToggle(_ site: PopularSite) -> some View {
        let isSelected = viewModel.selectedSites.contains(site.domain)
        return Button(action: {
            if isSelected {
                viewModel.selectedSites.remove(site.domain)
            } else {
                viewModel.selectedSites.insert(site.domain)
            }
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(isSelected ? "[x]" : "[ ]")
                        .foregroundColor(isSelected ? Theme.phosphor : Theme.phosphorDim)
                    Text(site.name.lowercased())
                        .font(Theme.mono.weight(.semibold))
                        .foregroundColor(isSelected ? Theme.phosphor : Theme.phosphorDim)
                }
                let count = DomainExpander.subdomainCount(for: site.domain)
                Text("+\(count) subdomains")
                    .font(Theme.monoSmall)
                    .foregroundColor(Theme.phosphorMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(isSelected ? Theme.phosphor.opacity(0.08) : Theme.surface)
            .terminalBox(color: isSelected ? Theme.phosphor : Theme.phosphorMuted)
        }
        .buttonStyle(.plain)
    }
}
