import SwiftUI

struct GameTimerCard: View {
    let remainingSeconds: Int
    let tint: Color
    let isPulsing: Bool
    let formattedTime: String

    init(
        remainingSeconds: Int,
        tint: Color,
        isPulsing: Bool,
        formattedTime: String? = nil
    ) {
        self.remainingSeconds = remainingSeconds
        self.tint = tint
        self.isPulsing = isPulsing
        self.formattedTime = formattedTime ?? "\(remainingSeconds)s"
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Text("Time Remaining")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(formattedTime)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .scaleEffect(isPulsing ? 1.12 : 1.0)
                .animation(.easeOut(duration: 0.18), value: isPulsing)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time remaining")
        .accessibilityValue(formattedTime)
    }
}

#Preview {
    GameTimerCard(
        remainingSeconds: 15,
        tint: .green,
        isPulsing: false
    )
    .padding()
}
