import SwiftUI

struct ModePicker: View {
    @Binding var prayerMode: HomeView.PrayerMode
    let disabled: Bool

    var body: some View {
        Picker("", selection: $prayerMode) {
            Label("Timer", systemImage: "timer")
                .tag(HomeView.PrayerMode.timer)
            Label("Stopwatch", systemImage: "stopwatch")
                .tag(HomeView.PrayerMode.stopwatch)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(disabled)
        .accessibilityLabel("Mode")
        .onChange(of: prayerMode) { _, _ in
            // Haptic to mirror your prior feedback when switching modes
            let h = UIImpactFeedbackGenerator(style: .light)
            h.impactOccurred()
        }
    }
}
