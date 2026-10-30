import Foundation
import Testing
@testable import Bible

#if DEBUG
/// The developer reset writes each game setting as a string. A string that isn't one of the
/// enum's raw values is ignored when the game reads it, so the game quietly falls back to its
/// own default. These tests make the reset say the right thing in the first place.
@MainActor
struct DeveloperSettingsResetTests {
    /// Each game setting the reset writes, with a check that a value is a real raw value of its enum.
    private let gameSettings: [(key: String, isValid: (String) -> Bool)] = [
        (AppStorageKey.beatTheClockDifficulty, { BeatTheClockDifficulty(rawValue: $0) != nil }),
        (AppStorageKey.beatTheClockCategory, { BeatTheClockCategory(rawValue: $0) != nil }),
        (AppStorageKey.hangmanDifficulty, { HangmanDifficulty(rawValue: $0) != nil }),
        (AppStorageKey.hangmanTheme, { HangmanTheme(rawValue: $0) != nil }),
        (AppStorageKey.verseMatchDifficulty, { VerseMatchDifficulty(rawValue: $0) != nil }),
        (AppStorageKey.quizDifficulty, { QuizDifficulty(rawValue: $0) != nil }),
        ("scrambleDifficulty", { ScrambleGameView.Difficulty(rawValue: $0) != nil })
    ]

    @Test
    func everyGameSettingIsResetToARealValue() {
        for setting in gameSettings {
            let value = DeveloperSettingsReset.defaultValues[setting.key] as? String

            #expect(value != nil, "\(setting.key) isn't reset to a string")
            #expect(setting.isValid(value ?? ""), "\(setting.key) is reset to \"\(value ?? "nil")\", which isn't one of its values")
        }
    }

    /// Runs `body` with the stored game settings cleared, so each game shows its own defaults,
    /// then puts the stored settings back.
    private func withNoStoredGameSettings(_ body: () -> Void) {
        let defaults = UserDefaults.standard
        let keys = gameSettings.map(\.key)
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        keys.forEach { defaults.removeObject(forKey: $0) }
        body()
    }

    @Test
    func theResetMatchesWhatEachGameStartsWith() {
        withNoStoredGameSettings {
            let reset = DeveloperSettingsReset.defaultValues
            let countdown = BeatTheClockGameViewModel()
            let hangman = HangmanGameViewModel()

            #expect(reset[AppStorageKey.beatTheClockDifficulty] as? String == countdown.difficulty.rawValue)
            #expect(reset[AppStorageKey.beatTheClockCategory] as? String == countdown.category.rawValue)
            #expect(reset[AppStorageKey.hangmanDifficulty] as? String == hangman.difficulty.rawValue)
            #expect(reset[AppStorageKey.hangmanTheme] as? String == hangman.theme.rawValue)
            #expect(reset[AppStorageKey.verseMatchDifficulty] as? String == VerseMatchGameViewModel().difficulty.rawValue)
            #expect(reset[AppStorageKey.quizDifficulty] as? String == QuizGameViewModel().difficulty.rawValue)
        }
    }
}
#endif
