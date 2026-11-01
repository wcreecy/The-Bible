import Foundation
import SwiftData
import Testing
@testable import Bible

struct GameActiveClockTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func countsOnlyTimeWhileRunning() {
        var clock = GameActiveClock()
        clock.start(at: start)
        clock.pause(at: start + 30)
        // An hour away doesn't count.
        #expect(clock.elapsed(at: start + 3_630) == 30)
        clock.resume(at: start + 3_630)
        #expect(clock.elapsedSeconds(at: start + 3_645) == 45)
    }

    @Test func pausingOrResumingTwiceChangesNothing() {
        var clock = GameActiveClock()
        clock.start(at: start)
        clock.pause(at: start + 10)
        clock.pause(at: start + 50)
        #expect(clock.elapsed(at: start + 100) == 10)

        clock.resume(at: start + 100)
        clock.resume(at: start + 200)
        #expect(clock.elapsed(at: start + 110) == 20)
        #expect(clock.isRunning)
    }

    @Test func startCanCarryOverSavedTime() {
        var clock = GameActiveClock()
        clock.start(at: start, alreadyElapsed: 75)
        #expect(clock.elapsedSeconds(at: start + 5) == 80)

        // Starting again begins a fresh round.
        clock.start(at: start + 5)
        #expect(clock.elapsed(at: start + 5) == 0)
    }
}

@MainActor
struct CrosswordPauseTests {
    private static let puzzle = CrosswordPuzzle(
        size: 5,
        rows: ["NOAH#", "##R##", "##KIN", "#####", "#####"],
        entries: [
            .init(number: 1, direction: .across, row: 0, col: 0, answer: "NOAH", clue: "Ark builder", reference: "Genesis 6:14", clueID: "noah"),
            .init(number: 3, direction: .across, row: 2, col: 2, answer: "KIN", clue: "Family", reference: "Ruth 2:20", clueID: "kin"),
            .init(number: 2, direction: .down, row: 0, col: 2, answer: "ARK", clue: "Noah's boat", reference: "Genesis 6:14", clueID: "ark"),
        ]
    )

    @Test func timeAwayFromTheAppIsLeftOutOfTheSolveTime() {
        let suite = "CrosswordPauseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = CrosswordGameViewModel(defaults: defaults, recordsStats: false, loadClues: { [] })
        vm.begin(with: Self.puzzle)
        let start = Date()

        vm.type("N")
        vm.appActiveChanged(false, at: start + 20)
        vm.appActiveChanged(true, at: start + 7_220)
        // 20 seconds before leaving + 10 after returning; the two hours away don't count.
        #expect(vm.activeSeconds(at: start + 7_230) == 30)

        // The board is exactly as it was left.
        #expect(vm.guesses[CrosswordPuzzle.Cell(row: 0, col: 0)] == "N")
        #expect(vm.phase == .playing)
    }
}

@MainActor
struct WordSearchPauseTests {
    private func startedGame(timed: Bool) async throws -> (WordSearchViewModel, () -> Void) {
        _ = await BibleRepository.shared.loadAllBooks()
        let defaults = UserDefaults.standard
        let keys = ["wordsearchTimedMode", "wordsearchDifficulty", "wordsearchVerseSource", "wordsearchBlindMode"]
        let saved = Dictionary(uniqueKeysWithValues: keys.compactMap { key in defaults.object(forKey: key).map { (key, $0) } })
        let restore = {
            keys.forEach { defaults.removeObject(forKey: $0) }
            saved.forEach { defaults.set($0.value, forKey: $0.key) }
        }

        let container = try ModelContainer(for: Favorite.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let vm = WordSearchViewModel(modelContext: ModelContext(container), favoritesFetch: { [] })
        vm.isTimedMode = timed
        vm.start()
        try #require(vm.started, "A puzzle couldn't be generated.")
        return (vm, restore)
    }

    @Test func leavingTheAppPausesATimedRoundUntilResume() async throws {
        let (vm, restore) = try await startedGame(timed: true)
        defer {
            vm.stopTimer()
            restore()
        }
        #expect(vm.canPause)

        vm.appActiveChanged(false)
        #expect(vm.isPaused)

        // Coming back keeps the grid hidden until the player taps Resume.
        vm.appActiveChanged(true)
        #expect(vm.isPaused)

        vm.resume()
        #expect(!vm.isPaused)
    }

    @Test func untimedRoundsNeverShowThePausedScreen() async throws {
        let (vm, restore) = try await startedGame(timed: false)
        defer {
            vm.stopTimer()
            restore()
        }
        #expect(!vm.canPause)

        vm.pause()
        vm.appActiveChanged(false)
        #expect(!vm.isPaused)
        vm.appActiveChanged(true)
        #expect(!vm.isPaused)
    }
}
