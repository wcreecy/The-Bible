import Foundation
import Observation
import SwiftUI

/// The ways to play Book Order.
enum BookOrderMode: String, CaseIterable, Identifiable {
    // Raw values are stored in settings.
    /// Tap the books in Bible order.
    case tapInOrder
    /// Tap the book that comes first, as many as you can in a minute.
    case beforeAfter
    /// Pick the book missing from a run.
    case missingBook
    /// Pick the part of the Bible a book belongs to.
    case whichSection
    /// Drag the books into order. iPad only, where the list fits on screen.
    case classic

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .tapInOrder: "Tap in Order"
        case .beforeAfter: "Before or After?"
        case .missingBook: "Missing Book"
        case .whichSection: "Which Section?"
        case .classic: "Classic"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .tapInOrder: "Tap the books in Bible order."
        case .beforeAfter: "Tap the book that comes first. As many as you can in a minute."
        case .missingBook: "Pick the book missing from a run."
        case .whichSection: "Pick the part of the Bible each book is in."
        case .classic: "Drag the books into order."
        }
    }

    var systemImage: String {
        switch self {
        case .tapInOrder: "hand.tap.fill"
        case .beforeAfter: "arrow.left.arrow.right"
        case .missingBook: "rectangle.dashed"
        case .whichSection: "books.vertical.fill"
        case .classic: "list.number"
        }
    }

    /// Tap in Order and Classic are puzzles; the rest are rounds of quick questions.
    var isPuzzle: Bool { self == .tapInOrder || self == .classic }

    /// The modes offered on this screen size. Classic's drag list only works well on iPad.
    static func available(isWide: Bool) -> [BookOrderMode] {
        isWide ? allCases : allCases.filter { $0 != .classic }
    }
}

/// One question in a quick round.
struct BookOrderQuickQuestion: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Which of two books comes first.
        case beforeAfter(first: String, second: String)
        /// A run of books with one left out, shown as nil.
        case missingBook(run: [String?])
        /// Which part of the Bible a book is in.
        case whichSection(book: String)
    }

    let id = UUID()
    let kind: Kind
    /// The book the question is about, saved when it's missed.
    let book: String
    let options: [String]
    let correctAnswer: String

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

/// Before or After?, Missing Book and Which Section?: a round of quick questions about the
/// books of one part of the Bible.
@MainActor
@Observable
final class BookOrderQuickRound {
    static let questionsPerRound = 10
    /// Seconds in a Before or After? round.
    static let beforeAfterSeconds = 60

    let mode: BookOrderMode
    let difficulty: BookOrderDifficulty
    let source: BookSourceScope
    /// Books missed earlier, for a review round; empty for a normal round.
    let reviewBooks: [String]
    private let missedQuestions: MissedGameQuestionStore
    @ObservationIgnored private let sleep: (Duration) async throws -> Void
    @ObservationIgnored private let now: () -> Date

    private(set) var questions: [BookOrderQuickQuestion] = []
    private(set) var currentIndex = 0
    private(set) var selectedAnswer: String?
    private(set) var isFinished = false
    /// Score and streaks; see `GameScore` for the rules.
    private(set) var session = GameScore()
    private(set) var remainingSeconds = 0
    /// The last Before or After? answer, shown while the next pair is up.
    private(set) var lastFeedback: (isCorrect: Bool, text: String)?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var clock = GameActiveClock()

    init(
        mode: BookOrderMode,
        difficulty: BookOrderDifficulty,
        source: BookSourceScope,
        reviewBooks: [String] = [],
        missedQuestions: MissedGameQuestionStore? = nil,
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        now: @escaping () -> Date = Date.init
    ) {
        self.mode = mode
        self.difficulty = difficulty == .fullBible ? .hard : difficulty
        self.source = source
        self.reviewBooks = reviewBooks
        self.missedQuestions = missedQuestions ?? .shared
        self.sleep = sleep
        self.now = now
    }

    var isReview: Bool { !reviewBooks.isEmpty }

    /// Which Section? always uses the whole Bible, since one section's books would all have the same answer.
    private var books: [String] {
        isReview || mode == .whichSection ? BibleCanon.fallbackCanon : source.bookNames
    }

