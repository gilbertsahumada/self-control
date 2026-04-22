import SwiftUI

struct DomainChip: View {
    let domain: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(domain)
                .font(Theme.monoSM.weight(.semibold))
                .foregroundColor(Theme.phosphor)
                .lineLimit(1)
                .truncationMode(.middle)
            Button(action: onRemove) {
                Text("×")
                    .font(Theme.mono(14, weight: .bold))
                    .foregroundColor(Theme.phosphorDim)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .help("Remove \(domain)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.phosphor.opacity(0.1))
        .overlay(Rectangle().stroke(Theme.phosphor, lineWidth: 1))
    }
}
