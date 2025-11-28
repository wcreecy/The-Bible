import SwiftUI
import Combine

struct StatsView: View {
    private enum SortMode: String, CaseIterable, Identifiable {
        case canonical = "Canonical"
        case mostRead = "Most Read"
        var id: String { rawValue }
    }

    @State private var expanded: Bool = false
    @State private var sortMode: SortMode = .canonical

    @State private var perBookTotals: [String: Int] = [:]
    @State private var totalSeconds: Int = 0
    @State private var cancellable: AnyCancellable?

    // New derived stats
    @State private var todaySeconds: Int = 0
    @State private var thisWeekSeconds: Int = 0
    @State private var lastWeekSeconds: Int = 0
    @State private var otSeconds: Int = 0
    @State private var ntSeconds: Int = 0
    @State private var visitedCount: Int = 0

    // Completion metrics
    @State private var booksCompleted: Int = 0
    @State private var totalBooks: Int = 0
    @State private var bibleCompletionPercent: Int = 0
    @State private var totalChapters: Int = 0

    // Per-book progress (chapters read / total)
    @State private var bookProgress: [String: (read: Int, total: Int, fraction: Double)] = [:]

    // Collapsible state for Book Reading Progress
    @State private var progressExpanded: Bool = false

    // Last read details split for better alignment
    @State private var lastReadBookChapter: String = "—"
    @State private var lastReadTimeText: String = "—"

    // Genre distribution (computed from perBookTotals)
    @State private var perGenreTotals: [(genre: String, seconds: Int)] = []

    // Genre detail popup
    @State private var selectedGenre: Genre? = nil
    @State private var genreDetailRows: [(book: String, seconds: Int)] = []

    private var orderedAllBooks: [String] {
        // Prefer BibleData order if available, else fallback canonical order
        if !BibleData.books.isEmpty {
            return BibleData.books.map { $0.name }
        }
        return BibleCanon.canonicalOrder()
    }

    private func refreshTotals() {
        let store = BibleStatsStore.shared
        let totals = store.loadTotals()
        perBookTotals = totals
        totalSeconds = totals.values.reduce(0, +)

        // Daily
        todaySeconds = store.totalForLast(days: 1)
        thisWeekSeconds = store.totalForLast(days: 7)
        lastWeekSeconds = store.totalForLast(days: 14) - thisWeekSeconds

        // OT/NT
        let split = store.splitOTNT(totals: totals)
        otSeconds = split.ot
        ntSeconds = split.nt

        // Visited chapters
        let visited = store.loadVisitedChapters()
        visitedCount = visited.count

        // Completion metrics (chapter-based)
        computeCompletionMetrics(visitedChapters: visited)

        // Per-book progress
        computePerBookProgress(visitedChapters: visited)

        // Last read (split into book+chapter and time)
        if let last = store.loadLastRead() {
            lastReadBookChapter = "\(last.bookName) \(last.chapterNumber)"
            lastReadTimeText = timeOnlyString(last.date)
        } else {
            lastReadBookChapter = "—"
            lastReadTimeText = "—"
        }

        // Genres
        perGenreTotals = computeGenreTotals(from: totals)
        // If a sheet is open, refresh its rows too
        if let g = selectedGenre {
            genreDetailRows = rowsForGenre(g, totals: totals)
        }
    }

    // Compute:
    // - totalBooks
    // - totalChapters (across all books)
    // - booksCompleted = count of books where all chapters are in visitedChapters
    // - bibleCompletionPercent = round(visitedChapters / totalChapters * 100)
    private func computeCompletionMetrics(visitedChapters: Set<String>) {
        let books = BibleData.books
        totalBooks = books.count
        totalChapters = books.reduce(0) { $0 + $1.chapters.count }

        var completed = 0
        for book in books {
            let allChaptersVisited = book.chapters.allSatisfy { chap in
                visitedChapters.contains("\(book.name):\(chap.number)")
            }
            if allChaptersVisited { completed += 1 }
        }
        booksCompleted = completed

        let denom = max(1, totalChapters)
        let pct = Int(round((Double(visitedCount) / Double(denom)) * 100.0))
        bibleCompletionPercent = pct
    }

    private func computePerBookProgress(visitedChapters: Set<String>) {
        var progress: [String: (read: Int, total: Int, fraction: Double)] = [:]
        let books = BibleData.books
        for book in books {
            let total = max(1, book.chapters.count)
            let read = book.chapters.reduce(0) { acc, chap in
                acc + (visitedChapters.contains("\(book.name):\(chap.number)") ? 1 : 0
                )
            }
            let fraction = Double(read) / Double(total)
            progress[book.name] = (read, total, fraction)
        }
        // Ensure every ordered book has an entry, even if BibleData was empty
        for name in orderedAllBooks {
            if progress[name] == nil {
                progress[name] = (0, 1, 0.0)
            }
        }
        bookProgress = progress
    }

