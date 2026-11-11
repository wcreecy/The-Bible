import Foundation

/// Reading-time and read-verse tracking for the Home panel.
///
/// It only runs after the reader interacts, and pauses after a couple of idle minutes, so
/// leaving Home open does not count as reading. It shares `ReadingTimeTracker` with the
/// Bible tab and only pauses or stops a session that is still its own.
@MainActor
final class HomeReadingSession {
    private(set) var isActive = false
    private var location: (bookName: String, chapter: Int)?

    private lazy var verseTracker = VerseReadingTracker { updates in
        BibleStatsStore.shared.markVersesSeen(updates)
    }
    private lazy var inactivityMonitor = InactivityMonitor(timeout: 120) { [weak self] in
        self?.pause()
    }

    func markActivity(bookName: String, chapter: Int) {
        location = (bookName, chapter)
        let tracker = ReadingTimeTracker.shared
        tracker.start(bookName: bookName, chapter: chapter)
        tracker.setCurrentLocation(bookName: bookName, chapter: chapter)
        tracker.resume()
        verseTracker.setActive(true)
        isActive = true
        inactivityMonitor.markActivity()
    }

    func verseVisibilityChanged(_ update: SeenVerseUpdate, isVisible: Bool) {
        verseTracker.visibilityChanged(update, isVisible: isVisible)
    }

    func recordEngagement(_ update: SeenVerseUpdate) {
        verseTracker.recordDirectEngagement(update)
    }

    func chapterChanged() {
        verseTracker.resetVisibility()
    }

    /// After inactivity, or when the app leaves the foreground.
    func pause() {
        guard isActive else { return }
        isActive = false
        inactivityMonitor.cancel()
        verseTracker.setActive(false)
        if let location, ReadingTimeTracker.shared.isTiming(bookName: location.bookName, chapter: location.chapter) {
            ReadingTimeTracker.shared.pause()
        }
    }

    /// When the panel leaves the screen.
    func stop() {
        inactivityMonitor.cancel()
        verseTracker.stop()
        if isActive, let location,
           ReadingTimeTracker.shared.isTiming(bookName: location.bookName, chapter: location.chapter) {
            ReadingTimeTracker.shared.stopAndFlush()
        }
        isActive = false
        ReadingPositionStore.shared.flush()
    }
}
