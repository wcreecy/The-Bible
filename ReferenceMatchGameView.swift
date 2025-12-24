import SwiftUI
import SwiftData

struct VerseMatchGameView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]

    private struct AnswerOption: Hashable, Identifiable {
        let id = UUID()
        let snippet: String
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
        let verseText: String
    }

    enum Difficulty: String, CaseIterable, Identifiable { case easy, normal, hard; var id: String { rawValue } }
    @State private var difficulty: Difficulty = .normal

    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false

    @State private var started = false
    @AppStorage("versematchScope") private var verseScopeRaw: String = "whole"
    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    @State private var questionNumber: Int = 0
    @State private var score: Int = 0
    @State private var answered: Int = 0

    @State private var currentStreak: Int = 0
    @State private var currentBestStreak: Int = 0

    // History of questions to support Previous/Next navigation
    @State private var history: [(book: Book, chapter: Chapter, verse: Verse, options: [AnswerOption], correctIndex: Int, selectedIndex: Int?)] = []
    @State private var currentIndex: Int = -1

    private var allTimeCorrect: Int { UserDefaults.standard.integer(forKey: "versematchAllTimeCorrect_\(difficultyKeySuffix())") }
    private var allTimeAnswered: Int { UserDefaults.standard.integer(forKey: "versematchAllTimeAnswered_\(difficultyKeySuffix())") }
    private var allTimeBestStreak: Int { UserDefaults.standard.integer(forKey: "versematchAllTimeBestStreak_\(difficultyKeySuffix())") }

    @State private var refBook: Book? = nil
    @State private var refChapter: Chapter? = nil
    @State private var refVerse: Verse? = nil

    @State private var options: [AnswerOption] = []
    @State private var correctIndex: Int = -1
    @State private var selectedIndex: Int? = nil

    // MARK: - Persistent streak helpers (per difficulty)
    private func persistentSuffix() -> String {
        switch difficulty {
        case .easy: return "easy"
        case .normal: return "normal"
        case .hard: return "hard"
        }
    }
    private func persistentStreakKey() -> String { "versematchPersistentStreak_\(persistentSuffix())" }
    private func persistentBestKey() -> String { "versematchPersistentBestStreak_\(persistentSuffix())" }

    private func readPersistentStreak() -> Int {
        max(0, UserDefaults.standard.integer(forKey: persistentStreakKey()))
    }
    private func writePersistentStreak(_ value: Int) {
        let v = max(0, value)
        let key = persistentStreakKey()
        UserDefaults.standard.set(v, forKey: key)
        iCloudSyncCoordinator.shared.pushKey(key)
    }
    private func readPersistentBest() -> Int {
        max(0, UserDefaults.standard.integer(forKey: persistentBestKey()))
    }
    private func writePersistentBest(_ value: Int) {
        let v = max(0, value)
        let key = persistentBestKey()
        UserDefaults.standard.set(v, forKey: key)
        iCloudSyncCoordinator.shared.pushKey(key)
    }
    private func seedStreakFromPersistence() {
        let persisted = readPersistentStreak()
        currentStreak = persisted
        let persistedBest = readPersistentBest()
        currentBestStreak = max(currentBestStreak, persistedBest)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !started {
                    Spacer(minLength: 32)
                    Text("Choose the verse text that matches the reference.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        GroupBox {
                            DisclosureGroup(isExpanded: $howToExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Choose a verse source and difficulty, then tap Start.")
                                    Text("• You'll see a reference; pick the verse text that matches it.")
                                    Text("• Review your answer, then tap Next for a new question.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("How to Play").font(.headline)
                            }
                        }

                        GroupBox {
                            DisclosureGroup(isExpanded: $difficultyExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Easy: Possible answers can come from any book of the Bible.")
                                    Text("• Normal: Possible answers are limited to the same testament (Old or New) as the reference.")
                                    Text("• Hard: Possible answers all come from the same book as the reference.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Difficulty Levels").font(.headline)
                            }
                        }
                    }
                    .padding(.horizontal)

                    VStack(spacing: 6) {
                        Text("Verse Source")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Verse Source", selection: Binding<String>(
                            get: { verseScopeRaw },
                            set: { verseScopeRaw = $0 }
                        )) {
                            Text("OT/NT").tag("whole")
                            Text("OT").tag("old")
                            Text("NT").tag("new")
                        }
                        .pickerStyle(.segmented)
                    }

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases) { d in
                            Text(d.rawValue.capitalized).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Button("Start") { startGame() }
                        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                        .controlSize(.large)
                        .frame(maxWidth: 240)
                    Spacer(minLength: 32)
                } else {
                    GameScoreboardCard(
                        currentCorrect: score,
                        currentAnswered: answered,
                        currentStreak: currentStreak,
                        allTimeCorrect: allTimeCorrect,
                        allTimeAnswered: allTimeAnswered,
                        allTimeBestStreak: allTimeBestStreak
                    )

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            if let b = refBook, let c = refChapter, let v = refVerse {
                                Text("Reference")
                                    .font(.headline)
                                HStack(spacing: 8) {
                                    Text("\(b.name) \(c.number):\(v.number)")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    if selectedIndex != nil {
                                        Button(action: { toggleFavoriteCurrent() }) {
                                            Image(systemName: currentFavoriteExists() ? "heart.fill" : "heart")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(currentFavoriteExists() ? "Remove Favorite" : "Add to Favorites")
                                    }
                                }
                            } else {
                                Text("No reference")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Which verse matches this reference?")
                        .font(.headline)
                        .padding(.top, 4)

                    VStack(spacing: 12) {
                        ForEach(Array(options.enumerated()), id: \.element.id) { (idx, opt) in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(opt.snippet)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if selectedIndex != nil {
                                    HStack(spacing: 8) {
                                        Text("\(opt.bookName) \(opt.chapterNumber):\(opt.verseNumber)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Button(action: {
                                            toggleFavorite(bookName: opt.bookName, chapterNumber: opt.chapterNumber, verseNumber: opt.verseNumber, verseText: opt.verseText)
                                        }) {
                                            Image(systemName: isFavorited(bookName: opt.bookName, chapterNumber: opt.chapterNumber, verseNumber: opt.verseNumber) ? "heart.fill" : "heart")
                                                .foregroundStyle(.red)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(isFavorited(bookName: opt.bookName, chapterNumber: opt.chapterNumber, verseNumber: opt.verseNumber) ? "Remove Favorite" : "Add to Favorites")
                                    }
                                }
                            }
                            .padding()
                            .background(buttonBackground(forIndex: idx))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(buttonBorder(forIndex: idx), lineWidth: 1)
                            )
                            .cornerRadius(12)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedIndex == nil { select(idx) }
                            }
                        }
                    }

                    if let sel = selectedIndex {
                        let correct = sel == correctIndex
                        Text(correct ? "Correct!" : "Not quite.")
                            .font(.headline)
                            .foregroundStyle(correct ? .green : .red)
                            .padding(.top, 8)
                    }

                    // DEBUG: WIN button
                    if debugAutoWinEnabled, started, selectedIndex == nil, correctIndex >= 0 {
                        Button("WIN") {
                            select(correctIndex)
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .red))
                        .controlSize(.large)
                        .padding(.top, 6)
                        .accessibilityLabel("Win this round")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Verse Match")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if started && currentIndex > 0 {
                    Button("Previous") { currentIndex -= 1; loadFromHistory() }
                        .disabled(selectedIndex == nil)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if started {
                    Button("Next") {
                        if currentIndex < history.count - 1 { currentIndex += 1; loadFromHistory() }
                        else { nextQuestion() }
                    }
                    .disabled(selectedIndex == nil)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.regular)
                }
            }
        }
        .onAppear {
            // Seed streaks from persisted values so they survive navigation/relaunch
            seedStreakFromPersistence()
        }
        .onChange(of: difficulty) { _, _ in
            // Switch to this difficulty’s persisted streaks
            seedStreakFromPersistence()
        }
    }

    // MARK: - Game flow

    private func startGame() {
        score = 0
        answered = 0
        // Do NOT reset persistent streaks here; seed from persistence
        seedStreakFromPersistence()
        questionNumber = 0
        started = true
        history = []
        currentIndex = -1
        generateQuestion()
    }

    private func nextQuestion() {
        questionNumber += 1
        selectedIndex = nil
        generateQuestion()
    }

    private func select(_ idx: Int) {
        guard selectedIndex == nil else { return }
        selectedIndex = idx
        if currentIndex >= 0 && currentIndex < history.count {
            history[currentIndex].selectedIndex = idx
        }
        answered += 1
        if idx == correctIndex { score += 1 }

        if idx == correctIndex {
            // Persistent streak: increment on correct
            let persisted = readPersistentStreak() + 1
            writePersistentStreak(persisted)
            currentStreak = persisted

            // Update persistent best if needed
            let bestPersisted = readPersistentBest()
            if persisted > bestPersisted {
                writePersistentBest(persisted)
            }
            currentBestStreak = max(currentBestStreak, persisted, readPersistentBest())

            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            GameStats.shared.recordRound(
                game: .versematch,
                difficulty: mapDifficulty(difficulty),
                correct: 1,
                answered: 1,
                currentBestStreak: currentBestStreak
            )
        } else {
            // Persistent streak: reset on incorrect
            writePersistentStreak(0)
            currentStreak = 0

            GameStats.shared.recordRound(
                game: .versematch,
                difficulty: mapDifficulty(difficulty),
                correct: 0,
                answered: 1,
                currentBestStreak: currentBestStreak
            )
        }
    }

    // MARK: - Question generation and history

    private func generateQuestion(maxAttempts: Int = 8) {
        var attempts = 0
        while attempts < maxAttempts {
            attempts += 1

            // Choose a reference book/chapter/verse according to scope (reference respects scope)
            let books = scopedBooks()
            guard let book = books.randomElement(),
                  let chapter = book.chapters.randomElement(),
                  let verse = chapter.verses.randomElement()
            else { return }

            // Build correct option
            let correct = AnswerOption(
                snippet: snippet(for: verse.text),
                bookName: book.name,
                chapterNumber: chapter.number,
                verseNumber: verse.number,
                verseText: verse.text
            )

            // Build distractors according to difficulty rules
            let neededDistractors = 3 // 4 options total
            var distractors: [AnswerOption] = []

            switch difficulty {
            case .easy:
                // Easy: distinct books across OT and NT, ignoring scope for distractors
                if let built = makeDistinctBookDistractorsAcrossAll(
                    excluding: (book: book.name, chapter: chapter.number, verse: verse.number),
                    count: neededDistractors
                ) {
                    distractors = built
                } else {
                    continue // re-roll
                }

            case .normal:
                // Normal: distinct books within the same testament as the correct answer
                let sameTestamentBooks = booksInSameTestament(as: book)
                if let built = makeDistinctBookDistractors(
                    from: sameTestamentBooks,
                    excludingBookName: book.name,
                    excludingReference: (book: book.name, chapter: chapter.number, verse: verse.number),
                    count: neededDistractors
                ) {
                    distractors = built
                } else {
                    continue // re-roll
                }

            case .hard:
                // Hard: strictly same book; if not enough, re-roll
                if let built = makeDistractorsSameBookStrict(
                    book: book,
                    excluding: (chapter: chapter.number, verse: verse.number),
                    count: neededDistractors
                ) {
                    distractors = built
                } else {
                    continue // re-roll
                }
            }

            var opts = distractors
            opts.append(correct)
            opts.shuffle()

            guard let correctIdx = opts.firstIndex(where: { $0.bookName == book.name && $0.chapterNumber == chapter.number && $0.verseNumber == verse.number }) else {
                continue // re-roll
            }

            // Update current ref
            refBook = book
            refChapter = chapter
            refVerse = verse
            options = opts
            correctIndex = correctIdx
            selectedIndex = nil

            // Append to history and advance index
            history.append((book: book, chapter: chapter, verse: verse, options: opts, correctIndex: correctIdx, selectedIndex: nil))
            currentIndex = history.count - 1
            return
        }

        // Fallback if we couldn't generate a valid question after attempts (keep last known state)
        refBook = nil
        refChapter = nil
        refVerse = nil
        options = []
        correctIndex = -1
        selectedIndex = nil
    }

    private func loadFromHistory() {
        guard currentIndex >= 0 && currentIndex < history.count else { return }
        let entry = history[currentIndex]
        refBook = entry.book
        refChapter = entry.chapter
        refVerse = entry.verse
        options = entry.options
        correctIndex = entry.correctIndex
        selectedIndex = entry.selectedIndex
    }

    // MARK: - Option visuals

    private func buttonBackground(forIndex idx: Int) -> Color {
        guard let sel = selectedIndex else {
            return Color(.secondarySystemBackground)
        }
        if idx == correctIndex {
            return Color.green.opacity(0.18)
        }
        if idx == sel, sel != correctIndex {
            return Color.red.opacity(0.18)
        }
        return Color(.secondarySystemBackground)
    }

    private func buttonBorder(forIndex idx: Int) -> Color {
        guard let sel = selectedIndex else {
            return Color.black.opacity(0.12)
        }
        if idx == correctIndex {
            return Color.green.opacity(0.6)
        }
        if idx == sel, sel != correctIndex {
            return Color.red.opacity(0.6)
        }
        return Color.black.opacity(0.12)
    }

    // MARK: - Favorites helpers (SwiftData)

    private func currentFavoriteExists() -> Bool {
        guard let b = refBook, let c = refChapter, let v = refVerse else { return false }
        return favorites.contains { fav in
            fav.bookName == b.name && fav.chapterNumber == c.number && fav.verseNumber == v.number
        }
    }

    private func toggleFavoriteCurrent() {
        guard let b = refBook, let c = refChapter, let v = refVerse else { return }
        toggleFavorite(bookName: b.name, chapterNumber: c.number, verseNumber: v.number, verseText: v.text)
    }

    private func toggleFavorite(bookName: String, chapterNumber: Int, verseNumber: Int, verseText: String) {
        if let existing = favorites.first(where: { $0.bookName == bookName && $0.chapterNumber == chapterNumber && $0.verseNumber == verseNumber }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber, verseText: verseText)
            modelContext.insert(fav)
            try? modelContext.save()
        }
    }

    private func isFavorited(bookName: String, chapterNumber: Int, verseNumber: Int) -> Bool {
        favorites.contains { $0.bookName == bookName && $0.chapterNumber == chapterNumber && $0.verseNumber == verseNumber }
    }

    // MARK: - Generation utilities

    private func scopedBooks() -> [Book] {
        let all = BibleData.books
        guard !all.isEmpty else { return [] }
        switch verseScopeRaw {
        case "old":
            return booksInOT()
        case "new":
            return booksInNT()
        default:
            return all
        }
    }

    private func booksInOT() -> [Book] {
        let all = BibleData.books
        guard let mattIdx = all.firstIndex(where: { $0.name == "Matthew" }) else { return all } // fallback: all if not found
        return Array(all.prefix(mattIdx))
    }

    private func booksInNT() -> [Book] {
        let all = BibleData.books
        guard let mattIdx = all.firstIndex(where: { $0.name == "Matthew" }) else { return [] } // fallback: none if not found
        return Array(all.suffix(from: mattIdx))
    }

    private func booksInSameTestament(as book: Book) -> [Book] {
        let all = BibleData.books
        guard let mattIdx = all.firstIndex(where: { $0.name == "Matthew" }),
              let idx = all.firstIndex(where: { $0.name == book.name }) else {
            // fallback to whole scope if unknown
            return scopedBooks()
        }
        if idx < mattIdx {
            // OT
            return Array(all.prefix(mattIdx))
        } else {
            // NT
            return Array(all.suffix(from: mattIdx))
        }
    }

    // Distinct-book distractors across all books (ignores scope for Easy)
    private func makeDistinctBookDistractorsAcrossAll(
        excluding target: (book: String, chapter: Int, verse: Int),
        count: Int
    ) -> [AnswerOption]? {
        let allBooks = BibleData.books
        return makeDistinctBookDistractors(
            from: allBooks,
            excludingBookName: target.book,
            excludingReference: (book: target.book, chapter: target.chapter, verse: target.verse),
            count: count
        )
    }

    // Distinct-book distractors from a given set of books
    private func makeDistinctBookDistractors(
        from books: [Book],
        excludingBookName: String,
        excludingReference: (book: String, chapter: Int, verse: Int),
        count: Int
    ) -> [AnswerOption]? {
        var usedBooks = Set<String>()
        var out: [AnswerOption] = []

        // Shuffle book order first to encourage wide spread
        for b in books.shuffled() {
            guard b.name != excludingBookName else { continue }
            if usedBooks.contains(b.name) { continue }

            // Find any verse in this book that isn't the exact reference (book/chapter/verse)
            var foundOption: AnswerOption? = nil
            outer: for c in b.chapters.shuffled() {
                for v in c.verses.shuffled() {
                    if b.name == excludingReference.book && c.number == excludingReference.chapter && v.number == excludingReference.verse {
                        continue
                    }
                    foundOption = AnswerOption(
                        snippet: snippet(for: v.text),
                        bookName: b.name,
                        chapterNumber: c.number,
                        verseNumber: v.number,
                        verseText: v.text
                    )
                    break outer
                }
            }

            if let opt = foundOption {
                usedBooks.insert(b.name)
                out.append(opt)
                if out.count >= count { return out }
            }
        }

        // Not enough distinct books found
        return nil
    }

    // Strict same-book distractors; returns nil if not enough to meet count
    private func makeDistractorsSameBookStrict(
        book: Book,
        excluding target: (chapter: Int, verse: Int),
        count: Int
    ) -> [AnswerOption]? {
        var picks: Set<String> = []
        var out: [AnswerOption] = []
        for c in book.chapters.shuffled() {
            for v in c.verses.shuffled() {
                if c.number == target.chapter && v.number == target.verse { continue }
                let key = "\(c.number)-\(v.number)"
                if picks.contains(key) { continue }
                picks.insert(key)
                out.append(AnswerOption(
                    snippet: snippet(for: v.text),
                    bookName: book.name,
                    chapterNumber: c.number,
                    verseNumber: v.number,
                    verseText: v.text
                ))
                if out.count >= count { return out }
            }
        }
        // If not enough within the same book, return nil so caller can re-roll
        return nil
    }

    private func snippet(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLen = 160
        if trimmed.count <= maxLen { return "“\(trimmed)”" }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: maxLen)
        return "“\(trimmed[..<idx])…”"
    }

    // MARK: - Stats helpers

    private func difficultyKeySuffix() -> String {
        switch difficulty { case .easy: return "easy"; case .normal: return "normal"; case .hard: return "hard" }
    }

    private func mapDifficulty(_ d: Difficulty) -> GameStats.Difficulty {
        switch d {
        case .easy: return .easy
        case .normal: return .normal
        case .hard: return .hard
        }
    }
}
