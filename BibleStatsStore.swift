import Foundation
import SwiftUI

// Tiny store that reads/writes a [bookName: seconds] dictionary to UserDefaults as JSON.
// It also provides helpers for formatting and ranking.
final class BibleStatsStore {
    static let shared = BibleStatsStore()
    private init() {}

    struct Defaults {
        static let key = "bookReadingTimes"
        // Swap this to your app group if desired:
        static var provider: UserDefaults { UserDefaults.standard }
    }

    func loadTotals() -> [String: Int] {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.key) else { return [:] }
        do {
            let decoded = try JSONDecoder().decode([String: Int].self, from: data)
            return decoded
        } catch {
            return [:]
        }
    }

    func saveTotals(_ totals: [String: Int]) {
        let defaults = Defaults.provider
        do {
            let data = try JSONEncoder().encode(totals)
            defaults.set(data, forKey: Defaults.key)
        } catch {
            // Ignore encoding error (shouldn't happen with [String:Int])
        }
    }

    func sortedTop(n: Int) -> [(book: String, seconds: Int)] {
        let totals = loadTotals()
        return totals
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .prefix(n)
            .map { ($0.key, $0.value) }
    }

    func totalMax() -> Int {
        loadTotals().values.max() ?? 0
    }

    // Format seconds as h:mm:ss if >= 1h, otherwise m:ss
    func format(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else {
            return String(format: "%d:%02d", m, sec)
        }
    }
}

