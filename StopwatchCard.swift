import SwiftUI

struct StopwatchCard: View {
    @Binding var prayerMode: HomeView.PrayerMode

    let stopwatchRunning: Bool
    let stopwatchElapsed: Int
    let formattedStopwatch: (Int) -> String

    let onStart: () -> Void
    let onPause: () -> Void
    let onStop: () -> Void

    let isTimerRunning: Bool
    let modePicker: (_ disabled: Bool) -> AnyView

    var body: some View {
        HeroCard(
            title: "Stopwatch",
            subtitle: nil,
            icon: "stopwatch",
            tint: .blue,
            trailingAccessory: {
                modePicker(isTimerRunning || stopwatchRunning)
            }
        ) {
            HStack(alignment: .center, spacing: 16) {
                Group {
                    if stopwatchRunning {
                        Button(action: onPause) {
                            Image(systemName: "pause.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.yellow)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Pause")
                    } else if stopwatchElapsed > 0 {
                        Button(action: onStart) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Resume")
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedStopwatch(stopwatchElapsed))
                    .font(.system(size: 36, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(stopwatchRunning ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if stopwatchRunning { onPause() } else { onStart() }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(stopwatchRunning ? "Pause stopwatch" : (stopwatchElapsed > 0 ? "Resume stopwatch" : "Start stopwatch"))
                    .accessibilityHint("Tap the time to \(stopwatchRunning ? "pause" : (stopwatchElapsed > 0 ? "resume" : "start"))")

                HStack(spacing: 16) {
                    if stopwatchRunning {
                        Button(action: onStop) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 44))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Stop")
                    } else if stopwatchElapsed > 0 {
                        Button(action: onStop) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 44))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Stop")
                    } else {
                        Button(action: onStart) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.green)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
