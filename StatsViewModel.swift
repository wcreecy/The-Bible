import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    // Session-derived scoped datasets
    @Published var perBookAllTimeSessionTotals: [String: Int] = [:] // sessions within retention
    @Published var perBookMonthTotals: [String: Int] = [:]           // sessions in current month
    @Published var perBookLast7Totals: [String: Int] = [:]           // sessions in last 7 days

    // Derived
    @Published var todaySeconds: Int = 0
    @Published var thisWeekSeconds: Int = 0
    @Published var lastWeekSeconds: Int = 0
    @Published var lastReadBookChapter: String = "—"
    @Published var lastReadTimeText: String = "—"
    @Published var lastReadEntry: BibleStatsStore.LastRead? = nil

    @Published var visitedCount: Int = 0
    @Published var booksCompleted: Int = 0
    @Published var totalBooks: Int = 0
    @Published var bibleCompletionPercent: Int = 0
    @Published var totalChapters: Int = 0

    // Verse-level overall progress
    @Published var totalVerses: Int = 0
    @Published var completedVerses: Int = 0

    // Per-book progress (chapters read / total)
    @Published var bookProgress: [String: (read: Int, total: Int, fraction: Double)] = [:]

    // Charts datasets and consistency
    @Published var last7Daily: [(date: Date, seconds: Int)] = []
    @Published var sessionsLast7: [(index: Int, minutes: Int)] = []
    @Published var avgSessionSecondsLast7: Int = 0
    @Published var last30Daily: [(date: Date, seconds: Int)] = []

    // This Month metrics
    @Published var monthTotalSeconds: Int = 0
    @Published var monthChaptersCompleted: Int = 0
    @Published var monthTop3Books: [(book: String, seconds: Int)] = []

    // Summary glance additions
    @Published var totalSecondsAllTime: Int = 0
    @Published var lastMonthSeconds: Int = 0

    // Last session length (seconds)
    @Published var lastSessionSeconds: Int = 0

    // Config
    private let minSessionSeconds: Int

    // Observers/subscriptions
    private var cancellables: Set<AnyCancellable> = []

    init(minSessionSeconds: Int = 45) {
        self.minSessionSeconds = minSessionSeconds
    }

    func start() {
        // ReadingTimeTracker publisher
        ReadingTimeTracker.shared.$lastTotalsVersion
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAll()
                }
            }
            .store(in: &cancellables)

        // External updates to Bible stats
        NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshAll() }
            }
            .store(in: &cancellables)

        // Chapter progress changes
        NotificationCenter.default.publisher(for: .chapterProgressChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshAll() }
            }
            .store(in: &cancellables)

        // Initial load
        refreshAll()
    }

    // MARK: - Public refresh entry point

    func refreshAll() {
        refreshTotals()
        refreshChartsAndMonth()
        refreshSessionScopedPerBook()
        computeCompletionMetricsVerseComplete()
        computePerBookProgressVerseComplete()
        computeVerseTotalsAndCompleted()
    }

    // MARK: - Data refresh internals

    private func refreshTotals() {
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent

        // Today from synced totals
        todaySeconds = BibleStatsStore.shared.totalForLast(days: 1)

        // This week (rolling 7 local days including today) from synced daily totals
        do {
            let map = BibleStatsStore.shared.loadDailyTotals()
            let startOfToday = cal.startOfDay(for: Date())
            var total = 0
            for i in 0..<7 {
                if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                    let key = BibleStatsStore.isoDateString(d, calendar: cal)
                    total += max(0, map[key, default: 0])
                }
            }
            thisWeekSeconds = total
        }

        // Last week rolling window (7 days immediately prior)
        do {
            let map = BibleStatsStore.shared.loadDailyTotals()
            let startOfToday = cal.startOfDay(for: Date())
            var total = 0
            for i in 7..<14 {
                if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                    let key = BibleStatsStore.isoDateString(d, calendar: cal)
                    total += max(0, map[key, default: 0])
                }
            }
            lastWeekSeconds = total
        }

        if let last = BibleStatsStore.shared.loadLastRead() {
            lastReadEntry = last
            lastReadBookChapter = "\(last.bookName) \(last.chapterNumber)"
            lastReadTimeText = timeOnlyString(last.date)
        } else {
            lastReadEntry = nil
            lastReadBookChapter = "—"
            lastReadTimeText = "—"
        }

        // Overall counts used by progress
        computeCompletionMetricsVerseComplete()
        computePerBookProgressVerseComplete()
        computeVerseTotalsAndCompleted()
    }

    private func refreshChartsAndMonth() {
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent

        // Last 7 days daily bars from synced daily totals
        do {
            let map = BibleStatsStore.shared.loadDailyTotals()
            let startOfToday = cal.startOfDay(for: Date())
            var days: [(Date, Int)] = []
            for i in stride(from: 6, through: 0, by: -1) {
                if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                    let key = BibleStatsStore.isoDateString(d, calendar: cal)
                    days.append((d, max(0, map[key, default: 0])))
                }
            }
            last7Daily = days
        }

        // Sessions-based cards (keep as session analytics)
        let sessionsAll = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: Date(), calendar: cal)
            .filter { Int(max(0, $0.end.timeIntervalSince($0.start))) >= minSessionSeconds }
            .sorted { $0.end < $1.end }
        let lastTwenty = Array(sessionsAll.suffix(20))
        let sessionsIn7Days = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: Date(), calendar: cal)
            .filter { Int(max(0, $0.end.timeIntervalSince($0.start))) >= minSessionSeconds }
        avgSessionSecondsLast7 = StatsSeriesBuilder.averageSessionLength(sessions: sessionsIn7Days, minSessionSeconds: minSessionSeconds)
        sessionsLast7 = lastTwenty.enumerated().map { (idx, s) in
            let durSec = Int(max(0, s.end.timeIntervalSince(s.start)))
            let minutes = Int(round(Double(durSec) / 60.0))
            return (index: idx + 1, minutes: minutes)
        }

        // Last session length (all sessions)
        do {
            let allSessions = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: Date(), calendar: cal)
            if let last = allSessions.max(by: { $0.end < $1.end }) {
                lastSessionSeconds = Int(max(0, last.end.timeIntervalSince(last.start)))
            } else {
                lastSessionSeconds = 0
            }
        }

        // Consistency: last 30 from synced daily totals
        do {
            let map = BibleStatsStore.shared.loadDailyTotals()
            let startOfToday = cal.startOfDay(for: Date())
            var days: [(Date, Int)] = []
            for i in stride(from: 29, through: 0, by: -1) {
                if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                    let key = BibleStatsStore.isoDateString(d, calendar: cal)
                    days.append((d, max(0, map[key, default: 0])))
                }
            }
            last30Daily = days
        }

        // This Month (totals and chapters from BibleStatsStore)
        let now = Date()
        let comps = BibleStatsStore.shared.chapterCompletions(inMonth: now)
        monthChaptersCompleted = comps.count
        monthTotalSeconds = BibleStatsStore.shared.totalForMonth(containing: now)
    }

    private func refreshSessionScopedPerBook() {
        let cal = Calendar.current
        let now = Date()

        let last7Sessions = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: now, calendar: cal)
        perBookLast7Totals = StatsSeriesBuilder.groupSessionsByBook(last7Sessions)

        let monthSessions = ReadingSessionsStore.shared.sessions(inMonthContaining: now, calendar: cal)
        perBookMonthTotals = StatsSeriesBuilder.groupSessionsByBook(monthSessions)

        let allSessions = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: now, calendar: cal)
        perBookAllTimeSessionTotals = StatsSeriesBuilder.groupSessionsByBook(allSessions)
        totalSecondsAllTime = allSessions.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }

        let sortedTop = perBookMonthTotals.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        monthTop3Books = Array(sortedTop.prefix(3)).map { (book: $0.key, seconds: $0.value) }
    }

    // MARK: - Compute helpers

    private func computeCompletionMetricsVerseComplete() {
        let books = BibleData.books
        totalBooks = books.count
        totalChapters = books.reduce(0) { $0 + $1.chapters.count }

        var completedBooks = 0
        var completedChapters = 0

        for book in books {
            var allChaptersComplete = true
            for chap in book.chapters {
                let totalVerses = chap.verses.count
                let isComplete = totalVerses > 0 && BibleStatsStore.shared.isChapterComplete(bookName: book.name, chapter: chap.number, totalVerses: totalVerses)
                if isComplete {
                    completedChapters += 1
                } else {
                    allChaptersComplete = false
                }
            }
            if allChaptersComplete { completedBooks += 1 }
        }

        visitedCount = completedChapters
        booksCompleted = completedBooks

        let denom = max(1, totalChapters)
        let pct = Int(round((Double(completedChapters) / Double(denom)) * 100.0))
        bibleCompletionPercent = pct
    }

    private func computePerBookProgressVerseComplete() {
        var progress: [String: (read: Int, total: Int, fraction: Double)] = [:]
        let books = BibleData.books
        for book in books {
            let total = max(1, book.chapters.count)
            let read = book.chapters.reduce(0) { acc, chap in
                let totalVerses = chap.verses.count
                let complete = totalVerses > 0 && BibleStatsStore.shared.isChapterComplete(bookName: book.name, chapter: chap.number, totalVerses: totalVerses)
                return acc + (complete ? 1 : 0)
            }
            let fraction = Double(read) / Double(total)
            progress[book.name] = (read, total, fraction)
        }
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
    }

    private func computeVerseTotalsAndCompleted() {
        let books = BibleData.books
        var total = 0
        var completed = 0
        for book in books {
            for chap in book.chapters {
                let versesCount = chap.verses.count
                total += versesCount
                if versesCount > 0 {
                    let seen = BibleStatsStore.shared.loadSeenVerses(bookName: book.name, chapter: chap.number)
                    completed += min(versesCount, seen.count)
                }
            }
        }
        totalVerses = total
        completedVerses = completed
    }

    private func timeOnlyString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
