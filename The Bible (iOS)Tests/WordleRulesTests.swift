import Foundation
import Testing
@testable import Bible

@MainActor
struct WordleRulesTests {
    typealias KeyState = WordleKeyState

    // MARK: - Judging a guess

    @Test
    func aMatchingGuessIsAllCorrect() {
        #expect(WordleRules.evaluate(guess: "PLANT", against: "PLANT") == Array(repeating: KeyState.correct, count: 5))
    }

    @Test
    func lettersNotInTheWordAreAbsent() {
        #expect(WordleRules.evaluate(guess: "QUICK", against: "PLANT") == Array(repeating: KeyState.absent, count: 5))
    }

    @Test
    func aRepeatedLetterIsOnlyMarkedAsOftenAsTheWordHasIt() {
        // ABIDE has one E, so only the first E in SPEED is yellow.
        #expect(WordleRules.evaluate(guess: "SPEED", against: "ABIDE") == [.absent, .absent, .present, .absent, .present])
    }

    @Test
    func greenLettersAreClaimedBeforeYellowOnes() {
        // THEME has two Es, and both are matched in place, so none is left for the E at position 2.
        #expect(WordleRules.evaluate(guess: "GEESE", against: "THEME") == [.absent, .absent, .correct, .absent, .correct])
    }

    @Test
    func aLetterInTheRightPlaceUsesUpTheMatchBeforeAYellowDoes() {
        // LLAMA has two Ls and two As: the L at position 2 is green, the other L and the A are yellow.
        #expect(WordleRules.evaluate(guess: "ALLOW", against: "LLAMA") == [.present, .correct, .present, .absent, .absent])
    }

    // MARK: - Keyboard colors

    @Test
    func keyStatesMergeByPrecedence() {
        #expect(KeyState.merged(.unknown, .absent) == .absent)
        #expect(KeyState.merged(.absent, .present) == .present)
        #expect(KeyState.merged(.present, .correct) == .correct)
        #expect(KeyState.merged(.correct, .absent) == .correct)
        #expect(KeyState.merged(.present, .absent) == .present)
    }

    @Test
    func aKeyNeverMovesDownAfterAGuess() {
        let before: [Character: KeyState] = ["A": .correct, "B": .absent]

        let after = WordleRules.mergedKeyboardStates(
            before,
            guess: "ABCDE",
            evaluation: [.absent, .present, .correct, .absent, .unknown]
        )

        #expect(after["A"] == .correct)
        #expect(after["B"] == .present)
        #expect(after["C"] == .correct)
        #expect(after["D"] == .absent)
        #expect(after["E"] == .unknown)
        #expect(before["B"] == .absent)
    }

    // MARK: - Hard Mode

    /// A board with the given guesses played against a target, padded to six rows as the game keeps it.
    private func board(target: String, guesses played: [String]) -> (guesses: [String], evaluations: [[KeyState]]) {
        var guesses = Array(repeating: "", count: 6)
        var evaluations = Array(repeating: Array(repeating: KeyState.unknown, count: 5), count: 6)
        for (row, guess) in played.enumerated() {
            guesses[row] = guess
            evaluations[row] = WordleRules.evaluate(guess: guess, against: target)
        }
        return (guesses, evaluations)
    }

    private func violation(_ guess: String, target: String, after played: [String]) -> String? {
        let board = board(target: target, guesses: played)
        return WordleRules.hardModeViolation(
            for: guess,
            guesses: board.guesses,
            evaluations: board.evaluations,
            playedRows: played.count
        )
    }

    @Test
    func theFirstGuessIsNeverRestricted() {
        #expect(violation("QUICK", target: "PLANT", after: []) == nil)
    }

    @Test
    func hardModeCollectsGreensYellowsAndRuledOutPositions() {
        // PANTS against PLANT: P is green; A, N and T are yellow at positions 2, 3 and 4.
        let board = board(target: "PLANT", guesses: ["PANTS"])

        let constraints = WordleRules.hardModeConstraints(
            guesses: board.guesses,
            evaluations: board.evaluations,
            playedRows: 1
        )

        #expect(constraints.greens == [0: "P"])
        #expect(constraints.minCount == ["P": 1, "A": 1, "N": 1, "T": 1])
        #expect(constraints.disallowedPositions == ["A": [1], "N": [2], "T": [3]])
    }

