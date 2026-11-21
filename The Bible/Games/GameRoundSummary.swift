import Foundation

/// One answered question (or word) in a game, kept for the end-of-round summary.
struct GameRoundEntry: Identifiable {
    enum Outcome {
        case correct
        case wrong
        case timedOut
    }

    let id = UUID()
    /// What the player was asked: a question, clue, verse, or scrambled letters.
    let prompt: String
    let outcome: Outcome
    /// What the player chose; nil when time ran out or the answer was revealed.
    let givenAnswer: String?
    let correctAnswer: String
    /// A grouping for the "By type" breakdown, such as "People" or "Gospels".
    var category: String?
    /// The book the question is about, for the strongest and weakest book.
    var bookName: String?
    /// A passage to open from the answer review, such as "Genesis 6:13-22".
    var reference: String?
    /// Hints used to solve this question or word. Zero when the game has no hints.
    var hintCount: Int = 0
    /// Time from the question appearing to the answer. Filled in by `GameScore`.
    var duration: Duration?
    /// All books associated with a person; one question can contribute to several book tallies.
    var relatedBookNames: [String] = []

    var summaryBookNames: [String] {
        var seen: Set<String> = []
        return ((bookName.map { [$0] } ?? []) + relatedBookNames)
            .filter { seen.insert($0).inserted }
    }

    var summaryCategories: [String] {
        guard !relatedBookNames.isEmpty else { return category.map { [$0] } ?? [] }
        var seen: Set<QuizVerseSection> = []
        return summaryBookNames.compactMap { QuizVerseSection.containing($0) }
            .filter { seen.insert($0).inserted }
            .map { String(localized: $0.title) }
    }
}

/// The numbers behind the end-of-round summary, worked out from a finished `GameScore`.
/// What a round scored once bonus points are counted, for games that award them. A round can
/// score more points than it had questions, so the summary shows the total and how it adds up.
struct RoundPoints: Equatable {
    struct Bonus: Equatable {
        /// "3 speed bonuses", already worded for the count.
        let title: String
        let systemImage: String
        let count: Int
    }

    /// Correct answers plus every bonus.
    let total: Int
    let correct: Int
    /// Only the bonuses that were earned.
    let bonuses: [Bonus]

    /// Nil when no bonus was earned, so the summary keeps its plain "N of M correct" look.
    init?(correct: Int, bonuses: [Bonus]) {
        let earned = bonuses.filter { $0.count > 0 }
        guard !earned.isEmpty else { return nil }
        self.correct = correct
        self.bonuses = earned
        self.total = correct + earned.reduce(0) { $0 + $1.count }
    }

    static func speed(_ count: Int) -> Bonus {
        Bonus(
            title: count == 1 ? String(localized: "1 speed bonus") : String(localized: "\(count) speed bonuses"),
            systemImage: "bolt.fill",
            count: count
        )
    }

    static func chapter(_ count: Int) -> Bonus {
        Bonus(
            title: count == 1 ? String(localized: "1 chapter bonus") : String(localized: "\(count) chapter bonuses"),
            systemImage: "star.fill",
            count: count
        )
    }

    static func lessKnown(_ count: Int) -> Bonus {
        Bonus(
            title: count == 1 ? String(localized: "1 less-known book") : String(localized: "\(count) less-known books"),
            systemImage: "books.vertical.fill",
            count: count
        )
    }
}

struct GameRoundSummary {
    enum Grade {
        case perfect
        case great
        case good
        case keepPracticing
    }

    /// Correct answers out of the total for one book or category.
    struct Tally: Identifiable, Equatable {
        let name: String
        var correct: Int
        var total: Int

        var id: String { name }
        var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
    }

    let entries: [GameRoundEntry]
    let roundDuration: Duration?
    let isTimed: Bool
    /// The saved streak after this round; it carries into the next one.
    let currentStreak: Int
    /// The best saved streak for this game and difficulty.
    let bestStreak: Int
    let isNewBestStreak: Bool

    init(
        entries: [GameRoundEntry],
        roundDuration: Duration?,
        isTimed: Bool,
        currentStreak: Int,
        bestStreak: Int,
        isNewBestStreak: Bool
    ) {
        self.entries = entries
        self.roundDuration = roundDuration
        self.isTimed = isTimed
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.isNewBestStreak = isNewBestStreak
    }

    init(score: GameScore) {
        self.init(
            entries: score.entries,
            roundDuration: score.gameDuration,
            isTimed: score.wasTimed,
            currentStreak: score.savedCurrentStreak,
            bestStreak: score.savedBestStreak,
            isNewBestStreak: score.savedBestStreak > score.savedBestStreakAtStart
        )
    }

