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

    @State private var sortMode: SortMode = .canonical
    @State private var timeScope: TimeScope = .allTime

    // Core stats
    @State private var perBookTotals: [String: Int] = [:]
    @State private var totalSeconds: Int = 0

    // Derived
    @State private var todaySeconds: Int = 0
    @State private var thisWeekSeconds: Int = 0
    @State private var lastWeekSeconds: Int = 0
    @State private var lastReadBookChapter: String = "—"
    @State private var lastReadTimeText: String = "—"

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

    // Keep these for other cards that still use them
    @State private var weekdayTotals: [(weekday: Int, seconds: Int)] = []
    @State private var hourBuckets: [(hour: Int, seconds: Int)] = []
    @State private var avgSessionSeconds: Int = 0

    // New: This Month metrics
    @State private var monthTotalSeconds: Int = 0
    @State private var monthChaptersCompleted: Int = 0
    @State private var monthTop3Books: [(book: String, seconds: Int)] = []
    @State private var perBookMonthTotals: [String: Int] = [:]
    @State private var perBookLast7Totals: [String: Int] = [:]

    // Expand/collapse for existing sections
    @State private var showBookProgressDetails: Bool = false
    @State private var showGenreSection: Bool = false
    @State private var showTotalsSection: Bool = false

    // Daily goal minutes (for goal progress glance pill)
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30

    // Ensure all glance boxes visually match height
    private let glanceCardMinHeight: CGFloat = 86

    private var orderedAllBooks: [String] {
        if !BibleData.books.isEmpty {
            return BibleData.books.map { $0.name }
        }
        return BibleCanon.canonicalOrder()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                glanceRow

                // This Month section
                thisMonthCard

                // Average Session Length (last 20 sessions)
                averageSessionCard

                // Existing: OT vs NT
                otNtCard

                // Move Genre Distribution directly under OT vs NT
                genreSection

                // Existing: Book Reading Progress
                bookReadingProgressCard

                // Existing: Total Bible Reading Time + Per-book table (collapsible)
                totalsSection

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
                    let totals = BibleStatsStore.shared.loadTotals()
                    genreDetailRows = rowsForGenre(genre, totals: totals)
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
                    pill("Chapters completed", value: "\(monthChaptersCompleted)")
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

    // MARK: - Cards (existing ones kept)

    private var glanceRow: some View {
        HStack(spacing: 12) {
            statMiniCard(title: "Today", value: BibleStatsStore.shared.format(todaySeconds), subtitle: todayDeltaOnlyValue, tint: .blue)
            statMiniCard(title: "This Week", value: BibleStatsStore.shared.format(thisWeekSeconds), subtitle: weekDeltaOnlyValue, tint: .green)
            lastReadMiniCard
            // New: Goal progress glance pill (today)
            statMiniCard(title: "Daily Reading Goal", value: "\(goalPercentToday)%", subtitle: goalSubtitleToday, tint: .orange)
        }
    }

    private func statMiniCard(title: String, value: String, subtitle: String? = nil, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            if let subtitle, !subtitle.isEmpty, subtitle != "—" {
                let prefix = (title == "This Week") ? "vs last week: " : (title == "Today" ? "vs yesterday: " : "")
                if !prefix.isEmpty {
                    Text("\(prefix)\(subtitle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                } else {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: glanceCardMinHeight) // ensure consistent height
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private var lastReadMiniCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last Read")
                .font(.caption).foregroundStyle(.secondary)
            Text(lastReadBookChapter)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(lastReadTimeText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: glanceCardMinHeight) // ensure consistent height
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    private var otNtCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("OT vs NT")
                    .font(.headline)
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
        // Compute books completion percent for collapsed view and ring
        let booksPercent: Int = {
            let denom = max(1, totalBooks)
            let pct = Int(round((Double(booksCompleted) / Double(denom)) * 100.0))
            return max(0, min(100, pct))
        }()
        // Compute verses completion percent
        let versesPercent: Int = {
            let denom = max(1, totalVerses)
            let pct = Int(round((Double(completedVerses) / Double(denom)) * 100.0))
            return max(0, min(100, pct))
        }()

        return ZStack {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bible Reading Progress")
                                .font(.headline)
                            // Collapsed subtitle lines: Books, Chapters, Verses
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(booksCompleted)/\(totalBooks) books • \(booksPercent)%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text("\(visitedCount)/\(totalChapters) chapters • \(bibleCompletionPercent)%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Text("\(completedVerses)/\(totalVerses) verses • \(versesPercent)%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        Spacer()
                        // Progress ring now shows verses completion percent
                        ProgressRing(
                            progress: Double(versesPercent) / 100.0,
                            lineWidth: 8,
                            size: 30,
                            tint: .accentColor,
                            track: Color.primary.opacity(0.12),
                            label: {
                                Text("\(versesPercent)%")
                                    .font(.caption2.weight(.semibold))
                                    .monospacedDigit()
                            }
                        )
                    }
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
                        VStack(spacing: 8) {
                            ForEach(orderedAllBooks, id: \.self) { name in
                                let prog = bookProgress[name] ?? (0, 1, 0.0)
                                Button {
                                    selectedBookForChapters = name
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(name)
                                            .font(.subheadline)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                    .fill(Color.primary.opacity(0.10))
                                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                                    .fill(Color.accentColor.opacity(0.65))
                                                    .frame(width: geo.size.width * CGFloat(prog.fraction))
                                            }
                                        }
                                        .frame(width: 120, height: 6)
                                        Text("\(prog.read)/\(prog.total)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                            .frame(width: 44, alignment: .trailing)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(name) \(prog.read) of \(prog.total) chapters")
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }

            // Tap anywhere on the card to expand when collapsed
            if !showBookProgressDetails {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            toggleBookProgress()
                        }
                    }
                    .accessibilityHidden(true)
            }
        }
    }

    private var genreSection: some View {
        ZStack {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Genre Distribution")
                            .font(.headline)
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                toggleGenre()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(showGenreSection ? "Hide" : "Show")
                                    .font(.footnote.weight(.semibold))
                                Image(systemName: showGenreSection ? "chevron.up" : "chevron.down")
                                    .font(.footnote.weight(.semibold))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if showGenreSection {
                        let maxVal = max(1, perGenreTotals.map { $0.seconds }.max() ?? 1)
                        VStack(spacing: 8) {
                            ForEach(perGenreTotals, id: \.genre) { item in
                                Button {
                                    if let g = Genre(rawValue: item.genre) {
                                        selectedGenre = g
                                        genreDetailRows = rowsForGenre(g, totals: perBookTotals)
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
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }

            // Tap anywhere on the card to expand when collapsed
            if !showGenreSection {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            toggleGenre()
                        }
                    }
                    .accessibilityHidden(true)
            }
        }
    }

    private var totalsSection: some View {
        ZStack {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Total Bible Reading Time")
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

    // MARK: - One-open-only toggles

    private func toggleBookProgress() {
        if showBookProgressDetails {
            showBookProgressDetails = false
        } else {
            showGenreSection = false
            showTotalsSection = false
            showBookProgressDetails = true
        }
    }

    private func toggleGenre() {
        if showGenreSection {
            showGenreSection = false
        } else {
            showBookProgressDetails = false
            showTotalsSection = false
            showGenreSection = true
        }
    }

    private func toggleTotals() {
        if showTotalsSection {
            showTotalsSection = false
        } else {
            showBookProgressDetails = false
            showGenreSection = false
            showTotalsSection = true
        }
    }

    // MARK: - Data refresh

    private func refreshAll() {
        refreshTotals()
        refreshChartsAndMonth()
    }

    private func refreshTotals() {
        let store = BibleStatsStore.shared
        let totals = store.loadTotals()
        perBookTotals = totals
        totalSeconds = totals.values.reduce(0, +)

        todaySeconds = store.totalForLast(days: 1)
        thisWeekSeconds = store.totalForLast(days: 7)
        lastWeekSeconds = store.totalForLast(days: 14) - thisWeekSeconds

        let split = store.splitOTNT(totals: totals)
        otSeconds = split.ot
        ntSeconds = split.nt

        computeCompletionMetricsVerseComplete()
        computePerBookProgressVerseComplete()
        computeVerseTotalsAndCompleted() // NEW

        if let last = store.loadLastRead() {
            lastReadBookChapter = "\(last.bookName) \(last.chapterNumber)"
            lastReadTimeText = timeOnlyString(last.date)
        } else {
            lastReadBookChapter = "—"
            lastReadTimeText = "—"
        }

        perGenreTotals = computeGenreTotals(from: totals)
        if let g = selectedGenre {
            genreDetailRows = rowsForGenre(g, totals: totals)
        }
    }

    private func refreshChartsAndMonth() {
        let cal = Calendar.current

        // Last 7 days daily bars — now aggregated from sessions per GMT day
        do {
            var gmtCal = cal
            gmtCal.timeZone = .gmt
            let sessions = ReadingSessionsStore.shared.sessions(inLastDays: 7, now: Date(), calendar: gmtCal)
            var buckets: [String: Int] = [:] // ISO yyyy-MM-dd -> seconds
            for s in sessions {
                let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
                let key = BibleStatsStore.isoDateString(s.end, calendar: gmtCal)
                buckets[key, default: 0] += dur
            }
            // Build a contiguous last-7-days sequence (oldest -> newest)
            let days: [(Date, Int)] = (0..<7).compactMap { i -> (Date, Int)? in
                guard let d = gmtCal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
                let key = BibleStatsStore.isoDateString(d, calendar: gmtCal)
                return (d, buckets[key, default: 0])
            }.sorted { $0.0 < $1.0 }
            last7Daily = days
        }

        // Sessions: last 20 overall (within retention window)
        let sessionsAll = ReadingSessionsStore.shared.sessions(inLastDays: 180).sorted { $0.end < $1.end }
        let lastTwenty = Array(sessionsAll.suffix(20))
        // Average over sessions that occurred in the last 7 days
        let sessionsIn7Days = ReadingSessionsStore.shared.sessions(inLastDays: 7)
        avgSessionSecondsLast7 = averageSessionLength(sessions: sessionsIn7Days)
        // Keep the chart as last 20 sessions overall
        sessionsLast7 = lastTwenty.enumerated().map { (idx, s) in
            let durSec = Int(max(0, s.end.timeIntervalSince(s.start)))
            let minutes = Int(round(Double(durSec) / 60.0))
            return (index: idx + 1, minutes: minutes)
        }

        // Keep the broader habits aggregates for other parts if needed (still based on daily totals legacy)
        let dailyDict = BibleStatsStore.shared.loadDailyTotals()
        let last56 = (0..<56).compactMap { i -> (Date, Int)? in
            guard let d = cal.date(byAdding: .day, value: -i, to: Date()) else { return nil }
            let key = BibleStatsStore.isoDateString(d)
            return (d, dailyDict[key, default: 0])
        }
        var weekdayAgg: [Int: Int] = [:] // 1...7
        for (d, s) in last56 {
            let wd = cal.component(.weekday, from: d)
            weekdayAgg[wd, default: 0] += s
        }
        weekdayTotals = (1...7).map { (weekday: $0, seconds: weekdayAgg[$0, default: 0]) }

        let sessions30 = ReadingSessionsStore.shared.sessions(inLastDays: 30)
        avgSessionSeconds = averageSessionLength(sessions: sessions30)
        hourBuckets = bucketsByHour(sessions: sessions30)

        // This Month section
        let now = Date()
        monthTotalSeconds = BibleStatsStore.shared.totalForMonth(containing: now)
        let comps = BibleStatsStore.shared.chapterCompletions(inMonth: now)
        monthChaptersCompleted = comps.count
        let monthByBook = BibleStatsStore.shared.totalsByBookForMonth(containing: now)
        let sortedTop = monthByBook.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        // Map (key,value) -> (book,seconds)
        monthTop3Books = Array(sortedTop.prefix(3)).map { (book: $0.key, seconds: $0.value) }

        // Scoped per-book datasets
        perBookMonthTotals = monthByBook
        perBookLast7Totals = BibleStatsStore.shared.totalsByBookForLast(days: 7)
    }

    private func averageSessionLength(sessions: [ReadingSessionsStore.Session]) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        return total / sessions.count
    }

    private func bucketsByHour(sessions: [ReadingSessionsStore.Session]) -> [(hour: Int, seconds: Int)] {
        var buckets: [Int: Int] = [:] // 0...23
        for s in sessions {
            let h = Calendar.current.component(.hour, from: s.start)
            let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
            buckets[h, default: 0] += dur
        }
        return (0...23).map { (hour: $0, seconds: buckets[$0, default: 0]) }
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
            return perBookTotals
        case .thisMonth:
            return perBookMonthTotals
        case .last7:
            return perBookLast7Totals
        }
    }

    private var scopedTotalSeconds: Int {
        switch timeScope {
        case .allTime:
            return totalSeconds
        case .thisMonth:
            return monthTotalSeconds
        case .last7:
            return thisWeekSeconds
        }
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

    // MARK: - Helpers

    private var weekDeltaOnlyValue: String {
        let delta = thisWeekSeconds - lastWeekSeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        let absVal = abs(delta)
        return "\(sign)\(BibleStatsStore.shared.format(absVal))"
    }

    private var todayDeltaOnlyValue: String {
        let store = BibleStatsStore.shared
        let last2 = store.totalForLast(days: 2)
        let yesterday = max(0, last2 - todaySeconds)
        let delta = todaySeconds - yesterday
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        let absVal = abs(delta)
        return "\(sign)\(BibleStatsStore.shared.format(absVal))"
    }

    // NEW: Goal progress (today) for glance pill
    private var goalPercentToday: Int {
        let goalSeconds = max(1, dailyGoalMinutes) * 60
        if goalSeconds <= 0 { return 0 }
        let pct = Int(round((Double(min(todaySeconds, goalSeconds)) / Double(goalSeconds)) * 100.0))
        return max(0, min(100, pct))
    }

    private var goalSubtitleToday: String {
        let goalSeconds = max(1, dailyGoalMinutes) * 60
        if todaySeconds >= goalSeconds {
            return "Reached"
        } else {
            let remaining = max(0, goalSeconds - todaySeconds)
            let m = remaining / 60
            let s = remaining % 60
            if m > 0 {
                return s > 0 ? "\(m)m \(s)s left" : "\(m)m left"
            } else {
                return "\(s)s left"
            }
        }
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
                        Text("\(readCount)/\(chapterNumbers.count) chapters read")
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

