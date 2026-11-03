import SwiftUI
import SwiftData

// The games on the Games tab, how they're grouped, and the recommendation shown above them.

/// Opens a game from elsewhere in the app (for example a Today challenge).
/// The request is held until the Games screen consumes it, because the Games tab
/// may not have been created yet when the request is made.
@MainActor
enum GameLaunchRequest {
    private(set) static var pendingGameName: String?

    /// Switches to the Games tab and opens the game with the given display name.
    static func open(gameName: String) {
        pendingGameName = GameStats.canonicalDisplayName(gameName)
        AppRouter.shared.open(.gameStart)
    }

    static func consume() -> String? {
        defer { pendingGameName = nil }
        return pendingGameName
    }
}

enum GameRoute: String, CaseIterable, Hashable, Identifiable {
    case quiz
    case hangman
    case beatTheClock
    case bookOrder
    case wordSearch
    case scramble
    case crossword
    case whoAmI
    case wordle
    case trivia
    case reviewRound

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .quiz: "Quiz"
        case .hangman: "Hangman"
        case .beatTheClock: "Countdown"
        case .bookOrder: "Book Order"
        case .wordSearch: "Word Search"
        case .scramble: "Scramble"
        case .crossword: "Crossword"
        case .whoAmI: "Who?"
        case .wordle: "Word"
        case .trivia: "Trivia"
        case .reviewRound: "Review Round"
        }
    }

    var displayName: String {
        switch self {
        case .quiz: "Quiz"
        case .hangman: "Hangman"
        case .beatTheClock: "Countdown"
        case .bookOrder: "Book Order"
        case .wordSearch: "Word Search"
        case .scramble: "Scramble"
        case .crossword: "Crossword"
        case .whoAmI: "Who?"
        case .wordle: "Word"
        case .trivia: "Trivia"
        case .reviewRound: "Review Round"
        }
    }

    var subtitle: LocalizedStringResource {
        switch self {
        case .quiz: "Test your knowledge"
        case .hangman: "People, places & books"
        case .beatTheClock: "Select the correct answer before time runs out"
        case .bookOrder: "Order the books of the Bible"
        case .wordSearch: "Find the hidden words"
        case .scramble: "Unscramble words found in the Bible"
        case .crossword: "Solve clues about the Bible"
        case .whoAmI: "Identify the person listed from the description"
        case .wordle: "5 letters, 6 tries"
        case .trivia: "How well do you know Bible events & people"
        case .reviewRound: "Previously missed questions"
        }
    }

    var systemImage: String {
        switch self {
        case .quiz: "questionmark.circle.fill"
        case .hangman: "text.word.spacing"
        case .beatTheClock: "hourglass"
        case .bookOrder: "list.number"
        case .wordSearch: "square.grid.3x3.topleft.filled"
        case .scramble: "text.line.first.and.arrowtriangle.forward"
        case .crossword: CrosswordGameView.systemImage
        case .whoAmI: "person.text.rectangle"
        case .wordle: "textformat.abc"
        case .trivia: "questionmark.text.page.fill"
        case .reviewRound: "arrow.clockwise.heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .quiz: .blue
        case .hangman: .teal
        case .beatTheClock: .indigo
        case .bookOrder: .purple
        case .wordSearch: .green
        case .scramble: .pink
        case .crossword: CrosswordGameView.tint
        case .whoAmI: .brown
        case .wordle: .mint
        case .trivia: .cyan
        case .reviewRound: .red
        }
    }
}

enum GameLearningGroup: CaseIterable, Identifiable {
    case daily
    case learn
    case wordGames

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .daily: "Daily"
        case .learn: "Learn"
        case .wordGames: "Word Games"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .daily: "Short practices to return to each day."
        case .learn: "Build familiarity with people, places, and Bible knowledge."
        case .wordGames: "Find and recognize Bible words."
        }
    }

    var routes: [GameRoute] {
        switch self {
        case .daily: [.wordle]
        case .learn: [.bookOrder, .beatTheClock, .quiz, .trivia, .whoAmI]
        case .wordGames: [.crossword, .hangman, .scramble, .wordSearch]
        }
    }
}

struct DailyWordResult: Codable {
    let won: Bool
    let guesses: Int
    let elapsed: Int
    let word: String
}

enum GameProgress: Equatable {
    case standard(String)
    case dailyWord(word: String, won: Bool)
}

enum ReviewRoundDestination: Hashable {
    case game(String)
}

struct ReviewRoundProgress: Identifiable {
    let game: MissedGameQuestionStore.Entry.Game
    let count: Int

    var id: String { game.rawValue }
    var isReady: Bool { count >= 10 }

    var title: LocalizedStringResource {
        switch game {
        case .beatTheClock: "Countdown"
        case .bibleQuiz: "Quiz"
        case .bibleTrivia: "Trivia"
        case .quizReverse: "Quiz — Reverse"
        case .whoAmI: "Who?"
        case .bookOrder: "Book Order"
        }
    }
}

enum GameRecommendationDestination {
    case game(GameRoute)

    var accessibilityHint: String {
        switch self {
        case .game(let route):
            "Opens \(route.displayName)"
        }
    }
}

struct GameRecommendation {
    let title: String
    let detail: String
    let systemImage: String
    let destination: GameRecommendationDestination
}