    @Test
    func aGreenLetterMustStayInPlace() {
        #expect(violation("SLANT", target: "PLANT", after: ["PANTS"]) == "Hard Mode: must keep P at position 1")
    }

    @Test
    func everyYellowLetterMustBeReused() {
        // PLAIN keeps the P and uses A and N, but drops the T.
        #expect(violation("PLAIN", target: "PLANT", after: ["PANTS"]) == "Hard Mode: must include 1 T")
    }

    @Test
    func aYellowLetterCannotReturnToThePositionItWasRuledOutOf() {
        // PALNT has every required letter, but the A is back at position 2.
        #expect(violation("PALNT", target: "PLANT", after: ["PANTS"]) == "Hard Mode: A cannot be at position 2")
    }

    @Test
    func reusingTheLettersInNewPositionsIsAllowed() {
        #expect(violation("PTANL", target: "PLANT", after: ["PANTS"]) == nil)
        #expect(violation("PLANT", target: "PLANT", after: ["PANTS"]) == nil)
    }

    @Test
    func aLetterFoundTwiceMustBeUsedTwice() {
        // ALLOW against LLAMA finds two Ls (one green, one yellow), so ALARM, with one L, isn't enough.
        #expect(violation("ALARM", target: "LLAMA", after: ["ALLOW"]) == "Hard Mode: must include 2 Ls")
    }

    @Test
    func aRowOfTheWrongLengthPlacesNoConstraint() {
        var board = board(target: "PLANT", guesses: [])
        board.guesses[0] = "PAN"

        let constraints = WordleRules.hardModeConstraints(guesses: board.guesses, evaluations: board.evaluations, playedRows: 1)

        #expect(constraints.greens.isEmpty)
        #expect(constraints.minCount.isEmpty)
    }
}

/// A deterministic generator, so the picker's random choices can be repeated in tests.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@MainActor
struct WordleWordPickerTests {
    private let pool = ["AAAAA", "BBBBB", "CCCCC", "DDDDD", "EEEEE"]

