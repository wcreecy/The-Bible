import Foundation

/// The best round score (in points, so bonuses count) for each game, difficulty, and mode.
///
/// Scores live in the app's saved settings, one value per key, and sync through iCloud with the
/// other game data so every device shows the same best. Games that award bonus points can score
/// more than their number of questions.
enum GameBestScore {
    /// Which score a round competes for. Standard and Reverse Quiz, and each Countdown mode,
    /// score on different scales, so each keeps its own best.
    enum Kind: CaseIterable {
        case quiz
        case quizReverse
        case trivia
        case whoAmI
        /// Countdown's Classic mode, which keeps Countdown's original key.
        case countdown
        case countdownSurvival
        case countdownFirstAppearance
        case countdownHigherOrLower

        /// The saved key for a difficulty (`easy`, `normal`, or `hard`).
        func key(difficulty: String) -> String {
            switch self {
            // Quiz and Who? keep their original keys, so a best saved earlier carries over.
            case .quiz: "quizBestGameScore_\(difficulty)"
            case .quizReverse: "quizReverseBestGameScore_\(difficulty)"
            case .trivia: "bibleTriviaBestScore.\(difficulty)"
            case .whoAmI: "whoamiBestGameScore_\(difficulty)"
            case .countdown: "beatclockBestGameScore_\(difficulty)"
            case .countdownSurvival: "beatclockSurvivalBestGameScore_\(difficulty)"
            case .countdownFirstAppearance: "beatclockFirstAppearanceBestGameScore_\(difficulty)"
            case .countdownHigherOrLower: "beatclockHigherOrLowerBestGameScore_\(difficulty)"
            }
        }
    }

    static let difficulties = ["easy", "normal", "hard"]

    /// Every best-score key, for iCloud sync and for clearing with the rest of the game data.
    static let allKeys: [String] = Kind.allCases.flatMap { kind in
        difficulties.map { kind.key(difficulty: $0) }
    }

    /// The saved best for a key, or 0 if there isn't one.
    static func value(forKey key: String, defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: key)
    }

    /// The best-score kinds behind a game's name on the stats page. Nil for games without one.
    /// Countdown's modes score on different scales, so only Survival, its main mode, shows there.
    static func kinds(forDisplayName name: String) -> [Kind]? {
        switch name {
        case "Quiz": [.quiz, .quizReverse]
        case "Trivia": [.trivia]
        case "Who?": [.whoAmI]
        case "Countdown": [.countdownSurvival]
        default: nil
        }
    }

    /// The title-cased name of a saved difficulty, for the stats chip.
    static func difficultyTitle(_ difficulty: String) -> String {
        switch difficulty {
        case "easy": String(localized: "Easy")
        case "hard": String(localized: "Hard")
        default: String(localized: "Normal")
        }
    }

    /// The highest saved best across a game's difficulties, with the difficulty it was set on.
    static func highest(
        for kinds: [Kind],
        defaults: UserDefaults = .standard
    ) -> (points: Int, difficulty: String)? {
        var result: (points: Int, difficulty: String)?
        for kind in kinds {
            for difficulty in difficulties {
                let points = value(forKey: kind.key(difficulty: difficulty), defaults: defaults)
                if points > (result?.points ?? 0) {
                    result = (points, difficulty)
                }
            }
        }
        return result
    }
}

/// What a finished round did to the saved best, for the end-of-round screen.
struct RoundBest: Equatable {
    let points: Int
    let isNew: Bool
}
