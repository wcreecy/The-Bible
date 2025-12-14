import Foundation
import Combine
import SwiftUI

// Lightweight, battery-friendly tracker that only runs while a reading session is visible.
// It batches writes to UserDefaults and stops when the app leaves the foreground.
final class ReadingTimeTracker: ObservableObject {
    static let shared = ReadingTimeTracker()
    private init() {}

    // Public read-only publisher for UI that wants to refresh when totals change
    @Published private(set) var lastTotalsVersion: Int = 0

    private var currentBook: String?
    private var currentChapterNumber: Int? // new
    private var sessionStart: Date?
    private var accumulatedInSession: Int = 0 // seconds since start (plus any resumed accumulation)
    private var ticker: AnyCancellable?
    private var lastPersist: Date = .distantPast

    // Debounce writes to at most once every 15 seconds
    private let persistInterval: TimeInterval = 15

    // Pause state
    private(set) var isPaused: Bool = false

    // MARK: - Public API

    func start(bookName: String, chapter: Int? = nil) {
        // If already tracking same book and chapter (if provided), do nothing
        if currentBook == bookName, ticker != nil || isPaused {
            if let chapter { currentChapterNumber = chapter }
            return
        }

        // If switching from another book, flush first and close previous session
        if let _ = currentBook {
            closeCurrentSessionAndFlush(finalize: false) // close session segment
        }

        currentBook = bookName
        currentChapterNumber = chapter
        sessionStart = Date()
        accumulatedInSession = 0
        isPaused = false
        startTickerIfNeeded()
    }

    func changeBook(to bookName: String, chapter: Int? = nil) {
        guard !bookName.isEmpty else { return }
        if currentBook == bookName {
            if let chapter { currentChapterNumber = chapter }
            return
        }
        // Close the current session segment and flush before switching
        closeCurrentSessionAndFlush(finalize: false)
        currentBook = bookName
        currentChapterNumber = chapter
        sessionStart = Date()
        accumulatedInSession = 0
        isPaused = false
        startTickerIfNeeded()
    }

    // Allows the reader to update chapter without changing book
    func setCurrentLocation(bookName: String, chapter: Int) {
        if currentBook != bookName {
            changeBook(to: bookName, chapter: chapter)
            return
        }
        currentChapterNumber = chapter
        // No flush here; just update metadata for the next flush
    }

    func stopAndFlush() {
        // Close the current session with a final append and flush totals
        closeCurrentSessionAndFlush(finalize: true)
        stopTicker()
        self.currentBook = nil
        self.currentChapterNumber = nil
        self.sessionStart = nil
        self.accumulatedInSession = 0
        self.isPaused = false
    }

    // MARK: - Pause / Resume

    func pause() {
        guard !isPaused else { return }
        // Close the ongoing segment and flush softly so elapsed so far is recorded
        closeCurrentSessionAndFlush(finalize: false)
        stopTicker()
        isPaused = true
    }

    func resume() {
        guard isPaused, currentBook != nil else { return }
        // Start a new segment from now
        sessionStart = Date()
        accumulatedInSession = 0
        isPaused = false
        startTickerIfNeeded()
    }

    // MARK: - Ticker

    private func startTickerIfNeeded() {
        guard ticker == nil, !isPaused else { return }
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tick() {
        guard sessionStart != nil, currentBook != nil, !isPaused else { return }
        accumulatedInSession += 1

        // Persist at most every persistInterval seconds
        if Date().timeIntervalSince(lastPersist) >= persistInterval {
            if let currentBook {
                flush(bookName: currentBook, soft: true)
            }
            lastPersist = Date()
        }
    }

    // MARK: - Persistence

    private func flush(bookName: String, soft: Bool = false) {
        guard accumulatedInSession > 0 else { return }

        // Per-book totals (all-time)
        var totals = BibleStatsStore.shared.loadTotals()
        totals[bookName, default: 0] += accumulatedInSession
        BibleStatsStore.shared.saveTotals(totals)

        // Daily totals (overall)
        BibleStatsStore.shared.addToToday(seconds: accumulatedInSession)

        // Daily totals by book (for time-windowed top books)
        BibleStatsStore.shared.addToToday(bookName: bookName, seconds: accumulatedInSession)

        // Last read (do not mark chapter visited here; completion is verse-driven)
        if let chap = currentChapterNumber {
            BibleStatsStore.shared.saveLastRead(bookName: bookName, chapterNumber: chap, date: Date())
        }

        accumulatedInSession = 0

        // Bump a version so any listeners (like the Home card or Stats) can refresh
        lastTotalsVersion &+= 1
    }

    private func closeCurrentSessionAndFlush(finalize: Bool) {
        guard let book = currentBook, let start = sessionStart else { return }
        let end = Date()
        let duration = Int(max(0, end.timeIntervalSince(start)))
        if duration > 0 {
            // Append session record
            ReadingSessionsStore.shared.appendSession(.init(start: start, end: end, book: book, chapter: currentChapterNumber))
            // Also ensure totals reflect elapsed time (in case we didn’t persist yet)
            accumulatedInSession += duration
            flush(bookName: book, soft: !finalize)
        }
        // Reset the sessionStart for subsequent segments
        sessionStart = finalize ? nil : Date()
    }
}

