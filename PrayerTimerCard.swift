import SwiftUI

struct PrayerTimerCard: View {
    enum Mode { case timer, stopwatch }

    @Binding var prayerMode: HomeView.PrayerMode

    // Timer state
    let isTimerRunning: Bool
    let isPaused: Bool
    let remainingSeconds: Int
    let timerTintColor: Color
    let formattedTime: (Int) -> String

    // Actions
    let onOpenSetup: () -> Void
    let onStartPreset: (Int) -> Void
    let onTogglePause: () -> Void
    let onAddOne: () -> Void
    let onAddFive: () -> Void
    let onAddTen: () -> Void
    let onStop: () -> Void

    // Stopwatch state to disable mode changes while active
    let stopwatchRunning: Bool

    // ModePicker provider (so HomeView can host the Picker bound to its own storage)
    let modePicker: (_ disabled: Bool) -> AnyView

    private func presetCircle(_ label: String) -> some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .frame(width: 40, height: 40)
            .foregroundStyle(.primary)
            .background(Circle().fill(Color(.secondarySystemBackground)))
            .overlay(Circle().stroke(Color.gray.opacity(0.25), lineWidth: 1))
            .buttonStyle(.plain)
    }

    var body: some View {
        Group {
            if prayerMode == .timer {
                if isTimerRunning {
                    HeroCard(
                        title: "Prayer Timer",
                        subtitle: nil,
                        icon: "timer",
                        tint: timerTintColor,
                        backgroundColor: timerTintColor.opacity(0.20),
                        strokeColor: timerTintColor.opacity(0.35),
                        trailingAccessory: {
                            modePicker(isTimerRunning || stopwatchRunning)
                        }
                    ) {
                        HStack(alignment: .center, spacing: 16) {
                            HStack(spacing: 16) {
                                Button(action: onTogglePause) {
                                    Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(isPaused ? Color.green : timerTintColor)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(isPaused ? "Resume" : "Pause")

                                Button(action: onStop) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Stop")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(formattedTime(remainingSeconds))
                                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                                .foregroundStyle(timerTintColor)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .contentShape(Rectangle())
                                .onTapGesture(perform: onTogglePause)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel(isPaused ? "Resume timer" : "Pause timer")
                                .accessibilityHint("Tap the time to \(isPaused ? "resume" : "pause")")

                            HStack(spacing: 16) {
                                Button(action: onAddOne) {
                                    Text("+1")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(Color.blue))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add 1 minute")

                                Button(action: onAddFive) {
                                    Text("+5")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(.white)
                                        .background(Circle().fill(Color.blue))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Add 5 minutes")
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    HeroCard(
                        title: "Prayer Timer",
                        subtitle: nil,
                        icon: "timer",
                        tint: .blue,
                        trailingAccessory: {
                            modePicker(isTimerRunning || stopwatchRunning)
                        }
                    ) {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button(action: onOpenSetup) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(width: 40, height: 40)
                                        .foregroundStyle(.primary)
                                        .background(Circle().fill(Color(.secondarySystemBackground)))
                                        .overlay(Circle().stroke(Color.gray.opacity(0.25), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Custom duration")

                                Button { onStartPreset(5) } label: { presetCircle("5") }
                                    .accessibilityLabel("Start 5 minutes")

                                Button { onStartPreset(10) } label: { presetCircle("10") }
                                    .accessibilityLabel("Start 10 minutes")

                                Button { onStartPreset(15) } label: { presetCircle("15") }
                                    .accessibilityLabel("Start 15 minutes")

                                Button { onStartPreset(20) } label: { presetCircle("20") }
                                    .accessibilityLabel("Start 20 minutes")

                                Button { onStartPreset(30) } label: { presetCircle("30") }
                                    .accessibilityLabel("Start 30 minutes")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)

                            Text(formattedTime(remainingSeconds == 0 ? 0 : remainingSeconds))
                                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 2)
                        }
                    }
                }
            } else {
                EmptyView() // Stopwatch is handled in StopwatchCard
            }
        }
    }
}
