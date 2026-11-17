import Foundation
import Testing
@testable import Bible

@MainActor
struct ReaderDefaultsMigrationTests {
    private let suite = "ReaderDefaultsMigrationTests.\(UUID().uuidString)"

    private func makeDefaults() throws -> UserDefaults {
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func register(_ defaults: UserDefaults) {
        AppSettingsDefaults.register(in: defaults, domainName: suite)
    }

    @Test
    func aNewInstallGetsTheQuietVerseRow() throws {
        let defaults = try makeDefaults()
        register(defaults)

        #expect(defaults.bool(forKey: AppStorageKey.readerShowsFullReferences) == false)
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsFavoriteMarkersKey) == false)
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsBookmarkMarkersKey) == false)
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsPinnedVerseMarkerKey) == false)
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsNoteMarkersKey))
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsCrossReferenceMarkersKey))
    }

    @Test
    func anExistingInstallKeepsItsPreviousVerseRow() throws {
        let defaults = try makeDefaults()
        defaults.set(true, forKey: AppStorageKey.didCleanupAppTimeKeys)
        register(defaults)

        for (key, value) in AppSettingsDefaults.previousReaderDefaults {
            #expect(defaults.bool(forKey: key) == value, "\(key)")
        }
    }

    @Test
    func aChoiceTheReaderMadeIsLeftAlone() throws {
        let defaults = try makeDefaults()
        defaults.set(true, forKey: AppStorageKey.didCleanupAppTimeKeys)
        defaults.set(false, forKey: ReaderDisplaySettings.showsFavoriteMarkersKey)
        register(defaults)

        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsFavoriteMarkersKey) == false)
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsBookmarkMarkersKey))
    }

    @Test
    func previousDefaultsAreKeptOnlyOnce() throws {
        let defaults = try makeDefaults()
        register(defaults)
        // The install opens for the first time after the check has already run.
        defaults.set(true, forKey: AppStorageKey.didCleanupAppTimeKeys)
        register(defaults)

        #expect(defaults.bool(forKey: AppStorageKey.readerShowsFullReferences) == false)
    }
}
