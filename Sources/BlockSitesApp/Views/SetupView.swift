import SwiftUI
import MonkModeCore

struct SetupView: View {
    @EnvironmentObject var viewModel: BlockViewModel

    private let banner = """
 ███   ███  ██████  ███    ██ ██   ██ ███   ███  ██████  ██████  ███████
 ████ ████ ██    ██ ████   ██ ██  ██  ████ ████ ██    ██ ██   ██ ██
 ██ ███ ██ ██    ██ ██ ██  ██ █████   ██ ███ ██ ██    ██ ██   ██ █████
 ██  █  ██ ██    ██ ██  ██ ██ ██  ██  ██  █  ██ ██    ██ ██   ██ ██
 ██     ██  ██████  ██   ████ ██   ██ ██     ██  ██████  ██████  ███████
"""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    bannerBlock
                    promptLine
                    Divider().background(Theme.phosphorMuted)

                    if viewModel.isWaitingForDaemonCleanup {
                        waitingBanner
                    } else if viewModel.needsRecoveryCleanup {
                        recoveryBanner
                    }

                    section("TARGETS") {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 6),
                            GridItem(.flexible(), spacing: 6)
                        ], spacing: 6) {
                            ForEach(PopularSite.allSites) { site in
                                siteToggle(site)
                            }
                        }
                    }

                    section("CUSTOM DOMAINS") {
                        customDomainsBlock
                    }

                    section("DURATION") {
                        HStack(spacing: 20) {
                            durationField(label: "HRS", value: $viewModel.hours, range: 0...24)
                            durationField(label: "MIN", value: $viewModel.minutes, range: 0...59)
                            Spacer()
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text("!! ERROR: \(error.uppercased())")
                            .font(Theme.monoSM)
                            .foregroundColor(Theme.danger)
                    }

                    executeButton

                    Text("// WARNING: LOCKDOWN CANNOT BE ABORTED ONCE INITIATED")
                        .font(Theme.monoXS)
                        .foregroundColor(Theme.amber.opacity(0.7))
                }
                .padding(24)
            }

            statusBar
        }
        .alert("[ CONFIRM LOCKDOWN ]", isPresented: $viewModel.showConfirmation) {
            Button("ABORT", role: .cancel) {}
            Button("EXECUTE", role: .destructive) {
                viewModel.startBlocking()
            }
        } message: {
            let sites = viewModel.allSitesToBlock
            let duration = TimeFormatter.formatDurationShort(viewModel.totalDurationSeconds)
            Text("LOCKDOWN \(sites.count) TARGET(S) FOR \(duration.uppercased()).\n\nIRREVERSIBLE UNTIL TIMER EXPIRES.")
        }
    }

    private var bannerBlock: some View {
        Text(banner)
            .font(Theme.mono(9, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.85, green: 1.0, blue: 0.9),
                        Color(red: 0.45, green: 1.0, blue: 0.55),
                        Color(red: 0.2, green: 0.9, blue: 0.7),
                        Color(red: 0.15, green: 0.6, blue: 0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .lineSpacing(-2)
            .fixedSize(horizontal: true, vertical: true)
    }

    private var waitingBanner: some View {
        HStack(spacing: 8) {
            Text("..")
                .font(Theme.monoSM.weight(.bold))
                .foregroundColor(Theme.phosphorDim)
            Text("waiting for daemon cleanup")
                .font(Theme.monoSM)
                .foregroundColor(Theme.phosphorDim)
            Spacer()
            Text("polling...")
                .font(Theme.monoSM)
                .foregroundColor(Theme.phosphorMuted)
        }
        .padding(10)
        .background(Theme.surface)
        .overlay(Rectangle().stroke(Theme.phosphorMuted, lineWidth: 1))
    }

    private var customDomainsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("$")
                    .font(Theme.monoMD)
                    .foregroundColor(Theme.phosphorDim)
                TextField(
                    "",
                    text: $viewModel.pendingDomainInput,
                    prompt: Text("type domain + enter (e.g. reddit.com)")
                        .foregroundColor(Theme.phosphorMuted)
                )
                .textFieldStyle(.plain)
                .font(Theme.monoMD)
                .foregroundColor(Theme.phosphor)
                .tint(Theme.phosphor)
                .onSubmit {
                    viewModel.commitPendingDomain()
                }
                Button(action: { viewModel.commitPendingDomain() }) {
                    Text("ADD")
                        .font(Theme.monoSM.weight(.bold))
                        .foregroundColor(Theme.background)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            viewModel.pendingDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Theme.phosphorMuted : Theme.phosphor
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.pendingDomainInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(Theme.surface)
            .overlay(Rectangle().stroke(Theme.phosphorMuted, lineWidth: 1))

            if let err = viewModel.pendingDomainError {
                Text("!! \(err)")
                    .font(Theme.monoSM)
                    .foregroundColor(Theme.amber)
            }

            if !viewModel.customDomains.isEmpty {
                FlowLayout(spacing: 6, runSpacing: 6) {
                    ForEach(viewModel.customDomains, id: \.self) { domain in
                        DomainChip(domain: domain) {
                            viewModel.removeCustomDomain(domain)
                        }
                    }
                }
            } else {
                Text("// no custom domains added")
                    .font(Theme.monoXS)
                    .foregroundColor(Theme.phosphorMuted)
            }
        }
    }

    private var recoveryBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("!!")
                    .font(Theme.monoSM.weight(.bold))
                    .foregroundColor(Theme.amber)
                Text("STALE LOCKDOWN DETECTED")
                    .font(Theme.monoSM.weight(.bold))
                    .foregroundColor(Theme.amber)
                Spacer()
            }
            Text("/etc/hosts still contains block entries from a previous lockdown that was not cleaned up. Sites may still be unreachable. Run cleanup to restore normal access.")
                .font(Theme.monoSM)
                .foregroundColor(Theme.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: { viewModel.runRecoveryCleanup() }) {
                HStack(spacing: 6) {
                    Text(">>")
                    Text("RUN_CLEANUP.sh")
                    Text("<<")
                }
                .font(Theme.monoSM.weight(.bold))
                .foregroundColor(Theme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Theme.amber)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isProcessing)
        }
        .padding(12)
        .background(Theme.surface)
        .overlay(Rectangle().stroke(Theme.amber, lineWidth: 1))
    }

    private var promptLine: some View {
        HStack(spacing: 6) {
            Text("user@local:~$")
                .font(Theme.monoSM)
                .foregroundColor(Theme.phosphorDim)
            Text("monkmode --init")
                .font(Theme.monoSM)
                .foregroundColor(Theme.phosphor)
            Spacer()
            Text("v1.0.0")
                .font(Theme.monoSM)
                .foregroundColor(Theme.phosphorMuted)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
            content()
        }
    }

    private func durationField(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Theme.monoSM)
                .foregroundColor(Theme.phosphorDim)
            HStack(spacing: 0) {
                stepperButton("◀") {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                }
                Text(String(format: "%02d", value.wrappedValue))
                    .font(Theme.mono(15, weight: .bold))
                    .foregroundColor(Theme.phosphor)
                    .frame(width: 44, height: 28)
                    .background(Theme.surface)
                stepperButton("▶") {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                }
            }
            .overlay(Rectangle().stroke(Theme.phosphorMuted, lineWidth: 1))
        }
    }

    private func stepperButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(Theme.monoSM.weight(.bold))
                .foregroundColor(Theme.phosphor)
                .frame(width: 26, height: 28)
                .background(Theme.surface)
        }
        .buttonStyle(.plain)
    }

    private var executeButton: some View {
        Button(action: { viewModel.showConfirmation = true }) {
            HStack(spacing: 8) {
                if viewModel.isProcessing {
                    Text("// PROCESSING...")
                        .font(Theme.monoMD.weight(.bold))
                } else {
                    Text(">>")
                        .font(Theme.monoMD.weight(.bold))
                    Text("EXECUTE_LOCKDOWN.sh")
                        .font(Theme.monoMD.weight(.bold))
                    Text("<<")
                        .font(Theme.monoMD.weight(.bold))
                }
            }
            .foregroundColor(Theme.background)
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
            HStack(spacing: 8) {
                Text(isSelected ? "[■]" : "[ ]")
                    .font(Theme.monoMD.weight(.bold))
                    .foregroundColor(isSelected ? Theme.phosphor : Theme.phosphorDim)
                VStack(alignment: .leading, spacing: 2) {
                    Text(site.domain)
                        .font(Theme.monoMD.weight(.semibold))
                        .foregroundColor(isSelected ? Theme.phosphor : Theme.phosphorDim)
                    let count = DomainExpander.subdomainCount(for: site.domain)
                    Text("+\(count) subs")
                        .font(Theme.monoXS)
                        .foregroundColor(Theme.phosphorMuted)
                }
                Spacer()
            }
            .padding(10)
            .background(isSelected ? Theme.phosphor.opacity(0.1) : Theme.surface)
            .overlay(Rectangle().stroke(isSelected ? Theme.phosphor : Theme.phosphorMuted, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var statusBar: some View {
        HStack(spacing: 0) {
            Text(" READY ")
                .font(Theme.monoSM.weight(.bold))
                .foregroundColor(Theme.background)
                .padding(.horizontal, 4)
                .background(Theme.phosphor)
            Text(" TARGETS:\(viewModel.allSitesToBlock.count) ")
                .font(Theme.monoSM)
                .foregroundColor(Theme.phosphor)
                .background(Theme.surface)
            Text(" DUR:\(viewModel.hours)h\(String(format: "%02d", viewModel.minutes))m ")
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
}
