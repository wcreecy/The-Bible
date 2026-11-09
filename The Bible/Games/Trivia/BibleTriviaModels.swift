import Foundation
import Observation
import SwiftUI

// Trivia questions, difficulty levels, and the saved progress through each question pool.

struct BibleTriviaQuestion: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let question: String
    let correctAnswer: String
    let incorrectAnswers: [String]
    let reference: String
    let difficulty: String
}

enum BibleTriviaDifficulty: String, CaseIterable, Identifiable, Codable {
    case easy
    case normal
    case hard

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    var timerSeconds: Int {
        switch self {
        case .easy: 30
        case .normal: 15
        case .hard: 10
        }
    }

    var statsDifficulty: GameStats.Difficulty {
        switch self {
        case .easy: .easy
        case .normal: .normal
        case .hard: .hard
        }
    }

    func includes(_ question: BibleTriviaQuestion) -> Bool {
        switch self {
        case .easy:
            question.difficulty == "easy"
        case .normal:
            question.difficulty == "easy" || question.difficulty == "normal"
        case .hard:
            true
        }
    }
}

struct BibleTriviaDifficultyProgress: Codable, Equatable {
    var completedQuestionIDs: Set<Int> = []
    /// Increments each time every question in the pool has been asked and the pool restarts.
    /// Merges keep the higher cycle so a restart on one device isn't undone by another's history.
    var cycle = 0

    init(completedQuestionIDs: Set<Int> = [], cycle: Int = 0) {
        self.completedQuestionIDs = completedQuestionIDs
        self.cycle = cycle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completedQuestionIDs = try container.decodeIfPresent(Set<Int>.self, forKey: .completedQuestionIDs) ?? []
        cycle = try container.decodeIfPresent(Int.self, forKey: .cycle) ?? 0
    }
}

@MainActor
@Observable
final class BibleTriviaProgressStore {
    static let shared = BibleTriviaProgressStore()

    // V3: the updated catalog revises existing questions, so prior completion history is ignored.
    nonisolated static let storageKey = "bibleTriviaProgressV3"

    private var progressByDifficulty: [String: BibleTriviaDifficultyProgress]
    @ObservationIgnored private var observer: NSObjectProtocol?
    /// False for a store made for tests, which keeps everything in memory.
    private let persists: Bool

    /// A store that keeps progress in memory only, never saving or syncing it. For tests.
    init(inMemory progress: [String: BibleTriviaDifficultyProgress]) {
        progressByDifficulty = progress
        persists = false
    }

    private init() {
        persists = true
        progressByDifficulty = Self.decode(UserDefaults.standard.data(forKey: Self.storageKey))
        observer = NotificationCenter.default.addObserver(
            forName: .gameStatsExternallyUpdated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reload()
            }
        }
    }

    private func reload() {
        progressByDifficulty = Self.decode(UserDefaults.standard.data(forKey: Self.storageKey))
    }

    private static func decode(_ data: Data?) -> [String: BibleTriviaDifficultyProgress] {
        guard let data,
              let decoded = PersistedDecoding.decode([String: BibleTriviaDifficultyProgress].self, from: data, name: "bibleTriviaProgress") else {
            return [:]
        }
        return decoded
    }

    static func mergedData(local: Data?, remote: Data?) -> Data? {
        let localProgress = decode(local)
        let remoteProgress = decode(remote)
        let keys = Set(localProgress.keys).union(remoteProgress.keys)
        var merged: [String: BibleTriviaDifficultyProgress] = [:]

        for key in keys {
            let localValue = localProgress[key] ?? BibleTriviaDifficultyProgress()
            let remoteValue = remoteProgress[key] ?? BibleTriviaDifficultyProgress()
            if localValue.cycle == remoteValue.cycle {
                merged[key] = BibleTriviaDifficultyProgress(
                    completedQuestionIDs: localValue.completedQuestionIDs.union(remoteValue.completedQuestionIDs),
                    cycle: localValue.cycle
                )
            } else {
                merged[key] = localValue.cycle > remoteValue.cycle ? localValue : remoteValue
            }
        }

        return try? JSONEncoder().encode(merged)
    }

    func progress(for difficulty: BibleTriviaDifficulty) -> BibleTriviaDifficultyProgress {
        progressByDifficulty[difficulty.rawValue] ?? BibleTriviaDifficultyProgress()
    }

    func record(questionID: Int, difficulty: BibleTriviaDifficulty) {
        var progress = progress(for: difficulty)
        progress.completedQuestionIDs.insert(questionID)
        progressByDifficulty[difficulty.rawValue] = progress
        save()
    }

    func resetCompletedPool(for difficulty: BibleTriviaDifficulty) {
        var progress = progress(for: difficulty)
        progress.completedQuestionIDs = []
        progress.cycle += 1
        progressByDifficulty[difficulty.rawValue] = progress
        save()
    }

    private func save() {
        guard persists, let data = try? JSONEncoder().encode(progressByDifficulty) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        iCloudSyncCoordinator.shared.pushKey(Self.storageKey)
    }
}
