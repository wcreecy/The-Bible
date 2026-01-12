import SwiftUI
import AudioToolbox

struct SettingsTimerSection: View {
    @AppStorage("timerSoundSelection") private var timerSoundSelection: String = TimerSound.default.rawValue

    var body: some View {
        Section(
            header: Text("Timer").foregroundStyle(.white),
            footer: Text("Choose the sound that plays when the prayer/study timer finishes.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.7))
        ) {
            LabeledContent {
                HStack(spacing: 10) {
                    Picker("", selection: Binding<String>(
                        get: { timerSoundSelection },
                        set: { timerSoundSelection = $0 }
                    )) {
                        ForEach(TimerSound.allCases) { sound in
                            Text(sound.title).tag(sound.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("timerSoundPicker")

                    Button {
                        let sound = TimerSound(rawValue: timerSoundSelection) ?? .default
                        AudioServicesPlaySystemSound(sound.systemSoundID)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Play Preview")
                    .accessibilityHint("Plays the selected timer sound")
                }
            } label: {
                Label("Timer Sound", systemImage: "speaker.wave.2")
            }
        }
        .headerProminence(.increased)
    }
}
