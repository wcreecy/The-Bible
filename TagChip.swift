import SwiftUI

// Shared UI: tag chip
struct TagChip: View {
    let text: String
    let tint: Color
    let isSelected: Bool
    var onTap: (() -> Void)? = nil

    var body: some View {
        let bg = tint.opacity(isSelected ? 0.30 : 0.15)
        let stroke = tint.opacity(isSelected ? 0.8 : 0.4)
        Button(action: { onTap?() }) {
            Text(text)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(bg, in: Capsule())
                .overlay(Capsule().stroke(stroke, lineWidth: isSelected ? 2 : 1))
                .foregroundStyle(tint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 1)
    }
}
