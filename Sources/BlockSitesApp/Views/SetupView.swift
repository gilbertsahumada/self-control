import SwiftUI
import BlockSitesCore

struct SetupView: View {
    @EnvironmentObject var viewModel: BlockViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("BlockSites")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Select sites to block")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Popular sites grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(PopularSite.allSites) { site in
                    siteToggle(site)
                }
            }

            Divider()

            // Custom domains
            VStack(alignment: .leading, spacing: 6) {
                Text("Custom domains")
                    .font(.headline)
                    .fontWeight(.medium)
                TextField("example.com, another.com", text: $viewModel.customSitesText)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            // Duration
            VStack(spacing: 12) {
                Text("Duration")
                    .font(.headline)
                    .fontWeight(.medium)

                HStack(spacing: 24) {
                    Stepper("Hours: \(viewModel.hours)", value: $viewModel.hours, in: 0...24)
                    Stepper("Minutes: \(viewModel.minutes)", value: $viewModel.minutes, in: 0...59, step: 5)
                }
            }

            Spacer()

            // Start button
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: {
                viewModel.showConfirmation = true
            }) {
                if viewModel.isProcessing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    Text("Start Blocking")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(!viewModel.canStartBlocking || viewModel.isProcessing)
            .alert("Confirm Block", isPresented: $viewModel.showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Block Sites", role: .destructive) {
                    viewModel.startBlocking()
                }
            } message: {
                let sites = viewModel.allSitesToBlock
                let duration = TimeFormatter.formatDurationShort(viewModel.totalDurationSeconds)
                Text("You are about to block \(sites.count) site(s) for \(duration).\n\nThis cannot be undone until the timer expires.")
            }

            Text("Cannot be undone until the timer expires")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(24)
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
            VStack(spacing: 6) {
                Image(systemName: site.icon)
                    .font(.title2)
                Text(site.name)
                    .font(.caption)
                    .fontWeight(.medium)
                let count = DomainExpander.subdomainCount(for: site.domain)
                Text("+ \(count) subdomains")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.red.opacity(0.15) : Color.secondary.opacity(0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.red : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
