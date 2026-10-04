import SwiftUI
import AVFAudio

struct SettingsTimerSection: View {
    @AppStorage("timerSoundSelection") private var timerSoundSelection: String = TimerSound.default.rawValue
    @State private var previewPlayer = TimerSoundPreviewPlayer()

    var body: some View {
        Section(
            header: Text("Timer").foregroundStyle(.primary),
            footer: Text("Sound played when the timer ends.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
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
                        previewPlayer.play(sound)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Play Preview")
                    .accessibilityHint("Plays the selected timer sound")
                }
            } label: {
                Label("Timer Sound", systemImage: "speaker.wave.2")
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
        .headerProminence(.increased)
    }
}

@MainActor
private final class TimerSoundPreviewPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat?

    init() {
        format = AVAudioFormat(
            standardFormatWithSampleRate: 44_100,
            channels: 1
        )

        guard let format else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play(_ sound: TimerSound) {
        guard let format,
              let buffer = makeBuffer(for: sound, format: format) else {
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)

            player.stop()
            if !engine.isRunning {
                engine.prepare()
                try engine.start()
            }

            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
        } catch {
            // A preview failure should not prevent the selected alarm tone from being saved.
        }
    }

    private func makeBuffer(
        for sound: TimerSound,
        format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let duration = 0.85
        let frameCount = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ), let samples = buffer.floatChannelData?[0] else {
            return nil
        }

        buffer.frameLength = frameCount
        let frequencies = previewFrequencies(for: sound)

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / format.sampleRate
            let progress = time / duration
            let noteIndex = min(
                Int(progress * Double(frequencies.count)),
                frequencies.count - 1
            )
            let frequency = frequencies[noteIndex]
            let attack = min(progress / 0.025, 1)
            let decay = pow(max(0, 1 - progress), 2.2)
            let envelope = attack * decay
            let fundamental = sin(2 * Double.pi * frequency * time)
            let harmonic = sin(2 * Double.pi * frequency * 2.01 * time) * 0.22
            samples[frame] = Float((fundamental + harmonic) * envelope * 0.35)
        }

        return buffer
    }

    private func previewFrequencies(for sound: TimerSound) -> [Double] {
        switch sound {
        case .bell: [880, 1_174]
        case .chime: [659, 784, 988]
        case .glass: [1_318, 1_568]
        case .horn: [392, 330]
        case .piano: [523, 659, 784]
        case .pop: [988, 659]
        case .synth: [440, 554, 659, 880]
        }
    }
}
