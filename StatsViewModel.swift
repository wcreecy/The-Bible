import Foundation
import Observation

@MainActor
@Observable
final class StatsViewModel {
    // Session-derived scoped datasets
    var perBookAllTimeSessionTotals: [String: Int] = [:] // sessions within retention
    var perBookMonthTotals: [String: Int] = [:]           // sessions in current month
    var perBookLast7Totals: [String: Int] = [:]           // sessions in last 7 days

    // Derived
    var todaySeconds: Int = 0
    var thisWeekSeconds: Int = 0
    var lastWeekSeconds: Int = 0
    var lastReadBookChapter: String = "—"
    var lastReadTimeText: String = "—"
    var lastReadEntry: BibleStatsStore.LastRead? = nil

    var visitedCount: Int = 0
    var booksCompleted: Int = 0
    var totalBooks: Int = 0
    var bibleCompletionPercent: Int = 0
    var totalChapters: Int = 0

    // Verse-level overall progress
    var totalVerses: Int = 0
    var completedVerses: Int = 0

    // Per-book progress (chapters read / total)
    var bookProgress: [String: (read: Int, total: Int, fraction: Double)] = [:]

    // Charts datasets and consistency
    var last7Daily: [(date: Date, seconds: Int)] = []
    var dailyAverageSessionsLast7: [(date: Date, seconds: Int)] = []
    private(set) var refreshRevision: Int = 0
    var avgSessionSecondsLast7: Int = 0
    var last30Daily: [(date: Date, seconds: Int)] = []

    // This Month metrics
    var monthTotalSeconds: Int = 0
    var monthChaptersCompleted: Int = 0
    var monthTop3Books: [(book: String, seconds: Int)] = []

    // Summary glance additions
    var totalSecondsAllTime: Int = 0
    var lastMonthSeconds: Int = 0

    // Last session length (seconds)
    var lastSessionSeconds: Int = 0
    var readingInsights = ReadingInsights()

    // MARK: - Refresh scheduling

    /// Reading saves its time about every 15 seconds and each save posts a stats
    /// notification. Rebuilding everything is expensive, so updates are coalesced and only
    /// applied while Stats is on screen; changes made while it's hidden are applied when
    /// it next appears.
    @ObservationIgnored private var observationTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    @ObservationIgnored private var isVisible = false
    @ObservationIgnored private var isStale = true
    private static let refreshDelay: Duration = .milliseconds(500)

    /// Call when Stats appears. Refreshes now if anything changed while it was hidden,
    /// and returns whether it did.
    @discardableResult
    func start() -> Bool {
        isVisible = true
        startObservingIfNeeded()
        guard isStale else { return false }
        refreshAll()
        return true
    }

    /// Call when Stats disappears. Later changes wait until it's shown again.
    func stop() {
        isVisible = false
        observationTask?.cancel()
        observationTask = nil
        if pendingRefresh != nil {
            pendingRefresh?.cancel()
            pendingRefresh = nil
            isStale = true
        }
    }

