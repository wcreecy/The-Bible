//
//  PrayerTimerActivity.swift
//  The Bible WidgetsExtension
//
//  Created by William Creecy on 11/7/25.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Local App Intents for Live Activity Controls (iOS 17+)
// Keeping intents defined in case you use them elsewhere, but they won’t be shown as buttons now.
@available(iOS 17.0, *)
struct PrayerTimerTogglePauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause/Resume Prayer Timer"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            shared.set("togglePause", forKey: "prayerTimerPendingAction")
            shared.set(UUID().uuidString, forKey: "prayerTimerActionToken")
        }
        return .result()
    }
}

@available(iOS 17.0, *)
struct PrayerTimerAddFiveMinutesIntent: AppIntent {
    static var title: LocalizedStringResource = "+5 Minutes"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            shared.set("add5", forKey: "prayerTimerPendingAction")
            shared.set(UUID().uuidString, forKey: "prayerTimerActionToken")
        }
        return .result()
    }
}

@available(iOS 17.0, *)
struct PrayerTimerStopIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Prayer Timer"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            shared.set("stop", forKey: "prayerTimerPendingAction")
            shared.set(UUID().uuidString, forKey: "prayerTimerActionToken")
        }
        return .result()
    }
}

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

private func focusLogoView() -> some View {
    // Try to load from widget bundle by name; fall back to an SF Symbol if missing
    if let ui = UIImage(named: "WidgetLogo") ?? UIImage(named: "AppIcon") {
        return AnyView(
            Image(uiImage: ui)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        )
    } else {
        return AnyView(
            Image(systemName: "target")
                .font(.system(size: 14, weight: .semibold))
        )
    }
}

// 2) Widget configuration for Lock Screen + Dynamic Island
struct PrayerTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerTimerAttributes.self) { context in
            // Lock Screen (and banner) UI — Larger, color-tinted, no controls
            let tint = timerTintColor(context)
            VStack(spacing: 10) {
                if context.state.status != "Focus" {
                    HStack(alignment: .firstTextBaseline) {
                        Text(context.attributes.sessionName)
                            .font(.headline)
                            .foregroundStyle(tint)
                        Spacer()
                        if context.state.total > 0 {
                            ProgressView(value: progress(context))
                                .tint(tint)
                                .frame(width: 90)
                        }
                    }
                }
                if context.state.status == "Focus" {
                    VStack(alignment: .leading, spacing: 6) {
                        if let title = (context.state.focusTitle?.isEmpty == false ? context.state.focusTitle : sharedFocusTitle()) {
                            Text(title)
                                .font(.title3.weight(.semibold))
                                .lineLimit(2)
                        }
                        if let body = (context.state.focusBody?.isEmpty == false ? context.state.focusBody : sharedFocusBody()) {
                            Text(body)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                } else {
                    // Big live countdown
                    Text(endDate(context.state.remaining), style: .timer)
                        .monospacedDigit()
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .activityBackgroundTint(.clear)
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
                                    .multilineTextAlignment(.center)
                            }
                            if let body = (context.state.focusBody?.isEmpty == false ? context.state.focusBody : sharedFocusBody()) {
                                Text(body)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        // Center both the title and the timer
                        VStack(alignment: .center, spacing: 6) {
                            Text(context.attributes.sessionName)
                                .font(.headline)
                                .multilineTextAlignment(.center)

                            Text(endDate(context.state.remaining), style: .timer)
                                .monospacedDigit()
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(timerTintColor(context))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Keep empty so nothing shows on the far right
                    EmptyView()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // No controls here anymore. Also avoid duplicating Focus body/title shown in center.
                    EmptyView()
                }
            } compactLeading: {
                if context.state.status == "Focus" {
                    focusLogoView()
                } else {
                    ProgressRing(progress: progress(context), tint: timerTintColor(context))
                }
            } compactTrailing: {
                if context.state.status == "Focus" {
                    // Keep Focus mode unconstrained so title can extend
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
                    // Constrain the timer to 48pt width
                    Text(endDate(context.state.remaining), style: .timer)
                        .font(.caption2)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: 48, alignment: .trailing)
                        .clipped()
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

    private func endDate(_ remaining: Int) -> Date {
        Date().addingTimeInterval(TimeInterval(max(0, remaining)))
    }

    private func timerTintColor(_ context: ActivityViewContext<PrayerTimerAttributes>) -> Color {
        let remaining = context.state.remaining
        let total = context.state.total
        guard total > 0 else { return .accentColor }
        if remaining > 300 { // > 5 minutes
            return .green
        } else if remaining > 120 { // 2–5 minutes
            return .yellow
        } else {
            return .red
        }
    }

    private struct ProgressRing: View {
        var progress: Double // 0.0 ... 1.0
        var tint: Color
        var lineWidth: CGFloat = 3
        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.15), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
        }
    }
}