    /// A picker backed by a private defaults suite, removed when the test finishes.
    private func withPicker(
        limit: Int = 365,
        _ body: (WordleWordPicker, UserDefaults) throws -> Void
    ) rethrows {
        let suite = "wordle-picker-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(
            WordleWordPicker(
                defaults: defaults,
                practiceBagKey: "bag",
                lastPracticeWordKey: "last",
                dailyAssignmentKey: "assignment",
                recentDailyWordsKey: "recent",
                recentDailyWordLimit: limit
            ),
            defaults
        )
    }

    // MARK: - Practice

    @Test
    func anEmptyPoolFallsBackToJesus() {
        withPicker { picker, _ in
            var generator = SplitMix64(seed: 1)
            #expect(picker.nextPracticeWord(pool: [], using: &generator) == "JESUS")
            #expect(picker.wordOfDay(pool: [], dayKey: "2026-10-30", using: &generator) == "JESUS")
        }
    }

    @Test
    func practiceUsesEveryWordBeforeAnyRepeats() {
        withPicker { picker, _ in
            var generator = SplitMix64(seed: 7)
            let drawn = (0..<pool.count).map { _ in picker.nextPracticeWord(pool: pool, using: &generator) }

            #expect(Set(drawn) == Set(pool))
            #expect(drawn.count == Set(drawn).count)
            #expect(pool.contains(picker.nextPracticeWord(pool: pool, using: &generator)))
        }
    }

    @Test
    func aNewPracticeBagNeverStartsWithTheWordThatEndedTheLastOne() {
        for seed in 0..<50 {
            withPicker { picker, _ in
                var generator = SplitMix64(seed: UInt64(seed))
                let twoWords = ["AAAAA", "BBBBB"]
                let drawn = (0..<4).map { _ in picker.nextPracticeWord(pool: twoWords, using: &generator) }

                #expect(drawn[0] != drawn[1])
                #expect(drawn[1] != drawn[2], "Seed \(seed) repeated a word across bags: \(drawn)")
                #expect(drawn[2] != drawn[3])
            }
        }
    }

    @Test
    func practiceDropsSavedWordsThatLeftThePool() {
        withPicker { picker, defaults in
            defaults.set(["GONEX", "AAAAA"], forKey: "bag")
            var generator = SplitMix64(seed: 3)

            #expect(picker.nextPracticeWord(pool: ["AAAAA", "BBBBB"], using: &generator) == "AAAAA")
            #expect(defaults.stringArray(forKey: "bag") == [])
        }
    }

    // MARK: - Daily

    @Test
    func theDailyWordStaysTheSameAllDay() {
        withPicker { picker, _ in
            var first = SplitMix64(seed: 1)
            var second = SplitMix64(seed: 99)

            let morning = picker.wordOfDay(pool: pool, dayKey: "2026-10-30", using: &first)
            let evening = picker.wordOfDay(pool: pool, dayKey: "2026-10-30", using: &second)

            #expect(pool.contains(morning))
            #expect(evening == morning)
        }
    }

    @Test
    func eachNewDayPicksAWordNotUsedRecently() {
        withPicker { picker, defaults in
            let threeWords = ["AAAAA", "BBBBB", "CCCCC"]
            var generator = SplitMix64(seed: 5)

            let day1 = picker.wordOfDay(pool: threeWords, dayKey: "2026-10-28", using: &generator)
            let day2 = picker.wordOfDay(pool: threeWords, dayKey: "2026-10-29", using: &generator)
            let day3 = picker.wordOfDay(pool: threeWords, dayKey: "2026-10-30", using: &generator)

            #expect(Set([day1, day2, day3]).count == 3)
            #expect(defaults.stringArray(forKey: "recent") == [day1, day2, day3])
        }
    }

    @Test
    func whenEveryWordWasUsedRecentlyTheDailyStillPicksOne() {
        withPicker { picker, defaults in
            defaults.set(["AAAAA", "BBBBB"], forKey: "recent")
            var generator = SplitMix64(seed: 2)

            #expect(["AAAAA", "BBBBB"].contains(picker.wordOfDay(pool: ["AAAAA", "BBBBB"], dayKey: "2026-10-30", using: &generator)))
        }
    }

    @Test
    func todaysWordSurvivesTheAnswerListChanging() {
        withPicker { picker, _ in
            var generator = SplitMix64(seed: 4)
            let assigned = picker.wordOfDay(pool: pool, dayKey: "2026-10-30", using: &generator)

            let later = picker.wordOfDay(pool: ["ZZZZZ"], dayKey: "2026-10-30", using: &generator)

            #expect(later == assigned)
        }
    }

    @Test
    func anAssignmentWithAWordOfTheWrongLengthIsReplaced() throws {
        try withPicker { picker, defaults in
            let bad = try JSONSerialization.data(withJSONObject: ["dayKey": "2026-10-30", "word": "ABC"])
            defaults.set(bad, forKey: "assignment")
            var generator = SplitMix64(seed: 6)

            let word = picker.wordOfDay(pool: pool, dayKey: "2026-10-30", using: &generator)

            #expect(pool.contains(word))
        }
    }

    @Test
    func anUnreadableAssignmentIsReplacedWithoutCrashing() {
        withPicker { picker, defaults in
            defaults.set(Data("not json".utf8), forKey: "assignment")
            var generator = SplitMix64(seed: 8)

            let word = picker.wordOfDay(pool: pool, dayKey: "2026-10-30", using: &generator)

            #expect(pool.contains(word))
        }
    }

    @Test
    func theRecentListKeepsOnlyTheLatestWords() {
        withPicker(limit: 3) { picker, defaults in
            let sixWords = ["AAAAA", "BBBBB", "CCCCC", "DDDDD", "EEEEE", "FFFFF"]
            var generator = SplitMix64(seed: 11)
            var picked: [String] = []

            for day in 1...5 {
                picked.append(picker.wordOfDay(pool: sixWords, dayKey: "2026-10-0\(day)", using: &generator))
            }

            #expect(defaults.stringArray(forKey: "recent") == Array(picked.suffix(3)))
        }
    }
}