    var current: BookOrderQuickQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var isAnswered: Bool { selectedAnswer != nil }

    var isTimed: Bool { mode == .beforeAfter }

    var progressText: String {
        isTimed
            ? String(localized: "\(session.score) correct")
            : String(localized: "Question \(currentIndex + 1) of \(questions.count)")
    }

    // MARK: - Flow

    func start() {
        session.beginGame(savedStreak: persistentStreak, isTimed: isTimed)
        isFinished = false
        currentIndex = 0
        selectedAnswer = nil
        lastFeedback = nil
        if isTimed {
            questions = [makeBeforeAfter()]
            remainingSeconds = Self.beforeAfterSeconds
            clock.start(at: now())
            startTimer()
        } else {
            let targets = isReview
                ? Array(reviewBooks.shuffled().prefix(Self.questionsPerRound))
                : Array(books.shuffled().prefix(Self.questionsPerRound))
            questions = targets.compactMap { mode == .whichSection ? makeWhichSection(for: $0) : makeMissingBook(for: $0) }
        }
        session.startQuestion()
    }

    func choose(_ answer: String) {
        guard !isFinished, !isAnswered, let current, current.options.contains(answer) else { return }
        let isCorrect = answer == current.correctAnswer
        record(current, answer: answer, isCorrect: isCorrect)

        if isTimed {
            // Before or After? moves straight on, showing how the last one went.
            lastFeedback = (isCorrect, isCorrect
                ? String(localized: "\(current.correctAnswer) comes first")
                : String(localized: "No: \(current.correctAnswer) comes first"))
            questions.append(makeBeforeAfter())
            currentIndex += 1
            session.startQuestion()
        } else {
            selectedAnswer = answer
        }
    }

    func next() {
        guard !isTimed, isAnswered else { return }
        if currentIndex + 1 >= questions.count {
            finish()
        } else {
            currentIndex += 1
            selectedAnswer = nil
            session.startQuestion()
        }
    }

    var isLastQuestion: Bool { currentIndex + 1 >= questions.count }

    private func finish() {
        timerTask?.cancel()
        clock.pause(at: now())
        session.endGame()
        if isTimed, session.score > bestBeforeAfterScore {
            UserDefaults.standard.set(session.score, forKey: bestScoreKey)
        }
        // Review rounds use only missed books, so their scores aren't comparable.
        if isTimed, !isReview {
            GameStats.shared.recordModeRound(.bookorder, mode: mode.rawValue, score: session.score)
        }
        isFinished = true
    }

    /// Leaving a Before or After? round ends it; the other rounds just stop.
    func stop() {
        timerTask?.cancel()
        clock.pause(at: now())
    }

    private func record(_ question: BookOrderQuickQuestion, answer: String, isCorrect: Bool) {
        session.record(
            GameRoundEntry(
                prompt: prompt(for: question),
                outcome: isCorrect ? .correct : .wrong,
                givenAnswer: answer,
                correctAnswer: question.correctAnswer,
                category: String(localized: mode.title),
                bookName: question.book
            ),
            savedStreak: persistentStreak
        )
        GameStats.shared.recordRound(
            game: .bookorder,
            difficulty: difficulty.statsDifficulty,
            correct: isCorrect ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        GameStats.shared.recordModeAnswer(.bookorder, mode: mode.rawValue, correct: isCorrect)
        // Misses are saved by book, the same as the puzzles, and a right answer clears one.
        if isCorrect {
            if missedQuestions.containsMiss(game: .bookOrder, questionID: question.book) {
                missedQuestions.resolveReviewQuestion(game: .bookOrder, questionID: question.book)
            }
        } else {
            missedQuestions.record(game: .bookOrder, bookNames: [question.book], topic: "Book order", questionID: question.book)
        }
        if isCorrect { Haptics.success() } else { Haptics.error() }
    }

    /// The question as text, for the round summary.
    func prompt(for question: BookOrderQuickQuestion) -> String {
        switch question.kind {
        case .beforeAfter(let first, let second):
            String(localized: "\(first) or \(second): which comes first?")
        case .missingBook(let run):
            run.map { $0 ?? "___" }.joined(separator: " · ")
        case .whichSection(let book):
            String(localized: "Which part of the Bible is \(book) in?")
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await self?.sleep(.milliseconds(100))
                guard let self, !Task.isCancelled, !self.isFinished else { return }
                let remaining = max(0, Self.beforeAfterSeconds - Int(self.clock.elapsed(at: self.now())))
                if remaining != self.remainingSeconds { self.remainingSeconds = remaining }
                if remaining == 0 {
                    self.finish()
                    return
                }
            }
        }
    }

