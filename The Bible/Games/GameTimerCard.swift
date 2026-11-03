import SwiftUI

struct GameTimerCard: View {
    let remainingSeconds: Int
    let tint: Color
    let isPulsing: Bool
    let formattedTime: String
    let isDisabled: Bool

    init(
        remainingSeconds: Int,
        tint: Color,
        isPulsing: Bool,
        formattedTime: String? = nil,
        isDisabled: Bool = false
    ) {
        self.remainingSeconds = remainingSeconds
        self.tint = tint
        self.isPulsing = isPulsing
        self.formattedTime = formattedTime ?? "\(remainingSeconds)s"
        self.isDisabled = isDisabled
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isDisabled ? "timer.slash" : "timer")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(displayTint)

            Text("Time Remaining")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(formattedTime)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(displayTint)
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
                .strokeBorder(displayTint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isDisabled ? "Timer off" : "Time remaining")
        .accessibilityValue(formattedTime)
    }

    private var displayTint: Color {
        isDisabled ? .secondary : tint
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
