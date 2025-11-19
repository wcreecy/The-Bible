import SwiftUI
import SwiftData

struct ReferenceMatchGameView: View {
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

    enum Difficulty: String, CaseIterable, Identifiable { case easy, medium, hard; var id: String { rawValue } }
    @State private var difficulty: Difficulty = .medium

    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false

    @State private var started = false
    @AppStorage("refmatchScope") private var verseScopeRaw: String = "whole"

    @State private var questionNumber: Int = 0
    @State private var score: Int = 0
    @State private var answered: Int = 0

    @State private var currentStreak: Int = 0
    @State private var currentBestStreak: Int = 0

    @State private var history: [(book: Book, chapter: Chapter, verse: Verse, options: [AnswerOption], correctIndex: Int, selectedIndex: Int?)] = []
    @State private var currentIndex: Int = -1

    private var allTimeCorrect: Int { UserDefaults.standard.integer(forKey: "refmatchAllTimeCorrect_\(difficultyKeySuffix())") }
    private var allTimeAnswered: Int { UserDefaults.standard.integer(forKey: "refmatchAllTimeAnswered_\(difficultyKeySuffix())") }
    private var allTimeBestStreak: Int { UserDefaults.standard.integer(forKey: "refmatchAllTimeBestStreak_\(difficultyKeySuffix())") }

    @State private var refBook: Book? = nil
    @State private var refChapter: Chapter? = nil
    @State private var refVerse: Verse? = nil

    @State private var options: [AnswerOption] = []
    @State private var correctIndex: Int = -1
    @State private var selectedIndex: Int? = nil

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
                                    Text("• Easy / Medium / Hard: Affects all-time stats buckets; gameplay remains untimed.")
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
                    // Scoreboard (shared)
                    GameScoreboardCard(
                        currentCorrect: score,
                        currentAnswered: answered,
                        currentStreak: currentStreak,
                        allTimeCorrect: allTimeCorrect,
                        allTimeAnswered: allTimeAnswered,
                        allTimeBestStreak: allTimeBestStreak
                    )

