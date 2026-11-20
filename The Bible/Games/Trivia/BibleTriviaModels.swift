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

    /// The book the reference starts in, e.g. "1 Samuel" for "1 Samuel 17:4-11". Read from the
    /// text rather than the loaded Bible, so it works before the Bible text is loaded.
    var bookName: String? {
        // Longest names first, so "1 John" isn't taken for "John".
        for name in Self.booksByLength where reference.hasPrefix(name + " ") {
            return name
        }
        // The catalog cites a single psalm as "Psalm 23:1".
        return reference.hasPrefix("Psalm ") ? "Psalms" : nil
    }

    private static let booksByLength = BibleCanon.fallbackCanon.sorted { $0.count > $1.count }
}

/// Which part of the Bible a round's questions come from.
enum BibleTriviaTopic: String, CaseIterable, Identifiable {
    // Raw values are stored in settings.
    case mixed
    case oldTestament
    case newTestament
    case law
    case history
    case wisdomAndPoetry
    case prophets
    case gospelsAndActs
    case lettersAndRevelation

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .mixed: "Whole Bible"
        case .oldTestament: "Old Testament"
        case .newTestament: "New Testament"
        case .law: "Law"
        case .history: "History"
        case .wisdomAndPoetry: "Wisdom & Poetry"
        case .prophets: "Prophets"
        case .gospelsAndActs: "Gospels & Acts"
        case .lettersAndRevelation: "Letters & Revelation"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .mixed: "Questions from every book"
        case .oldTestament: "Genesis to Malachi"
        case .newTestament: "Matthew to Revelation"
        case .law: "Genesis to Deuteronomy"
        case .history: "Joshua to Esther"
        case .wisdomAndPoetry: "Job to Song of Solomon"
        case .prophets: "Isaiah to Malachi"
        case .gospelsAndActs: "Matthew, Mark, Luke, John and Acts"
        case .lettersAndRevelation: "Romans to Revelation"
        }
    }

    var systemImage: String {
        switch self {
        case .mixed: "books.vertical.fill"
        case .oldTestament: "scroll.fill"
        case .newTestament: "cross.fill"
        case .law: "list.bullet.rectangle.portrait.fill"
        case .history: "crown.fill"
        case .wisdomAndPoetry: "music.note"
        case .prophets: "megaphone.fill"
        case .gospelsAndActs: "book.fill"
        case .lettersAndRevelation: "envelope.fill"
        }
    }

    /// Whether a question citing `bookName` belongs to this topic, using the Bible's book groups.
    func includes(bookName: String?) -> Bool {
        guard self != .mixed else { return true }
        guard let bookName else { return false }
        let group = BibleBookGroup.group(for: bookName)
        return switch self {
        case .mixed: true
        case .oldTestament: group.testament == .old
        case .newTestament: group.testament == .new
        case .law: group == .law
        case .history: group == .history
        case .wisdomAndPoetry: group == .wisdomAndPoetry
        case .prophets: group == .majorProphets || group == .minorProphets
        case .gospelsAndActs: group == .gospelsAndActs
        case .lettersAndRevelation: group == .letters || group == .revelation
        }
    }
}

/// The help a player can use once per round.
enum BibleTriviaLifeline: CaseIterable, Hashable {
    /// Removes two wrong answers.
    case fiftyFifty
    /// Shows the reference and its opening verse, with the answer blanked out.
    case verseHint
    /// Adds ten seconds to the clock. Not on Easy, which has the most time already.
    case extraTime

    static let extraSeconds = 10
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
