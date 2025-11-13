import ActivityKit
import WidgetKit
import SwiftUI
#if canImport(AppIntents)
import AppIntents
#endif

struct StopwatchLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StopwatchAttributes.self) { context in
#if canImport(AppIntentsUI)
            if #available(iOS 17.0, *) {
                VStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "stopwatch")
                        Text(context.attributes.sessionName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(context.state.status)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    let startDate = Date(timeIntervalSinceNow: -Double(context.state.elapsed))
                    if context.state.status == "Running" {
                        Text(startDate, style: .timer)
                            .monospacedDigit()
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    } else {
                        Text(timeString(context.state.elapsed))
                            .monospacedDigit()
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }

                    HStack(spacing: 16) {
                        if context.state.status == "Running" {
                            AppIntentButton(PauseStopwatchIntent()) {
                                Label("Pause", systemImage: "pause.fill")
                            }
                            .buttonStyle(.bordered)

                            AppIntentButton(StopStopwatchIntent()) {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        } else {
                            AppIntentButton(ResumeStopwatchIntent()) {
                                Label("Resume", systemImage: "play.fill")
                            }
                            .buttonStyle(.bordered)

                            AppIntentButton(StopStopwatchIntent()) {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                    }
                }
                .padding()
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch")
                    Text(context.attributes.sessionName)
                        .font(.headline)
                    Spacer()
                    Text(timeString(context.state.elapsed))
                        .monospacedDigit()
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .padding()
            }
#else
            HStack(spacing: 8) {
                Image(systemName: "stopwatch")
                Text(context.attributes.sessionName)
                    .font(.headline)
                Spacer()
                Text(timeString(context.state.elapsed))
                    .monospacedDigit()
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding()
#endif
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "stopwatch")
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 6) {
                        Text(context.attributes.sessionName).font(.headline)
                        let startDate = Date(timeIntervalSinceNow: -Double(context.state.elapsed))
                        if context.state.status == "Running" {
                            Text(startDate, style: .timer)
                                .font(.title2)
                                .monospacedDigit()
                        } else {
                            Text(timeString(context.state.elapsed))
                                .font(.title2)
                                .monospacedDigit()
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
#if canImport(AppIntentsUI)
    if #available(iOS 17.0, *) {
        HStack(spacing: 8) {
            if context.state.status == "Running" {
                AppIntentButton(PauseStopwatchIntent()) {
                    Image(systemName: "pause.fill")
                }
                AppIntentButton(StopStopwatchIntent()) {
                    Image(systemName: "stop.fill")
                }
            } else {
                AppIntentButton(ResumeStopwatchIntent()) {
                    Image(systemName: "play.fill")
                }
                AppIntentButton(StopStopwatchIntent()) {
                    Image(systemName: "stop.fill")
                }
            }
        }
    } else {
        HStack(spacing: 8) {
            Text(context.state.status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
#else
    HStack(spacing: 8) {
        Text(context.state.status)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
#endif
                }
                DynamicIslandExpandedRegion(.bottom) {
#if canImport(AppIntentsUI)
        if #available(iOS 17.0, *) {
            HStack(spacing: 16) {
                if context.state.status == "Running" {
                    AppIntentButton(PauseStopwatchIntent()) {
                        Label("Pause", systemImage: "pause.fill")
                    }
                    .buttonStyle(.bordered)

                    AppIntentButton(StopStopwatchIntent()) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    AppIntentButton(ResumeStopwatchIntent()) {
                        Label("Resume", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)

                    AppIntentButton(StopStopwatchIntent()) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(.top, 4)
        } else {
            HStack(spacing: 8) {
                Text(context.state.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
#else
        HStack(spacing: 8) {
            Text(context.state.status)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
#endif
    }
            } compactLeading: {
                Image(systemName: "stopwatch")
            } compactTrailing: {
                let startDate = Date(timeIntervalSinceNow: -Double(context.state.elapsed))
                if context.state.status == "Running" {
                    Text(startDate, style: .timer).monospacedDigit()
                } else {
                    Text(shortString(context.state.elapsed)).monospacedDigit()
                }
            } minimal: {
                Image(systemName: "stopwatch")
            }
            .widgetURL(URL(string: "thebible://stopwatch"))
        }
    }
}

private func timeString(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
    return String(format: "%02d:%02d", m, s)
}

private func shortString(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}