    // MARK: - Score

    var total: Int { entries.count }
    var correctCount: Int { entries.count(where: { $0.outcome == .correct }) }
    var wrongCount: Int { entries.count(where: { $0.outcome == .wrong }) }
    var timedOutCount: Int { entries.count(where: { $0.outcome == .timedOut }) }

    var accuracy: Double {
        total > 0 ? Double(correctCount) / Double(total) : 0
    }

    var grade: Grade {
        guard total > 0 else { return .keepPracticing }
        if correctCount == total { return .perfect }
        if accuracy >= 0.8 { return .great }
        if accuracy >= 0.5 { return .good }
        return .keepPracticing
    }

    /// The longest run of correct answers within this round alone.
    var longestRunThisRound: Int {
        var longest = 0
        var run = 0
        for entry in entries {
            run = entry.outcome == .correct ? run + 1 : 0
            longest = max(longest, run)
        }
        return longest
    }

    // MARK: - Time

    var averageAnswerTime: Duration? {
        let durations = entries.compactMap(\.duration)
        guard !durations.isEmpty else { return nil }
        return durations.reduce(.zero, +) / durations.count
    }

    var fastestCorrectAnswer: Duration? {
        entries.filter { $0.outcome == .correct }.compactMap(\.duration).min()
    }

    // MARK: - Breakdowns

    /// Accuracy for each category, in the order they first appeared. Empty unless the round
    /// mixed at least two, since a single row says nothing the score doesn't.
    var categoryTallies: [Tally] {
        let tallies = Self.tally(entries.flatMap { entry in entry.summaryCategories.map { ($0, entry.outcome) } })
        return tallies.count >= 2 ? tallies : []
    }

    /// Accuracy for each book, in the order they first appeared.
    var bookTallies: [Tally] {
        Self.tally(entries.flatMap { entry in entry.summaryBookNames.map { ($0, entry.outcome) } })
    }

    /// The best book among those asked at least twice, so one lucky answer doesn't count.
    var strongestBook: Tally? {
        guard let weakest = weakestBook else { return nil }
        let best = repeatedBooks.max { lhs, rhs in
            lhs.accuracy == rhs.accuracy ? lhs.correct < rhs.correct : lhs.accuracy < rhs.accuracy
        }
        // When every repeated book scored the same, there is no strongest or weakest.
        guard let best, best.accuracy > weakest.accuracy else { return nil }
        return best
    }

    /// The weakest book among those asked at least twice.
    var weakestBook: Tally? {
        let weakest = repeatedBooks.min { lhs, rhs in
            lhs.accuracy == rhs.accuracy ? lhs.total > rhs.total : lhs.accuracy < rhs.accuracy
        }
        guard let weakest, repeatedBooks.contains(where: { $0.accuracy > weakest.accuracy }) else { return nil }
        return weakest
    }

    /// Books with a wrong or timed-out answer, each listed once.
    var missedBooks: [String] {
        var seen: Set<String> = []
        return entries
            .filter { $0.outcome != .correct }
            .flatMap(\.summaryBookNames)
            .filter { seen.insert($0).inserted }
    }

    /// Old and New Testament accuracy, when the round had books from both.
    var testamentTallies: [Tally] {
        let oldTestament = String(localized: "Old Testament")
        let newTestament = String(localized: "New Testament")
        let pairs = entries.flatMap { entry -> [(String, GameRoundEntry.Outcome)] in
            // A person appearing in several books of one Testament counts once for that Testament.
            var seen: Set<String> = []
            return entry.summaryBookNames.compactMap { book in
                guard let section = QuizVerseSection.containing(book) else { return nil }
                let name = section.isOldTestament ? oldTestament : newTestament
                guard seen.insert(name).inserted else { return nil }
                return (name, entry.outcome)
            }
        }
        let tallies = Self.tally(pairs).sorted { $0.name == oldTestament && $1.name != oldTestament }
        return tallies.count == 2 ? tallies : []
    }

    private var repeatedBooks: [Tally] {
        bookTallies.filter { $0.total >= 2 }
    }

    private static func tally(_ pairs: [(String, GameRoundEntry.Outcome)]) -> [Tally] {
        var tallies: [Tally] = []
        var indexByName: [String: Int] = [:]
        for (name, outcome) in pairs {
            let index: Int
            if let existing = indexByName[name] {
                index = existing
            } else {
                index = tallies.count
                indexByName[name] = index
                tallies.append(Tally(name: name, correct: 0, total: 0))
            }
            tallies[index].total += 1
            if outcome == .correct {
                tallies[index].correct += 1
            }
        }
        return tallies
    }
}
