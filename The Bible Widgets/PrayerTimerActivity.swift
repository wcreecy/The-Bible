//
//  PrayerTimerActivity.swift
//  The Bible WidgetsExtension
//
//  Created by William Creecy on 11/7/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// 2) Widget configuration for Lock Screen + Dynamic Island
struct PrayerTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerTimerAttributes.self) { context in
            // Lock Screen (and banner) UI
            VStack(alignment: .leading, spacing: 6) {
                Text(context.attributes.sessionName)
                    .font(.headline)
                ProgressView(value: progress(context))
                Text("\(formatted(context.state.remaining)) left")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    Text("⏱")
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack {
                        Text(context.attributes.sessionName)
                            .font(.headline)
                        ProgressView(value: progress(context))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(short(context.state.remaining))")
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.status)
                }
            } compactLeading: {
                Text("⏱")
            } compactTrailing: {
                Text(short(context.state.remaining))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
            }
        }
    }

    private func progress(_ context: ActivityViewContext<PrayerTimerAttributes>) -> Double {
        let total = max(1, context.state.total)
        let remaining = max(0, min(context.state.remaining, total))
        return 1.0 - (Double(remaining) / Double(total))
    }
    private func short(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
    private func formatted(_ seconds: Int) -> String {
        if seconds >= 3600 {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return String(format: "%dh %dm", h, m)
        } else {
            let m = seconds / 60
            let s = seconds % 60
            return String(format: "%dm %02ds", m, s)
        }
    }
}
