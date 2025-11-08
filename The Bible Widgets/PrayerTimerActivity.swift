//
//  PrayerTimerActivity.swift
//  The Bible WidgetsExtension
//
//  Created by William Creecy on 11/7/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

private func sharedFocusTitle() -> String? {
    let shared = UserDefaults(suiteName: "group.bible.app")
    let title = shared?.string(forKey: "focusTitle")?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let t = title, !t.isEmpty { return t }
    return nil
}

private func sharedFocusBody() -> String? {
    let shared = UserDefaults(suiteName: "group.bible.app")
    let body = shared?.string(forKey: "focusBody")?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let b = body, !b.isEmpty { return b }
    return nil
}

// 2) Widget configuration for Lock Screen + Dynamic Island
struct PrayerTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerTimerAttributes.self) { context in
            // Lock Screen (and banner) UI
            VStack(alignment: .leading, spacing: 6) {
                if context.state.status == "Focus" {
                    // Show title prominently on Lock Screen tile
                    if let title = (context.state.focusTitle?.isEmpty == false ? context.state.focusTitle : sharedFocusTitle()) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(2)
                    } else {
                        Text(context.attributes.sessionName)
                            .font(.headline)
                    }
                    if let body = (context.state.focusBody?.isEmpty == false ? context.state.focusBody : sharedFocusBody()) {
                        Text(body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } else {
                    Text(context.attributes.sessionName)
                        .font(.headline)
                    ProgressView(value: progress(context))
                    Text("\(formatted(context.state.remaining)) left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions
                DynamicIslandExpandedRegion(.leading) {
                    if context.state.status == "Focus" {
                        Text("❝")
                    } else {
                        Text("⏱")
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if context.state.status == "Focus" {
                        VStack(spacing: 6) {
                            if let title = (context.state.focusTitle?.isEmpty == false ? context.state.focusTitle : sharedFocusTitle()) {
                                Text(title)
                                    .font(.headline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Focus")
                                    .font(.headline)
                            }
                            if let body = (context.state.focusBody?.isEmpty == false ? context.state.focusBody : sharedFocusBody()) {
                                Text(body)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    } else {
                        VStack {
                            Text(context.attributes.sessionName)
                                .font(.headline)
                            ProgressView(value: progress(context))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.status == "Focus" {
                        EmptyView()
                    } else {
                        Text("\(short(context.state.remaining))")
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.status == "Focus" {
                        if let body = (context.state.focusBody?.isEmpty == false ? context.state.focusBody : sharedFocusBody()) {
                            Text(body)
                                .font(.subheadline)
                                .lineLimit(2)
                                .truncationMode(.tail)
                        } else if let title = (context.state.focusTitle?.isEmpty == false ? context.state.focusTitle : sharedFocusTitle()) {
                            Text(title)
                                .font(.subheadline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text("Focus")
                                .font(.subheadline)
                        }
                    } else {
                        Text(context.state.status)
                    }
                }
            } compactLeading: {
                if context.state.status == "Focus" {
                    Text("❝") // Decorative open quote for Focus mode
                } else {
                    Image(systemName: "timer") // Timer icon for Timer/Stopwatch modes
                }
            } compactTrailing: {
                if context.state.status == "Focus" {
                    if let title = context.state.focusTitle, !title.isEmpty {
                        Text(title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else if let fallback = sharedFocusTitle() {
                        Text(fallback)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text("")
                    }
                } else {
                    Text(short(context.state.remaining))
                        .monospacedDigit()
                }
            } minimal: {
                if context.state.status == "Focus" {
                    Text("❝")
                } else {
                    Image(systemName: "timer")
                }
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

