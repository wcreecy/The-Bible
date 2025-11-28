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
    private var sessionStart: Date?
    private var accumulatedInSession: Int = 0 // seconds since start (plus any resumed accumulation)
    private var ticker: AnyCancellable?
    private var lastPersist: Date = .distantPast

    // Debounce writes to at most once every 15 seconds
    private let persistInterval: TimeInterval = 15

    // MARK: - Public API

    func start(bookName: String) {
        // If already tracking same book, do nothing
        if currentBook == bookName, ticker != nil { return }

        // If switching from another book, flush first
        if let currentBook {
            flush(bookName: currentBook)
        }

        currentBook = bookName
        sessionStart = Date()
        accumulatedInSession = 0
        startTickerIfNeeded()
    }

    func changeBook(to bookName: String) {
        guard !bookName.isEmpty else { return }
        if currentBook == bookName { return }
        if let currentBook {
            flush(bookName: currentBook)
        }
        currentBook = bookName
        sessionStart = Date()
        accumulatedInSession = 0
        startTickerIfNeeded()
    }

    func stopAndFlush() {
        guard let currentBook else { stopTicker(); return }
        flush(bookName: currentBook)
        stopTicker()
        self.currentBook = nil
        self.sessionStart = nil
        self.accumulatedInSession = 0
    }

    // MARK: - Ticker

    private func startTickerIfNeeded() {
        guard ticker == nil else { return }
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
        guard sessionStart != nil, currentBook != nil else { return }
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
        var totals = BibleStatsStore.shared.loadTotals()
        totals[bookName, default: 0] += accumulatedInSession
        BibleStatsStore.shared.saveTotals(totals)
        accumulatedInSession = 0

        // Bump a version so any listeners (like the Home card) can refresh
        if !soft {
            lastTotalsVersion &+= 1
        } else {
            // Even for soft flush, update so UI can reflect recent time
            lastTotalsVersion &+= 1
        }
    }
}

