import Foundation
import Testing
@testable import Bible

/// A review round's timer (its difficulty) is its own: changing it plays the review at that
/// difficulty but leaves the game's saved difficulty, which its main start page opens on, alone.
@Suite(.serialized)
@MainActor
struct ReviewDifficultyIndependenceTests {
    /// Saves `easy` as the game's difficulty, then checks that changing it to `hard` in a review
    /// leaves the saved one alone, while changing it in a normal game saves it.
    private func check(
        key: String,
        easy: String,
        hard: String,
        changeInReview: () -> Void,
        changeInGame: () -> Void
    ) async {
        await StandardDefaultsLock.lock()
        defer { StandardDefaultsLock.unlock() }
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: key)
        defer {
            if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) }
        }

        defaults.set(easy, forKey: key)
        changeInReview()
        #expect(defaults.string(forKey: key) == easy, "A review changed \(key)")
        changeInGame()
        #expect(defaults.string(forKey: key) == hard, "A normal game didn't save \(key)")
    }

    private var noMisses: MissedGameQuestionStore { MissedGameQuestionStore(entries: []) }

    @Test func quiz() async {
        await check(key: AppStorageKey.quizDifficulty, easy: QuizDifficulty.easy.rawValue, hard: QuizDifficulty.hard.rawValue) {
            QuizGameViewModel(reviewQuestionIDs: ["John|3|16"], missedQuestions: noMisses).difficulty = .hard
        } changeInGame: {
            QuizGameViewModel(missedQuestions: noMisses).difficulty = .hard
        }
    }

    @Test func countdown() async {
        await check(key: AppStorageKey.beatTheClockDifficulty, easy: BeatTheClockDifficulty.easy.rawValue, hard: BeatTheClockDifficulty.hard.rawValue) {
            BeatTheClockGameViewModel(reviewQuestionIDs: ["person-1"], missedQuestions: noMisses).difficulty = .hard
        } changeInGame: {
            BeatTheClockGameViewModel(missedQuestions: noMisses).difficulty = .hard
        }
    }

    @Test func whoAmI() async {
        typealias Difficulty = WhoAmIGameViewModel.Difficulty
        await check(key: AppStorageKey.whoAmIDifficulty, easy: Difficulty.easy.rawValue, hard: Difficulty.hard.rawValue) {
            WhoAmIGameViewModel(reviewQuestionIDs: ["who-1"], missedQuestions: noMisses).difficulty = .hard
        } changeInGame: {
            WhoAmIGameViewModel(missedQuestions: noMisses).difficulty = .hard
        }
    }

    @Test func trivia() async {
        await check(key: AppStorageKey.triviaDifficulty, easy: BibleTriviaDifficulty.easy.rawValue, hard: BibleTriviaDifficulty.hard.rawValue) {
            BibleTriviaGameModel(reviewQuestionIDs: ["1"], missedQuestions: noMisses).difficulty = .hard
        } changeInGame: {
            BibleTriviaGameModel(missedQuestions: noMisses).difficulty = .hard
        }
    }

    @Test func hangman() async {
        await check(key: AppStorageKey.hangmanDifficulty, easy: HangmanDifficulty.easy.rawValue, hard: HangmanDifficulty.hard.rawValue) {
            HangmanGameViewModel(reviewQuestionIDs: ["MOSES"], missedQuestions: noMisses).difficulty = .hard
        } changeInGame: {
            HangmanGameViewModel(missedQuestions: noMisses).difficulty = .hard
        }
    }

    @Test func scramble() async {
        typealias Difficulty = ScrambleGameViewModel.Difficulty
        await check(key: "scrambleDifficulty", easy: Difficulty.easy.rawValue, hard: Difficulty.hard.rawValue) {
            ScrambleGameViewModel(reviewQuestionIDs: ["MOSES"], missedQuestions: noMisses).difficulty = .hard
        } changeInGame: {
            ScrambleGameViewModel(missedQuestions: noMisses).difficulty = .hard
        }
    }

    @Test func bookOrder() async {
        await check(key: AppStorageKey.bookOrderDifficulty, easy: BookOrderDifficulty.easy.rawValue, hard: BookOrderDifficulty.hard.rawValue) {
            BookOrderGameViewModel(reviewBooks: ["Ruth"], reviewMode: .beforeAfter, missedQuestions: noMisses).difficulty = .hard
        } changeInGame: {
            BookOrderGameViewModel(missedQuestions: noMisses).difficulty = .hard
        }
    }
}
