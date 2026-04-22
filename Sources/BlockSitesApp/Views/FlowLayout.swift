import SwiftUI

/// Wraps children onto the next line when they exceed the available width.
/// Used to lay out the variable-length domain chip row.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var runSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, in: maxWidth)
        let height = rows.reduce(CGFloat(0)) { acc, row in
            acc + row.height + (acc > 0 ? runSpacing : 0)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : rows.map { $0.width }.max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, in: bounds.width)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row.items {
                item.view.place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height)
                )
                x += item.size.width + spacing
            }
            y += row.height + runSpacing
        }
    }

    private struct Row {
        var items: [(view: LayoutSubview, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            var current = rows[rows.count - 1]
            let projected = current.width + (current.items.isEmpty ? 0 : spacing) + size.width
            if projected > maxWidth && !current.items.isEmpty {
                rows.append(Row())
                current = rows[rows.count - 1]
            }
            if !current.items.isEmpty {
                current.width += spacing
            }
            current.items.append((view, size))
            current.width += size.width
            current.height = max(current.height, size.height)
            rows[rows.count - 1] = current
        }
        return rows
    }
}
