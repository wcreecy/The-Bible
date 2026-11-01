import SwiftUI

/// Play time that only counts while the app is in front.
///
/// Games that report how long a solve took (Crossword, Word) use this instead of comparing
/// the start time with the finish time, so a phone call or a trip to another app in the
/// middle of a puzzle doesn't count toward the solve time.
nonisolated struct GameActiveClock: Equatable, Sendable {
    /// Time counted before the current stretch of play.
    private(set) var accumulated: TimeInterval = 0
    /// When the current stretch of play began, or nil while paused.
    private(set) var runningSince: Date?

    var isRunning: Bool { runningSince != nil }

    /// Starts counting from zero, optionally carrying over time already played.
    mutating func start(at now: Date = Date(), alreadyElapsed: TimeInterval = 0) {
        accumulated = max(0, alreadyElapsed)
        runningSince = now
    }

    /// Stops counting and keeps the time so far. Does nothing if already paused.
    mutating func pause(at now: Date = Date()) {
        guard let runningSince else { return }
        accumulated += max(0, now.timeIntervalSince(runningSince))
        self.runningSince = nil
    }

    /// Continues counting. Does nothing if already running.
    mutating func resume(at now: Date = Date()) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    func elapsed(at now: Date = Date()) -> TimeInterval {
        accumulated + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    /// Whole seconds played, for results and stats.
    func elapsedSeconds(at now: Date = Date()) -> Int {
        Int(elapsed(at: now).rounded())
    }
}

extension View {
    /// Calls `action` with false when the app stops being active and with true when it's
    /// active again.
    ///
    /// "Not active" covers everything that takes the player away from the game: a phone
    /// call, switching apps, the app switcher, Control Center, Notification Center, and
    /// locking the phone. Games use it to pause their clocks.
    func onAppActiveChange(_ action: @escaping (_ isActive: Bool) -> Void) -> some View {
        modifier(AppActiveChangeModifier(action: action))
    }
}

private struct AppActiveChangeModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let action: (Bool) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { oldPhase, newPhase in
            let wasActive = oldPhase == .active
            let isActive = newPhase == .active
            if wasActive != isActive {
                action(isActive)
            }
        }
    }
}

/// Shown in place of a countdown game's question while it's paused, so pausing can't be
/// used as extra thinking time.
struct GamePausedView: View {
    let tint: Color
    /// Seconds left on the clock, shown so the player knows where they stand.
    var remainingSeconds: Int?
    let onResume: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(tint)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Paused")
                    .font(.title2.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                Text("The question is hidden until you resume.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let remainingSeconds {
                Label {
                    Text(Duration.seconds(remainingSeconds).formatted(.time(pattern: .minuteSecond)))
                        .monospacedDigit()
                } icon: {
                    Image(systemName: "timer")
                }
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("\(remainingSeconds) seconds left"))
            }

            Button("Resume", systemImage: "play.fill", action: onResume)
                .buttonStyle(GameProminentButtonStyle(tint: tint))
                .frame(maxWidth: 280)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
        .padding(.top, 24)
    }
}

/// The toolbar button that pauses a countdown game.
struct GamePauseButton: View {
    let action: () -> Void

    var body: some View {
        Button("Pause", systemImage: "pause.fill", action: action)
            .accessibilityHint("Stops the timer and hides the question")
    }
}

#Preview("Paused") {
    GamePausedView(tint: .indigo, remainingSeconds: 12, onResume: {})
        .padding()
}
