import SwiftUI

// Home's Prayer & Study Timer card, the banner shown while a timer runs, its detail sheet,
// and the alert when it finishes.

/// Keeps the timer's one-second observation scoped to this card instead of Home's full body.
struct HomePrayerTimerCard: View {
    let timerController: PrayerTimerController
    let verseOfDay: HomeVerseRef?
    let onOpenSetup: () -> Void

    var body: some View {
        PrayerTimerCard(
            isTimerRunning: timerController.isRunning,
            isPaused: timerController.isPaused,
            remainingSeconds: timerController.remainingSeconds,
            totalSeconds: timerController.totalSeconds,
            formattedTime: { TimeFormatters.compactClock($0) },
            verseOfDay: verseOfDay,
            canUndoStop: timerController.undoableStop != nil,
            onOpenSetup: onOpenSetup,
            onStartPreset: { timerController.start(minutes: $0) },
            onTogglePause: { timerController.togglePause() },
            onAddOne: { timerController.addOne() },
            onAddFive: { timerController.addFive() },
            onStop: { timerController.stop() },
            onUndoStop: { timerController.undoStop() }
        )
    }
}

/// A persistent reminder for an active timer when a Dynamic Island presentation is unavailable.
struct ActivePrayerTimerBanner: View {
    let kind: PrayerTimerKind
    let isPaused: Bool
    let remainingSeconds: Int
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: isPaused ? "pause.circle.fill" : kind.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(kind.sessionName)
                        .font(.subheadline.weight(.semibold))
                    Text(isPaused ? "Paused" : "In progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text(TimeFormatters.compactClock(remainingSeconds))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText(countsDown: true))

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.indigo.opacity(0.2))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Prayer timer")
        .accessibilityValue("\(TimeFormatters.compactClock(remainingSeconds)) remaining\(isPaused ? ", paused" : "")")
        .accessibilityHint("Opens prayer timer controls")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Gives the persistent banner a complete timer surface without changing the person's Home layout.
struct PrayerTimerDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let timerController: PrayerTimerController
    let verseOfDay: HomeVerseRef?
    @State private var showSetup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                PrayerTimerCard(
                    isTimerRunning: timerController.isRunning,
                    isPaused: timerController.isPaused,
                    remainingSeconds: timerController.remainingSeconds,
                    totalSeconds: timerController.totalSeconds,
                    formattedTime: { TimeFormatters.compactClock($0) },
                    verseOfDay: verseOfDay,
                    canUndoStop: timerController.undoableStop != nil,
                    onOpenSetup: { showSetup = true },
                    onStartPreset: { timerController.start(minutes: $0) },
                    onTogglePause: { timerController.togglePause() },
                    onAddOne: { timerController.addOne() },
                    onAddFive: { timerController.addFive() },
                    onStop: { timerController.stop() },
                    onUndoStop: { timerController.undoStop() }
                )
                .padding()
            }
            .navigationTitle("Prayer & Study Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showSetup) {
            PrayerStudyTimerSetupView(onStart: { minutes in
                timerController.start(minutes: minutes)
                showSetup = false
            })
            .presentationDetents([.medium, .large])
        }
    }
}

struct PrayerTimerFinishedAlert: ViewModifier {
    let timerController: PrayerTimerController

    func body(content: Content) -> some View {
        content
            .alert(
                timerController.kind.finishedTitle,
                isPresented: Bindable(timerController).showFinishedAlert
            ) {
                Button("Dismiss", role: .cancel) {
                    timerController.stopFinishAlerts()
                    timerController.showFinishedAlert = false
                }
            } message: {
                Text(timerController.kind.finishedMessage)
            }
    }
}