    private func timeOnlyString(_ date: Date) -> String {
        // Show local time in a short style (e.g., “3:41 PM”)
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.dateStyle = .none
        return fmt.string(from: date)
    }

    // Build rows with selected sort
    private var rows: [(book: String, seconds: Int)] {
        let canonical = orderedAllBooks
        let canonicalPos = Dictionary(uniqueKeysWithValues: canonical.enumerated().map { ($1, $0) })

        switch sortMode {
        case .canonical:
            // Keep canonical order; show all 66 with default 0 if missing
            return canonical.map { name in
                (book: name, seconds: perBookTotals[name, default: 0])
            }
        case .mostRead:
            // Sort by seconds desc, with canonical order as tie-breaker; still show all 66
            let all: [(book: String, seconds: Int)] = canonical.map { name in
                (book: name, seconds: perBookTotals[name, default: 0])
            }
            return all.sorted { lhs, rhs in
                if lhs.seconds == rhs.seconds {
                    // Stable by canonical order
                    return (canonicalPos[lhs.book] ?? .max) < (canonicalPos[rhs.book] ?? .max)
                }
                return lhs.seconds > rhs.seconds
            }
        }
    }

    var body: some View {
        List {
            // Quick summary cards
            Section {
                HStack(alignment: .top) {
                    // Today column
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(BibleStatsStore.shared.format(todaySeconds))
                            .font(.title3)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // This Week column
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("vs last week:")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(weekDeltaOnlyValue)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .lineLimit(1)
                        Text(BibleStatsStore.shared.format(thisWeekSeconds))
                            .font(.title3)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Last Read column (book+chapter, then time beneath)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Read")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(lastReadBookChapter)
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(lastReadTimeText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)

                // New: Completion summary row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Books Completed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(booksCompleted) / \(totalBooks)")
                            .font(.title3)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Bible Completion as a progress ring with percent inside
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bible Completion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ProgressRing(
                            progress: Double(bibleCompletionPercent) / 100.0,
                            lineWidth: 8,
                            size: 56,
                            tint: .accentColor,
                            track: Color.primary.opacity(0.12),
                            label: {
                                Text("\(bibleCompletionPercent)%")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.primary)
                            }
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Keep layout balanced with an empty spacer column
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)
            }

            // OT vs NT (Coverage removed)
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OT vs NT")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        let total = max(1, otSeconds + ntSeconds)
                        let otFrac = CGFloat(otSeconds) / CGFloat(total)
                        let ntFrac = CGFloat(ntSeconds) / CGFloat(total)
                        GeometryReader { geo in
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
                        .frame(height: 10)
                    }
                    HStack {
                        Text("OT \(BibleStatsStore.shared.format(otSeconds))")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("NT \(BibleStatsStore.shared.format(ntSeconds))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Genre Distribution with header title; rows are tappable
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(spacing: 8) {
                        let maxVal = max(1, perGenreTotals.map { $0.seconds }.max() ?? 1)
                        ForEach(perGenreTotals, id: \.genre) { item in
                            Button {
                                if let g = Genre(rawValue: item.genre) {
                                    selectedGenre = g
                                    // Precompute rows now
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
                    .padding(.top, 4)
                }
                .padding(.vertical, 6)
            } header: {
                Text("Genre Distribution")
            }

            // Bible Stats (total + per-book table) – time only
            Section {
                DisclosureGroup(isExpanded: $expanded) {
                    // Sort picker visible when expanded
                    Picker("Sort", selection: $sortMode) {
                        ForEach(SortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 6)

                    // Expanded list of all 66 books with their time
                    ForEach(rows, id: \.book) { entry in
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
                } label: {
                    HStack {
                        Text("Total Bible Time")
                            .font(.headline)
                        Spacer()
                        Text(BibleStatsStore.shared.format(totalSeconds))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .accessibilityHidden(true)
                            .overlay(
                                Color.clear
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Total \(BibleStatsStore.shared.format(totalSeconds))")
                            )
                    }
                }
            } header: {
                Text("Bible Stats")
            }

            // Book Reading Progress – collapsible
            Section {
                DisclosureGroup(isExpanded: $progressExpanded) {
                    // Expanded: show each book progress
                    ForEach(orderedAllBooks, id: \.self) { name in
                        let prog = bookProgress[name] ?? (0, 1, 0.0)
                        HStack(spacing: 8) {
                            Text(name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 4) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(Color.primary.opacity(0.10))
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .fill(Color.accentColor.opacity(0.65))
                                            .frame(width: geo.size.width * CGFloat(prog.fraction))
                                    }
                                }
                                .frame(width: 100, height: 6)
                                Text("\(prog.read)/\(prog.total)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .frame(width: 40, alignment: .trailing)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(name) progress \(prog.read) of \(prog.total) chapters")
                        }
                    }
                } label: {
                    // Collapsed label: title/summary on the left, ring on the right
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Book Reading Progress")
                                .font(.headline)
                            Text("\(visitedCount)/\(totalChapters) chapters • \(bibleCompletionPercent)%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer()
                        ProgressRing(
                            progress: Double(bibleCompletionPercent) / 100.0,
                            lineWidth: 8,
                            size: 28,
                            tint: .accentColor,
                            track: Color.primary.opacity(0.12),
                            label: {
                                EmptyView()
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshTotals()
            // Subscribe to tracker version bumps to keep stats fresh
            if cancellable == nil {
                cancellable = ReadingTimeTracker.shared.$lastTotalsVersion
                    .receive(on: RunLoop.main)
                    .sink { _ in
                        refreshTotals()
                    }
            }
        }
        .onDisappear {
            // Optional: keep subscription; or release when leaving
            // cancellable?.cancel(); cancellable = nil
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
                    // Safety: recompute rows from current totals so we always show canonical rows
                    let totals = BibleStatsStore.shared.loadTotals()
                    genreDetailRows = rowsForGenre(genre, totals: totals)
                }
            }
        }
    }

    // Delta value on its own line, small gray
    private var weekDeltaOnlyValue: String {
        let delta = thisWeekSeconds - lastWeekSeconds
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        let absVal = abs(delta)
        return "\(sign)\(BibleStatsStore.shared.format(absVal))"
    }

    // MARK: - Genre mapping and totals

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

    // Map canonical book names to genre. Must match BibleData/BibleCanon names.
    private func genreForBook(_ book: String) -> Genre {
        switch book {
        // Law (Pentateuch)
        case "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy":
            return .Law

        // History
        case "Joshua", "Judges", "Ruth",
             "1 Samuel", "2 Samuel",
             "1 Kings", "2 Kings",
             "1 Chronicles", "2 Chronicles",
             "Ezra", "Nehemiah", "Esther":
            return .History

        // Poetry/Wisdom
        case "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon":
            return .Poetry

        // Major Prophets
        case "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel":
            return .MajorProphets

        // Minor Prophets
        case "Hosea", "Joel", "Amos", "Obadiah", "Jonah",
             "Micah", "Nahum", "Habakkuk", "Zephaniah",
             "Haggai", "Zechariah", "Malachi":
            return .MinorProphets

        // Gospels
        case "Matthew", "Mark", "Luke", "John":
            return .Gospels

        // Acts
        case "Acts":
            return .Acts

        // Epistles
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

        // Apocalypse
        case "Revelation":
            return .Apocalypse

        default:
            // Fallback heuristics: if not found, assume OT History for safety
            return .History
        }
    }

    private func computeGenreTotals(from perBook: [String: Int]) -> [(genre: String, seconds: Int)] {
        var buckets: [Genre: Int] = [:]
        buckets.reserveCapacity(Genre.allCases.count)
        for (book, seconds) in perBook {
            let g = genreForBook(book)
            buckets[g, default: 0] += max(0, seconds)
        }
        // Fixed display order
        let order: [Genre] = [.Law, .History, .Poetry, .MajorProphets, .MinorProphets, .Gospels, .Acts, .Epistles, .Apocalypse]
        let rows = order.map { g in (genre: g.rawValue, seconds: buckets[g, default: 0]) }
        return rows
    }

    // Always canonical order in the popup, include zero-time books
    private func rowsForGenre(_ genre: Genre, totals: [String: Int]) -> [(book: String, seconds: Int)] {
        let canonical = orderedAllBooks
        let booksInGenre: [String] = canonical.filter { genreForBook($0) == genre }
        let rows: [(book: String, seconds: Int)] = booksInGenre.map { name in
            (book: name, seconds: totals[name, default: 0])
        }
        return rows
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
}

#Preview {
    NavigationStack {
        StatsView()
    }
}

// MARK: - Small Progress Ring

private struct ProgressRing<Label: View>: View {
    let progress: Double        // 0.0 ... 1.0
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
