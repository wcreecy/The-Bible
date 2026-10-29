import Foundation
import Testing
@testable import Bible

struct PersistedDecodingTests {
    private func makeDefaults() -> UserDefaults {
        let name = "PersistedDecodingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test
    func readableDataDecodesAndLeavesNoBackup() throws {
        let defaults = makeDefaults()
        let data = try JSONEncoder().encode(["a": 1])

        let decoded = PersistedDecoding.decode([String: Int].self, from: data, key: "stats", keepingUnreadableIn: defaults)

        #expect(decoded == ["a": 1])
        #expect(defaults.data(forKey: PersistedDecoding.backupKey(for: "stats")) == nil)
    }

    @Test
    func unreadableDataIsKeptBeforeTheCallerFallsBack() {
        let defaults = makeDefaults()
        let bad = Data("not json".utf8)

        let decoded = PersistedDecoding.decode([String: Int].self, from: bad, key: "stats", keepingUnreadableIn: defaults)

        #expect(decoded == nil)
        #expect(defaults.data(forKey: PersistedDecoding.backupKey(for: "stats")) == bad)
    }

    @Test
    func theFirstUnreadableCopyIsNotReplacedByLaterOnes() {
        let defaults = makeDefaults()
        let first = Data("first".utf8)
        let second = Data("second".utf8)

        _ = PersistedDecoding.decode([String: Int].self, from: first, key: "stats", keepingUnreadableIn: defaults)
        _ = PersistedDecoding.decode([String: Int].self, from: second, key: "stats", keepingUnreadableIn: defaults)

        #expect(defaults.data(forKey: PersistedDecoding.backupKey(for: "stats")) == first)
    }

    @Test
    func emptyTextMeansNothingWasSavedYet() {
        let defaults = makeDefaults()

        let decoded = PersistedDecoding.decode([String].self, fromText: "  ", key: "layout", keepingUnreadableIn: defaults)

        #expect(decoded == nil)
        #expect(defaults.data(forKey: PersistedDecoding.backupKey(for: "layout")) == nil)
    }

    @Test
    func unreadableTextIsKept() {
        let defaults = makeDefaults()

        let decoded = PersistedDecoding.decode([String].self, fromText: "{oops", key: "layout", keepingUnreadableIn: defaults)

        #expect(decoded == nil)
        #expect(defaults.data(forKey: PersistedDecoding.backupKey(for: "layout")) == Data("{oops".utf8))
    }
}
