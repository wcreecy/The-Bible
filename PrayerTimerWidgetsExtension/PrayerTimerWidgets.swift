import SwiftUI
import WidgetKit
import ActivityKit

@available(iOS 16.1, *)
struct PrayerTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerTimerAttributes.self) { context in
            // Lock Screen / Banner Live Activity view
            HStack(spacing: 12) {
                Image(systemName: context.state.isPaused ? "pause.fill" : "play.fill")
                    .foregroundStyle(context.state.isPaused ? .yellow : .green)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .bold()
                    // Countdown to the end date
                    Text(context.state.endDate, style: .timer)
                        .font(.system(.title3, design: .monospaced))
                        .monospacedDigit()
                }
                Spacer()
                // Secondary state indicator
                Text(context.state.isPaused ? "Paused" : "In progress")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPaused ? "pause.fill" : "play.fill")
                        .foregroundStyle(context.state.isPaused ? .yellow : .green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endDate, style: .timer)
                        .font(.headline)
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .bold()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isPaused ? "Paused" : "In progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "play.fill")
            } compactTrailing: {
                Text(context.state.endDate, style: .timer)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "play.fill")
            }
        }
    }
}

@available(iOS 16.1, *)
struct PrayerTimerWidgets: WidgetBundle {
    var body: some Widget {
        PrayerTimerLiveActivity()
    }
}

extension PrayerTimerAttributes {
    fileprivate static var preview: PrayerTimerAttributes {
        PrayerTimerAttributes(title: "Prayer Timer")
    }
}

extension PrayerTimerAttributes.ContentState {
    fileprivate static var running: PrayerTimerAttributes.ContentState {
        PrayerTimerAttributes.ContentState(
            endDate: Date().addingTimeInterval(600),
            isPaused: false,
            remainingSeconds: 600
        )
    }

    fileprivate static var paused: PrayerTimerAttributes.ContentState {
        PrayerTimerAttributes.ContentState(
            endDate: Date().addingTimeInterval(600),
            isPaused: true,
            remainingSeconds: 600
        )
    }
}

#Preview("Live Activity", as: .content, using: PrayerTimerAttributes.preview) {
    PrayerTimerLiveActivity()
} contentStates: {
    PrayerTimerAttributes.ContentState.running
    PrayerTimerAttributes.ContentState.paused
}

#Preview("Dynamic Island (Expanded)", as: .dynamicIsland(.expanded), using: PrayerTimerAttributes.preview) {
    PrayerTimerLiveActivity()
} contentStates: {
    PrayerTimerAttributes.ContentState.running
    PrayerTimerAttributes.ContentState.paused
}
