import SwiftUI

/// A small labeled value used by the game stats cards.

struct MetricChip: View {
    let title: String
    let value: String
    let tint: Color
    var fillsWidth: Bool = false
    var scrollsValue: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if scrollsValue {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(value)
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .fixedSize(horizontal: true, vertical: false)
                }
            } else {
                Text(value)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .allowsTightening(true)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}