                    // Reference card
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
    }

    private func startGame() {
        score = 0
        answered = 0
        currentStreak = 0
        currentBestStreak = 0
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
            currentStreak += 1
            if currentStreak > currentBestStreak {
                currentBestStreak = currentStreak
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            updateAllTime(correct: 1, answered: 1, streak: currentBestStreak)
        } else {
            currentStreak = 0
            updateAllTime(correct: 0, answered: 1, streak: currentBestStreak)
        }
    }

    private func generateQuestion() {
        // Define Old and New Testament sets
        let oldTestamentSet: Set<String> = [
            "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
            "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel", "1 Kings", "2 Kings",
            "1 Chronicles", "2 Chronicles", "Ezra", "Nehemiah", "Esther", "Job",
            "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon", "Isaiah",
            "Jeremiah", "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel",
            "Amos", "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
            "Zephaniah", "Haggai", "Zechariah", "Malachi"
        ]
        let newTestamentSet: Set<String> = [
            "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
            "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
            "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
            "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews",
            "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
            "Jude", "Revelation"
        ]

        var filteredBooks: [Book]
        switch verseScopeRaw {
        case "old":
            filteredBooks = BibleData.books.filter { oldTestamentSet.contains($0.name) }
        case "new":
            filteredBooks = BibleData.books.filter { newTestamentSet.contains($0.name) }
        default:
            filteredBooks = BibleData.books
        }

        guard let book = filteredBooks.randomElement(),
              let chapter = book.chapters.randomElement(),
              let verse = chapter.verses.randomElement() else {
            refBook = nil; refChapter = nil; refVerse = nil; options = []; correctIndex = -1; return
        }
        refBook = book; refChapter = chapter; refVerse = verse

        // Build correct option
        let correctFull = verse.text
        let correctSnippet = snippet(for: correctFull)
        let correct = AnswerOption(
            snippet: correctSnippet,
            bookName: book.name,
            chapterNumber: chapter.number,
            verseNumber: verse.number,
            verseText: correctFull
        )

        // Build distractors: pick from other verses (avoid duplicate snippets)
        var distractors: [AnswerOption] = []
        var snippetSet: Set<String> = [correct.snippet]
        var safety = 0
        while distractors.count < 3 && safety < 3000 {
            safety += 1
            guard let b = filteredBooks.randomElement(),
                  let c = b.chapters.randomElement(),
                  let v = c.verses.randomElement() else { continue }
            let snip = snippet(for: v.text)
            if !snippetSet.contains(snip) {
                snippetSet.insert(snip)
                distractors.append(AnswerOption(
                    snippet: snip,
                    bookName: b.name,
                    chapterNumber: c.number,
                    verseNumber: v.number,
                    verseText: v.text
                ))
            }
        }
        var allOptions = distractors
        allOptions.append(correct)
        allOptions.shuffle()
        options = allOptions
        correctIndex = options.firstIndex(where: { $0.bookName == book.name && $0.chapterNumber == chapter.number && $0.verseNumber == verse.number }) ?? -1

        var newHistory = history
        newHistory.append((book: book, chapter: chapter, verse: verse, options: options, correctIndex: correctIndex, selectedIndex: nil))
        history = newHistory
        currentIndex = history.count - 1
        loadFromHistory()
    }

    private func loadFromHistory() {
        guard currentIndex >= 0 && currentIndex < history.count else { return }
        let h = history[currentIndex]
        refBook = h.book
        refChapter = h.chapter
        refVerse = h.verse
        options = h.options
        correctIndex = h.correctIndex
        selectedIndex = h.selectedIndex
    }

    private func snippet(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 160 { return trimmed }
        let idx = trimmed.index(trimmed.startIndex, offsetBy: 160)
        return String(trimmed[..<idx]) + "…"
    }

    private func buttonBackground(forIndex idx: Int) -> Color {
        guard let sel = selectedIndex else { return Color(.secondarySystemBackground) }
        if idx == correctIndex {
            return sel == idx ? Color.green.opacity(0.25) : Color.green.opacity(0.15)
        } else if sel == idx {
            return Color.red.opacity(0.25)
        }
        return Color(.secondarySystemBackground)
    }

    private func buttonBorder(forIndex idx: Int) -> Color {
        guard let sel = selectedIndex else { return Color.black.opacity(0.12) }
        if idx == correctIndex { return .green }
        if idx == sel { return .red }
        return Color.black.opacity(0.12)
    }

    @ViewBuilder
    private func statPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(tint)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }

    private func updateAllTime(correct addCorrect: Int, answered addAnswered: Int, streak: Int) {
        let defaults = UserDefaults.standard
        let suffix = difficultyKeySuffix()
        let correctKey = "refmatchAllTimeCorrect_\(suffix)"
        let answeredKey = "refmatchAllTimeAnswered_\(suffix)"
        let bestKey = "refmatchAllTimeBestStreak_\(suffix)"
        let newCorrect = defaults.integer(forKey: correctKey) + addCorrect
        let newAnswered = defaults.integer(forKey: answeredKey) + addAnswered
        let newBest = max(defaults.integer(forKey: bestKey), streak)
        defaults.set(newCorrect, forKey: correctKey)
        defaults.set(newAnswered, forKey: answeredKey)
        defaults.set(newBest, forKey: bestKey)
    }

    private func difficultyKeySuffix() -> String {
        switch difficulty { case .easy: return "easy"; case .medium: return "medium"; case .hard: return "hard" }
    }

    private func percentString(correct: Int, answered: Int) -> String {
        guard answered > 0 else { return "0%" }
        let pct = Int(round((Double(correct) / Double(answered)) * 100.0))
        return "\(pct)%"
    }

    private func currentFavoriteExists() -> Bool {
        guard let b = refBook, let c = refChapter, let v = refVerse else { return false }
        return favorites.contains { fav in
            fav.bookName == b.name && fav.chapterNumber == c.number && fav.verseNumber == v.number
        }
    }

    private func toggleFavoriteCurrent() {
        guard let b = refBook, let c = refChapter, let v = refVerse else { return }
        if let existing = favorites.first(where: { $0.bookName == b.name && $0.chapterNumber == c.number && $0.verseNumber == v.number }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(
                bookName: b.name,
                chapterNumber: c.number,
                verseNumber: v.number,
                verseText: v.text
            )
            modelContext.insert(fav)
            try? modelContext.save()
        }
    }

    private func isFavorited(bookName: String, chapterNumber: Int, verseNumber: Int) -> Bool {
        favorites.contains { fav in
            fav.bookName == bookName && fav.chapterNumber == chapterNumber && fav.verseNumber == verseNumber
        }
    }

    private func toggleFavorite(bookName: String, chapterNumber: Int, verseNumber: Int, verseText: String) {
        if let existing = favorites.first(where: { $0.bookName == bookName && $0.chapterNumber == chapterNumber && $0.verseNumber == verseNumber }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(
                bookName: bookName,
                chapterNumber: chapterNumber,
                verseNumber: verseNumber,
                verseText: verseText
            )
            modelContext.insert(fav)
            try? modelContext.save()
        }
    }
}

#Preview {
    NavigationStack { ReferenceMatchGameView() }
}
