import SwiftUI

// Scramble setup choices. Declared on ScrambleGameView so existing references
// (ScrambleGameView.Difficulty, ScrambleGameViewModel.Difficulty) keep working.
extension ScrambleGameView {
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy
        case normal
        case hard

        var id: Self { self }

        var experienceLevel: GameExperienceLevel {
            switch self {
            case .easy: .learn
            case .normal: .standard
            case .hard: .challenge
            }
        }

        init(experienceLevel: GameExperienceLevel) {
            switch experienceLevel {
            case .learn: self = .easy
            case .standard: self = .normal
            case .challenge: self = .hard
            }
        }

        var timeLimit: Int? {
            switch self {
            case .easy: 45
            case .normal: 30
            case .hard: 30
            }
        }

        var timerLabel: String {
            switch self {
            case .easy: String(localized: "45 seconds")
            case .normal: String(localized: "30 seconds")
            case .hard: String(localized: "30 seconds")
            }
        }

        var hintLimit: Int {
            switch self {
            case .easy, .normal: 1
            case .hard: 2
            }
        }

        var hintLabel: String {
            switch hintLimit {
            case 1: String(localized: "1 hint")
            default: String(localized: "\(hintLimit) hints")
            }
        }

        var detail: LocalizedStringKey {
            switch self {
            case .easy: "Familiar words with 45 seconds per word."
            case .normal: "A broader word list with 30 seconds per word."
            case .hard: "Tougher words with 30 seconds per word."
            }
        }

        var statsDifficulty: GameStats.Difficulty {
            switch self {
            case .easy: .easy
            case .normal: .normal
            case .hard: .hard
            }
        }
    }

    enum SessionLength: Int, CaseIterable, Identifiable {
        case short = 5
        case quick = 10
        case extended = 20

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .short: "5 words"
            case .quick: "10 words"
            case .extended: "20 words"
            }
        }
    }
}
