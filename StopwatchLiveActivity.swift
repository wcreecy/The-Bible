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
                    // Only title + timer stacked, centered
                    VStack(alignment: .center, spacing: 4) {
                        Text(context.attributes.sessionName)
                            .font(.headline)
                            .multilineTextAlignment(.center)

                        let startDate = Date(timeIntervalSinceNow: -Double(context.state.elapsed))
                        if context.state.status == "Running" {
                            Text(startDate, style: .timer)
                                .font(.title2)
                                .monospacedDigit()
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .multilineTextAlignment(.center)
                        } else {
                            Text(timeString(context.state.elapsed))
                                .font(.title2)
                                .monospacedDigit()
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                // Removed trailing and bottom regions to keep expanded island compact
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
