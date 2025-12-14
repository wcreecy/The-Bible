// the entire code of the file with your changes goes here.
// Do not skip over anything.
import SwiftUI
import Combine
import Charts

struct StatsView: View {
    private enum SortMode: String, CaseIterable, Identifiable {
        case canonical = "Canonical"
        case mostRead = "Most Read"
        var id: String { rawValue }
    }

    private enum TimeScope: String, CaseIterable, Identifiable {
        case allTime = "All Time"
        case thisMonth = "This Month"
        case last7 = "Last 7 Days"
        var id: String { rawValue }
    }

    // Filter for Book Progress grid
    enum BookFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case ot = "OT"
        case nt = "NT"
        var id: String { rawValue }
    }

    // Minimum duration for a session to be counted in averages/series
    private let minSessionSeconds: Int = 45

    @State private var sortMode: SortMode = .canonical
    @State private var timeScope: TimeScope = .allTime

    // Session-derived scoped datasets
    @State private var perBookAllTimeSessionTotals: [String: Int] = [:] // sessions within retention
    @State private var perBookMonthTotals: [String: Int] = [:]           // sessions in current month
    @State private var perBookLast7Totals: [String: Int] = [:]           // sessions in last 7 days

    // Derived
    @State private var todaySeconds: Int = 0
    @State private var thisWeekSeconds: Int = 0
    @State private var lastWeekSeconds: Int = 0
    @State private var lastReadBookChapter: String = "—"
    @State private var lastReadTimeText: String = "—"
    // New: keep the object for navigation
    @State private var lastReadEntry: BibleStatsStore.LastRead? = nil

    @State private var otSeconds: Int = 0
    @State private var ntSeconds: Int = 0

    @State private var visitedCount: Int = 0
    @State private var booksCompleted: Int = 0
    @State private var totalBooks: Int = 0
    @State private var bibleCompletionPercent: Int = 0
    @State private var totalChapters: Int = 0

    // New: verse-level overall progress
    @State private var totalVerses: Int = 0
    @State private var completedVerses: Int = 0

    // Per-book progress (chapters read / total)
    @State private var bookProgress: [String: (read: Int, total: Int, fraction: Double)] = [:]

    // Genre distribution
    @State private var perGenreTotals: [(genre: String, seconds: Int)] = []
    @State private var selectedGenre: Genre? = nil
    @State private var genreDetailRows: [(book: String, seconds: Int)] = []

    // Updates from tracker
    @State private var cancellable: AnyCancellable?

    // New: selected book for chapter detail sheet
    @State private var selectedBookForChapters: String? = nil

    // New: Charts datasets
    @State private var last7Daily: [(date: Date, seconds: Int)] = []
    // Now shows last 20 sessions overall
    @State private var sessionsLast7: [(index: Int, minutes: Int)] = []
    @State private var avgSessionSecondsLast7: Int = 0

    // Consistency card (last 30 days)
    @State private var last30Daily: [(date: Date, seconds: Int)] = []

    // New: This Month metrics
    @State private var monthTotalSeconds: Int = 0
    @State private var monthChaptersCompleted: Int = 0
    @State private var monthTop3Books: [(book: String, seconds: Int)] = []

    // New: Summary glance additions
    @State private var totalSecondsAllTime: Int = 0
    @State private var lastMonthSeconds: Int = 0

    // Expand/collapse for existing sections
    @State private var showBookProgressDetails: Bool = false
    @State private var showTotalsSection: Bool = false

    // Daily goal minutes (for goal progress glance pill)
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30

    // Ensure all glance boxes visually match height
    private let glanceCardMinHeight: CGFloat = 86

    // New: filter/search for Book Progress grid
    @State private var bookFilter: BookFilter = .all
    @State private var bookSearch: String = ""

    // Size-class aware layout
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // Totals card dynamic metrics
    @State private var totalsDaily: [(date: Date, seconds: Int)] = []
    @State private var avgSecondsPerActiveBucketInScope: Int = 0
    @State private var activeDaysInScope: Int = 0
    @State private var topBookInScope: String = "—"

    // All-time aggregation mode for the totals chart
    private enum Aggregation { case daily, weekly, monthly, yearly }
    @State private var allTimeAggregation: Aggregation = .daily

    // New: last session length (seconds)
    @State private var lastSessionSeconds: Int = 0

    private var orderedAllBooks: [String] {
        if !BibleData.books.isEmpty {
            return BibleData.books.map { $0.name }
        }
        return BibleCanon.canonicalOrder()
    }

    // OT/NT helpers (canonical split by "Matthew")
    private var canonicalIndexMap: [String: Int] {
        Dictionary(uniqueKeysWithValues: BibleData.books.enumerated().map { ($1.name, $0) })
    }
    private var matthewIndex: Int { canonicalIndexMap["Matthew"] ?? Int.max }

    // Filtered books for the grid
    private var filteredBookNames: [String] {
        let base: [String] = {
            switch bookFilter {
            case .all: return orderedAllBooks
            case .ot:
                return orderedAllBooks.filter { (canonicalIndexMap[$0] ?? Int.max) < matthewIndex }
            case .nt:
                return orderedAllBooks.filter { (canonicalIndexMap[$0] ?? Int.max) >= matthewIndex }
            }
        }()
        let q = bookSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    // Adaptive grid for book tiles
    private var bookGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 10)]
    }

    // MARK: - Smart Insights state

    @State private var insightBestDayText: String? = nil
    @State private var insightNewStreakText: String? = nil
    @State private var insightSevenDayAvgVsMonthText: String? = nil
    @State private var insightGoalHitsLast7Text: String? = nil
    @State private var insightLongestSessionText: String? = nil
    @State private var insightTopBookThisMonthText: String? = nil

    // MARK: - Integer formatting

    private func formatInt(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    // MARK: - Active bucket label for Totals card

    private var activeBucketLabel: String {
        switch currentBarUnit {
        case .day: return "Active Days"
        case .weekOfYear: return "Active Weeks"
        case .month: return "Active Months"
        case .year: return "Active Years"
        default: return "Active"
        }
    }

    private var avgPerActiveBucketLabel: String {
        switch currentBarUnit {
        case .day: return "Avg per active day"
        case .weekOfYear: return "Avg per active week"
        case .month: return "Avg per active month"
        case .year: return "Avg per active year"
        default: return "Avg per active period"
        }
    }

    private var activeBucketCount: Int {
        let count = totalsDaily.reduce(0) { partial, element in
            partial + (element.seconds > 0 ? 1 : 0)
        }
        return count
    }

    var body: some View {
        ScrollView {
            contentVStack
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            iCloudSyncCoordinator.shared.start()
            refreshAll()
            if cancellable == nil {
                cancellable = ReadingTimeTracker.shared.$lastTotalsVersion
                    .receive(on: RunLoop.main)
                    .sink { _ in refreshAll() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)) { _ in
            refreshAll()
        }
        .sheet(item: Binding(
            get: { selectedBookForChapters.map { ChapterDetailKey(bookName: $0) } },
            set: { selectedBookForChapters = $0?.bookName }
        )) { key in
            NavigationStack {
                BookChaptersDetailView(bookName: key.bookName)
                    .navigationTitle(key.bookName)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { selectedBookForChapters = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            if let next = nextUnreadChapter(in: key.bookName) {
                                Button("Open Next Unread") {
                                    openReader(bookName: key.bookName, chapter: next, verse: 1)
                                    selectedBookForChapters = nil
                                }
                            }
                        }
                    }
            }
        }
        .sheet(item: $selectedGenre) { genre in
            NavigationStack {
                List {
                    Section {
                        ForEach(genreDetailRows, id: \.book) { row in
                            HStack {
                                Text(row.book)
                                Spacer()
                                Text(BibleStatsStore.shared.format(row.seconds))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    } header: {
                        Text(genre.rawValue)
                    }
                }
                .navigationTitle("\(genre.rawValue)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { selectedGenre = nil }
                    }
                }
                .onAppear {
                    let totalsMap = scopedPerBookTotals
                    genreDetailRows = rowsForGenre(genre, totals: totalsMap)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("switchToTab"))) { _ in
            selectedBookForChapters = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .chapterProgressChanged)) { _ in
            refreshAll()
        }
        .onChange(of: timeScope) {
            recomputeOTNTFromScope()
            recomputeGenresFromScope()
            recomputeTotalsCardMetrics()
        }
        // Ensure only one expandable card is open at a time
        .onChange(of: showBookProgressDetails) {
            if showBookProgressDetails {
                showTotalsSection = false
            }
        }
        .onChange(of: showTotalsSection) {
            if showTotalsSection {
                showBookProgressDetails = false
            }
        }
    }

    private var contentVStack: some View {
        VStack(spacing: 16) {
            glanceRow

            InsightsCardView(
                tiles: buildInsightTiles(),
                onRefresh: { computeInsights() }
            )

            ConsistencyCardView(last30Daily: last30Daily)

            ProgressCardView(
                booksCompleted: booksCompleted,
                totalBooks: totalBooks,
                visitedCount: visitedCount,
                totalChapters: totalChapters,
                completedVerses: completedVerses,
                totalVerses: totalVerses,
                orderedBookNames: orderedAllBooks,
                bookProgress: bookProgress,
                onContinue: {
                    if let last = lastReadEntry {
                        openReader(bookName: last.bookName, chapter: last.chapterNumber, verse: 1)
                    }
                },
                onOpenNextUnread: {
                    if let next = nextUnreadGlobal() {
                        openReader(bookName: next.book, chapter: next.chapter, verse: 1)
                    }
                },
                hasLastRead: lastReadEntry != nil,
                isExpanded: $showBookProgressDetails,
                filter: $bookFilter,
                search: $bookSearch,
                selectedBookForChapters: $selectedBookForChapters
            )

            TotalsCardView(
                timeScope: Binding(
                    get: {
                        switch timeScope {
                        case .allTime: return .allTime
                        case .thisMonth: return .thisMonth
                        case .last7: return .last7
                        }
                    },
                    set: { new in
                        switch new {
                        case .allTime: timeScope = .allTime
                        case .thisMonth: timeScope = .thisMonth
                        case .last7: timeScope = .last7
                        }
                    }
                ),
                totalSeconds: scopedTotalSeconds,
                series: totalsDaily,
                chartSubtitle: totalsChartSubtitle,
                currentBarUnit: currentBarUnit,
                showValueLabels: shouldShowBarValueLabels,
                xAxis: { AnyAxisContent(chartXAxisMarks) },
                activeBucketLabel: activeBucketLabel,
                activeBucketCount: activeBucketCount,
                avgPerActiveBucketLabel: avgPerActiveBucketLabel,
                avgSecondsPerActiveBucket: avgSecondsPerActiveBucketInScope,
                topBook: topBookInScope,
                isExpanded: $showTotalsSection,
                sortMode: Binding(
                    get: {
                        switch sortMode {
                        case .canonical: return .canonical
                        case .mostRead: return .mostRead
                        }
                    },
                    set: { new in
                        switch new {
                        case .canonical: sortMode = .canonical
                        case .mostRead: sortMode = .mostRead
                        }
                    }
                ),
                rows: scopedRows,
                formatSeconds: { BibleStatsStore.shared.format($0) }
            )

            OTNTCardView(
                timeScope: Binding(
                    get: { mapScopeToOTNT(timeScope) },
                    set: { new in timeScope = mapScopeFromOTNT(new) }
                ),
                otSeconds: otSeconds,
                ntSeconds: ntSeconds,
                formatSeconds: { BibleStatsStore.shared.format($0) }
            )

            GenreDistributionCardView(
                timeScope: Binding(
                    get: { mapScopeToGenre(timeScope) },
                    set: { new in timeScope = mapScopeFromGenre(new) }
                ),
                perGenreTotals: perGenreTotals,
                selectedGenre: $selectedGenre,
                onSelectGenre: { g in
                    genreDetailRows = rowsForGenre(g, totals: scopedPerBookTotals)
                },
                genreColor: { genreColor($0) },
                formatSeconds: { BibleStatsStore.shared.format($0) }
            )

            AverageSessionCardView(
                sessionsSeries: sessionsLast7,
                avgSessionSeconds: avgSessionSecondsLast7,
                formatSeconds: { BibleStatsStore.shared.format($0) }
            )

            GamesCardView()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Smart Insights

    private func buildInsightTiles() -> [InsightChipModel] {
        [
            insightBestDayText.map { InsightChipModel(icon: "calendar.badge.clock", title: "Best Day", detail: $0, tint: .blue) },
            insightNewStreakText.map { InsightChipModel(icon: "flame.fill", title: "Streak", detail: $0, tint: .orange) },
            insightSevenDayAvgVsMonthText.map { InsightChipModel(icon: "chart.line.uptrend.xyaxis", title: "7‑day Avg", detail: $0, tint: .green) },
            insightGoalHitsLast7Text.map { InsightChipModel(icon: "target", title: $0.contains("7") ? "Goal Hits" : "Goal", detail: $0, tint: .purple) },
            insightLongestSessionText.map { InsightChipModel(icon: "timer", title: "Longest Session", detail: $0, tint: .teal) },
            insightTopBookThisMonthText.map { InsightChipModel(icon: "book.fill", title: "Top Book", detail: $0, tint: .pink) }
        ].compactMap { $0 }
    }

    // MARK: - Cards and helpers preserved (glance row etc.)

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let idx = max(1, min(7, weekday)) - 1
        return symbols[idx]
    }

    private func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        var comps = DateComponents()
        comps.hour = hour
        let date = Calendar.current.date(from: comps) ?? Date()
        return formatter.string(from: date)
    }

    private var glanceRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statMiniPill(title: "Today", value: BibleStatsStore.shared.format(todaySeconds), subtitle: todayDeltaOnlyValue, tint: .blue)
                statMiniPill(title: "This Week", value: BibleStatsStore.shared.format(thisWeekSeconds), subtitle: weekDeltaOnlyValue, tint: .green)
                statMiniPill(title: "This Month", value: BibleStatsStore.shared.format(monthTotalSeconds), subtitle: monthDeltaOnlyValue, tint: .mint)
                // New: Last session length
                statMiniPill(title: "Last Session", value: lastSessionSeconds > 0 ? BibleStatsStore.shared.format(lastSessionSeconds) : "—", tint: .indigo)
                statMiniPill(title: "All-time", value: BibleStatsStore.shared.format(totalSecondsAllTime), subtitle: nil, tint: .purple)
                lastReadMiniPill(title: "Last Read", ref: lastReadBookChapter, relative: lastReadTimeText)
            }
            .padding(.vertical, 2)
        }
    }

    private func statMiniPill(title: String, value: String, subtitle: String? = nil, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty, subtitle != "—" {
                let prefix = (title == "This Week") ? "vs lst wk: " : (title == "Today" ? "vs yday: " : (title == "This Month" ? "vs lst mo: " : ""))
                if !prefix.isEmpty {
                    Text("\(prefix)\(subtitle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private func lastReadMiniPill(title: String, ref: String, relative: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption).foregroundStyle(.secondary)
            Text(ref)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Whether to show numeric labels above bars

    private var shouldShowBarValueLabels: Bool {
        switch timeScope {
        case .thisMonth: return true
        case .last7: return true
        case .allTime: return true
        }
    }

    // MARK: - One-open-only toggles retained

    private func toggleBookProgress() {
        if showBookProgressDetails {
            showBookProgressDetails = false
        } else {
            showTotalsSection = false
            showBookProgressDetails = true
        }
    }

    private func toggleTotals() {
        if showTotalsSection {
            showTotalsSection = false
        } else {
            showBookProgressDetails = false
            showTotalsSection = true
        }
    }

    // MARK: - Data refresh (unchanged logic)

    private func refreshAll() {
        refreshTotals()
        refreshChartsAndMonth()
        refreshSessionScopedPerBook()
        recomputeOTNTFromScope()
        recomputeGenresFromScope()
        recomputeTotalsCardMetrics()
        computeInsights()
    }

    private func refreshTotals() {
        let cal = Calendar.current

        // Today
        do {
            let sessions7 = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: Date(), calendar: cal)
            let todayKey = BibleStatsStore.isoDateString(Date(), calendar: cal)
            todaySeconds = sessions7.reduce(0) { acc, s in
                let key = BibleStatsStore.isoDateString(s.end, calendar: cal)
                let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
                return acc + (key == todayKey ? dur : 0)
            }
        }

        // This week (rolling 7 days)
        do {
            let sessions7 = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: Date(), calendar: cal)
            thisWeekSeconds = sessions7.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        }

        // Last week rolling window
        do {
            let startOfToday = cal.startOfDay(for: Date())
            guard
                let thisWeekStart = cal.date(byAdding: .day, value: -6, to: startOfToday),
                let lastWeekEnd = cal.date(byAdding: .day, value: -7, to: startOfToday),
                let lastWeekStart = cal.date(byAdding: .day, value: -13, to: startOfToday)
            else {
                lastWeekSeconds = 0
                return
            }

            let sessions14 = ReadingSessionsStore.shared.sessions(inLastDays: 14, now: Date(), calendar: cal)
            lastWeekSeconds = sessions14.reduce(0) { acc, s in
                if s.end >= lastWeekStart && s.end < lastWeekEnd {
                    return acc + Int(max(0, s.end.timeIntervalSince(s.start)))
                } else {
                    return acc
                }
            }

            _ = thisWeekStart
        }

        computeCompletionMetricsVerseComplete()
        computePerBookProgressVerseComplete()
        computeVerseTotalsAndCompleted()

        if let last = BibleStatsStore.shared.loadLastRead() {
            lastReadEntry = last
            lastReadBookChapter = "\(last.bookName) \(last.chapterNumber)"
            lastReadTimeText = timeOnlyString(last.date)
        } else {
            lastReadEntry = nil
            lastReadBookChapter = "—"
            lastReadTimeText = "—"
        }
    }

    private func refreshChartsAndMonth() {
        let cal = Calendar.current

        // Last 7 days daily bars
        do {
            let sessions = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: Date(), calendar: cal)
            var buckets: [String: Int] = [:]
            for s in sessions {
                let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
                let key = BibleStatsStore.isoDateString(s.end, calendar: cal)
                buckets[key, default: 0] += dur
            }
            let days: [(Date, Int)] = (0..<7).compactMap { i -> (Date, Int)? in
                guard let d = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
                let key = BibleStatsStore.isoDateString(d, calendar: cal)
                return (d, buckets[key, default: 0])
            }.sorted { $0.0 < $1.0 }
            last7Daily = days
        }

        // Sessions: last 20 overall (>= minSessionSeconds)
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

        // New: compute last session length from all sessions (not filtered by min threshold here)
        do {
            let allSessions = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: Date(), calendar: cal)
            if let last = allSessions.max(by: { $0.end < $1.end }) {
                lastSessionSeconds = Int(max(0, last.end.timeIntervalSince(last.start)))
            } else {
                lastSessionSeconds = 0
            }
        }

        // Consistency
        last30Daily = StatsSeriesBuilder.dailySeries(lastNDays: 30, now: Date(), calendar: cal)

        // This Month
        let now = Date()
        let comps = BibleStatsStore.shared.chapterCompletions(inMonth: now)
        monthChaptersCompleted = comps.count

        // monthTotalSeconds set in refreshSessionScopedPerBook()
    }

    private func refreshSessionScopedPerBook() {
        let cal = Calendar.current
        let now = Date()

        let last7Sessions = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: now, calendar: cal)
        perBookLast7Totals = StatsSeriesBuilder.groupSessionsByBook(last7Sessions)

        let monthSessions = ReadingSessionsStore.shared.sessions(inMonthContaining: now, calendar: cal)
        perBookMonthTotals = StatsSeriesBuilder.groupSessionsByBook(monthSessions)
        monthTotalSeconds = perBookMonthTotals.values.reduce(0, +)

        let allSessions = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: now, calendar: cal)
        perBookAllTimeSessionTotals = StatsSeriesBuilder.groupSessionsByBook(allSessions)
        totalSecondsAllTime = allSessions.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }

        if let prevMonth = cal.date(byAdding: .month, value: -1, to: now) {
            let lastMonthSessions = ReadingSessionsStore.shared.sessions(inMonthContaining: prevMonth, calendar: cal)
            lastMonthSeconds = lastMonthSessions.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        } else {
            lastMonthSeconds = 0
        }

        let sortedTop = perBookMonthTotals.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        monthTop3Books = Array(sortedTop.prefix(3)).map { (book: $0.key, seconds: $0.value) }
    }

    private func averageSessionLength(sessions: [ReadingSessionsStore.Session]) -> Int {
        // Kept for compatibility where used locally (if any).
        StatsSeriesBuilder.averageSessionLength(sessions: sessions, minSessionSeconds: minSessionSeconds)
    }

    private func groupSessionsByBook(_ sessions: [ReadingSessionsStore.Session]) -> [String: Int] {
        StatsSeriesBuilder.groupSessionsByBook(sessions)
    }

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

    // MARK: - Rows

    private var scopedPerBookTotals: [String: Int] {
        switch timeScope {
        case .allTime: return perBookAllTimeSessionTotals
        case .thisMonth: return perBookMonthTotals
        case .last7: return perBookLast7Totals
        }
    }

    private var scopedTotalSeconds: Int {
        scopedPerBookTotals.values.reduce(0, +)
    }

    private var scopedRows: [(book: String, seconds: Int)] {
        let canonical = orderedAllBooks
        let canonicalPos = Dictionary(uniqueKeysWithValues: canonical.enumerated().map { ($1, $0) })

        switch sortMode {
        case .canonical:
            return canonical.map { name in
                (book: name, seconds: scopedPerBookTotals[name, default: 0])
            }
        case .mostRead:
            let all: [(book: String, seconds: Int)] = canonical.map { name in
                (book: name, seconds: scopedPerBookTotals[name, default: 0])
            }
            return all.sorted { lhs, rhs in
                if lhs.seconds == rhs.seconds {
                    return (canonicalPos[lhs.book] ?? .max) < (canonicalPos[rhs.book] ?? .max)
                }
                return lhs.seconds > rhs.seconds
            }
        }
    }

    private var scopedPerGenreTotalsComputed: [(genre: String, seconds: Int)] {
        StatsSeriesBuilder.computeGenreTotals(from: scopedPerBookTotals).map { ($0.genre, $0.seconds) }
    }

    // MARK: - Glance helpers

    private var weekDeltaOnlyValue: String {
        let delta = thisWeekSeconds - lastWeekSeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        let absVal = abs(delta)
        return "\(sign)\(BibleStatsStore.shared.format(absVal))"
    }

    private var todayDeltaOnlyValue: String {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        guard let startOfYesterday = cal.date(byAdding: .day, value: -1, to: startOfToday),
              let endOfYesterday = cal.date(byAdding: .second, value: -1, to: startOfToday)
        else { return "—" }

        let yesterdaySeconds = totalSecondsForDay(from: startOfYesterday, to: endOfYesterday, calendar: cal)
        let delta = todaySeconds - yesterdaySeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        let absVal = abs(delta)
        return "\(sign)\(BibleStatsStore.shared.format(absVal))"
    }

    private var monthDeltaOnlyValue: String {
        let delta = monthTotalSeconds - lastMonthSeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        let absVal = abs(delta)
        return "\(sign)\(BibleStatsStore.shared.format(absVal))"
    }

    private func totalSecondsForDay(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let sessions = ReadingSessionsStore.shared.sessions(inLastDays: 2, now: end, calendar: calendar)
        return sessions.reduce(0) { acc, s in
            if s.end >= start && s.end <= end {
                return acc + Int(max(0, s.end.timeIntervalSince(s.start)))
            } else {
                return acc
            }
        }
    }

    private func openReader(bookName: String, chapter: Int, verse: Int = 1) {
        NotificationCenter.default.post(name: .openBibleReference, object: nil, userInfo: [
            "book": bookName,
            "chapter": chapter,
            "verse": verse
        ])
    }

    private func nextUnreadGlobal() -> (book: String, chapter: Int)? {
        for b in BibleData.books {
            for c in b.chapters {
                let totalVerses = c.verses.count
                let complete = totalVerses > 0 && BibleStatsStore.shared.isChapterComplete(bookName: b.name, chapter: c.number, totalVerses: totalVerses)
                if !complete { return (b.name, c.number) }
            }
        }
        return nil
    }

    private func nextUnreadChapter(in bookName: String) -> Int? {
        guard let b = BibleData.books.first(where: { $0.name == bookName }) else { return nil }
        for c in b.chapters {
            let totalVerses = c.verses.count
            let complete = totalVerses > 0 && BibleStatsStore.shared.isChapterComplete(bookName: b.name, chapter: c.number, totalVerses: totalVerses)
            if !complete { return c.number }
        }
        return nil
    }

    enum Genre: String, CaseIterable, Identifiable {
        case Law = "Law"
        case History = "History"
        case Poetry = "Poetry"
        case MajorProphets = "Major Prophets"
        case MinorProphets = "Minor Prophets"
        case Gospels = "Gospels"
        case Acts = "Acts"
        case Epistles = "Epistles"
        case Apocalypse = "Apocalypse"

        var id: String { rawValue }
    }

    private func genreForBook(_ book: String) -> Genre {
        switch StatsSeriesBuilder.genreForBook(book) {
        case .Law: return .Law
        case .History: return .History
        case .Poetry: return .Poetry
        case .MajorProphets: return .MajorProphets
        case .MinorProphets: return .MinorProphets
        case .Gospels: return .Gospels
        case .Acts: return .Acts
        case .Epistles: return .Epistles
        case .Apocalypse: return .Apocalypse
        }
    }

    private func computeGenreTotals(from perBook: [String: Int]) -> [(genre: String, seconds: Int)] {
        StatsSeriesBuilder.computeGenreTotals(from: perBook).map { ($0.genre, $0.seconds) }
    }

    private func rowsForGenre(_ genre: Genre, totals: [String: Int]) -> [(book: String, seconds: Int)] {
        let canonical = orderedAllBooks
        let booksInGenre: [String] = canonical.filter { genreForBook($0) == genre }
        return booksInGenre.map { name in
            (book: name, seconds: totals[name, default: 0])
        }
    }

    private func genreColor(_ genre: String) -> Color {
        switch genre {
        case Genre.Law.rawValue: return .blue
        case Genre.History.rawValue: return .teal
        case Genre.Poetry.rawValue: return .purple
        case Genre.MajorProphets.rawValue: return .orange
        case Genre.MinorProphets.rawValue: return .pink
        case Genre.Gospels.rawValue: return .green
        case Genre.Acts.rawValue: return .mint
        case Genre.Epistles.rawValue: return .indigo
        case Genre.Apocalypse.rawValue: return .red
        default: return .gray
        }
    }

    private func timeOnlyString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Scope recompute

    private func recomputeOTNTFromScope() {
        let split = BibleStatsStore.shared.splitOTNT(totals: scopedPerBookTotals)
        otSeconds = split.ot
        ntSeconds = split.nt
    }

    private func recomputeGenresFromScope() {
        perGenreTotals = scopedPerGenreTotalsComputed
        if let g = selectedGenre {
            genreDetailRows = rowsForGenre(g, totals: scopedPerBookTotals)
        }
    }

    // MARK: - Totals card metrics and chart config

    private var totalsChartSubtitle: String {
        switch timeScope {
        case .last7:
            return "Daily minutes — Last 7 days"
        case .thisMonth:
            return "Daily minutes — This month"
        case .allTime:
            switch allTimeAggregation {
            case .monthly: return "Monthly minutes — All-time"
            case .yearly:  return "Yearly minutes — All-time"
            case .weekly:  return "Weekly minutes — All-time"
            case .daily:   return "Daily minutes — All-time"
            }
        }
    }

    private var currentXAxisAggregation: Aggregation {
        if timeScope == .allTime {
            return allTimeAggregation
        } else if timeScope == .thisMonth {
            return .weekly
        } else {
            return .daily
        }
    }

    private var currentBarUnit: Calendar.Component {
        switch timeScope {
        case .last7:
            return .day
        case .thisMonth:
            return .day
        case .allTime:
            switch allTimeAggregation {
            case .monthly: return .month
            case .yearly:  return .year
            case .weekly:  return .weekOfYear
            case .daily:   return .day
            }
        }
    }

    @AxisContentBuilder
    private var chartXAxisMarks: some AxisContent {
        switch currentXAxisAggregation {
        case .daily:
            AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        case .weekly:
            AxisMarks(values: .stride(by: .weekOfYear, count: 1)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        case .monthly:
            AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).year())
            }
        case .yearly:
            AxisMarks(values: .stride(by: .year, count: 1)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.year())
            }
        }
    }

    private func recomputeTotalsCardMetrics() {
        let cal = Calendar.current
        let now = Date()

        switch timeScope {
        case .last7:
            totalsDaily = StatsSeriesBuilder.dailySeries(lastNDays: 7, now: now, calendar: cal)
            allTimeAggregation = .daily
        case .thisMonth:
            totalsDaily = StatsSeriesBuilder.dailySeriesForMonth(containing: now, calendar: cal)
            allTimeAggregation = .weekly
        case .allTime:
            let r = StatsSeriesBuilder.allTimeAggregatedSeries(calendar: cal)
            totalsDaily = r.series
            allTimeAggregation = r.aggregation == .monthly ? .monthly : .yearly
        }

        activeDaysInScope = totalsDaily.reduce(0) { $0 + ($1.seconds > 0 ? 1 : 0) }
        let totalInSeries = totalsDaily.reduce(0) { $0 + $1.seconds }
        avgSecondsPerActiveBucketInScope = activeDaysInScope > 0 ? totalInSeries / activeDaysInScope : 0

        if let top = scopedPerBookTotals.sorted(by: { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }).first, top.value > 0 {
            topBookInScope = top.key
        } else {
            topBookInScope = "—"
        }
    }

    private func dailySeries(lastNDays: Int, now: Date, calendar: Calendar) -> [(date: Date, seconds: Int)] {
        StatsSeriesBuilder.dailySeries(lastNDays: lastNDays, now: now, calendar: calendar)
    }

    private func dailySeriesForMonth(containing date: Date, calendar: Calendar) -> [(date: Date, seconds: Int)] {
        StatsSeriesBuilder.dailySeriesForMonth(containing: date, calendar: calendar)
    }

    private func allTimeAggregatedSeries(calendar: Calendar) -> (series: [(date: Date, seconds: Int)], aggregation: Aggregation) {
        let r = StatsSeriesBuilder.allTimeAggregatedSeries(calendar: calendar)
        // Map utility’s Aggregation to our local Aggregation for this view
        let mappedAgg: Aggregation = {
            switch r.aggregation {
            case .daily: return .daily
            case .weekly: return .weekly
            case .monthly: return .monthly
            case .yearly: return .yearly
            }
        }()
        return (r.series, mappedAgg)
    }

    // MARK: - Smart insights computation (unchanged)

    private func computeInsights() {
        let cal = Calendar.autoupdatingCurrent
        let now = Date()

        // Best day in last 90 days
        do {
            let sessions = ReadingSessionsStore.shared.sessions(inLastDays: 90, now: now, calendar: cal)
            var buckets: [String: Int] = [:]
            for s in sessions {
                let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
                let key = BibleStatsStore.isoDateString(s.end, calendar: cal)
                buckets[key, default: 0] += dur
            }
            if let (bestKey, bestSeconds) = buckets.max(by: { $0.value < $1.value }),
               bestSeconds > 0 {
                let df = DateFormatter()
                df.calendar = cal
                df.timeZone = cal.timeZone
                df.setLocalizedDateFormatFromTemplate("MMM d")
                let isoParser = DateFormatter()
                isoParser.calendar = cal
                isoParser.timeZone = cal.timeZone
                isoParser.dateFormat = "yyyy-MM-dd"
                let bestDate = isoParser.date(from: bestKey) ?? cal.startOfDay(for: now)
                let pretty = df.string(from: bestDate)
                let val = BibleStatsStore.shared.format(bestSeconds)
                insightBestDayText = "Best day in 90 days: \(val) (\(pretty))"
            } else {
                insightBestDayText = nil
            }
        }

        // New streak: compare current streak today vs yesterday
        do {
            let current = StreakTracker.currentStreak
            let yesterday: Int = {
                var count = 0
                var day = cal.date(byAdding: .day, value: -1, to: now) ?? now
                if !StreakTracker.isGoalMet(on: day) {
                    if let prev = cal.date(byAdding: .day, value: -1, to: day) {
                        day = prev
                    }
                }
                while StreakTracker.isGoalMet(on: day) {
                    count += 1
                    guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
                    day = prev
                }
                return count
            }()
            if current > 0, current > yesterday {
                insightNewStreakText = "New streak: \(current) day\(current == 1 ? "" : "s") in a row"
            } else {
                insightNewStreakText = nil
            }
        }

        // 7‑day average up/down vs last month
        do {
            let last7 = StatsSeriesBuilder.dailySeries(lastNDays: 7, now: now, calendar: cal)
            let avg7 = last7.isEmpty ? 0 : last7.reduce(0) { $0 + $1.seconds } / last7.count

            if let prevMonth = cal.date(byAdding: .month, value: -1, to: now) {
                let prevMonthSeries = StatsSeriesBuilder.dailySeriesForMonth(containing: prevMonth, calendar: cal)
                let prevAvgPerDay = prevMonthSeries.isEmpty ? 0 : prevMonthSeries.reduce(0) { $0 + $1.seconds } / prevMonthSeries.count
                if prevAvgPerDay > 0 {
                    let change = Double(avg7 - prevAvgPerDay) / Double(prevAvgPerDay) * 100.0
                    let pct = Int(round(abs(change)))
                    if pct >= 1 {
                        insightSevenDayAvgVsMonthText = change >= 0
                        ? "7‑day average up \(pct)% vs last month"
                        : "7‑day average down \(pct)% vs last month"
                    } else {
                        insightSevenDayAvgVsMonthText = nil
                    }
                } else {
                    insightSevenDayAvgVsMonthText = nil
                }
            } else {
                insightSevenDayAvgVsMonthText = nil
            }
        }

        // Goal hits in last 7 days
        do {
            var hits = 0
            for i in 0..<7 {
                if let day = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: now)) {
                    if StreakTracker.isGoalMet(on: day) { hits += 1 }
                }
            }
            if hits > 0 {
                insightGoalHitsLast7Text = "You hit your goal \(hits) of the last 7 days"
            } else {
                insightGoalHitsLast7Text = nil
            }
        }

        // Longest session in last 30 days
        do {
            let sessions = ReadingSessionsStore.shared.sessions(inLastDays: 30, now: now, calendar: cal)
            if let longest = sessions.max(by: { ($0.end.timeIntervalSince($0.start)) < ($1.end.timeIntervalSince($1.start)) }) {
                let dur = Int(max(0, longest.end.timeIntervalSince(longest.start)))
                if dur >= minSessionSeconds {
                    let df = DateFormatter()
                    df.calendar = cal
                    df.timeZone = cal.timeZone
                    df.setLocalizedDateFormatFromTemplate("MMM d")
                    let when = df.string(from: longest.end)
                    insightLongestSessionText = "(30 days): \(BibleStatsStore.shared.format(dur)) (\(when))"
                } else {
                    insightLongestSessionText = nil
                }
            } else {
                insightLongestSessionText = nil
            }
        }

        // Most-read book this month
        do {
            if let top = monthTop3Books.first, top.seconds > 0 {
                insightTopBookThisMonthText = "Most‑read book this month: \(top.book)"
            } else {
                insightTopBookThisMonthText = nil
            }
        }
    }

    // MARK: - Mapping helpers for new card bindings

    private func mapScopeToOTNT(_ s: TimeScope) -> OTNTCardView.TimeScope {
        switch s {
        case .allTime: return .allTime
        case .thisMonth: return .thisMonth
        case .last7: return .last7
        }
    }
    private func mapScopeFromOTNT(_ s: OTNTCardView.TimeScope) -> TimeScope {
        switch s {
        case .allTime: return .allTime
        case .thisMonth: return .thisMonth
        case .last7: return .last7
        }
    }

    private func mapScopeToGenre(_ s: TimeScope) -> GenreDistributionCardView.TimeScope {
        switch s {
        case .allTime: return .allTime
        case .thisMonth: return .thisMonth
        case .last7: return .last7
        }
    }
    private func mapScopeFromGenre(_ s: GenreDistributionCardView.TimeScope) -> TimeScope {
        switch s {
        case .allTime: return .allTime
        case .thisMonth: return .thisMonth
        case .last7: return .last7
        }
    }
}

