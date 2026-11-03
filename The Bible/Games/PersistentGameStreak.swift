import Foundation

/// A game's saved streak for one difficulty or mode: the current run of correct answers
/// and the best run so far. Both survive relaunches and sync through iCloud.
///
/// The keys are `<game>PersistentStreak_<variant>` and `<game>PersistentBestStreak_<variant>`
/// (no suffix when `variant` is nil), which `iCloudSyncCoordinator` already syncs.
struct PersistentGameStreak {
    let currentKey: String
    let bestKey: String

    init(game: String, variant: String? = nil) {
        let suffix = variant.map { "_\($0)" } ?? ""
        currentKey = "\(game)PersistentStreak\(suffix)"
        bestKey = "\(game)PersistentBestStreak\(suffix)"
    }

    var current: Int { Self.read(currentKey) }
    var best: Int { Self.read(bestKey) }

    /// Extends the streak by one after a correct answer, raising the best if needed.
    @discardableResult
    func recordWin() -> (current: Int, best: Int) {
        recordWin(reaching: current + 1)
    }

    /// Sets the streak to a value worked out by the game (WORD counts solved days),
    /// raising the best if needed.
    @discardableResult
    func recordWin(reaching newCurrent: Int) -> (current: Int, best: Int) {
        let newCurrent = max(0, newCurrent)
        Self.write(newCurrent, forKey: currentKey)
        let newBest = max(best, newCurrent)
        if newBest > best {
            Self.write(newBest, forKey: bestKey)
        }
        return (newCurrent, newBest)
    }

    /// Ends the streak after a wrong answer, loss, or timeout.
    func reset() {
        Self.write(0, forKey: currentKey)
    }

    private static func read(_ key: String) -> Int {
        max(0, UserDefaults.standard.integer(forKey: key))
    }

    private static func write(_ value: Int, forKey key: String) {
        UserDefaults.standard.set(max(0, value), forKey: key)
        iCloudSyncCoordinator.shared.pushKey(key)
    }
}
