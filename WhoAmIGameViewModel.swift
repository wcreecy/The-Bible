import Foundation
import SwiftUI
import Combine
import Observation

@MainActor
@Observable
final class WhoAmIGameViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case names = "Names"     // prompt: name -> choices: descriptions
        case reverse = "Bible Names"   // prompt: clue -> choices: names

        var id: String { rawValue }
    }

    enum Difficulty: String, CaseIterable, Identifiable {
        case easy, normal, hard
        var id: String { rawValue }

        var timeLimit: Int {
            switch self {
            case .easy: return 0
            case .normal: return 30
            case .hard: return 15
            }
        }

        var statsDifficulty: GameStats.Difficulty {
            switch self {
            case .easy: return .easy
            case .normal: return .normal
            case .hard: return .hard
            }
        }
    }

    struct Entry: Hashable {
        let id: Int
        let name: String
        let description: String
        let firstReference: String?
        // NEW: full comma-separated references line (preferred for Who Am I reference sheet)
        let referencesLine: String?
        let difficulty: String

        func matchesDifficulty(_ selectedDifficulty: Difficulty) -> Bool {
            switch selectedDifficulty {
            case .easy:
                return difficulty.caseInsensitiveCompare("Easy") == .orderedSame
            case .normal:
                return difficulty.caseInsensitiveCompare("Medium") == .orderedSame
                    || difficulty.caseInsensitiveCompare("Normal") == .orderedSame
            case .hard:
                return difficulty.caseInsensitiveCompare("Hard") == .orderedSame
            }
        }
    }

    // Start screen state
    var started: Bool = false
    var mode: Mode = .reverse
    var difficulty: Difficulty = .normal {
        didSet { seedStreakFromPersistence() }
    }

    // Data
    private(set) var entries: [Entry] = []
    private var questionQueue: [Entry] = []

    // Current round
    var promptTitle: String = ""
    var choices: [String] = []
    var correctChoice: String = ""
    var selectedChoice: String? = nil

    // Timer
    var remainingSeconds: Int = 0
    private var timerCancellable: AnyCancellable? = nil
    var pulseOn: Bool = false

    // Scoring
    var score: Int = 0
    var answered: Int = 0
    var currentStreak: Int = 0
    var currentBestStreak: Int = 0

    // All-time (combined across difficulties)
    private var allTimeCorrectKey: String { "whoamiAllTimeCorrect_all" }
    private var allTimeAnsweredKey: String { "whoamiAllTimeAnswered_all" }
    private var allTimeBestStreakKey: String { "whoamiAllTimeBestStreak_all" }

    var allTimeCorrect: Int { UserDefaults.standard.integer(forKey: allTimeCorrectKey) }
    var allTimeAnswered: Int { UserDefaults.standard.integer(forKey: allTimeAnsweredKey) }
    var allTimeBestStreak: Int { UserDefaults.standard.integer(forKey: allTimeBestStreakKey) }

    // UI flags
    var roundOver: Bool = false
    var showReveal: Bool = false
    var isGameComplete: Bool = false

    // NEW: Jesus bonus alert flag (bound in view)
    var showJesusBonusAlert: Bool = false

    // MARK: - Persistent streak helpers (per difficulty)
    private var persistentStreakKey: String { "whoamiPersistentStreak_\(difficulty.rawValue)" }
    private var persistentBestKey: String { "whoamiPersistentBestStreak_\(difficulty.rawValue)" }

    private func readPersistentStreak() -> Int {
        max(0, UserDefaults.standard.integer(forKey: persistentStreakKey))
    }
    private func writePersistentStreak(_ value: Int) {
        let v = max(0, value)
        UserDefaults.standard.set(v, forKey: persistentStreakKey)
        iCloudSyncCoordinator.shared.pushKey(persistentStreakKey)
    }
    private func readPersistentBest() -> Int {
        max(0, UserDefaults.standard.integer(forKey: persistentBestKey))
    }
    private func writePersistentBest(_ value: Int) {
        let v = max(0, value)
        UserDefaults.standard.set(v, forKey: persistentBestKey)
        iCloudSyncCoordinator.shared.pushKey(persistentBestKey)
    }
    private func seedStreakFromPersistence() {
        let persisted = readPersistentStreak()
        currentStreak = persisted
        let persistedBest = readPersistentBest()
        currentBestStreak = max(currentBestStreak, persistedBest)
    }

    // Load data
    func onAppear() {
        // Seed streaks from persisted values so they survive navigation/relaunch
        seedStreakFromPersistence()

        Task {
            if entries.isEmpty {
                let characters = await GameDataLoaders.loadCharactersAsync()
                self.entries = characters.compactMap { character in
                    let name = character.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    let description = character.shortDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty, !description.isEmpty else { return nil }

                    return Entry(
                        id: character.id,
                        name: name,
                        description: description,
                        firstReference: nil,
                        referencesLine: nil,
                        difficulty: character.difficulty
                    )
                }
            }
        }
    }

    func startGame() {
        score = 0
        answered = 0
        // Do NOT reset persistent streaks here; seed from persistence
        seedStreakFromPersistence()
        roundOver = false
        showReveal = false
        selectedChoice = nil
        questionQueue = entries.shuffled()
        isGameComplete = false
        started = true
        nextRound()
    }

    func nextRound() {
        stopTimer()
        guard !isGameComplete else { return }
        guard entries.count >= 4 else {
            promptTitle = "Not enough data"
            choices = []
            correctChoice = ""
            selectedChoice = nil
            roundOver = true
            showReveal = true
            return
        }
        selectedChoice = nil
        roundOver = false
        showReveal = false

        guard !questionQueue.isEmpty else {
            isGameComplete = true
            return
        }

        // Generate a question (optionally force Jesus for testing)
        let forceJesus = UserDefaults.standard.bool(forKey: "forceJesusTestEnabled")
        let correct: Entry
        if forceJesus, let jesusIndex = questionQueue.firstIndex(where: { isJesusName($0.name) }) {
            correct = questionQueue.remove(at: jesusIndex)
        } else {
            correct = questionQueue.removeFirst()
        }

        switch mode {
        case .names:
            // Prompt is the exact name; choices are descriptions (1 correct + 3 random wrong)
            promptTitle = correct.name
            correctChoice = correct.description
            choices = fourRandomDescriptions(for: correct, from: entries)
        case .reverse:
            // Prompt is the exact description; choices are names (1 correct + 3 random wrong)
            promptTitle = correct.description
            correctChoice = correct.name
            choices = fourRandomNames(for: correct, from: entries)
        }

        // Reset timer per difficulty
        remainingSeconds = difficulty.timeLimit
        if remainingSeconds > 0 {
            startTimer()
        }
    }

    func select(_ choice: String) {
        guard !roundOver else { return }
        selectedChoice = choice
        stopTimer()
        answered += 1
        let isCorrect = (choice == correctChoice)
        if isCorrect {
            score += 1

            // Persistent streak: increment on correct
            let persisted = readPersistentStreak() + 1
            writePersistentStreak(persisted)
            currentStreak = persisted

            // Update persistent best if needed
            let bestPersisted = readPersistentBest()
            if persisted > bestPersisted {
                writePersistentBest(persisted)
            }
            currentBestStreak = max(currentBestStreak, persisted, readPersistentBest())

            GameStats.shared.recordRound(
                game: .whoami,
                difficulty: difficulty.statsDifficulty,
                correct: 1,
                answered: 1,
                currentBestStreak: currentBestStreak
            )

            // Jesus bonus popup trigger:
            if (mode == .names && isJesusName(promptTitle)) || (mode == .reverse && isJesusName(correctChoice)) {
                showJesusBonusAlert = true
            }
        } else {
            // Persistent streak: reset on incorrect
            writePersistentStreak(0)
            currentStreak = 0

            GameStats.shared.recordRound(
                game: .whoami,
                difficulty: difficulty.statsDifficulty,
                correct: 0,
                answered: 1,
                currentBestStreak: currentBestStreak
            )
        }
        roundOver = true
        showReveal = true
        finishGameIfNeeded()
    }

    func skipOrTimeout() {
        guard !roundOver else { return }
        stopTimer()
        answered += 1
        writePersistentStreak(0)
        currentStreak = 0
        GameStats.shared.recordRound(
            game: .whoami,
            difficulty: difficulty.statsDifficulty,
            correct: 0,
            answered: 1,
            currentBestStreak: currentBestStreak
        )
        roundOver = true
        showReveal = true
        finishGameIfNeeded()
    }

    private func finishGameIfNeeded() {
        isGameComplete = entries.count >= 4 && questionQueue.isEmpty
    }

    // MARK: - References lookup for sheet

    // Prefer the full comma-separated references line when available; fall back to firstReference.
    func referenceString(for choice: String) -> String? {
        switch mode {
        case .names:
            // choice is a description
            guard let entry = entries.first(where: { $0.description == choice }) else { return nil }
            return entry.referencesLine ?? entry.firstReference
        case .reverse:
            // choice is a name
            guard let entry = entries.first(where: { $0.name == choice }) else { return nil }
            return entry.referencesLine ?? entry.firstReference
        }
    }

    // MARK: - Choice builders (global random wrong answers)

    private func fourRandomDescriptions(for correct: Entry, from entries: [Entry]) -> [String] {
        // Unique descriptions from the selected difficulty, excluding the correct one
        var universe = Array(Set(entries.map { $0.description })).filter { $0 != correct.description }
        universe.shuffle()
        let wrong = Array(universe.prefix(3))
        var all = wrong
        let insertIndex = Int.random(in: 0...all.count)
        all.insert(correct.description, at: insertIndex)
        return all
    }

    private func fourRandomNames(for correct: Entry, from entries: [Entry]) -> [String] {
        // Unique names from the selected difficulty, excluding the correct one
        var universe = Array(Set(entries.map { $0.name })).filter { $0 != correct.name }
        universe.shuffle()
        let wrong = Array(universe.prefix(3))
        var all = wrong
        let insertIndex = Int.random(in: 0...all.count)
        all.insert(correct.name, at: insertIndex)
        return all
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        guard remainingSeconds > 0 else { return }
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard !self.roundOver else { return }
                if self.remainingSeconds > 0 {
                    self.remainingSeconds -= 1
                    if self.remainingSeconds <= 5 {
                        withAnimation(.easeInOut(duration: 0.25)) { self.pulseOn.toggle() }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            self.pulseOn = false
                        }
                    }
                }
                if self.remainingSeconds == 0 {
                    self.skipOrTimeout()
                }
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        pulseOn = false
    }

    // MARK: - Jesus detection helper
    private func isJesusName(_ s: String) -> Bool {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        return lower == "jesus" || lower == "jesus christ"
    }
}
