import SwiftUI
import Charts

private struct ReadingStatsSections<
    ReadingAndGames: View,
    Progress: View,
    Insights: View,
    Totals: View,
    Testament: View,
    Genre: View,
    AverageSession: View,
    TopBooks: View,
    History: View,
    Prayer: View
>: View {
    let usesWideLayout: Bool
    let readingAndGames: ReadingAndGames
    let progress: Progress
    let insights: Insights
    let totals: Totals
    let testament: Testament
    let genre: Genre
    let averageSession: AverageSession
    let topBooks: TopBooks
    let history: History
    let prayer: Prayer

    var body: some View {
        Group {
            if usesWideLayout {
                // Reading History and Prayer sit in the columns too, so they don't
                // stretch across the full width on iPad.
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) {
                        readingAndGames
                        progress
                        insights
                        topBooks
                        genre
                        prayer
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(spacing: 16) {
                        totals
                        testament
                        averageSession
                        history
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                VStack(spacing: 16) {
                    readingAndGames
                    progress
                    insights
                    totals
                    testament
                    genre
                    averageSession
                    topBooks
                    history
                    prayer
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct GameStatsSections: View {
    let usesWideLayout: Bool

    var body: some View {
        Group {
            if usesWideLayout {
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) {
                        GamesOverviewCardView()
                        GameInsightsCardView()
                    }
                    .frame(maxWidth: 560, alignment: .topLeading)

                    VStack(spacing: 16) {
                        AllGamesComparisonCardView()
                        PlayerStatSheetCardView()
                    }
                    .frame(maxWidth: 560, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .top)
            } else {
                VStack(spacing: 16) {
                    GamesOverviewCardView()
                    GameInsightsCardView()
                    AllGamesComparisonCardView()
                    PlayerStatSheetCardView()
                }
                .frame(maxWidth: 560)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

struct StatsView: View {
    private enum StatsMode: String, CaseIterable, Identifiable {
        case bible = "Reading Stats"
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
    @State private var model = StatsViewModel()

    // Each card's time scope, and the series and totals behind them, live in `model`.
    @State private var sortMode: StatsSortMode = .canonical
    @State private var selectedGenre: StatsSeriesBuilder.Genre? = nil

    // New: selected book for chapter detail sheet — UI-only
    @State private var selectedBookForChapters: String? = nil

    // Expand/collapse for existing sections — UI-only
    @State private var showBookProgressDetails: Bool = false
    @State private var showTotalsSection: Bool = false

    // New: filter/search for Book Progress grid — UI-only
    @State private var bookFilter: BookFilter = .all
    @State private var bookSearch: String = ""

    // Size-class aware layout
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    // Segmented control tint for readability
    private var segmentedTint: Color {
        colorScheme == .light ? Color.black.opacity(0.85) : Color.accentColor
    }

    // MARK: - Active bucket label for Totals card

    private var activeBucketLabel: String {
        StatsChartConfig.activeBucketLabel(for: totalsCurrentBarUnit)
    }

    private var avgPerActiveBucketLabel: String {
        StatsChartConfig.avgPerActiveBucketLabel(for: totalsCurrentBarUnit)
    }

    private var activeBucketCount: Int {
        // Use the already-computed state to keep type-checking simple and fast.
        model.activeDaysInScope
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
                // Top toggle: Reading Stats vs Game Stats
                HStack {
                    Picker("Mode", selection: statsModeBinding) {
                        ForEach(StatsMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode as StatsMode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(segmentedTint)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // Ensure the mode picker is always above scroll content and captures taps
                .background(.clear)
                .zIndex(10)

                // Mode-specific content
                if statsSelectedMode == .bible {
                    bibleContent
                } else {
                    gameContent
                }
            }
        }
        .groupBoxStyle(StatsHeroGroupBoxStyle())
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // A refresh recomputes the cards through `refreshRevision` below.
            if !model.start() {
                model.recomputeScopedCards()
            }
        }
        .onDisappear {
            model.stop()
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
                        ForEach(model.genreDetailRows(for: genre), id: \.book) { row in
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
            }
        }
        // Close the chapter sheet when the app navigates somewhere else.
        .onChange(of: AppRouter.shared.latest) { _, request in
            if let request, case .stats = request.destination { return }
            selectedBookForChapters = nil
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

    private var usesWideStatsLayout: Bool {
        !dynamicTypeSize.isAccessibilitySize && (hSizeClass == .regular || vSizeClass == .compact)
    }

    private var bibleContent: some View {
        VStack(spacing: 16) {
            WeeklyReadingSummaryCard(
                thisWeekSeconds: model.thisWeekSeconds,
                lastWeekSeconds: model.lastWeekSeconds,
                activeDays: model.activeReadingDaysThisWeek,
                topBook: model.topBookThisWeek,
                formatSeconds: { BibleStatsStore.shared.format($0) }
            )

            ReadingStatsSections(
                usesWideLayout: usesWideStatsLayout,
                readingAndGames: ReadingAndGamesComparisonCard(),
                progress: progressCard,
                insights: readingInsightsCard,
                totals: totalsCard,
                testament: otntCard,
                genre: genreCard,
                averageSession: avgSessionCard,
                topBooks: topBooksThisMonthCard,
                history: readingHistoryCard,
                prayer: PrayerStatsCard()
            )
        }
    }

    private var readingHistoryCard: some View {
        ReadingHistoryCalendarCard(usesCompactLayout: usesWideStatsLayout)
    }

    private var gameContent: some View {
        VStack(spacing: 16) {
            GameWeekSummaryCardView()
            GameStatsSections(usesWideLayout: usesWideStatsLayout)
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
            orderedBookNames: model.orderedBookNames,
            bookProgress: model.bookProgress,
            isExpanded: $showBookProgressDetails,
            filter: $bookFilter,
            search: $bookSearch,
            selectedBookForChapters: $selectedBookForChapters
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    private var totalsCard: some View {
        TotalsCardView(
            timeScope: $model.timeScopeTotals,
            totalSeconds: model.totalsScopedTotalSeconds,
            series: model.totalsDaily,
            chartSubtitle: totalsChartSubtitle,
            currentBarUnit: totalsCurrentBarUnit,
            showValueLabels: totalsShouldShowBarValueLabels,
            xAxis: { AnyAxisContent(totalsChartXAxisMarks) },
            activeBucketLabel: activeBucketLabel,
            activeBucketCount: activeBucketCount,
            avgPerActiveBucketLabel: avgPerActiveBucketLabel,
            avgSecondsPerActiveBucket: model.avgSecondsPerActiveBucketInScope,
            topBook: model.topBookInScope,
            isExpanded: $showTotalsSection,
            sortMode: $sortMode,
            rows: model.totalsScopedRows(sortedBy: sortMode),
            formatSeconds: { BibleStatsStore.shared.format($0) }
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    private var readingInsightsCard: some View {
        ReadingInsightsCardView(
            insights: model.readingInsights,
            formatSeconds: { BibleStatsStore.shared.format($0) }
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    private var otntCard: some View {
        OTNTCardView(
            timeScope: $model.timeScopeOTNT,
            otSeconds: model.otSeconds,
            ntSeconds: model.ntSeconds,
            formatSeconds: { BibleStatsStore.shared.format($0) }
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    private var genreCard: some View {
        GenreDistributionCardView(
            timeScope: $model.timeScopeGenre,
            perGenreTotals: model.perGenreTotals,
            selectedGenre: $selectedGenre,
            onSelectGenre: { _ in },
            genreColor: { genreColor($0) },
            formatSeconds: { BibleStatsStore.shared.format($0) }
        )
        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.topLeading)
    }

    private var avgSessionCard: some View {
        AverageSessionCardView(
            dailyAverages: model.dailyAverageSessionsLast7,
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

    // MARK: - Glance helpers

    private func openReader(bookName: String, chapter: Int, verse: Int = 1) {
        AppRouter.shared.openBibleReference(book: bookName, chapter: chapter, verse: verse)
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

    // MARK: - Totals chart config via helper

    private var totalsChartSubtitle: String {
        StatsChartConfig.subtitle(for: model.timeScopeTotals, allTimeAggregation: model.allTimeAggregation)
    }

    private var totalsCurrentXAxisAggregation: StatsSeriesBuilder.Aggregation {
        StatsChartConfig.currentXAxisAggregation(for: model.timeScopeTotals, allTimeAggregation: model.allTimeAggregation)
    }

    private var totalsCurrentBarUnit: Calendar.Component {
        StatsChartConfig.currentBarUnit(for: model.timeScopeTotals, allTimeAggregation: model.allTimeAggregation)
    }

    private var totalsShouldShowBarValueLabels: Bool {
        StatsChartConfig.shouldShowBarValueLabels(
            for: model.timeScopeTotals,
            allTimeAggregation: model.allTimeAggregation,
            count: model.totalsDaily.count,
            isRegular: (hSizeClass == .regular)
        )
    }

    @AxisContentBuilder
    private var totalsChartXAxisMarks: some AxisContent {
        StatsChartConfig.xAxisMarks(for: totalsCurrentXAxisAggregation)
    }
}

private struct StatsHeroGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.label
            configuration.content
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
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
