import SwiftUI

struct ModePicker: View {
    @Binding var prayerMode: HomeView.PrayerMode
    let disabled: Bool

    var body: some View {
        HStack(spacing: 0) {
            segmentButton(title: "Timer", mode: .timer, systemImage: "timer")
            verticalSeparator()
            segmentButton(title: "Stopwatch", mode: .stopwatch, systemImage: "stopwatch")
        }
        .frame(height: 28)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .opacity(disabled ? 0.5 : 1.0)
        .allowsHitTesting(!disabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode")
    }

    private func segmentButton(title: String, mode: HomeView.PrayerMode, systemImage: String) -> some View {
        let selected = prayerMode == mode
        return Button {
            guard !disabled else { return }
            if prayerMode != mode {
                let h = UIImpactFeedbackGenerator(style: .light)
                h.impactOccurred()
                prayerMode = mode
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.caption.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? .primary : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Group {
                    if selected {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.15))
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func verticalSeparator() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 1, height: 20)
    }
}

