import SwiftUI

/// How a letter on the board or the keyboard was judged.
enum WordleKeyState: Int {
    case unknown = 0
    case absent   // gray
    case present  // yellow
    case correct  // green

    // Keep the “max” precedence when merging states (correct > present > absent > unknown)
    static func merged(_ a: WordleKeyState, _ b: WordleKeyState) -> WordleKeyState {
        return (a.rawValue >= b.rawValue) ? a : b
    }

    var tint: Color {
        switch self {
        case .unknown: return .blue
        case .absent:  return .gray
        case .present: return .yellow
        case .correct: return .green
        }
    }
}

/// The Word game's rules, apart from the screen: judging a guess, keeping the keyboard colors,
/// and Hard Mode. They take the board as plain values so they can be tested.
enum WordleRules {
    typealias KeyState = WordleKeyState

    // Standard Wordle evaluation (two-pass to handle duplicates)
    static func evaluate(guess: String, against target: String) -> [KeyState] {
        var result = Array(repeating: KeyState.absent, count: 5)
        var targetChars = Array(target)
        let guessChars = Array(guess)

        // First pass: correct positions
        for i in 0..<5 {
            if guessChars[i] == targetChars[i] {
                result[i] = .correct
                targetChars[i] = "*" // mark used
            }
        }
        // Second pass: present letters
        for i in 0..<5 where result[i] != .correct {
            if let idx = targetChars.firstIndex(of: guessChars[i]) {
                result[i] = .present
                targetChars[idx] = "*" // mark used
            } else {
                result[i] = .absent
            }
        }
        return result
    }

    /// The keyboard colors after a guess. A letter only ever moves up: correct, then present,
    /// then absent, then unknown.
    static func mergedKeyboardStates(
        _ keyboardStates: [Character: KeyState],
        guess: String,
        evaluation: [KeyState]
    ) -> [Character: KeyState] {
        var states = keyboardStates
        for (i, ch) in guess.enumerated() {
            let old = states[ch] ?? .unknown
            states[ch] = KeyState.merged(old, evaluation[i])
        }
        return states
    }

    // MARK: - Hard Mode constraints

    struct HardModeConstraints {
        /// Letters that must stay where they were found.
        var greens: [Int: Character]
        /// How many of each letter every later guess must include.
        var minCount: [Character: Int]
        /// Positions a letter was found to be wrong in.
        var disallowedPositions: [Character: Set<Int>]
    }

    /// What the first `playedRows` guesses require of the next one.
    static func hardModeConstraints(guesses: [String], evaluations: [[KeyState]], playedRows: Int) -> HardModeConstraints {
        var greens: [Int: Character] = [:]
        var minCount: [Character: Int] = [:]
        var disallowed: [Character: Set<Int>] = [:]

        for r in 0..<playedRows {
            let g = guesses[r]
            guard g.count == 5 else { continue }
            let eval = evaluations[r]
            var perRowCounts: [Character: Int] = [:]

            for i in 0..<5 {
                let ch = Array(g)[i]
                switch eval[i] {
                case .correct:
                    greens[i] = ch
                    perRowCounts[ch, default: 0] += 1
                case .present:
                    disallowed[ch, default: []].insert(i)
                    perRowCounts[ch, default: 0] += 1
                case .absent, .unknown:
                    break
                }
            }

            for (ch, c) in perRowCounts {
                if let old = minCount[ch] {
                    if c > old { minCount[ch] = c }
                } else {
                    minCount[ch] = c
                }
            }
        }

        return HardModeConstraints(greens: greens, minCount: minCount, disallowedPositions: disallowed)
    }

    /// Why a guess breaks Hard Mode, or nil when it keeps every green, uses every yellow, and
    /// doesn't repeat a position already ruled out.
    static func hardModeViolation(for guess: String, guesses: [String], evaluations: [[KeyState]], playedRows: Int) -> String? {
        let constraints = hardModeConstraints(guesses: guesses, evaluations: evaluations, playedRows: playedRows)
        let greens = constraints.greens
        let minCount = constraints.minCount
        let disallowed = constraints.disallowedPositions
        let guessChars = Array(guess)

        for (idx, ch) in greens {
            if guessChars[idx] != ch {
                return "Hard Mode: must keep \(ch) at position \(idx + 1)"
            }
        }

        var guessCounts: [Character: Int] = [:]
        for ch in guessChars {
            guessCounts[ch, default: 0] += 1
        }
        for (ch, required) in minCount {
            let have = guessCounts[ch] ?? 0
            if have < required {
                return "Hard Mode: must include \(required) \(ch)\(required > 1 ? "s" : "")"
            }
        }

        for (ch, badPositions) in disallowed {
            for idx in badPositions {
                if guessChars[idx] == ch {
                    return "Hard Mode: \(ch) cannot be at position \(idx + 1)"
                }
            }
        }

        return nil
    }
}

/// Chooses the answer for a Practice round and for the Daily, remembering what it picked in
/// `UserDefaults` so words don't repeat too soon.
struct WordleWordPicker {
    let defaults: UserDefaults
    let practiceBagKey: String
    let lastPracticeWordKey: String

    /// Practice answers come out of a shuffled bag, so every word is used before any repeats. A
    /// new bag never starts with the word that ended the last one.
    func nextPracticeWord<G: RandomNumberGenerator>(pool: [String], using generator: inout G) -> String {
        guard !pool.isEmpty else { return "JESUS" }

        let eligibleWords = Set(pool)
        var bag = (defaults.stringArray(forKey: practiceBagKey) ?? [])
            .filter { eligibleWords.contains($0) }

        if bag.isEmpty {
            bag = pool.shuffled(using: &generator)

            if bag.count > 1,
               let lastWord = defaults.string(forKey: lastPracticeWordKey),
               bag.last == lastWord {
                bag.swapAt(0, bag.count - 1)
            }
        }

        let nextWord = bag.removeLast()
        defaults.set(bag, forKey: practiceBagKey)
        defaults.set(nextWord, forKey: lastPracticeWordKey)
        return nextWord
    }

    /// Today's Daily WORD comes from the release-bundled shared schedule. The schedule is a
    /// seeded full shuffle of the curated answer IDs, so every device gets the same answer and
    /// each answer appears once before the cycle repeats.
    func wordOfDay<G: RandomNumberGenerator>(pool: [String], dayKey: String, using generator: inout G) -> String {
        guard !pool.isEmpty else { return "JESUS" }

        let eligibleWords = Set(pool.map { $0.uppercased() })
        let dailyWordKey = "\(practiceBagKey).daily.\(dayKey)"

        if let savedWord = defaults.string(forKey: dailyWordKey),
           eligibleWords.contains(savedWord.uppercased()) {
            return savedWord
        }

        let selectedWord = WordleDailySchedule.word(for: dayKey, pool: pool)
            ?? pool.randomElement(using: &generator)
            ?? "JESUS"
        defaults.set(selectedWord, forKey: dailyWordKey)
        return selectedWord
    }
}
