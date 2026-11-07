import Foundation

/// Counts game time only while a game screen is open in the foreground.
/// Reading time comes from ReadingTimeTracker, the single source for reading stats.
@MainActor
final class GamePlayTimeSession {
    private var start: Date?
    private var flushTimer: Timer?

    /// Starts or stops counting to match whether a game screen is open.
    /// Call after any change to the scene phase, selected tab, or Games navigation.
    func update(isPlaying: Bool) {
        if isPlaying {
            guard start == nil else { return }
            start = Date()
            // Persist periodically so a crash or force quit loses at most a few seconds.
            let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.flush() }
            }
            RunLoop.main.add(timer, forMode: .common)
            flushTimer = timer
        } else {
            flush()
            start = nil
            flushTimer?.invalidate()
            flushTimer = nil
        }
    }

    private func flush() {
        guard let start else { return }
        // A game left open and untouched stops counting after the idle limit.
        let now = Date()
        let span = UserActivityMonitor.shared.countedSpan(since: start, now: now)
        self.start = span.nextCheckpoint
        guard span.seconds > 0 else { return }
        GameStats.shared.recordPlayTime(
            seconds: span.seconds,
            endingAt: span.start.addingTimeInterval(TimeInterval(span.seconds))
        )
    }
}
