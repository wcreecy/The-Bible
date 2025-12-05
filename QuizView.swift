import SwiftUI
import Combine
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct QuizView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    
    @AppStorage("quizScope") private var quizScopeRaw: String = "whole"
    @AppStorage("quizDifficulty") private var quizDifficulty: String = "easy"
    
    @AppStorage("quizAllTimeCorrect_easy") private var allTimeCorrectEasy: Int = 0
    @AppStorage("quizAllTimeAnswered_easy") private var allTimeAnsweredEasy: Int = 0
    @AppStorage("quizAllTimeBestStreak_easy") private var allTimeBestStreakEasy: Int = 0

    @AppStorage("quizAllTimeCorrect_normal") private var allTimeCorrectNormal: Int = 0
    @AppStorage("quizAllTimeAnswered_normal") private var allTimeAnsweredNormal: Int = 0
    @AppStorage("quizAllTimeBestStreak_normal") private var allTimeBestStreakNormal: Int = 0

    @AppStorage("quizAllTimeCorrect_hard") private var allTimeCorrectHard: Int = 0
    @AppStorage("quizAllTimeAnswered_hard") private var allTimeAnsweredHard: Int = 0
    @AppStorage("quizAllTimeBestStreak_hard") private var allTimeBestStreakHard: Int = 0

    private var allTimeCorrect: Int {
        switch quizDifficulty {
        case "normal": return allTimeCorrectNormal
        case "hard": return allTimeCorrectHard
        default: return allTimeCorrectEasy
        }
    }

    private var allTimeAnswered: Int {
        switch quizDifficulty {
        case "normal": return allTimeAnsweredNormal
        case "hard": return allTimeAnsweredHard
        default: return allTimeAnsweredEasy
        }
    }

    private var allTimeBestStreak: Int {
        switch quizDifficulty {
        case "normal": return allTimeBestStreakNormal
        case "hard": return allTimeBestStreakHard
        default: return allTimeBestStreakEasy
        }
    }
    
    private func recordRound(correct: Int, answered: Int, bestStreak: Int) {
        let diff: GameStats.Difficulty
        switch quizDifficulty {
        case "normal": diff = .normal
        case "hard": diff = .hard
        default: diff = .easy
        }
        GameStats.shared.recordRound(
            game: .quiz,
            difficulty: diff,
            correct: correct,
            answered: answered,
            currentBestStreak: bestStreak
        )
    }
    
    private struct QuizQuestion: Identifiable {
        let id = UUID()
        let verseText: String
        let correctBook: String
        let chapter: Int
        let verse: Int
        let options: [String]
        var selected: String?
    }

    // MARK: - Missing state restored to satisfy references

    // Game/session state
    @State private var started: Bool = false
    @State private var score: Int = 0
    @State private var sessionAnswered: Int = 0
    @State private var currentStreak: Int = 0
    @State private var bestStreak: Int = 0

    // Question flow/history
    @State private var history: [QuizQuestion] = []
    @State private var currentIndex: Int = -1
    @State private var selectedOption: String? = nil
    @State private var showAnswerReveal: Bool = false

    // Timer
    @State private var remainingSeconds: Int = 0
    private let quizTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var pulseOn: Bool = false

    // Safe accessor for the current question’s correct book
    private var correctBook: String {
        guard currentIndex >= 0, currentIndex < history.count else { return "" }
        return history[currentIndex].correctBook
    }

    // ... [rest of constants and state remain unchanged] ...

    var body: some View {
        // [UI unchanged]
        ScrollView {
            // ... original UI ...
        }
        .onReceive(quizTimer) { _ in
            // Timer logic unchanged
            guard started else { return }
            guard selectedOption == nil else { return }
            guard quizDifficulty == "normal" || quizDifficulty == "hard" else { return }
            guard remainingSeconds > 0 else { return }
            remainingSeconds -= 1
            if remainingSeconds == 0 {
                timeOutQuestion()
            }
        }
        // ... rest unchanged ...
    }

    // Replace selectOption implementation where it updates all-time:
    private func selectOption(_ name: String) {
        guard selectedOption == nil else { return }
        guard currentIndex >= 0 && currentIndex == history.count - 1 else { return }
        pulseOn = false
        remainingSeconds = 0
        selectedOption = name
        history[currentIndex].selected = name
        sessionAnswered += 1

        // Always record answered +1
        let isCorrect = (name == correctBook)
        if isCorrect {
            score += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            recordRound(correct: 1, answered: 1, bestStreak: currentStreak)
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } else {
            currentStreak = 0
            recordRound(correct: 0, answered: 1, bestStreak: currentStreak)
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            #endif
        }
        showAnswerReveal = true
    }

    private func timeOutQuestion() {
        guard selectedOption == nil else { return }
        selectedOption = "__timeout__"
        sessionAnswered += 1
        currentStreak = 0
        // Centralized write: incorrect due to timeout
        recordRound(correct: 0, answered: 1, bestStreak: currentStreak)
        showAnswerReveal = true
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    // The rest of the original file (generation, favorites, UI helpers) remains unchanged.
}
