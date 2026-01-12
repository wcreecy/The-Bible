import SwiftUI

struct SettingsLiveActivitiesSection: View {
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true

    var body: some View {
        Section(
            header: Text("Live Activities").foregroundStyle(.white),
            footer: Text("Show your Prayer Timer, Stopwatch, or Daily Focus on the Lock Screen and Dynamic Island. You can turn this off anytime.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.7))
        ) {
            Toggle(isOn: $liveActivitiesEnabled) {
                Label("Enable Live Activities", systemImage: "livephoto.play")
            }
            .accessibilityIdentifier("liveActivitiesToggle")
        }
        .onChange(of: liveActivitiesEnabled) { _, enabled in
            if !enabled {
                PrayerTimerActivityController.shared.cancel()
                StopwatchActivityController.shared.cancel()
            }
        }
        .headerProminence(.increased)
    }
}
