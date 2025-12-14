import SwiftUI

struct DayCell: View {
    let dayNumber: Int
    let met: Bool
    let future: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.caption)
                .foregroundStyle(future ? .tertiary : .secondary)
            Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(future ? AnyShapeStyle(.tertiary) : AnyShapeStyle(met ? Color.green : Color.red))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}
