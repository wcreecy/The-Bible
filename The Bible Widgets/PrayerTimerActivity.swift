//
//  PrayerTimerActivity.swift
//  The Bible WidgetsExtension
//
//  Created by William Creecy on 11/7/25.
//

import ActivityKit
import WidgetKit
import SwiftUI
#if canImport(AppIntents)
import AppIntents
#endif
#if canImport(AppIntentsUI)
import AppIntentsUI
#endif

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
                    VStack(alignment: .center, spacing: 8) {
                        // Top: Name
                        Text(context.attributes.sessionName)
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        // Middle: Ring + Timer side by side for compactness
                        HStack(alignment: .center, spacing: 10) {
                            ProgressRing(progress: progress(context), tint: timerTintColor(context), lineWidth: 5, size: 36)
                            Text(endDate(context.state.remaining), style: .timer)
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }

                        // Bottom: Compact controls
                        // AppIntentButton on iOS 17+ if available; otherwise deep links
                        if #available(iOS 17.0, *) {
#if canImport(AppIntentsUI)
                            HStack(spacing: 14) {
                                AppIntentButton(PauseOrResumePrayerTimerIntent()) {
                                    Image(systemName: context.state.status == "Paused" ? "play.fill" : "pause.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .accessibilityLabel(context.state.status == "Paused" ? "Resume" : "Pause")

                                AppIntentButton(AddFiveMinutesPrayerTimerIntent()) {
                                    Text("+5")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .accessibilityLabel("Add five minutes")

                                AppIntentButton(StopPrayerTimerIntent()) {
                                    Image(systemName: "stop.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .controlSize(.small)
                                .accessibilityLabel("Stop")
                            }
#else
                            HStack(spacing: 14) {
                                Link(destination: URL(string: "thebible://timer?action=togglePause")!) {
                                    Image(systemName: context.state.status == "Paused" ? "play.fill" : "pause.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Link(destination: URL(string: "thebible://timer?action=add5")!) {
                                    Text("+5").font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Link(destination: URL(string: "thebible://timer?action=stop")!) {
                                    Image(systemName: "stop.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .controlSize(.small)
                            }
#endif
                        } else {
                            HStack(spacing: 14) {
                                Link(destination: URL(string: "thebible://timer?action=togglePause")!) {
                                    Image(systemName: context.state.status == "Paused" ? "play.fill" : "pause.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Link(destination: URL(string: "thebible://timer?action=add5")!) {
                                    Text("+5").font(.caption.weight(.semibold))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Link(destination: URL(string: "thebible://timer?action=stop")!) {
                                    Image(systemName: "stop.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(.vertical, 4)
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
                        VStack(spacing: 6) {
                            Text(context.attributes.sessionName)
                                .font(.subheadline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            HStack(spacing: 8) {
                                ProgressRing(progress: progress(context), tint: timerTintColor(context), lineWidth: 4, size: 28)
                                Text(endDate(context.state.remaining), style: .timer)
                                    .font(.headline)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.status == "Focus" {
                        EmptyView()
                    } else {
                        Text(endDate(context.state.remaining), style: .timer)
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
                        // Controls (Pause/Resume, +5, Stop)
                        if #available(iOS 17.0, *) {
#if canImport(AppIntentsUI)
                            HStack(spacing: 16) {
                                AppIntentButton(PauseOrResumePrayerTimerIntent()) { Image(systemName: context.state.status == "Paused" ? "play.fill" : "pause.fill") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                AppIntentButton(AddFiveMinutesPrayerTimerIntent()) { Text("+5").font(.caption.weight(.semibold)) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                AppIntentButton(StopPrayerTimerIntent()) { Image(systemName: "stop.fill") }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    .controlSize(.small)
                            }
#else
                            HStack(spacing: 16) {
                                Link(destination: URL(string: "thebible://timer?action=togglePause")!) { Image(systemName: context.state.status == "Paused" ? "play.fill" : "pause.fill") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                Link(destination: URL(string: "thebible://timer?action=add5")!) { Text("+5").font(.caption.weight(.semibold)) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                Link(destination: URL(string: "thebible://timer?action=stop")!) { Image(systemName: "stop.fill") }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    .controlSize(.small)
                            }
#endif
                        } else {
                            HStack(spacing: 16) {
                                Link(destination: URL(string: "thebible://timer?action=togglePause")!) { Image(systemName: context.state.status == "Paused" ? "play.fill" : "pause.fill") }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                Link(destination: URL(string: "thebible://timer?action=add5")!) { Text("+5").font(.caption.weight(.semibold)) }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                Link(destination: URL(string: "thebible://timer?action=stop")!) { Image(systemName: "stop.fill") }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.red)
                                    .controlSize(.small)
                            }
                        }
                    }
                }
            } compactLeading: {
                if context.state.status == "Focus" {
                    focusLogoView()
                } else {
                    ProgressRing(progress: progress(context), tint: timerTintColor(context))
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
                    Text(endDate(context.state.remaining), style: .timer)
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
        var size: CGFloat = 22
        var body: some View {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.15), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: size, height: size)
        }
    }
}