    /// Stops the clock while the app is in the background.
    func pause() {
        guard isTimed, !isFinished else { return }
        clock.pause(at: now())
        timerTask?.cancel()
    }

    func resume() {
        guard isTimed, !isFinished else { return }
        clock.resume(at: now())
        startTimer()
    }

    // MARK: - Best score and streak

    private var variant: String { "\(mode.rawValue)_\(source.rawValue)_\(difficulty.rawValue)" }

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "bookorder", variant: variant)
    }

    private var bestScoreKey: String { "bookorderBestScore_\(variant)" }

    /// The most Before or After? answers right in one minute, for these settings.
    var bestBeforeAfterScore: Int { UserDefaults.standard.integer(forKey: bestScoreKey) }

    // MARK: - Building questions

    /// Two books, closer together on harder levels: far apart on Easy, a few books apart on
    /// Normal, and next to each other on Hard.
    private func makeBeforeAfter() -> BookOrderQuickQuestion {
        let books = self.books
        let distances: ClosedRange<Int> = switch difficulty {
        case .easy: 8...max(8, books.count - 1)
        case .normal: 3...7
        case .hard, .fullBible: 1...2
        }
        let maxDistance = max(1, books.count - 1)
        let distance = min(Int.random(in: distances), maxDistance)
        let start = Int.random(in: 0...(books.count - 1 - distance))
        let first = books[start]
        let second = books[start + distance]
        let shown = Bool.random() ? [first, second] : [second, first]
        return BookOrderQuickQuestion(
            kind: .beforeAfter(first: shown[0], second: shown[1]),
            book: second,
            options: shown,
            correctAnswer: first
        )
    }

    /// A run of four books with `book` left out, and three wrong books to choose from: from
    /// anywhere on Easy, the same Testament on Normal, and the books just around the run on Hard.
    func makeMissingBook(for book: String) -> BookOrderQuickQuestion? {
        let canon = BibleCanon.fallbackCanon
        guard let index = canon.firstIndex(of: book) else { return nil }
        let runLength = 4
        let lowest = max(0, index - runLength + 1)
        let highest = min(canon.count - runLength, index)
        let start = Int.random(in: lowest...highest)
        let run = Array(canon[start..<(start + runLength)])
        let shown: [String?] = run.map { $0 == book ? nil : $0 }

        let testament = BibleBookGroup.group(for: book).testament
        let pool: [String] = switch difficulty {
        case .easy: canon
        case .normal: canon.filter { BibleBookGroup.group(for: $0).testament == testament }
        case .hard, .fullBible: Array(canon[max(0, start - 3)..<min(canon.count, start + runLength + 3)])
        }
        let wrong = pool.filter { !run.contains($0) }.shuffled().prefix(3)
        return BookOrderQuickQuestion(
            kind: .missingBook(run: shown),
            book: book,
            options: (Array(wrong) + [book]).shuffled(),
            correctAnswer: book
        )
    }

    private func makeWhichSection(for book: String) -> BookOrderQuickQuestion {
        let groups = BibleBookGroup.allCases.map(\.title)
        return BookOrderQuickQuestion(
            kind: .whichSection(book: book),
            book: book,
            options: groups,
            correctAnswer: BibleBookGroup.group(for: book).title
        )
    }

    /// The books in a section, for teaching after a Which Section? answer.
    static func books(inSection title: String) -> [String] {
        guard let group = BibleBookGroup.allCases.first(where: { $0.title == title }) else { return [] }
        return BibleCanon.fallbackCanon.filter { BibleBookGroup.group(for: $0) == group }
    }
}
