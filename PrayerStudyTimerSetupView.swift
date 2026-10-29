import SwiftUI

struct PrayerStudyTimerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: (Int) -> Void

    @State private var selectedMinutes: Int = 15
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage(PrayerTimerController.lastMinutesKey) private var lastMinutes: Int = 0
    @AppStorage(PrayerTimerKind.preferenceKey) private var kindRaw = PrayerTimerKind.prayer.rawValue

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("Prayer & Study Timer")
                .font(.title2)
                .bold()

            Picker("Timer type", selection: $kindRaw) {
                ForEach(PrayerTimerKind.allCases) { kind in
                    Text(kind.title).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)

            if contextualTipsEnabled {
                ContextualTipView(
                    id: "timer.mindfulMinutes",
                    title: "Track mindful minutes",
                    message: "Completed prayer and study timers can contribute Mindful Minutes to Apple Health when access is allowed in Settings.",
                    systemImage: "heart.text.square"
                )
            }

            VStack(spacing: 16) {
                Text("Duration")
                    .font(.headline)

                Picker("Minutes", selection: $selectedMinutes) {
                    ForEach(1...120, id: \.self) { m in
                        Text("\(m) minute\(m == 1 ? "" : "s")").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 160)

                Text("Selected: \(selectedMinutes) minute\(selectedMinutes == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                onStart(selectedMinutes)
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("Start Timer")
                        .font(.headline)
                        .bold()
                    Spacer()
                }
            }
            .buttonStyle(GameProminentButtonStyle(tint: .blue))
            .controlSize(.large)

            Spacer()
        }
        .padding()
        .onAppear {
            // Start from the duration used last time.
            if (1...120).contains(lastMinutes) {
                selectedMinutes = lastMinutes
            }
        }
    }
}