    private func startObservingIfNeeded() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                // Session appends and reading-time saves both post this notification.
                for name in [Notification.Name.bibleStatsExternallyUpdated, .chapterProgressChanged] {
                    group.addTask { @MainActor [weak self] in
                        for await _ in NotificationCenter.default.notifications(named: name) {
                            self?.statsDidChange()
                        }
                    }
                }
            }
        }
    }

    private func statsDidChange() {
        isStale = true
        guard isVisible, pendingRefresh == nil else { return }
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(for: Self.refreshDelay)
            guard !Task.isCancelled, let self else { return }
            self.pendingRefresh = nil
            self.refreshAll()
        }
    }

    deinit {
        observationTask?.cancel()
        pendingRefresh?.cancel()
    }

    // MARK: - Public refresh entry point

    func refreshAll() {
        isStale = false
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = TimeZone.autoupdatingCurrent
        let now = Date()
        let snapshot = BibleStatsStore.shared.statisticsSnapshot()
        let sessions = ReadingSessionsStore.shared.allSessions().filter(ReadingSessionsStore.isValid)

        refreshTotals(snapshot: snapshot, now: now, calendar: calendar)
        refreshChartsAndMonth(snapshot: snapshot, sessions: sessions, now: now, calendar: calendar)
        refreshSessionScopedPerBook(snapshot: snapshot, now: now, calendar: calendar)
        computeBibleProgress(snapshot: snapshot)
        readingInsights = ReadingInsightsCalculator.calculate(
            dailyTotals: snapshot.dailyTotals,
            sessions: sessions,
            now: now,
            calendar: calendar
        )
        refreshRevision &+= 1
    }

    // MARK: - Data refresh internals

    private func refreshTotals(
        snapshot: BibleStatsStore.StatisticsSnapshot,
        now: Date,
        calendar: Calendar
    ) {
        let dailyTotals = snapshot.dailyTotals
        let startOfToday = calendar.startOfDay(for: now)
        // Today from synced totals
        let todayKey = BibleStatsStore.isoDateString(startOfToday, calendar: calendar)
        todaySeconds = max(0, dailyTotals[todayKey, default: 0])

        // This week (rolling 7 local days including today) from synced daily totals
        do {
            var total = 0
            for i in 0..<7 {
                if let d = calendar.date(byAdding: .day, value: -i, to: startOfToday) {
                    let key = BibleStatsStore.isoDateString(d, calendar: calendar)
                    total += max(0, dailyTotals[key, default: 0])
                }
            }
            thisWeekSeconds = total
        }

        // Last week rolling window (7 days immediately prior)
        do {
            var total = 0
            for i in 7..<14 {
                if let d = calendar.date(byAdding: .day, value: -i, to: startOfToday) {
                    let key = BibleStatsStore.isoDateString(d, calendar: calendar)
                    total += max(0, dailyTotals[key, default: 0])
                }
            }
            lastWeekSeconds = total
        }

        if let last = snapshot.lastRead {
            lastReadEntry = last
            lastReadBookChapter = "\(last.bookName) \(last.chapterNumber)"
            lastReadTimeText = timeOnlyString(last.date)
        } else {
            lastReadEntry = nil
            lastReadBookChapter = "—"
            lastReadTimeText = "—"
        }

    }

    private func refreshChartsAndMonth(
        snapshot: BibleStatsStore.StatisticsSnapshot,
        sessions: [ReadingSessionsStore.Session],
        now: Date,
        calendar: Calendar
    ) {
        let dailyTotals = snapshot.dailyTotals
        let startOfToday = calendar.startOfDay(for: now)
        // Last 7 days daily bars from synced daily totals
        do {
            var days: [(Date, Int)] = []
            for i in stride(from: 6, through: 0, by: -1) {
                if let d = calendar.date(byAdding: .day, value: -i, to: startOfToday) {
                    let key = BibleStatsStore.isoDateString(d, calendar: calendar)
                    days.append((d, max(0, dailyTotals[key, default: 0])))
                }
            }
            last7Daily = days
        }

        // Sessions-based cards (keep as session analytics)
        let cutoff = ReadingSessionsStore.startDate(forLastDays: 7, now: now, calendar: calendar)
        let sessionsIn7Days = sessions.filter { $0.end >= cutoff }
            .sorted { $0.end < $1.end }
        avgSessionSecondsLast7 = StatsSeriesBuilder.averageSessionLength(sessions: sessionsIn7Days)
        dailyAverageSessionsLast7 = StatsSeriesBuilder.dailyAverageSessionLengths(
            sessions: sessionsIn7Days,
            days: 7,
            now: now,
            calendar: calendar
        )

        lastSessionSeconds = sessions.max(by: { $0.end < $1.end })
            .map(ReadingSessionsStore.duration(of:)) ?? 0

        // Consistency: last 30 from synced daily totals
        do {
            var days: [(Date, Int)] = []
            for i in stride(from: 29, through: 0, by: -1) {
                if let d = calendar.date(byAdding: .day, value: -i, to: startOfToday) {
                    let key = BibleStatsStore.isoDateString(d, calendar: calendar)
                    days.append((d, max(0, dailyTotals[key, default: 0])))
                }
            }
            last30Daily = days
        }

        // This Month (totals and chapters from BibleStatsStore)
        let monthComponents = calendar.dateComponents([.year, .month], from: now)
        monthChaptersCompleted = snapshot.chapterCompletionDates.values.filter {
            calendar.dateComponents([.year, .month], from: $0) == monthComponents
        }.count
        let monthKeys = BibleStatsStore.isoKeysForMonth(containing: now, calendar: calendar)
        monthTotalSeconds = monthKeys.reduce(0) { total, key in
            total + max(0, dailyTotals[key, default: 0])
        }
    }

    private func refreshSessionScopedPerBook(
        snapshot: BibleStatsStore.StatisticsSnapshot,
        now: Date,
        calendar: Calendar
    ) {
        // REVISED: Build per-book maps from BibleStatsStore daily totals (not sessions)
        let startOfToday = calendar.startOfDay(for: now)

        // Daily per-book map: ["yyyy-MM-dd": [book: seconds]]
        let dailyByBook = snapshot.dailyTotalsByBook

        func sumPerBook(for keys: [String]) -> [String: Int] {
            var map: [String: Int] = [:]
            for k in keys {
                if let perBook = dailyByBook[k] {
                    for (book, sec) in perBook {
                        map[book, default: 0] += max(0, sec)
                    }
                }
            }
            return map
        }

        // All-time per-book derived by summing all dailyByBook entries (ensures seconds + prevents legacy drift),
        // plus reading older than the retention cutoff, which is kept in the archive.
        do {
            var allTimeMap = BibleStatsStore.shared.archivedBookTotals()
            for (_, perBook) in dailyByBook {
                for (book, sec) in perBook {
                    allTimeMap[book, default: 0] += max(0, sec)
                }
            }
            perBookAllTimeSessionTotals = allTimeMap
            totalSecondsAllTime = allTimeMap.values.reduce(0) { $0 + max(0, $1) }
        }

        // Last 7 days (including today)
        var last7Keys: [String] = []
        for i in 0..<7 {
            if let d = calendar.date(byAdding: .day, value: -i, to: startOfToday) {
                last7Keys.append(BibleStatsStore.isoDateString(d, calendar: calendar))
            }
        }
        perBookLast7Totals = sumPerBook(for: last7Keys)

        // This month
        let monthKeys = BibleStatsStore.isoKeysForMonth(containing: now, calendar: calendar)
        perBookMonthTotals = sumPerBook(for: monthKeys)

        // Top 3 books for this month (based on daily totals by book)
        let sortedTop = perBookMonthTotals.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        monthTop3Books = Array(sortedTop.prefix(3)).map { (book: $0.key, seconds: $0.value) }
    }

    // MARK: - Compute helpers

    private func computeBibleProgress(snapshot: BibleStatsStore.StatisticsSnapshot) {
        let books = BibleData.books
        totalBooks = books.count
        totalChapters = books.reduce(0) { $0 + $1.chapters.count }

        var completedBooks = 0
        var completedChapters = 0
        var verseCount = 0
        var completedVerseCount = 0
        var progress: [String: (read: Int, total: Int, fraction: Double)] = [:]

        for book in books {
            var allChaptersComplete = true
            var completedChaptersInBook = 0
            for chap in book.chapters {
                let chapterVerseCount = chap.verses.count
                let key = "\(book.name):\(chap.number)"
                let seen = snapshot.seenVersesByChapter[key, default: []]
                let validSeenCount = chapterVerseCount > 0
                    ? seen.filter { (1...chapterVerseCount).contains($0) }.count
                    : 0
                let isComplete = chapterVerseCount > 0 && validSeenCount >= chapterVerseCount

                verseCount += chapterVerseCount
                completedVerseCount += min(chapterVerseCount, validSeenCount)
                if isComplete {
                    completedChapters += 1
                    completedChaptersInBook += 1
                } else {
                    allChaptersComplete = false
                }
            }
            if allChaptersComplete { completedBooks += 1 }

            let chapterCount = max(1, book.chapters.count)
            progress[book.name] = (
                completedChaptersInBook,
                chapterCount,
                Double(completedChaptersInBook) / Double(chapterCount)
            )
        }

        visitedCount = completedChapters
        booksCompleted = completedBooks

        let denom = max(1, totalChapters)
        let pct = Int(round((Double(completedChapters) / Double(denom)) * 100.0))
        bibleCompletionPercent = pct

        // Ensure placeholder entries for any missing books
        let orderedAllBooks: [String] = {
            if !BibleData.books.isEmpty { return BibleData.books.map { $0.name } }
            return BibleCanon.canonicalOrder()
        }()
        for name in orderedAllBooks {
            if progress[name] == nil {
                progress[name] = (0, 1, 0.0)
            }
        }
        bookProgress = progress
        totalVerses = verseCount
        completedVerses = completedVerseCount
    }

    private func timeOnlyString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
