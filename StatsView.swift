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
    private enum BookFilter: String, CaseIterable, Identifiable {
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
        totalsDaily.reduce(0) { $0 + ($1.seconds > 0 ? 1 : 0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                glanceRow

                // Smart Insights
                smartInsightsCard

                // This Month section
                thisMonthCard

                // Average Session Length (last 20 sessions)
                averageSessionCard

                // NEW: Consistency — last 30 days
                consistencyCard

                // Revamped: Bible Reading Progress
                bookReadingProgressCard

                // Existing: Total Bible Reading Time + Per-book table (collapsible)
                totalsSection

                // Moved: OT vs NT chart now appears directly under the Total Bible Reading Time card
                // so it shares the same scope controls.
                otNtCard

                // Genre Distribution stays below OT vs NT
                genreSection

                // NEW: Games card at the bottom (shared with Home)
                GamesCardView()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Start KVS coordinator (safe to call multiple times)
            iCloudSyncCoordinator.shared.start()

            refreshAll()
            if cancellable == nil {
                cancellable = ReadingTimeTracker.shared.$lastTotalsVersion
                    .receive(on: RunLoop.main)
                    .sink { _ in refreshAll() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)) { _ in
            // Refresh when stats changed on another device
            refreshAll()
        }
        .sheet(item: Binding(
            get: {
                selectedBookForChapters.map { ChapterDetailKey(bookName: $0) }
            },
            set: { newValue in
                selectedBookForChapters = newValue?.bookName
            }
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
                            // Quick jump: Next unread in this book (if any)
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
                    // Use scoped per-book totals for the selected timeframe
                    let totalsMap = scopedPerBookTotals
                    genreDetailRows = rowsForGenre(genre, totals: totalsMap)
                }
            }
        }
        // Close the chapters sheet when switching to the Bible tab
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("switchToTab"))) { _ in
            selectedBookForChapters = nil
        }
        // Refresh stats when chapter progress changes
        .onReceive(NotificationCenter.default.publisher(for: .chapterProgressChanged)) { _ in
            refreshAll()
        }
        // Keep OT/NT and Genre in sync with the selected scope
        .onChange(of: timeScope) {
            recomputeOTNTFromScope()
            recomputeGenresFromScope()
            recomputeTotalsCardMetrics()
        }
    }

    // MARK: - Smart Insights

    private var smartInsightsCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Smart Insights")
                        .font(.headline)
                    Spacer()
                    Button {
                        computeInsights()
                    } label: {
                        Label("Refresh insights", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                // Build tile models from available insights (short, glanceable)
                let tiles: [InsightChipModel] = [
                    insightBestDayText.map { InsightChipModel(icon: "calendar.badge.clock", title: "Best Day", detail: $0, tint: .blue) },
                    insightNewStreakText.map { InsightChipModel(icon: "flame.fill", title: "Streak", detail: $0, tint: .orange) },
                    insightSevenDayAvgVsMonthText.map { InsightChipModel(icon: "chart.line.uptrend.xyaxis", title: "7‑day Avg", detail: $0, tint: .green) },
                    insightGoalHitsLast7Text.map { InsightChipModel(icon: "target", title: $0.contains("7") ? "Goal Hits" : "Goal", detail: $0, tint: .purple) },
                    insightLongestSessionText.map { InsightChipModel(icon: "timer", title: "Longest Session", detail: $0, tint: .teal) },
                    insightTopBookThisMonthText.map { InsightChipModel(icon: "book.fill", title: "Top Book", detail: $0, tint: .pink) }
                ].compactMap { $0 }

                if tiles.isEmpty {
                    ContentUnavailableView("No insights yet", systemImage: "sparkles")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // Two-column adaptive grid with glanceable tiles
                    let columns = [GridItem(.adaptive(minimum: 260), spacing: 10)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(tiles) { model in
                            InsightTile(model: model)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Cards

    private var thisMonthCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Reading Time This Month")
                        .font(.headline)
                    Spacer()
                    Text(BibleStatsStore.shared.format(monthTotalSeconds))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                        .overlay(
                            Color.clear
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("This month total \(BibleStatsStore.shared.format(monthTotalSeconds))")
                        )
                }

                HStack(spacing: 12) {
                    pill("Chapters completed", value: "\(formatInt(monthChaptersCompleted))")
                    // Show only the single top book by time this month
                    let topSummary: String = monthTop3Books.first.map { $0.book } ?? "—"
                    pill("Top book", value: topSummary)
                }

                if !last7Daily.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reading Time (last 7 days)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Chart {
                            ForEach(last7Daily, id: \.date) { item in
                                let minutes = Int(round(Double(item.seconds) / 60.0))
                                BarMark(
                                    x: .value("Date", item.date, unit: .day),
                                    y: .value("Minutes", minutes)
                                )
                                .foregroundStyle(Color.accentColor)
                                // Label above each bar for last 7 days chart too (nice consistency)
                                .annotation(position: .top, alignment: .center) {
                                    if minutes > 0 {
                                        Text("\(minutes)")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                            }
                        }
                        .chartYAxisLabel("Minutes")
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            }
                        }
                        .frame(height: 160)
                    }
                }
            }
        }
    }

    private var averageSessionCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Average Session Length")
                        .font(.headline)
                    Spacer()
                    Text("Avg (last 7 days): \(BibleStatsStore.shared.format(avgSessionSecondsLast7))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if !sessionsLast7.isEmpty {
                    Chart {
                        ForEach(sessionsLast7, id: \.index) { point in
                            LineMark(
                                x: .value("Session", point.index),
                                y: .value("Minutes", point.minutes)
                            )
                            .foregroundStyle(.teal)
                            PointMark(
                                x: .value("Session", point.index),
                                y: .value("Minutes", point.minutes)
                            )
                            .foregroundStyle(.teal)
                        }
                    }
                    .chartYAxisLabel("Minutes")
                    .chartXAxisLabel("Sessions")
                    .frame(height: 180)
                } else {
                    ContentUnavailableView("No recent sessions", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
        }
    }

    // NEW: Consistency — last 30 days
    private var consistencyCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Consistency — last 30 days")
                    .font(.headline)

                // Row of 30 small squares, horizontally scrollable
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(last30Daily, id: \.date) { item in
                            consistencySquare(for: item.seconds)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Legend
                HStack(spacing: 16) {
                    legendItem(color: consistencyColor(for: 0), label: "0")
                    legendItem(color: consistencyColor(for: 5*60), label: "5m")
                    legendItem(color: consistencyColor(for: 15*60), label: "15m")
                    legendItem(color: consistencyColor(for: 30*60), label: "30m")
                    legendItem(color: consistencyColor(for: 60*60), label: "1h+")
                }
            }
        }
    }

    private func consistencySquare(for seconds: Int) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(consistencyColor(for: seconds))
            .frame(width: 20, height: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // Threshold-based color mapping (blue, teal, orange, red)
    private func consistencyColor(for seconds: Int) -> Color {
        if seconds <= 0 { return Color.gray.opacity(0.28) } // 0
        if seconds >= 60*60 { return .red }                 // 1h+
        if seconds >= 30*60 { return .orange }              // 30m–<1h
        if seconds >= 15*60 { return .teal }                // 15m–<30m
        return .blue                                        // 0–<15m (non-zero)
    }

    private func pill(_ title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    // New helper to fix missing symbol
    private func milestonePill(text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        // 1=Sunday ... 7=Saturday
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

    // MARK: - Top glance row (scrollable mini‑pills matching Home)

    private var glanceRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                statMiniPill(title: "Today", value: BibleStatsStore.shared.format(todaySeconds), subtitle: todayDeltaOnlyValue, tint: .blue)
                statMiniPill(title: "This Week", value: BibleStatsStore.shared.format(thisWeekSeconds), subtitle: weekDeltaOnlyValue, tint: .green)
                statMiniPill(title: "This Month", value: BibleStatsStore.shared.format(monthTotalSeconds), subtitle: monthDeltaOnlyValue, tint: .mint)
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

    private var otNtCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("OT vs NT — \(timeScope.rawValue)")
                        .font(.headline)
                    Spacer()
                }

                // Scope picker for this card (shares the same timeScope state)
                Picker("Scope", selection: $timeScope) {
                    ForEach(TimeScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    Text("OT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    otNtBar
                    Text("NT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("OT \(BibleStatsStore.shared.format(otSeconds))")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("NT \(BibleStatsStore.shared.format(ntSeconds))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var otNtBar: some View {
        let total = max(1, otSeconds + ntSeconds)
        let otFrac = CGFloat(otSeconds) / CGFloat(total)
        let ntFrac = CGFloat(ntSeconds) / CGFloat(total)
        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: geo.size.width * otFrac)
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: geo.size.width * ntFrac)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 12)
    }

    private var bookReadingProgressCard: some View {
        // Compute books completion percent for summary ring
        let booksPercent: Int = {
            let denom = max(1, totalBooks)
            let pct = Int(round((Double(booksCompleted) / Double(denom)) * 100.0))
            return max(0, min(100, pct))
        }()
        // Compute verses completion percent for summary ring
        let versesPercent: Int = {
            let denom = max(1, totalVerses)
            let pct = Int(round((Double(completedVerses) / Double(denom)) * 100.0))
            return max(0, min(100, pct))
        }()

        let nextUnread = nextUnreadGlobal()

        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                // Collapsed header: adaptive by size class
                if hSizeClass == .compact {
                    compactProgressHeader(
                        booksPercent: booksPercent,
                        chaptersPercent: bibleCompletionPercent,
                        versesPercent: versesPercent
                    )
                } else {
                    // Regular width (iPad): keep the existing header with inline counts and three labeled rings
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bible Reading Progress")
                                .font(.headline)
                            HStack(spacing: 8) {
                                Text("\(formatInt(booksCompleted))/\(formatInt(totalBooks)) books")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text("• \(formatInt(visitedCount))/\(formatInt(totalChapters)) chapters")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text("• \(formatInt(completedVerses))/\(formatInt(totalVerses)) verses")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        Spacer()
                        // Reordered and labeled rings: Books • Chapters • Verses
                        HStack(spacing: 12) {
                            VStack(spacing: 4) {
                                Text("Books")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                ProgressRing(
                                    progress: Double(booksPercent) / 100.0,
                                    lineWidth: 7,
                                    size: 40,
                                    tint: .green,
                                    track: Color.primary.opacity(0.12),
                                    label: {
                                        Text("\(booksPercent)%")
                                            .font(.caption2.weight(.semibold))
                                            .monospacedDigit()
                                    }
                                )
                                .accessibilityLabel(Text("Books \(booksPercent) percent complete"))
                            }
                            VStack(spacing: 4) {
                                Text("Chapters")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                ProgressRing(
                                    progress: Double(bibleCompletionPercent) / 100.0,
                                    lineWidth: 7,
                                    size: 40,
                                    tint: .blue,
                                    track: Color.primary.opacity(0.12),
                                    label: {
                                        Text("\(bibleCompletionPercent)%")
                                            .font(.caption2.weight(.semibold))
                                            .monospacedDigit()
                                    }
                                )
                                .accessibilityLabel(Text("Chapters \(bibleCompletionPercent) percent complete"))
                            }
                            VStack(spacing: 4) {
                                Text("Verses")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                ProgressRing(
                                    progress: Double(versesPercent) / 100.0,
                                    lineWidth: 7,
                                    size: 40,
                                    tint: .accentColor,
                                    track: Color.primary.opacity(0.12),
                                    label: {
                                        Text("\(versesPercent)%")
                                            .font(.caption2.weight(.semibold))
                                            .monospacedDigit()
                                    }
                                )
                                .accessibilityLabel(Text("Verses \(versesPercent) percent complete"))
                            }
                        }
                    }
                }

                // Navigation actions: Continue Reading, Next Unread
                HStack(spacing: 10) {
                    Button {
                        if let last = lastReadEntry {
                            openReader(bookName: last.bookName, chapter: last.chapterNumber, verse: 1)
                        }
                    } label: {
                        Label("Continue Reading", systemImage: "arrowtriangle.right.fill")
                            .font(.footnote.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(lastReadEntry == nil)

                Button {
                        if let t = nextUnread {
                            openReader(bookName: t.book, chapter: t.chapter, verse: 1)
                        }
                    } label: {
                        Label("Next Unread", systemImage: "sparkles")
                            .font(.footnote.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .disabled(nextUnread == nil)
                }

                // Expand/collapse
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        toggleBookProgress()
                    }
                } label: {
                    HStack {
                        Text(showBookProgressDetails ? "Hide details" : "Show details")
                            .font(.footnote.weight(.semibold))
                        Spacer()
                        Image(systemName: showBookProgressDetails ? "chevron.up" : "chevron.down")
                            .font(.footnote.weight(.semibold))
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if showBookProgressDetails {
                    // Filter + Search
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Filter", selection: $bookFilter) {
                            ForEach(BookFilter.allCases) { f in
                                Text(f.rawValue).tag(f)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search books", text: $bookSearch)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(true)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }

                    // Book tiles grid
                    LazyVGrid(columns: bookGridColumns, spacing: 10) {
                        ForEach(filteredBookNames, id: \.self) { name in
                            let prog = bookProgress[name] ?? (0, 1, 0.0)
                            Button {
                                selectedBookForChapters = name
                            } label: {
                                HStack(spacing: 10) {
                                    ProgressRing(
                                        progress: prog.fraction,
                                        lineWidth: 6,
                                        size: 34,
                                        tint: .accentColor,
                                        track: Color.primary.opacity(0.12),
                                        label: {
                                            Text("\(Int(round(prog.fraction * 100)))%")
                                                .font(.caption2.weight(.semibold))
                                                .monospacedDigit()
                                        }
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(name)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                        Text("\(formatInt(prog.read))/\(formatInt(prog.total)) chapters")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(name) \(prog.read) of \(prog.total) chapters")
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var genreSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Genre Distribution — \(timeScope.rawValue)")
                        .font(.headline)
                    Spacer()
                }

                // Scope picker for this card (shares the same timeScope state)
                Picker("Scope", selection: $timeScope) {
                    ForEach(TimeScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                let maxVal = max(1, perGenreTotals.map { $0.seconds }.max() ?? 1)
                VStack(spacing: 8) {
                    ForEach(perGenreTotals, id: \.genre) { item in
                        Button {
                            if let g = Genre(rawValue: item.genre) {
                                selectedGenre = g
                                // rows should reflect the same scoped timeframe
                                genreDetailRows = rowsForGenre(g, totals: scopedPerBookTotals)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(item.genre)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 110, alignment: .leading)
                                GeometryReader { geo in
                                    let frac = CGFloat(item.seconds) / CGFloat(maxVal)
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(genreColor(item.genre).opacity(0.7))
                                        .frame(width: geo.size.width * frac, height: 10, alignment: .leading)
                                }
                                .frame(height: 10)
                                Text(BibleStatsStore.shared.format(item.seconds))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 60, alignment: .trailing)
                            }
                            .frame(height: 16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.genre) \(BibleStatsStore.shared.format(item.seconds))")
                    }
                }
            }
        }
    }

    private var totalsSection: some View {
        ZStack {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        // Make the scope explicit in the title for clarity
                        Text("Total Bible Reading Time — \(timeScope.rawValue)")
                            .font(.headline)
                        Spacer()
                        Text(BibleStatsStore.shared.format(scopedTotalSeconds))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .accessibilityHidden(true)
                            .overlay(
                                Color.clear
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Total \(BibleStatsStore.shared.format(scopedTotalSeconds))")
                            )
                    }

                    // Scope picker (always visible; does not expand/collapse the card)
                    Picker("Scope", selection: $timeScope) {
                        ForEach(TimeScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Quick insights — clean, uniform chips
                    LazyVGrid(columns: chipGridColumns, spacing: 8) {
                        metricChip(title: activeBucketLabel, value: "\(formatInt(activeBucketCount))")
                        metricChip(title: avgPerActiveBucketLabel, value: BibleStatsStore.shared.format(avgSecondsPerActiveBucketInScope))
                        metricChip(title: "Top book", value: topBookInScope)
                    }

                    // Daily/Weekly/Monthly/Yearly chart for the selected scope
                    if !totalsDaily.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(totalsChartSubtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Chart {
                                ForEach(totalsDaily, id: \.date) { item in
                                    let minutes = Int(round(Double(item.seconds) / 60.0))
                                    BarMark(
                                        x: .value("Date", item.date, unit: currentBarUnit),
                                        y: .value("Minutes", minutes)
                                    )
                                    // Make the "This Month" daily bars feel smaller/less cramped
                                    .foregroundStyle(
                                        (timeScope == .thisMonth ? Color.accentColor.opacity(0.75) : Color.accentColor.opacity(0.85))
                                    )
                                    .cornerRadius(3)
                                    // Show value above each bar when daily bars are displayed.
                                    .annotation(position: .top, alignment: .center) {
                                        if minutes > 0, shouldShowBarValueLabels {
                                            Text("\(minutes)")
                                                .font(timeScope == .thisMonth ? .system(size: 7, weight: .semibold) : .caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                    }
                                }
                            }
                            .chartYAxisLabel("Minutes")
                            .chartXAxis { chartXAxisMarks }
                            // Add subtle horizontal padding to give daily bars in "This Month" some breathing room
                            .chartPlotStyle { area in
                                area
                                    .padding(.horizontal, timeScope == .thisMonth ? 6 : 0)
                            }
                            .frame(height: 160)
                        }
                    } else {
                        ContentUnavailableView("No data in this period", systemImage: "chart.bar.xaxis")
                    }

                    // Make only this row the tap target to expand/collapse
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            toggleTotals()
                        }
                    } label: {
                        HStack {
                            Text(showTotalsSection ? "Hide details" : "Show details")
                                .font(.footnote.weight(.semibold))
                            Spacer()
                            Image(systemName: showTotalsSection ? "chevron.up" : "chevron.down")
                                .font(.footnote.weight(.semibold))
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    if showTotalsSection {
                        Picker("Sort", selection: $sortMode) {
                            ForEach(SortMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        ForEach(scopedRows, id: \.book) { entry in
                            HStack {
                                Text(entry.book)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(BibleStatsStore.shared.format(entry.seconds))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(entry.book) \(BibleStatsStore.shared.format(entry.seconds))")
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    // Whether to show numeric labels above bars for the current scope/aggregation.
    private var shouldShowBarValueLabels: Bool {
        switch timeScope {
        case .thisMonth:
            // Daily bars in month view — show labels
            return true
        case .last7:
            // Also show labels for last 7 days (small, readable)
            return true
        case .allTime:
            // For all-time, labels can get crowded depending on aggregation.
            // We’ll hide them to keep the chart clean.
            return false
        }
    }

    // Responsive grid for chips: 2 columns on compact (iPhone), 3 on regular (iPad)
    private var chipGridColumns: [GridItem] {
        if hSizeClass == .compact {
            return [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        } else {
            return [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        }
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - One-open-only toggles

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

    // MARK: - Data refresh

    private func refreshAll() {
        refreshTotals()
        refreshChartsAndMonth()
        refreshSessionScopedPerBook() // build session-derived per-book maps
        // Ensure OT/NT and Genre match the current scope after datasets are refreshed
        recomputeOTNTFromScope()
        recomputeGenresFromScope()
        // Recompute dynamic totals card metrics
        recomputeTotalsCardMetrics()
        // Smart insights last
        computeInsights()
    }

    private func refreshTotals() {
        // Use sessions (local time) for Today and This Week, to match charts
        let cal = Calendar.current

        // Today: sum durations for sessions that ended today (local)
        do {
            let sessions7 = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: Date(), calendar: cal)
            let todayKey = BibleStatsStore.isoDateString(Date(), calendar: cal)
            todaySeconds = sessions7.reduce(0) { acc, s in
                let key = BibleStatsStore.isoDateString(s.end, calendar: cal)
                let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
                return acc + (key == todayKey ? dur : 0)
            }
        }

        // This week: last 7 days total from sessions (local)
        do {
            let sessions7 = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: Date(), calendar: cal)
            thisWeekSeconds = sessions7.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        }

        // Last week: the 7-day window ending 7 days ago (days -8...-14 from today), via sessions (local)
        do {
            // Compute cutoff windows with local start-of-day boundaries
            let startOfToday = cal.startOfDay(for: Date())
            guard
                let thisWeekStart = cal.date(byAdding: .day, value: -6, to: startOfToday),
                let lastWeekEnd = cal.date(byAdding: .day, value: -7, to: startOfToday),
                let lastWeekStart = cal.date(byAdding: .day, value: -13, to: startOfToday)
            else {
                lastWeekSeconds = 0
                return
            }

            // Fetch enough sessions to cover last 14 days
            let sessions14 = ReadingSessionsStore.shared.sessions(inLastDays: 14, now: Date(), calendar: cal)
            // Sum sessions whose end falls within last week's window [lastWeekStart, lastWeekEnd)
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
        computeVerseTotalsAndCompleted() // NEW

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

        // Last 7 days daily bars — aggregated from sessions per local day
        do {
            let sessions = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: Date(), calendar: cal)
            var buckets: [String: Int] = [:] // ISO yyyy-MM-dd -> seconds
            for s in sessions {
                let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
                let key = BibleStatsStore.isoDateString(s.end, calendar: cal)
                buckets[key, default: 0] += dur
            }
            // Build a contiguous last-7-days sequence (oldest -> newest)
            let days: [(Date, Int)] = (0..<7).compactMap { i -> (Date, Int)? in
                guard let d = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
                let key = BibleStatsStore.isoDateString(d, calendar: cal)
                return (d, buckets[key, default: 0])
            }.sorted { $0.0 < $1.0 }
            last7Daily = days
        }

        // Sessions: last 20 overall (within retention), excluding very short sessions (< minSessionSeconds)
        let sessionsAll = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: Date(), calendar: cal)
            .filter { Int(max(0, $0.end.timeIntervalSince($0.start))) >= minSessionSeconds }
            .sorted { $0.end < $1.end }
        let lastTwenty = Array(sessionsAll.suffix(20))
        // Average over sessions that occurred in the last 7 days, excluding < minSessionSeconds
        let sessionsIn7Days = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: Date(), calendar: cal)
            .filter { Int(max(0, $0.end.timeIntervalSince($0.start))) >= minSessionSeconds }
        avgSessionSecondsLast7 = averageSessionLength(sessions: sessionsIn7Days)
        // Keep the chart as last 20 sessions overall (filtered)
        sessionsLast7 = lastTwenty.enumerated().map { (idx, s) in
            let durSec = Int(max(0, s.end.timeIntervalSince(s.start)))
            let minutes = Int(round(Double(durSec) / 60.0))
            return (index: idx + 1, minutes: minutes)
        }

        // Consistency (last 30 days) — reuse dailySeries helper
        last30Daily = dailySeries(lastNDays: 30, now: Date(), calendar: cal)

        // This Month section:
        // monthChaptersCompleted stays from chapter completion dates (not session-derived).
        let now = Date()
        let comps = BibleStatsStore.shared.chapterCompletions(inMonth: now)
        monthChaptersCompleted = comps.count

        // monthTotalSeconds is computed from perBookMonthTotals in refreshSessionScopedPerBook(),
        // ensuring it matches the OT/NT, Genre, and Totals sections.
        // monthTop3Books is also set in refreshSessionScopedPerBook().
    }

    // Build session-derived per-book maps for last7, thisMonth, and all-time (within retention).
    private func refreshSessionScopedPerBook() {
        let cal = Calendar.current
        let now = Date()

        // Last 7 days
        let last7Sessions = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: now, calendar: cal)
        perBookLast7Totals = groupSessionsByBook(last7Sessions)

        // This month
        let monthSessions = ReadingSessionsStore.shared.sessions(inMonthContaining: now, calendar: cal)
        perBookMonthTotals = groupSessionsByBook(monthSessions)
        // Compute month total from the same per-book map used by other sections
        monthTotalSeconds = perBookMonthTotals.values.reduce(0, +)

        // All time (within retention window of ReadingSessionsStore; now 5 years)
        let allSessions = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: now, calendar: cal)
        perBookAllTimeSessionTotals = groupSessionsByBook(allSessions)
        totalSecondsAllTime = allSessions.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }

        // Last month seconds (for delta)
        if let prevMonth = cal.date(byAdding: .month, value: -1, to: now) {
            let lastMonthSessions = ReadingSessionsStore.shared.sessions(inMonthContaining: prevMonth, calendar: cal)
            lastMonthSeconds = lastMonthSessions.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        } else {
            lastMonthSeconds = 0
        }

        // Update Top 3 books for month from the session-derived map
        let sortedTop = perBookMonthTotals.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        monthTop3Books = Array(sortedTop.prefix(3)).map { (book: $0.key, seconds: $0.value) }
    }

    private func averageSessionLength(sessions: [ReadingSessionsStore.Session]) -> Int {
        // Ignore very short sessions (< minSessionSeconds)
        let filtered = sessions.filter { Int(max(0, $0.end.timeIntervalSince($0.start))) >= minSessionSeconds }
        guard !filtered.isEmpty else { return 0 }
        let total = filtered.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        return total / filtered.count
    }

    // Group sessions by book name and sum durations
    private func groupSessionsByBook(_ sessions: [ReadingSessionsStore.Session]) -> [String: Int] {
        var map: [String: Int] = [:]
        for s in sessions {
            let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
            guard dur > 0 else { continue }
            // Ignore empty/whitespace-only book names so per-book maps align with UI
            let name = s.book.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            map[name, default: 0] += dur
        }
        return map
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

    // NEW: Compute total verses and completed verses
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
        case .allTime:
            // Sessions-only for All Time (no fallback)
            return perBookAllTimeSessionTotals
        case .thisMonth:
            return perBookMonthTotals
        case .last7:
            return perBookLast7Totals
        }
    }

    private var scopedTotalSeconds: Int {
        // Sum from the same per-book map used elsewhere so all cards align
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

    // Compute genre totals from the currently scoped per-book map
    private var scopedPerGenreTotalsComputed: [(genre: String, seconds: Int)] {
        computeGenreTotals(from: scopedPerBookTotals)
    }

    // MARK: - Helpers

    private var weekDeltaOnlyValue: String {
        let delta = thisWeekSeconds - lastWeekSeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        let absVal = abs(delta)
        return "\(sign)\(BibleStatsStore.shared.format(absVal))"
    }

    // Sessions-only computation for “today vs yesterday”, using local day boundaries to match charts and todaySeconds.
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

    // New: Month delta vs last month, sessions-only
    private var monthDeltaOnlyValue: String {
        let delta = monthTotalSeconds - lastMonthSeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        let absVal = abs(delta)
        return "\(sign)\(BibleStatsStore.shared.format(absVal))"
    }

    // Sum all sessions whose end falls within [start, end] inclusive window (local day)
    private func totalSecondsForDay(from start: Date, to end: Date, calendar: Calendar) -> Int {
        // Fetch enough sessions to cover the two-day span (yesterday + today) to be safe
        let sessions = ReadingSessionsStore.shared.sessions(inLastDays: 2, now: end, calendar: calendar)
        return sessions.reduce(0) { acc, s in
            if s.end >= start && s.end <= end {
                return acc + Int(max(0, s.end.timeIntervalSince(s.start)))
            } else {
                return acc
            }
        }
    }

    // Navigation helper: open reader via app-wide notification
    private func openReader(bookName: String, chapter: Int, verse: Int = 1) {
        NotificationCenter.default.post(name: .openBibleReference, object: nil, userInfo: [
            "book": bookName,
            "chapter": chapter,
            "verse": verse
        ])
    }

    // Find first unread chapter globally (canonical order)
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

    // Find first unread chapter in a given book
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
        switch book {
        case "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy":
            return .Law
        case "Joshua", "Judges", "Ruth",
             "1 Samuel", "2 Samuel",
             "1 Kings", "2 Kings",
             "1 Chronicles", "2 Chronicles",
             "Ezra", "Nehemiah", "Esther":
            return .History
        case "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon":
            return .Poetry
        case "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel":
            return .MajorProphets
        case "Hosea", "Joel", "Amos", "Obadiah", "Jonah",
             "Micah", "Nahum", "Habakkuk", "Zephaniah",
             "Haggai", "Zechariah", "Malachi":
            return .MinorProphets
        case "Matthew", "Mark", "Luke", "John":
            return .Gospels
        case "Acts":
            return .Acts
        case "Romans",
             "1 Corinthians", "2 Corinthians",
             "Galatians", "Ephesians", "Philippians", "Colossians",
             "1 Thessalonians", "2 Thessalonians",
             "1 Timothy", "2 Timothy",
             "Titus", "Philemon",
             "Hebrews", "James",
             "1 Peter", "2 Peter",
             "1 John", "2 John", "3 John",
             "Jude":
            return .Epistles
        case "Revelation":
            return .Apocalypse
        default:
            return .History
        }
    }

    private func computeGenreTotals(from perBook: [String: Int]) -> [(genre: String, seconds: Int)] {
        var buckets: [Genre: Int] = [:]
        for (book, seconds) in perBook {
            let g = genreForBook(book)
            buckets[g, default: 0] += max(0, seconds)
        }
        let order: [Genre] = [.Law, .History, .Poetry, .MajorProphets, .MinorProphets, .Gospels, .Acts, .Epistles, .Apocalypse]
        return order.map { g in (genre: g.rawValue, seconds: buckets[g, default: 0]) }
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
        // Update open detail rows if a genre is selected
        if let g = selectedGenre {
            genreDetailRows = rowsForGenre(g, totals: scopedPerBookTotals)
        }
    }

    // MARK: - Compact header helpers

    @ViewBuilder
    private func compactProgressHeader(booksPercent: Int, chaptersPercent: Int, versesPercent: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bible Reading Progress")
                .font(.headline)

            VStack(spacing: 8) {
                metricRow(
                    title: "Books",
                    countText: "\(formatInt(booksCompleted))/\(formatInt(totalBooks))",
                    percent: booksPercent,
                    tint: .green
                )
                metricRow(
                    title: "Chapters",
                    countText: "\(formatInt(visitedCount))/\(formatInt(totalChapters))",
                    percent: chaptersPercent,
                    tint: .blue
                )
                metricRow(
                    title: "Verses",
                    countText: "\(formatInt(completedVerses))/\(formatInt(totalVerses))",
                    percent: versesPercent,
                    tint: .accentColor
                )
            }
        }
    }

    private func metricRow(title: String, countText: String, percent: Int, tint: Color) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(countText)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            ProgressRing(
                progress: Double(percent) / 100.0,
                lineWidth: 7,
                size: 36,
                tint: tint,
                track: Color.primary.opacity(0.12),
                label: {
                    Text("\(percent)%")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                }
            )
            .accessibilityLabel(Text("\(title) \(percent) percent complete"))
        }
        .padding(.vertical, 2)
    }

    // MARK: - Totals card metrics

    private var totalsChartSubtitle: String {
        switch timeScope {
        case .last7:
            return "Daily minutes — Last 7 days"
        case .thisMonth:
            // Bars are daily; ticks are weekly for readability.
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

    // Compute the current aggregation for the X axis outside the result builder
    private var currentXAxisAggregation: Aggregation {
        if timeScope == .allTime {
            return allTimeAggregation
        } else if timeScope == .thisMonth {
            return .weekly
        } else {
            return .daily
        }
    }

    // The unit used to bucket bars (explicit so bars look right)
    private var currentBarUnit: Calendar.Component {
        switch timeScope {
        case .last7:
            return .day
        case .thisMonth:
            // Bars are daily, ticks are weekly
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

    // Axis marks adapted to current aggregation
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
        // Build daily/weekly/monthly/yearly series and quick insights based on the selected scope using sessions (local day boundaries)
        let cal = Calendar.current
        let now = Date()

        switch timeScope {
        case .last7:
            totalsDaily = dailySeries(lastNDays: 7, now: now, calendar: cal)
            allTimeAggregation = .daily
        case .thisMonth:
            totalsDaily = dailySeriesForMonth(containing: now, calendar: cal)
            allTimeAggregation = .weekly // axis ticks will show weekly marks
        case .allTime:
            let r = allTimeAggregatedSeries(calendar: cal)
            totalsDaily = r.series
            allTimeAggregation = r.aggregation
        }

        // Quick insights
        activeDaysInScope = totalsDaily.reduce(0) { $0 + ($1.seconds > 0 ? 1 : 0) }
        let totalInSeries = totalsDaily.reduce(0) { $0 + $1.seconds }
        avgSecondsPerActiveBucketInScope = activeDaysInScope > 0 ? totalInSeries / activeDaysInScope : 0

        // Top book (from the same scoped totals map used elsewhere)
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
        guard lastNDays > 0 else { return [] }
        let sessions = ReadingSessionsStore.shared.sessions(inLastDays: lastNDays, now: now, calendar: calendar)
        var buckets: [String: Int] = [:] // yyyy-MM-dd -> seconds
        for s in sessions {
            let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
            let key = BibleStatsStore.isoDateString(s.end, calendar: calendar)
            buckets[key, default: 0] += dur
        }
        // Build contiguous sequence (oldest -> newest)
        let series: [(Date, Int)] = (0..<lastNDays).compactMap { i -> (Date, Int)? in
            guard let d = calendar.date(byAdding: .day, value: -(lastNDays - 1 - i), to: calendar.startOfDay(for: now)) else { return nil }
            let key = BibleStatsStore.isoDateString(d, calendar: calendar)
            return (d, buckets[key, default: 0])
        }
        return series
    }

    private func dailySeriesForMonth(containing date: Date, calendar: Calendar) -> [(date: Date, seconds: Int)] {
        // Use a strictly local, autoupdating calendar for both session bucketing and day iteration
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent

        // Fetch sessions for the month using the same calendar semantics
        let sessions = ReadingSessionsStore.shared.sessions(inMonthContaining: date, calendar: cal)

        // Bucket sessions by local-day ISO key
        var buckets: [String: Int] = [:]
        for s in sessions {
            let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
            let key = BibleStatsStore.isoDateString(s.end, calendar: cal)
            buckets[key, default: 0] += dur
        }

        // Compute local start of month and start of next month
        let comps = cal.dateComponents([.year, .month], from: date)
        guard
            let startOfMonth = cal.date(from: comps),
            let startOfNextMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth)
        else {
            return []
        }

        // Build contiguous daily series from startOfMonth to (but not including) startOfNextMonth
        var series: [(Date, Int)] = []
        var cursor = startOfMonth
        while cursor < startOfNextMonth {
            let key = BibleStatsStore.isoDateString(cursor, calendar: cal)
            let seconds = buckets[key, default: 0]
            series.append((cursor, seconds))
            // Step exactly one local day
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return series
    }

    private func allTimeAggregatedSeries(calendar: Calendar) -> (series: [(date: Date, seconds: Int)], aggregation: Aggregation) {
        // Use a long window that matches other “all time” computations in this view
        let sessions = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: Date(), calendar: calendar)
        guard !sessions.isEmpty else { return ([], .daily) }

        let ends = sessions.map { $0.end }
        let now = Date()
        let start = calendar.startOfDay(for: ends.min() ?? now)
        let end = calendar.startOfDay(for: now)

        // Choose aggregation based on number of months spanned
        let monthsSpan = calendar.dateComponents([.month], from: start, to: end).month ?? 0

        // Prefer monthly buckets up to a year of data, otherwise yearly
        let aggregation: Aggregation = (monthsSpan <= 12) ? .monthly : .yearly

        // Helper to find the bucket start date for a given date
        func bucketStart(for date: Date) -> Date {
            switch aggregation {
            case .monthly:
                let comps = calendar.dateComponents([.year, .month], from: date)
                return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
            case .yearly:
                let comps = calendar.dateComponents([.year], from: date)
                return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
            default:
                // Not used for all-time
                return calendar.startOfDay(for: date)
            }
        }

        // Sum sessions into buckets
        var buckets: [Date: Int] = [:]
        for s in sessions {
            let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
            let key = bucketStart(for: s.end)
            buckets[key, default: 0] += dur
        }

        // Build a contiguous series from start to end at the chosen aggregation
        var series: [(Date, Int)] = []
        var cursor: Date = {
            switch aggregation {
            case .monthly:
                let comps = calendar.dateComponents([.year, .month], from: start)
                return calendar.date(from: comps) ?? start
            case .yearly:
                let comps = calendar.dateComponents([.year], from: start)
                return calendar.date(from: comps) ?? start
            default:
                return start
            }
        }()

        func step(_ date: Date) -> Date {
            switch aggregation {
            case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
            case .yearly: return calendar.date(byAdding: .year, value: 1, to: date) ?? date
            default: return date
            }
        }

        while cursor <= end {
            let val = buckets[cursor, default: 0]
            series.append((cursor, val))
            cursor = step(cursor)
        }

        // Cap monthly series to last 6 or 12 months to keep axis readable
        if aggregation == .monthly {
            let maxMonths = (monthsSpan <= 6) ? 6 : 12
            if series.count > maxMonths {
                series = Array(series.suffix(maxMonths))
            }
        }

        // Cap yearly series to last 10 years to avoid overly thin bars
        if aggregation == .yearly {
            let maxYears = 10
            if series.count > maxYears {
                series = Array(series.suffix(maxYears))
            }
        }

        return (series, aggregation)
    }

    // MARK: - Smart insights computation

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
                // Format date like "Mar 12"
                let df = DateFormatter()
                df.calendar = cal
                df.timeZone = cal.timeZone
                df.setLocalizedDateFormatFromTemplate("MMM d")
                let date = df.date(from: bestKey) ?? cal.startOfDay(for: now) // bestKey is yyyy-MM-dd; parsing with df might fail
                // Parse yyyy-MM-dd reliably
                let isoParser = DateFormatter()
                isoParser.calendar = cal
                isoParser.timeZone = cal.timeZone
                isoParser.dateFormat = "yyyy-MM-dd"
                let bestDate = isoParser.date(from: bestKey) ?? date
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
            // Compute yesterday's streak by evaluating with a shifted "today"
            let yesterday: Int = {
                var count = 0
                var day = cal.date(byAdding: .day, value: -1, to: now) ?? now
                // If yesterday not met, allow streak to end the day before yesterday
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

        // 7‑day average up/down vs last month (use previous calendar month's daily average)
        do {
            let last7 = dailySeries(lastNDays: 7, now: now, calendar: cal)
            let avg7 = last7.isEmpty ? 0 : last7.reduce(0) { $0 + $1.seconds } / last7.count

            // Previous month average per day
            if let prevMonth = cal.date(byAdding: .month, value: -1, to: now) {
                let prevMonthSeries = dailySeriesForMonth(containing: prevMonth, calendar: cal)
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
                    insightLongestSessionText = "Longest session in 30 days: \(BibleStatsStore.shared.format(dur)) (\(when))"
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
}

// MARK: - Small Progress Ring

private struct ProgressRing<Label: View>: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let tint: Color
    let track: Color
    let label: Label

    init(progress: Double, lineWidth: CGFloat = 8, size: CGFloat = 56, tint: Color = .accentColor, track: Color = Color.primary.opacity(0.12), @ViewBuilder label: () -> Label) {
        self.progress = max(0, min(1, progress))
        self.lineWidth = lineWidth
        self.size = size
               self.tint = tint
        self.track = track
        self.label = label()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Completion \(Int(round(progress * 100))) percent"))
    }
}

// MARK: - Chapter detail support

private struct ChapterDetailKey: Identifiable, Hashable {
    let bookName: String
    var id: String { bookName }
}

private struct BookChaptersDetailView: View {
    let bookName: String

    @State private var visited: Set<String> = []
    @State private var selectedChapter: Int? = nil
    @State private var refreshID: UUID = UUID()

    private var book: Book? {
        BibleData.books.first(where: { $0.name == bookName })
    }
    private var chapterNumbers: [Int] {
        guard let b = book else { return [] }
        return b.chapters.map { $0.number }.sorted()
    }

    var body: some View {
        Group {
            if let b = book, !chapterNumbers.isEmpty {
                List {
                    Section {
                        ForEach(chapterNumbers, id: \.self) { chap in
                            let totalVerses = b.chapters.first(where: { $0.number == chap })?.verses.count ?? 0
                            let isRead = totalVerses > 0 && BibleStatsStore.shared.isChapterComplete(bookName: b.name, chapter: chap, totalVerses: totalVerses)

                            NavigationLink(destination: VersesChecklistView(bookName: b.name, chapterNumber: chap)) {
                                HStack(spacing: 8) {
                                    Image(systemName: isRead ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isRead ? .green : .secondary)
                                    Text("Chapter \(chap)")
                                        .strikethrough(isRead, color: .secondary)
                                        .foregroundStyle(isRead ? .secondary : .primary)
                                    Spacer()
                                    Button("Unread") {
                                        clearChapter(bookName: b.name, chapterNumber: chap)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                    .tint(.red)
                                    .disabled(!isRead)
                                    .accessibilityLabel("Mark Chapter \(chap) Unread")
                                }
                            }
                            .accessibilityLabel("Chapter \(chap) \(isRead ? "read" : "unread")")
                        }
                    } header: {
                        Text(b.name)
                    } footer: {
                        let readCount = chapterNumbers.reduce(0) { acc, chap in
                            let total = b.chapters.first(where: { $0.number == chap })?.verses.count ?? 0
                            let complete = total > 0 && BibleStatsStore.shared.isChapterComplete(bookName: b.name, chapter: chap, totalVerses: total)
                            return acc + (complete ? 1 : 0)
                        }
                        Text("\(readCount.formatted(.number.grouping(.automatic)))/\(chapterNumbers.count.formatted(.number.grouping(.automatic))) chapters read")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .id(refreshID)
            } else if book != nil {
                ContentUnavailableView("No chapters found", systemImage: "exclamationmark.triangle")
            } else {
                ContentUnavailableView("Book not found", systemImage: "exclamationmark.triangle")
            }
        }
        .onAppear {
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBibleReference)) { _ in
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
        .onReceive(NotificationCenter.default.publisher(for: .chapterProgressChanged)) { _ in
            refreshID = UUID()
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
    }

    private func clearChapter(bookName: String, chapterNumber: Int) {
        BibleStatsStore.shared.saveSeenVerses([], bookName: bookName, chapter: chapterNumber)
        var v = BibleStatsStore.shared.loadVisitedChapters()
        v.remove("\(bookName):\(chapterNumber)")
        BibleStatsStore.shared.saveVisitedChapters(v)
        refreshID = UUID()
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
    }
}

// MARK: - Smart Insights chip view

private struct InsightChipModel: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

// New, glanceable tile presentation for insights
private struct InsightTile: View {
    let model: InsightChipModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Leading color bar + icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(model.tint.opacity(0.12))
                Image(systemName: model.icon)
                    .foregroundStyle(model.tint)
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.subheadline.weight(.semibold))
                Text(model.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(model.tint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.title). \(model.detail)")
    }
}

// Retained but no longer used; can be removed if desired.
// private struct InsightChip: View { ... } // removed usage above

