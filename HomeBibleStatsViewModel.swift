import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeBibleStatsViewModel: ObservableObject {
    @Published var todaySeconds: Int = 0
    @Published var thisWeekSeconds: Int = 0
    @Published var lastWeekSeconds: Int = 0
    @Published var totalSeconds: Int = 0

    @Published var lastReadBookChapter: String = "—"
    @Published var lastReadRelativeTime: String = "—"

    @Published var otSeconds: Int = 0
    @Published var ntSeconds: Int = 0

    @Published var visitedCount: Int = 0
    @Published var totalChapters: Int = 0
    @Published var completionPercent: Int = 0

    @Published var topBooks: [(book: String, seconds: Int)] = []
    @Published var maxTopSeconds: Int = 1

    private var cancellable: AnyCancellable?

    init() {
        refresh()
        cancellable = ReadingTimeTracker.shared.$lastTotalsVersion
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func refresh(now: Date = Date()) {
        let store = BibleStatsStore.shared
        let totals = store.loadTotals()
        totalSeconds = totals.values.reduce(0, +)

        todaySeconds = store.totalForLast(days: 1)
        thisWeekSeconds = store.totalForLast(days: 7)
        let last14 = store.totalForLast(days: 14)
        lastWeekSeconds = last14 - thisWeekSeconds

        let split = store.splitOTNT(totals: totals)
        otSeconds = split.ot
        ntSeconds = split.nt

        // Visited and completion
        let visited = store.loadVisitedChapters()
        visitedCount = visited.count
        computeCompletionMetrics(visitedChapters: visited)

        // Last read
        if let last = store.loadLastRead() {
            lastReadBookChapter = "\(last.bookName) \(last.chapterNumber)"
            lastReadRelativeTime = relativeTimeString(from: last.date, to: now)
        } else {
            lastReadBookChapter = "—"
            lastReadRelativeTime = "—"
        }

        // Top books (compute 5, UI will show 3/5)
        let all = totals.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        topBooks = all.prefix(5).map { ($0.key, $0.value) }
        maxTopSeconds = max(1, topBooks.map { $0.seconds }.max() ?? 1)
    }

    private func computeCompletionMetrics(visitedChapters: Set<String>) {
        let books = BibleData.books
        let total = books.reduce(0) { $0 + $1.chapters.count }
        totalChapters = max(1, total)
        let pct = Int(round((Double(visitedCount) / Double(totalChapters)) * 100.0))
        completionPercent = max(0, min(100, pct))
    }

    func formatted(_ seconds: Int) -> String {
        BibleStatsStore.shared.format(seconds)
    }

    var weekDeltaOnlyValue: String {
        let delta = thisWeekSeconds - lastWeekSeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(formatted(abs(delta)))"
    }

    // New: Today vs Yesterday delta (e.g., "+3:15" or "−05:20", or "—" when equal)
    var todayDeltaOnlyValue: String {
        // Yesterday = total of last 2 days minus today
        let store = BibleStatsStore.shared
        let last2 = store.totalForLast(days: 2)
        let yesterday = max(0, last2 - todaySeconds)
        let delta = todaySeconds - yesterday
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(formatted(abs(delta)))"
    }

    private func relativeTimeString(from date: Date, to now: Date = Date()) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: now)
    }
}

