import SwiftUI

/// Wraps its children onto rows, left to right, and stretches every child in a row to the row's
/// height, so a tile with a two-line gloss doesn't sit taller than its neighbors.
struct InterlinearFlowLayout: Layout {
    var spacing: CGFloat

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let width = measuredSize(of: subviews[index]).width
                subviews[index].place(
                    at: CGPoint(x: x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(width: width, height: row.height)
                )
                x += width + spacing
            }
        }
    }

    /// A tile's size once its gloss has wrapped. The ideal size alone reports the width the text
    /// is capped to but the height of the unwrapped line, so a two-line gloss would overflow its row.
    private func measuredSize(of subview: LayoutSubview) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        return subview.sizeThatFits(ProposedViewSize(width: ideal.width, height: nil))
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = measuredSize(of: subviews[index])
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

/// One word of the interlinear: the original over its transliteration, its meaning in this
/// verse, and its Strong's number.
struct InterlinearWordTile: View {
    /// Long glosses wrap instead of stretching a tile across the row.
    @ScaledMetric(relativeTo: .caption) private var maximumGlossWidth: CGFloat = 120

    let word: OriginalWord
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Text(word.original)
                    .font(.title3)
                    .foregroundStyle(.primary)
                // The meaning in this verse, then the dictionary's when it adds something.
                Text(word.contextGloss)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: maximumGlossWidth)
                    .fixedSize(horizontal: false, vertical: true)
                if let dictionary = word.tileDictionaryGloss {
                    Text(dictionary)
                        .font(.caption)
                        .foregroundStyle(.wordStudySecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: maximumGlossWidth)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let number = word.displayStrongsNumber {
                    Text(number)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.wordStudyNumber)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            // Takes the height of its row (see InterlinearFlowLayout), so tiles side by side match.
            .frame(maxHeight: .infinity)
            .background(
                isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.15)) : AnyShapeStyle(.background.secondary),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            }
            .overlay(alignment: .topTrailing) {
                // The word isn't in every text; the entry panel says which.
                if word.textVariant != nil {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.wordStudySecondary)
                        .padding(4)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Shows the dictionary entry")
        .accessibilityIdentifier("interlinearTile-\(word.id)")
    }

    private var accessibilityLabel: String {
        var parts = [word.original]
        if !word.transliteration.isEmpty { parts.append(word.transliteration) }
        if !word.contextGloss.isEmpty { parts.append(word.contextGloss) }
        if let dictionary = word.tileDictionaryGloss {
            parts.append(String(localized: "dictionary meaning \(dictionary)"))
        }
        if let number = word.displayStrongsNumber {
            parts.append(String(localized: "Strong’s \(number)"))
        }
        if let variant = word.textVariant {
            parts.append(variant.explanation)
        }
        return parts.joined(separator: ", ")
    }
}
