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

    private enum StatsMode: String, CaseIterable, Identifiable {
        case bible = "Bible Stats"
        case games = "Game Stats"
        var id: String { rawValue }
    }

    // Persist the selected mode so the user’s choice sticks
    @AppStorage("statsSelectedMode") private var statsSelectedModeRaw: String = StatsMode.bible.rawValue
    private var statsSelectedMode: StatsMode {
        get { StatsMode(rawValue: statsSelectedModeRaw) ?? .bible }
        set { statsSelectedModeRaw = newValue.rawValue }
    }

    // View model
    @StateObject private var model = StatsViewModel()

    // Independent scopes per card (Totals, OT/NT, Genre) — UI-only
    @State private var timeScopeTotals: TimeScope = .allTime
    @State private var timeScopeOTNT: TimeScope = .allTime
    @State private var timeScopeGenre: TimeScope = .allTime

    @State private var sortMode: SortMode = .canonical

    // Genre distribution (derived by scope) — UI-only
    @State private var perGenreTotals: [(genre: String, seconds: Int)] = []
    @State private var selectedGenre: StatsSeriesBuilder.Genre? = nil
    @State private var genreDetailRows: [(book: String, seconds: Int)] = []

    // New: selected book for chapter detail sheet — UI-only
    @State private var selectedBookForChapters: String? = nil

    // Totals card dynamic metrics — UI-only (depends on scope)
    @State private var totalsDaily: [(date: Date, seconds: Int)] = []
    @State private var avgSecondsPerActiveBucketInScope: Int = 0
    @State private var activeDaysInScope: Int = 0
    @State private var topBookInScope: String = "—"

    // All-time aggregation mode for the totals chart — UI-only
    @State private var allTimeAggregation: StatsSeriesBuilder.Aggregation = .daily

    // Expand/collapse for existing sections — UI-only
    @State private var showBookProgressDetails: Bool = false
    @State private var showTotalsSection: Bool = false

    // New: filter/search for Book Progress grid — UI-only
    @State private var bookFilter: BookFilter = .all
    @State private var bookSearch: String = ""

    // Size-class aware layout
    @Environment(\.horizontalSizeClass) private var hSizeClass

    // OT/NT totals for the OTNT card — UI-only
    @State private var otSeconds: Int = 0
    @State private var ntSeconds: Int = 0

    // MARK: - Active bucket label for Totals card

    private var activeBucketLabel: String {
        StatsChartConfig.activeBucketLabel(for: totalsCurrentBarUnit)
    }

    private var avgPerActiveBucketLabel: String {
        StatsChartConfig.avgPerActiveBucketLabel(for: totalsCurrentBarUnit)
    }

    private var activeBucketCount: Int {
        // Use the already-computed state to keep type-checking simple and fast.
        activeDaysInScope
    }

    // Explicit typed bindings to help the type-checker
    private var statsModeBinding: Binding<StatsMode> {
        $statsSelectedModeRaw.derived(
            get: { StatsMode(rawValue: $0) ?? .bible },
            set: { $0.rawValue }
        )
    }

    private var chapterDetailItemBinding: Binding<ChapterDetailKey?> {
        $selectedBookForChapters.derived(
            get: { $0.map { ChapterDetailKey(bookName: $0) } },
            set: { $0?.bookName }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Top toggle: Bible Stats vs Game Stats
                HStack {
                    Picker("Mode", selection: statsModeBinding) {
                        ForEach(StatsMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode as StatsMode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // Ensure the mode picker is always above scroll content and captures taps
                .background(Color(.systemBackground))
                .zIndex(10)

                // Mode-specific content
                if statsSelectedMode == .bible {
                    bibleContent
                } else {
                    gameContent
                }
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.start()
            recomputeOTNTFromScope()
            recomputeGenresFromScope()
            recomputeTotalsCardMetrics()
        }
        .sheet(item: chapterDetailItemBinding) { key in
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
                    let totalsMap = genreScopedPerBookTotals
                    genreDetailRows = rowsForGenre(genre, totals: totalsMap)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { _ in
            selectedBookForChapters = nil
        }
        // Independent scope changes per card
        .onChange(of: timeScopeTotals) { _, _ in
            recomputeTotalsCardMetrics()
        }
        .onChange(of: timeScopeOTNT) { _, _ in
            recomputeOTNTFromScope()
        }
        .onChange(of: timeScopeGenre) { _, _ in
            recomputeGenresFromScope()
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

    // MARK: - Mode-specific content

    private var bibleContent: some View {
        Group {
            if hSizeClass == .regular {
                // Two-column layout on iPad (Bible-only)
                HStack(alignment: .top, spacing: 16) {
                    // Column 1
                    VStack(spacing: 16) {
                        progressCard
                        topBooksThisMonthCard
                        // Moved Genre Distribution under Top Books This Month in the first column
                        genreCard
                    }
                    .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)

                    // Column 2
                    VStack(spacing: 16) {
                        totalsCard
                        otntCard
                        // Removed genreCard from column 2
                        avgSessionCard
                    }
                    .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            } else {
                // Single-column layout on iPhone (Bible-only)
                VStack(spacing: 16) {
                    progressCard
                    totalsCard
                    otntCard
                    genreCard
                    avgSessionCard
                    topBooksThisMonthCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    private var gameContent: some View {
        Group {
            if hSizeClass == .regular {
                // iPad: stack game stats vertically, full width
                VStack(spacing: 16) {
                    GamesOverviewCardView()
                        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
                    PlayerStatSheetCardView()
                        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            } else {
                // iPhone: single-column stack of game stats
                VStack(spacing: 16) {
                    GamesOverviewCardView()
                    PlayerStatSheetCardView()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }

    // Extracted card views for reuse in both layouts

    private var progressCard: some View {
        ProgressCardView(
            booksCompleted: model.booksCompleted,
            totalBooks: model.totalBooks,
            visitedCount: model.visitedCount,
            totalChapters: model.totalChapters,
            completedVerses: model.completedVerses,
            totalVerses: model.totalVerses,
            orderedBookNames: orderedAllBooks,
            bookProgress: model.bookProgress,
            onContinue: {
                if let last = model.lastReadEntry {
                    openReader(bookName: last.bookName, chapter: last.chapterNumber, verse: 1)
                }
            },
            onOpenNextUnread: {
                if let next = nextUnreadGlobal() {
                    openReader(bookName: next.book, chapter: next.chapter, verse: 1)
                }
            },
            hasLastRead: model.lastReadEntry != nil,
            isExpanded: $showBookProgressDetails,
            filter: $bookFilter,
            search: $bookSearch,
            selectedBookForChapters: $selectedBookForChapters
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    private var totalsCard: some View {
        TotalsCardView(
            timeScope: Binding(
                get: {
                    switch timeScopeTotals {
                    case .allTime: return .allTime
                    case .thisMonth: return .thisMonth
                    case .last7: return .last7
                    }
                },
                set: { new in
                    switch new {
                    case .allTime: timeScopeTotals = .allTime
                    case .thisMonth: timeScopeTotals = .thisMonth
                    case .last7: timeScopeTotals = .last7
                    }
                }
            ),
            totalSeconds: totalsScopedTotalSeconds,
            series: totalsDaily,
            chartSubtitle: totalsChartSubtitle,
            currentBarUnit: totalsCurrentBarUnit,
            showValueLabels: totalsShouldShowBarValueLabels,
            xAxis: { AnyAxisContent(totalsChartXAxisMarks) },
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
            rows: totalsScopedRows,
            formatSeconds: { BibleStatsStore.shared.format($0) }
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    private var otntCard: some View {
        OTNTCardView(
            timeScope: Binding(
                get: { mapScopeToOTNT(timeScopeOTNT) },
                set: { new in timeScopeOTNT = mapScopeFromOTNT(new) }
            ),
            otSeconds: otSeconds,
            ntSeconds: ntSeconds,
            formatSeconds: { BibleStatsStore.shared.format($0) }
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    private var genreCard: some View {
        GenreDistributionCardView(
            timeScope: Binding(
                get: { mapScopeToGenre(timeScopeGenre) },
                set: { new in timeScopeGenre = mapScopeFromGenre(new) }
            ),
            perGenreTotals: perGenreTotals,
            selectedGenre: $selectedGenre,
            onSelectGenre: { g in
                genreDetailRows = rowsForGenre(g, totals: genreScopedPerBookTotals)
            },
            genreColor: { genreColor($0) },
            formatSeconds: { BibleStatsStore.shared.format($0) }
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    private var avgSessionCard: some View {
        AverageSessionCardView(
            sessionsSeries: model.sessionsLast7,
            avgSessionSeconds: model.avgSessionSecondsLast7,
            formatSeconds: { BibleStatsStore.shared.format($0) }
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    private var topBooksThisMonthCard: some View {
        TopBooksThisMonthCardView(
            top3: model.monthTop3Books,
            totalSeconds: model.monthTotalSeconds,
            formatSeconds: BibleStatsStore.shared.format
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    // MARK: - Helpers and computed data

    private var orderedAllBooks: [String] {
        if !BibleData.books.isEmpty {
            return BibleData.books.map { $0.name }
        }
        return BibleCanon.canonicalOrder()
    }

    // MARK: - Per-card scoped maps

    private var totalsScopedPerBookTotals: [String: Int] {
        switch timeScopeTotals {
        case .allTime: return model.perBookAllTimeSessionTotals
        case .thisMonth: return model.perBookMonthTotals
        case .last7: return model.perBookLast7Totals
        }
    }

    private var otntScopedPerBookTotals: [String: Int] {
        switch timeScopeOTNT {
        case .allTime: return model.perBookAllTimeSessionTotals
        case .thisMonth: return model.perBookMonthTotals
        case .last7: return model.perBookLast7Totals
        }
    }

    private var genreScopedPerBookTotals: [String: Int] {
        switch timeScopeGenre {
        case .allTime: return model.perBookAllTimeSessionTotals
        case .thisMonth: return model.perBookMonthTotals
        case .last7: return model.perBookLast7Totals
        }
    }

    private var totalsScopedTotalSeconds: Int {
        totalsScopedPerBookTotals.values.reduce(0, +)
    }

    private var totalsScopedRows: [(book: String, seconds: Int)] {
        let canonical = orderedAllBooks
        let canonicalPos = Dictionary(uniqueKeysWithValues: canonical.enumerated().map { ($1, $0) })

        switch sortMode {
        case .canonical:
            return canonical.map { name in
                (book: name, seconds: totalsScopedPerBookTotals[name, default: 0])
            }
        case .mostRead:
            let all: [(book: String, seconds: Int)] = canonical.map { name in
                (book: name, seconds: totalsScopedPerBookTotals[name, default: 0])
            }
            return all.sorted { lhs, rhs in
                if lhs.seconds == rhs.seconds {
                    return (canonicalPos[lhs.book] ?? .max) < (canonicalPos[rhs.book] ?? .max)
                }
                return lhs.seconds > rhs.seconds
            }
        }
    }

    private var genreScopedPerGenreTotalsComputed: [(genre: String, seconds: Int)] {
        StatsSeriesBuilder.computeGenreTotals(from: genreScopedPerBookTotals).map { ($0.genre, $0.seconds) }
    }

    // MARK: - Glance helpers

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

    private func rowsForGenre(_ genre: StatsSeriesBuilder.Genre, totals: [String: Int]) -> [(book: String, seconds: Int)] {
        let canonical = orderedAllBooks
        let booksInGenre: [String] = canonical.filter { StatsSeriesBuilder.genreForBook($0) == genre }
        return booksInGenre.map { name in
            (book: name, seconds: totals[name, default: 0])
        }
    }

    private func genreColor(_ genre: String) -> Color {
        switch genre {
        case StatsSeriesBuilder.Genre.Law.rawValue: return .blue
        case StatsSeriesBuilder.Genre.History.rawValue: return .teal
        case StatsSeriesBuilder.Genre.Poetry.rawValue: return .purple
        case StatsSeriesBuilder.Genre.MajorProphets.rawValue: return .orange
        case StatsSeriesBuilder.Genre.MinorProphets.rawValue: return .pink
        case StatsSeriesBuilder.Genre.Gospels.rawValue: return .green
        case StatsSeriesBuilder.Genre.Acts.rawValue: return .mint
        case StatsSeriesBuilder.Genre.Epistles.rawValue: return .indigo
        case StatsSeriesBuilder.Genre.Apocalypse.rawValue: return .red
        default: return .gray
        }
    }

    // MARK: - Scope mapping helpers

    private func mapScopeToOTNT(_ scope: TimeScope) -> OTNTCardView.TimeScope {
        switch scope {
        case .allTime: return .allTime
        case .thisMonth: return .thisMonth
        case .last7: return .last7
        }
    }

    private func mapScopeFromOTNT(_ scope: OTNTCardView.TimeScope) -> TimeScope {
        switch scope {
        case .allTime: return .allTime
        case .thisMonth: return .thisMonth
        case .last7: return .last7
        }
    }

    private func mapScopeToGenre(_ scope: TimeScope) -> GenreDistributionCardView.TimeScope {
        switch scope {
        case .allTime: return .allTime
        case .thisMonth: return .thisMonth
        case .last7: return .last7
        }
    }

    private func mapScopeFromGenre(_ scope: GenreDistributionCardView.TimeScope) -> TimeScope {
        switch scope {
        case .allTime: return .allTime
        case .thisMonth: return .thisMonth
        case .last7: return .last7
        }
    }

    // MARK: - Totals chart config via helper

    private var totalsChartScope: StatsChartConfig.Scope {
        switch timeScopeTotals {
        case .allTime: return .allTime
        case .thisMonth: return .thisMonth
        case .last7: return .last7
        }
    }

    private var totalsChartSubtitle: String {
        StatsChartConfig.subtitle(for: totalsChartScope, allTimeAggregation: allTimeAggregation)
    }

    private var totalsCurrentXAxisAggregation: StatsSeriesBuilder.Aggregation {
        StatsChartConfig.currentXAxisAggregation(for: totalsChartScope, allTimeAggregation: allTimeAggregation)
    }

    private var totalsCurrentBarUnit: Calendar.Component {
        StatsChartConfig.currentBarUnit(for: totalsChartScope, allTimeAggregation: allTimeAggregation)
    }

    private var totalsShouldShowBarValueLabels: Bool {
        StatsChartConfig.shouldShowBarValueLabels(
            for: totalsChartScope,
            allTimeAggregation: allTimeAggregation,
            count: totalsDaily.count,
            isRegular: (hSizeClass == .regular)
        )
    }

    @AxisContentBuilder
    private var totalsChartXAxisMarks: some AxisContent {
        StatsChartConfig.xAxisMarks(for: totalsCurrentXAxisAggregation)
    }

    // MARK: - Scope recompute

    private func recomputeOTNTFromScope() {
        let split = BibleStatsStore.shared.splitOTNT(totals: otntScopedPerBookTotals)
        otSeconds = split.ot
        ntSeconds = split.nt
    }

    private func recomputeGenresFromScope() {
        perGenreTotals = genreScopedPerGenreTotalsComputed
        if let g = selectedGenre {
            genreDetailRows = rowsForGenre(g, totals: genreScopedPerBookTotals)
        }
    }

    // MARK: - Totals card metrics and chart config (independent scope)

    private func recomputeTotalsCardMetrics() {
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let dailyMap = BibleStatsStore.shared.loadDailyTotals()

        switch timeScopeTotals {
        case .last7:
            var series: [(Date, Int)] = []
            for i in stride(from: 6, through: 0, by: -1) {
                if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                    let key = BibleStatsStore.isoDateString(d, calendar: cal)
                    series.append((d, max(0, dailyMap[key, default: 0])))
                }
            }
            totalsDaily = series
            allTimeAggregation = .daily

        case .thisMonth:
            var series: [(Date, Int)] = []
            // Enumerate all days in this month using isoKeysForMonth for consistency
            let keys = BibleStatsStore.isoKeysForMonth(containing: now, calendar: cal)
            for key in keys {
                // Rebuild Date from key using calendar startOfDay
                let comps = key.split(separator: "-").compactMap { Int($0) }
                if comps.count == 3, let date = cal.date(from: DateComponents(year: comps[0], month: comps[1], day: comps[2])) {
                    series.append((date, max(0, dailyMap[key, default: 0])))
                }
            }
            totalsDaily = series
            allTimeAggregation = .weekly

        case .allTime:
            // Aggregate daily totals into monthly or yearly buckets based on span, similar to StatsSeriesBuilder
            // Build a [Date: Int] map of all known daily entries as Dates
            var entries: [(date: Date, seconds: Int)] = []
            for (key, seconds) in dailyMap {
                let parts = key.split(separator: "-").compactMap { Int($0) }
                if parts.count == 3, let date = cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) {
                    entries.append((cal.startOfDay(for: date), max(0, seconds)))
                }
            }
            guard !entries.isEmpty else {
                totalsDaily = []
                allTimeAggregation = .daily
                break
            }
            let start = entries.map { $0.date }.min() ?? startOfToday
            let end = startOfToday
            let monthsSpan = cal.dateComponents([.month], from: start, to: end).month ?? 0
            let aggregation: StatsSeriesBuilder.Aggregation = (monthsSpan <= 12) ? .monthly : .yearly

            func bucketStart(for date: Date) -> Date {
                switch aggregation {
                case .monthly:
                    let comps = cal.dateComponents([.year, .month], from: date)
                    return cal.date(from: comps) ?? cal.startOfDay(for: date)
                case .yearly:
                    let comps = cal.dateComponents([.year], from: date)
                    return cal.date(from: comps) ?? cal.startOfDay(for: date)
                default:
                    return cal.startOfDay(for: date)
                }
            }

            var buckets: [Date: Int] = [:]
            for e in entries {
                let key = bucketStart(for: e.date)
                buckets[key, default: 0] += e.seconds
            }

            var series: [(Date, Int)] = []
            var cursor: Date = {
                switch aggregation {
                case .monthly:
                    let comps = cal.dateComponents([.year, .month], from: start)
                    return cal.date(from: comps) ?? start
                case .yearly:
                    let comps = cal.dateComponents([.year], from: start)
                    return cal.date(from: comps) ?? start
                default:
                    return start
                }
            }()

            func step(_ date: Date) -> Date {
                switch aggregation {
                case .monthly: return cal.date(byAdding: .month, value: 1, to: date) ?? date
                case .yearly: return cal.date(byAdding: .year, value: 1, to: date) ?? date
                default: return date
                }
            }

            while cursor <= end {
                let val = buckets[cursor, default: 0]
                series.append((cursor, val))
                cursor = step(cursor)
            }

            if aggregation == .monthly {
                let maxMonths = (monthsSpan <= 6) ? 6 : 12
                if series.count > maxMonths {
                    series = Array(series.suffix(maxMonths))
                }
                allTimeAggregation = .monthly
            } else {
                let maxYears = 10
                if series.count > maxYears {
                    series = Array(series.suffix(maxYears))
                }
                allTimeAggregation = .yearly
            }

            totalsDaily = series
        }

        activeDaysInScope = totalsDaily.reduce(0) { $0 + ($1.seconds > 0 ? 1 : 0) }
        let totalInSeries = totalsDaily.reduce(0) { $0 + $1.seconds }
        avgSecondsPerActiveBucketInScope = activeDaysInScope > 0 ? totalInSeries / activeDaysInScope : 0

        if let top = totalsScopedPerBookTotals.sorted(by: { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }).first, top.value > 0 {
            topBookInScope = top.key
        } else {
            topBookInScope = "—"
        }
    }
}

// MARK: - Binding helper

private extension Binding {
    func derived<T>(get: @escaping (Value) -> T, set: @escaping (T) -> Value) -> Binding<T> {
        Binding<T>(
            get: { get(self.wrappedValue) },
            set: { self.wrappedValue = set($0) }
        )
    }
}
