import Foundation
import SwiftUI
import Combine

@MainActor
final class WhoAmIGameViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case names = "Names"     // prompt: name -> choices: descriptions
        case reverse = "Reverse" // prompt: description -> choices: names
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
        let name: String
        let description: String
        let firstReference: String?
        // NEW: full comma-separated references line (preferred for Who Am I reference sheet)
        let referencesLine: String?
    }

    // Start screen state
    @Published var started: Bool = false
    @Published var mode: Mode = .names
    @Published var difficulty: Difficulty = .easy
    @Published var howToExpanded: Bool = false
    @Published var difficultyExpanded: Bool = false

    // Data
    private(set) var entries: [Entry] = []

    // Current round
    @Published var promptTitle: String = ""
    @Published var choices: [String] = []
    @Published var correctChoice: String = ""
    @Published var selectedChoice: String? = nil

    // Timer
    @Published var remainingSeconds: Int = 0
    private var timerCancellable: AnyCancellable? = nil
    @Published var pulseOn: Bool = false

    // Scoring
    @Published var score: Int = 0
    @Published var answered: Int = 0
    @Published var currentStreak: Int = 0
    @Published var currentBestStreak: Int = 0

    // All-time (read-only via UserDefaults keys managed by GameStats)
    private var allTimeCorrectKey: String { "whoamiAllTimeCorrect_\(difficulty.rawValue)" }
    private var allTimeAnsweredKey: String { "whoamiAllTimeAnswered_\(difficulty.rawValue)" }
    private var allTimeBestStreakKey: String { "whoamiAllTimeBestStreak_\(difficulty.rawValue)" }

    var allTimeCorrect: Int { UserDefaults.standard.integer(forKey: allTimeCorrectKey) }
    var allTimeAnswered: Int { UserDefaults.standard.integer(forKey: allTimeAnsweredKey) }
    var allTimeBestStreak: Int { UserDefaults.standard.integer(forKey: allTimeBestStreakKey) }

    // UI flags
    @Published var roundOver: Bool = false
    @Published var showReveal: Bool = false

    // Load data
    func onAppear() {
        Task {
            if entries.isEmpty {
                let names = await GameDataLoaders.loadNamesAsync()
                // Filter to those with non-empty description
                self.entries = names.compactMap { n in
                    let d = n.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let nm = n.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !nm.isEmpty, !d.isEmpty else { return nil }
                    let firstRef = n.firstReference?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let fullRefs = n.referencesLine?.trimmingCharacters(in: .whitespacesAndNewlines)
                    return Entry(
                        name: nm,
                        description: d,
                        firstReference: (firstRef?.isEmpty == true ? nil : firstRef),
                        referencesLine: (fullRefs?.isEmpty == true ? nil : fullRefs)
                    )
                }
            }
        }
    }

    func startGame() {
        score = 0
        answered = 0
        currentStreak = 0
        currentBestStreak = 0
        roundOver = false
        showReveal = false
        selectedChoice = nil
        started = true
        nextRound()
    }

    func nextRound() {
        stopTimer()
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

        // Generate a question
        let correct = entries.randomElement()!
        switch mode {
        case .names:
            // Prompt is the exact name; choices are descriptions (1 correct + 3 random wrong)
            promptTitle = correct.name
            correctChoice = correct.description
            choices = fourRandomDescriptions(for: correct)
        case .reverse:
            // Prompt is the exact description; choices are names (1 correct + 3 random wrong)
            promptTitle = correct.description
            correctChoice = correct.name
            choices = fourRandomNames(for: correct)
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
            currentStreak += 1
            currentBestStreak = max(currentBestStreak, currentStreak)
            GameStats.shared.recordRound(
                game: .whoami,
                difficulty: difficulty.statsDifficulty,
                correct: 1,
                answered: 1,
                currentBestStreak: currentBestStreak
            )
        } else {
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
    }

    func skipOrTimeout() {
        guard !roundOver else { return }
        stopTimer()
        answered += 1
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

    private func fourRandomDescriptions(for correct: Entry) -> [String] {
        // Unique descriptions across all entries, excluding the correct one
        var universe = Array(Set(entries.map { $0.description })).filter { $0 != correct.description }
        universe.shuffle()
        let wrong = Array(universe.prefix(3))
        var all = wrong
        let insertIndex = Int.random(in: 0...all.count)
        all.insert(correct.description, at: insertIndex)
        return all
    }

    private func fourRandomNames(for correct: Entry) -> [String] {
        // Unique names across all entries, excluding the correct one
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
}
