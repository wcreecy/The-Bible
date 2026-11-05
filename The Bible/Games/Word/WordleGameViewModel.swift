import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The state and rules of a WORD game: the board, guesses, streaks, and the Daily and
/// Practice words. `WordleView` lays it out and handles the keyboard.
@MainActor
@Observable
final class WordleGameViewModel {
    typealias Mode = WordleView.Mode
    typealias KeyState = WordleKeyState

    /// Saved under the keys the game has always used, so existing choices carry over.
    var mode: Mode = Mode(rawValue: UserDefaults.standard.string(forKey: "wordleMode") ?? "") ?? .practice {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "wordleMode") }
    }

    var hardModeEnabled: Bool = UserDefaults.standard.bool(forKey: AppStorageKey.wordleHardModeEnabled) {
        didSet { UserDefaults.standard.set(hardModeEnabled, forKey: AppStorageKey.wordleHardModeEnabled) }
    }

    // MARK: - State
    var started: Bool = false

    var isAnswerBankPrepared: Bool = false

    var target: String = ""

    var guesses: [String] = Array(repeating: "", count: 6)

    var evaluations: [[KeyState]] = Array(repeating: Array(repeating: .unknown, count: 5), count: 6)

    var rowIndex: Int = 0

    var currentInput: String = ""

    var didWin: Bool = false

    var roundOver: Bool = false

    var message: String? = nil

    var keyboardStates: [Character: KeyState] = [:]

    nonisolated static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    // Pinned letters stay fixed in the active row until their tile is tapped again.
    var pinned: [[Character?]] = Array(repeating: Array(repeating: nil, count: 5), count: 6)

    // Session stats (for the scoreboard’s Current section)
    var score: Int = 0

    var answered: Int = 0

    var currentStreak: Int = 0

    var currentBestStreak: Int = 0

    var practiceStreak: Int = 0

    var practiceBestStreak: Int = 0

    // Difficulty captured when a round starts, so a round keeps its rules even if the setting changes.
    var roundHardMode: Bool = false

    // Daily
    /// Daily results are stored by day and read back by `GameStats`, so both use its day key.
    var todayKey: String { GameStats.localDayKey(for: Date()) }

    var dailyCompletedToday: Bool {
        UserDefaults.standard.string(forKey: AppStorageKey.wordleDailyCompletedDay) == todayKey
    }

    // timing for each round
    /// Solve time. It only runs while the app is in front, so time away doesn't count.
    var roundClock = GameActiveClock()

    // store elapsed seconds for the last round to show in the bottom chip
    var lastRoundElapsedSeconds: Int? = nil

    // End-of-round result
    /// True when the round just finished raised the best streak for its mode.
    var isNewBestStreak: Bool = false

    /// All-time wins by guess count for the round's mode, read once when the round ends.
    var guessDistribution: [Int] = []

    // MARK: - Persistent WORD streak (overall, survives app relaunch)
    let persistentStreak = PersistentGameStreak(game: "wordle")

    /// The Practice streak: solved Practice words in a row, kept until a Practice word is missed.
    let practicePersistentStreak = PersistentGameStreak(game: "wordle", variant: "practice")

    let practiceWordBagKey = AppStorageKey.wordlePracticeWordBag

    let lastPracticeWordKey = AppStorageKey.wordleLastPracticeWord

    let dailyWordAssignmentKey = AppStorageKey.wordleDailyWordAssignment

    let recentDailyWordsKey = AppStorageKey.wordleRecentDailyWords

    let recentDailyWordLimit = 365

    let dailyProgressKey = AppStorageKey.wordleDailyProgress

    #if canImport(UIKit)
    static var spellCheckLanguage: String {
        let languages = UITextChecker.availableLanguages

        return languages.first {
            $0.replacingOccurrences(of: "-", with: "_")
                .caseInsensitiveCompare("en_US") == .orderedSame
        } ?? languages.first {
            $0.lowercased().hasPrefix("en")
        } ?? "en_US"
    }
    #endif

    // MARK: - Answer verse
    struct VerseRefInfo: Sendable {
        let bookName: String
        let chapter: Int
        let verse: Int
        let text: String
        var display: String { "\(bookName) \(chapter):\(verse)" }
    }

    // The answer pool and a verse reference for each word.
    struct AnswerBank: Sendable {
        let words: [String]
        let verseIndex: [String: VerseRefInfo]
    }

    /// One entry in the bundled curated list; `verse_source` is editorial metadata and is ignored.
    struct CuratedWord: Decodable, Sendable {
        let word: String
        let reference: String
        let verse: String
    }

    /// Hand-curated answers, each with a verse that contains the word. Nil when the file
    /// is missing or yields no usable entries.
    nonisolated static let curatedAnswerBank: AnswerBank? = {
        guard let url = Bundle.main.url(forResource: "WORDCuratedWordList", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = PersistedDecoding.decode([CuratedWord].self, from: data, name: "WORDCuratedWordList.json") else {
            print("⚠️ WORDCuratedWordList.json could not be loaded or decoded.")
            return nil
        }

        var index: [String: VerseRefInfo] = [:]
        for entry in entries {
            let word = entry.word.uppercased()
            guard word.count == 5, word.allSatisfy({ alphabet.contains($0) }),
                  let ref = parseReference(entry.reference, text: entry.verse) else {
                print("⚠️ WORD: skipping curated entry \(entry.word) (\(entry.reference))")
                continue
            }
            index[word] = ref
        }
        guard !index.isEmpty else { return nil }
        return AnswerBank(words: index.keys.sorted(), verseIndex: index)
    }()

    /// Parses "Book C:V" (e.g. "1 Timothy 2:9", "Song of Solomon 8:7").
    nonisolated static func parseReference(_ reference: String, text: String) -> VerseRefInfo? {
        guard let space = reference.lastIndex(of: " ") else { return nil }
        let bookName = String(reference[..<space])
        let parts = reference[reference.index(after: space)...].split(separator: ":")
        guard !bookName.isEmpty, parts.count == 2,
              let chapter = Int(parts[0]), let verse = Int(parts[1]) else { return nil }
        return VerseRefInfo(bookName: bookName, chapter: chapter, verse: verse, text: text)
    }

    /// Used only if the curated list is missing or unreadable. These words have no verse,
    /// so the end-of-round Reference button stays disabled.
    static let fallbackAnswerBank = AnswerBank(
        words: ["JESUS", "GRACE", "FAITH", "ANGEL", "CROSS", "MOSES", "DAVID", "PEACE", "MERCY", "GLORY"],
        verseIndex: [:]
    )

    static var answerBank: AnswerBank { curatedAnswerBank ?? fallbackAnswerBank }

    static var filteredAnswerWords: [String] { answerBank.words }

    static var verseIndex: [String: VerseRefInfo] { answerBank.verseIndex }

    /// Every curated answer is accepted as a guess, so names like MOSES aren't rejected
    /// by the spell checker.
    static let curatedWordSet = Set(answerBank.words)

    /// Loads and indexes the bundled answer list before gameplay begins, off the main actor.
    static func prewarmAnswerBank() async {
        _ = await Task.detached(priority: .userInitiated) {
            curatedAnswerBank
        }.value
    }

    // State for showing reference button and navigating
    var roundRef: VerseRefInfo? = nil

    // Compose the current row’s 5 letters by merging pinned letters at fixed indices
    // with the typed letters (currentInput) in the remaining slots, left-to-right.
    func composedCurrentRow() -> [Character?] {
        var result: [Character?] = Array(repeating: nil, count: 5)
        guard pinned.indices.contains(rowIndex) else { return result }

        let pins = pinned[rowIndex]
        for c in result.indices where pins.indices.contains(c) {
            result[c] = pins[c]
        }
        var typed = Array(currentInput)
        for c in 0..<5 {
            if result[c] == nil, !typed.isEmpty {
                result[c] = typed.removeFirst()
            }
        }
        return result
    }

    func isCurrentRowFull() -> Bool {
        guard !roundOver else { return false }
        let row = composedCurrentRow()
        return row.allSatisfy { $0 != nil }
    }

    // Find the next empty, unlocked column for normal left-to-right typing.
    func nextAvailableColumn() -> Int? {
        guard pinned.indices.contains(rowIndex) else { return nil }

        let row = composedCurrentRow()
        for c in row.indices where pinned[rowIndex].indices.contains(c) {
            if pinned[rowIndex][c] == nil && row[c] == nil {
                return c
            }
        }
        return nil
    }

    // Remove the last non-pinned typed letter; locked letters stay in place.
    func removeLastNonPinnedTypedLetter() {
        _ = currentInput.popLast()
    }

    func tapLetter(_ ch: Character) {
        guard !roundOver else { return }
        let up = Character(String(ch).uppercased())
        guard up.isLetter else { return }

        if nextAvailableColumn() != nil {
            currentInput.append(up)
            message = nil
        }
    }

    func reuseCorrectLetter(_ letter: Character, at column: Int) {
        guard !roundOver, rowIndex < pinned.count, pinned[rowIndex].indices.contains(column) else { return }

        // Preserve letters already typed in their visible positions while replacing this column.
        let rowBeforePinning = composedCurrentRow()
        pinned[rowIndex][column] = letter
        currentInput = String(rowBeforePinning.indices.compactMap { index in
            guard pinned[rowIndex][index] == nil else { return nil }
            return rowBeforePinning[index]
        })
        message = nil
    }

    func deleteLetter() {
        guard !roundOver else { return }
        // Remove last non-pinned typed letter only; do not clear pinned letters
        if currentInput.isEmpty {
            // Nothing typed to remove (all filled might be pinned); do nothing
            return
        }
        removeLastNonPinnedTypedLetter()
    }

    func submitGuess() {
        guard !roundOver else { return }
        // Compose guess from pins + typed
        let row = composedCurrentRow()
        guard row.count == 5, row.allSatisfy({ $0 != nil }) else { return }
        let guess = String(row.compactMap { $0 }).uppercased()

        // Accept the target, any curated answer, or any correctly spelled 5-letter English word
        guard guess == target || Self.curatedWordSet.contains(guess) || isValidWord(guess) else {
            message = "Not in word list"
            return
        }

        // Hard Mode validation (must keep greens; must use yellows elsewhere)
        if roundHardMode, rowIndex > 0 {
            if let violation = hardModeViolation(for: guess) {
                message = violation
                return
            }
        }

        applyGuess(guess)

        if guess == target {
            endRound(win: true)
            return
        }
        if rowIndex >= 6 {
            endRound(win: false)
            return
        }
        // Prepare the next row and ensure its locked-letter slots are empty.
        currentInput = ""
        if rowIndex < pinned.count {
            pinned[rowIndex] = Array(repeating: nil, count: 5)
        }
        message = nil

        if mode == .daily {
            saveDailyProgress()
        }
    }

    /// Records a guess on the board, updates the keyboard colors, and advances to the next row.
    @discardableResult
    func applyGuess(_ guess: String) -> [KeyState] {
        let eval = WordleRules.evaluate(guess: guess, against: target)
        evaluations[rowIndex] = eval
        guesses[rowIndex] = guess
        rowIndex += 1
        mergeKeyboardStates(guess: guess, evaluation: eval)
        return eval
    }

    // Update keyboard states with precedence
    func mergeKeyboardStates(guess: String, evaluation: [KeyState]) {
        keyboardStates = WordleRules.mergedKeyboardStates(keyboardStates, guess: guess, evaluation: evaluation)
    }

    // MARK: - Rules
    // The game's rules live in `WordleRules` and `WordleWordPicker`, where they are tested.

    func hardModeViolation(for guess: String) -> String? {
        WordleRules.hardModeViolation(for: guess, guesses: guesses, evaluations: evaluations, playedRows: rowIndex)
    }

    var wordPicker: WordleWordPicker {
        WordleWordPicker(
            defaults: .standard,
            practiceBagKey: practiceWordBagKey,
            lastPracticeWordKey: lastPracticeWordKey,
            dailyAssignmentKey: dailyWordAssignmentKey,
            recentDailyWordsKey: recentDailyWordsKey,
            recentDailyWordLimit: recentDailyWordLimit
        )
    }

    func nextPracticeWord() -> String {
        var generator = SystemRandomNumberGenerator()
        return wordPicker.nextPracticeWord(pool: Self.filteredAnswerWords, using: &generator)
    }

    /// Today's Daily word: picked at random the first time Daily is played each day and kept for the rest of that day.
    func wordOfDay() -> String {
        var generator = SystemRandomNumberGenerator()
        return wordPicker.wordOfDay(pool: Self.filteredAnswerWords, dayKey: todayKey, using: &generator)
    }

    // MARK: - Daily progress
    // An unfinished Daily is saved after every guess, so leaving and returning resumes
    // the same board instead of granting a fresh set of guesses.
    struct DailyProgress: Codable {
        let dayKey: String
        let word: String
        let hardMode: Bool
        let guesses: [String]
        let elapsedSeconds: Int
    }

    func saveDailyProgress() {
        let elapsed = roundClock.elapsedSeconds()
        let progress = DailyProgress(
            dayKey: todayKey,
            word: target,
            hardMode: roundHardMode,
            guesses: Array(guesses.prefix(rowIndex)),
            elapsedSeconds: elapsed
        )
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: dailyProgressKey)
        }
    }

    /// Restores today's unfinished Daily, if any. Returns true when guesses were restored.
    @discardableResult
    func restoreDailyProgress() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: dailyProgressKey),
              let progress = PersistedDecoding.decode(DailyProgress.self, from: data, key: dailyProgressKey, keepingUnreadableIn: .standard),
              progress.dayKey == todayKey,
              progress.word == target else {
            UserDefaults.standard.removeObject(forKey: dailyProgressKey)
            return false
        }

        // The round keeps the difficulty it was started with.
        roundHardMode = progress.hardMode
        roundClock.start(alreadyElapsed: Double(progress.elapsedSeconds))
        for guess in progress.guesses.prefix(6) where guess.count == 5 {
            applyGuess(guess)
        }

        // Shouldn't happen (finished rounds clear their progress), but never leave a solved board open.
        if guesses.prefix(rowIndex).contains(target) || rowIndex >= 6 {
            endRound(win: guesses.prefix(rowIndex).contains(target))
        }
        return !progress.guesses.isEmpty
    }

    // MARK: - Rounds
    func startNewRound(practice: Bool) {
        roundHardMode = hardModeEnabled

        guesses = Array(repeating: "", count: 6)
        evaluations = Array(repeating: Array(repeating: .unknown, count: 5), count: 6)
        rowIndex = 0
        currentInput = ""
        didWin = false
        roundOver = false
        message = nil
        keyboardStates.removeAll()
        roundRef = nil
        isNewBestStreak = false

        // Reset locked letters.
        pinned = Array(repeating: Array(repeating: nil, count: 5), count: 6)

        // Start timing
        roundClock.start()
        lastRoundElapsedSeconds = nil

        if practice {
            target = nextPracticeWord()
        } else {
            target = wordOfDay()
            restoreDailyProgress()
        }

        started = true
    }

    func endRound(win: Bool) {
        roundOver = true
        didWin = win
        // Clear current input to avoid duplicate rendering.
        currentInput = ""

        roundClock.pause()
        let elapsedSeconds = roundClock.elapsedSeconds()

        lastRoundElapsedSeconds = elapsedSeconds

        if win {
            let tries = rowIndex == 1 ? "1 guess" : "\(rowIndex) guesses"
            message = mode == .daily
                ? "You got it in \(tries)! See you tomorrow."
                : "You got it in \(tries)!"
        } else {
            // The answer box below shows the word, so the message only explains how the round ended.
            message = rowIndex < 6 ? "Word revealed." : "Out of guesses."
        }

        if mode == .daily {
            UserDefaults.standard.removeObject(forKey: dailyProgressKey)
            answered += 1

            if win {
                score += 1

                // Counts today plus the run of solved days immediately before it.
                let bestBefore = persistentStreak.best
                let streak = persistentStreak.recordWin(
                    reaching: GameStats.shared.wordleDailyWinStreak(treatingTodayAsSolved: true)
                )
                currentStreak = streak.current
                currentBestStreak = max(currentBestStreak, streak.best)
                isNewBestStreak = streak.best > bestBefore
            } else {
                // A Daily loss, including Reveal, ends the tracked streak.
                persistentStreak.reset()
                currentStreak = 0
            }

            GameStats.shared.recordWordleResult(
                type: .daily,
                mode: roundHardMode ? .hard : .normal,
                won: win,
                guesses: rowIndex,
                currentBestStreak: currentBestStreak
            )
            GameStats.shared.recordWordleTime(
                type: .daily,
                mode: roundHardMode ? .hard : .normal,
                won: win,
                elapsedSeconds: elapsedSeconds
            )
        } else {
            answered += 1

            if win {
                score += 1
                let bestBefore = practicePersistentStreak.best
                let streak = practicePersistentStreak.recordWin()
                practiceStreak = streak.current
                practiceBestStreak = streak.best
                isNewBestStreak = streak.best > bestBefore
            } else {
                // A Practice loss, including Reveal, ends the Practice streak.
                practicePersistentStreak.reset()
                practiceStreak = 0
            }

            GameStats.shared.recordWordleResult(
                type: .free,
                mode: roundHardMode ? .hard : .normal,
                won: win,
                guesses: rowIndex,
                currentBestStreak: practiceBestStreak
            )
            GameStats.shared.recordWordleTime(
                type: .free,
                mode: roundHardMode ? .hard : .normal,
                won: win,
                elapsedSeconds: elapsedSeconds
            )
        }

        roundRef = Self.verseIndex[target]
        guessDistribution = GameStats.shared.wordleWinGuessStats(type: mode == .daily ? .daily : .free).winsByGuess

        if mode == .daily {
            UserDefaults.standard.set(todayKey, forKey: AppStorageKey.wordleDailyCompletedDay)
            UserDefaults.standard.set(target, forKey: AppStorageKey.wordleDailyTarget)
            // Push daily flags to iCloud KVS so other devices see completion/target
            iCloudSyncCoordinator.shared.pushKey("wordleDailyCompletedDay")
            iCloudSyncCoordinator.shared.pushKey("wordleDailyTarget")

            // Persist a per-day result summary for the Games list row
            let defaults = UserDefaults.standard
            let key = AppStorageKey.wordleDailyResultMap
            struct DailyResult: Codable { let won: Bool; let guesses: Int; let elapsed: Int; let word: String }
            var map: [String: DailyResult] = [:]
            if let data = defaults.data(forKey: key),
               let decoded = PersistedDecoding.decode([String: DailyResult].self, from: data, key: key, keepingUnreadableIn: defaults) {
                map = decoded
            }
            map[todayKey] = DailyResult(won: win, guesses: rowIndex, elapsed: elapsedSeconds, word: target)
            if let data = try? JSONEncoder().encode(map) {
                defaults.set(data, forKey: key)
                // Mirror to iCloud KVS so other devices see the same-day result
                iCloudSyncCoordinator.shared.pushKey(key)
            }

            // Nudge any listeners that might want to update immediately
            AppDataChanges.shared.gameStatsChanged()
        }
    }

    // MARK: - Word validity (system dictionary)
    func isValidWord(_ uppercasedWord: String) -> Bool {
        let lower = uppercasedWord.lowercased()
        guard lower.count == 5, lower.unicodeScalars.allSatisfy({ CharacterSet.lowercaseLetters.contains($0) }) else {
            return false
        }
        #if canImport(UIKit)
        let lang = Self.spellCheckLanguage
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: lower.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(in: lower, range: range, startingAt: 0, wrap: false, language: lang)
        return misspelled.location == NSNotFound
        #else
        return true
        #endif
    }
}
