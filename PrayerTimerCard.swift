import SwiftUI

struct PrayerTimerCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

    private func presetCircle(_ label: String) -> some View {
        Text(label)
    }

    var body: some View {
        if isTimerRunning {
                    HeroCard(
                        title: "Prayer Timer",
                        subtitle: nil,
                        icon: "timer",
                        tint: timerTintColor,
                        backgroundColor: timerTintColor.opacity(0.20),
                        strokeColor: timerTintColor.opacity(0.35)
                    ) {
                        HStack(alignment: .center, spacing: 16) {
                            HStack(spacing: 16) {
                                Button(action: onTogglePause) {
                                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                                }
                                .buttonStyle(.glass(.regular.tint(isPaused ? .green : .yellow)))
                                .buttonBorderShape(.circle)
                                .controlSize(.large)
                                .accessibilityLabel(isPaused ? "Resume" : "Pause")

                                Button(action: onStop) {
                                    Image(systemName: "stop.fill")
                                }
                                .buttonStyle(.glass(.regular.tint(.red)))
                                .buttonBorderShape(.circle)
                                .controlSize(.large)
                                .accessibilityLabel("Stop")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text(formattedTime(remainingSeconds))
                                .font(.system(
                                    size: horizontalSizeClass == .compact ? 28 : 36,
                                    weight: .semibold,
                                    design: .monospaced
                                ))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
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
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                                .buttonStyle(.glass(.clear))
                                .buttonBorderShape(.circle)
                                .controlSize(.large)
                                .accessibilityLabel("Add 1 minute")

                                Button(action: onAddFive) {
                                    Text("+5")
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                                .buttonStyle(.glass(.clear))
                                .buttonBorderShape(.circle)
                                .controlSize(.large)
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
                        tint: .blue
                    ) {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Button(action: onOpenSetup) {
                                    Image(systemName: "slider.horizontal.3")
                                }
                                .buttonStyle(ModernCircleButtonStyle(tint: .blue))
                                .accessibilityLabel("Custom timer duration")

                                Button { onStartPreset(5) } label: { presetCircle("5") }
                                    .buttonStyle(ModernCircleButtonStyle(tint: .blue))
                                    .accessibilityLabel("Start 5 minutes")

                                Button { onStartPreset(10) } label: { presetCircle("10") }
                                    .buttonStyle(ModernCircleButtonStyle(tint: .blue))
                                    .accessibilityLabel("Start 10 minutes")

                                Button { onStartPreset(15) } label: { presetCircle("15") }
                                    .buttonStyle(ModernCircleButtonStyle(tint: .blue))
                                    .accessibilityLabel("Start 15 minutes")

                                Button { onStartPreset(20) } label: { presetCircle("20") }
                                    .buttonStyle(ModernCircleButtonStyle(tint: .blue))
                                    .accessibilityLabel("Start 20 minutes")

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
    }
}
