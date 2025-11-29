import SwiftUI
import Combine

struct StatsView: View {
    private enum SortMode: String, CaseIterable, Identifiable {
        case canonical = "Canonical"
        case mostRead = "Most Read"
        var id: String { rawValue }
    }

    @State private var sortMode: SortMode = .canonical

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

    // Per-book progress (chapters read / total)
    @State private var bookProgress: [String: (read: Int, total: Int, fraction: Double)] = [:]

    // Genre distribution
    @State private var perGenreTotals: [(genre: String, seconds: Int)] = []
    @State private var selectedGenre: Genre? = nil
    @State private var genreDetailRows: [(book: String, seconds: Int)] = []

    // Expand/collapse
    @State private var showBookProgressDetails: Bool = false
    @State private var showGenreSection: Bool = false
    @State private var showTotalsSection: Bool = false

    // Updates from tracker
    @State private var cancellable: AnyCancellable?

    // New: selected book for chapter detail sheet
    @State private var selectedBookForChapters: String? = nil

    private var orderedAllBooks: [String] {
        if !BibleData.books.isEmpty {
            return BibleData.books.map { $0.name }
        }
        return BibleCanon.canonicalOrder()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1) At a Glance
                glanceRow

                // 2) Bible Completion
                completionCard

                // 3) OT vs NT
                otNtCard

                // 4) Book Reading Progress
                bookReadingProgressCard

                // 5) Genre Distribution (collapsible)
                genreSection

                // 6) Total Bible Time + Per-book table (collapsible)
                totalsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshTotals()
            if cancellable == nil {
                cancellable = ReadingTimeTracker.shared.$lastTotalsVersion
                    .receive(on: RunLoop.main)
                    .sink { _ in refreshTotals() }
            }
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
        // Close the chapters sheet when switching to the Bible tab (so the user sees the reader)
        .onReceive(NotificationCenter.default.publisher(for: .switchToTab)) { _ in
            selectedBookForChapters = nil
        }
        // Refresh stats when chapter progress changes (e.g., Unread pressed, or chapter completed by reading)
        .onReceive(NotificationCenter.default.publisher(for: .init("chapterProgressChanged"))) { _ in
            refreshTotals()
        }
    }

    // MARK: - Cards

    private var glanceRow: some View {
        HStack(spacing: 12) {
            statMiniCard(title: "Today", value: BibleStatsStore.shared.format(todaySeconds), subtitle: todayDeltaOnlyValue, tint: .blue)
            statMiniCard(title: "This Week", value: BibleStatsStore.shared.format(thisWeekSeconds), subtitle: weekDeltaOnlyValue, tint: .green)
            lastReadMiniCard
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
                // Show context label matching Home card style:
                let prefix = (title == "This Week") ? "vs last: " : (title == "Today" ? "vs yesterday: " : "")
                if !prefix.isEmpty {
                    Text("\(prefix)\(subtitle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var completionCard: some View {
        GroupBox {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bible Completion")
                        .font(.headline)
                    Text("\(visitedCount)/\(totalChapters) chapters completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    HStack(spacing: 8) {
                        milestonePill(text: "Books Completed: \(booksCompleted)/\(totalBooks)")
                        milestonePill(text: "Overall: \(bibleCompletionPercent)%")
                    }
                }
                Spacer()
                ProgressRing(
                    progress: Double(bibleCompletionPercent) / 100.0,
                    lineWidth: 10,
                    size: 72,
                    tint: .accentColor,
                    track: Color.primary.opacity(0.12),
                    label: {
                        Text("\(bibleCompletionPercent)%")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func milestonePill(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
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
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                // Collapsed header
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
                        size: 30,
                        tint: .accentColor,
                        track: Color.primary.opacity(0.12),
                        label: {
                            Text("\(bibleCompletionPercent)%")
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                        }
                    )
                }
                // Toggle
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showBookProgressDetails.toggle()
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
                    // Per-book rows
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
    }

    private var genreSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Genre Distribution")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            showGenreSection.toggle()
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
    }

    private var totalsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
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

                // Toggle
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showTotalsSection.toggle()
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Data refresh

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

        // Verse-complete based completion metrics and per-book progress
        computeCompletionMetricsVerseComplete()
        computePerBookProgressVerseComplete()

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

    // MARK: - Rows

    private var rows: [(book: String, seconds: Int)] {
        let canonical = orderedAllBooks
        let canonicalPos = Dictionary(uniqueKeysWithValues: canonical.enumerated().map { ($1, $0) })

        switch sortMode {
        case .canonical:
            return canonical.map { name in
                (book: name, seconds: perBookTotals[name, default: 0])
            }
        case .mostRead:
            let all: [(book: String, seconds: Int)] = canonical.map { name in
                (book: name, seconds: perBookTotals[name, default: 0])
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

    // New: Today vs Yesterday delta string
    private var todayDeltaOnlyValue: String {
        // Yesterday = total of last 2 days minus today
        let store = BibleStatsStore.shared
        let last2 = store.totalForLast(days: 2)
        let yesterday = max(0, last2 - todaySeconds)
        let delta = todaySeconds - yesterday
        if delta == 0 { return "—" }
        let sign = delta > 0 ? "+" : "−"
        let absVal = abs(delta)
        return "\(sign)\(BibleStatsStore.shared.format(absVal))"
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

    // Formats a Date as a time-only string using the user's locale (e.g., "3:42 PM" or "15:42")
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

// Key to use Identifiable sheet(item:)
private struct ChapterDetailKey: Identifiable, Hashable {
    let bookName: String
    var id: String { bookName }
}

// Modal view listing all chapters with read/unread indication
private struct BookChaptersDetailView: View {
    let bookName: String

    @State private var visited: Set<String> = []
    @State private var selectedChapter: Int? = nil
    // Force refresh of rows after Unread
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
                            // Compute completion from seen verses, not from visited set alone
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
                        // Footer shows count of read chapters based on verse-complete logic
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
                // Book with zero chapters (shouldn’t happen), still avoid invalid range
                ContentUnavailableView("No chapters found", systemImage: "exclamationmark.triangle")
            } else {
                ContentUnavailableView("Book not found", systemImage: "exclamationmark.triangle")
            }
        }
        .onAppear {
            // Keep visited set for other stats; read state is derived from seen verses.
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openBibleReference)) { _ in
            // When returning from reading, seen state may have updated; refresh visited for counts if needed
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
        // Refresh rows when a chapter becomes completed by reading (or cleared)
        .onReceive(NotificationCenter.default.publisher(for: .init("chapterProgressChanged"))) { _ in
            refreshID = UUID()
            visited = BibleStatsStore.shared.loadVisitedChapters()
        }
    }

    private func clearChapter(bookName: String, chapterNumber: Int) {
        // Clear all seen verses for the chapter
        BibleStatsStore.shared.saveSeenVerses([], bookName: bookName, chapter: chapterNumber)
        // Optionally unmark visited for consistency
        var v = BibleStatsStore.shared.loadVisitedChapters()
        v.remove("\(bookName):\(chapterNumber)")
        BibleStatsStore.shared.saveVisitedChapters(v)
        // Force this list to recompute isRead
        refreshID = UUID()
        // Notify StatsView to refresh its metrics
        NotificationCenter.default.post(name: .init("chapterProgressChanged"), object: nil)
    }
}

