import SwiftUI

struct PrayerStudyTimerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: (Int) -> Void

    @State private var selectedMinutes: Int = 15
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("Prayer/Study Timer")
                .font(.title2)
                .bold()

            if contextualTipsEnabled {
                ContextualTipView(
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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }
}
