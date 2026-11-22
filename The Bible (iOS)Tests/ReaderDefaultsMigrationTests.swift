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
    func aNewInstallGetsAllVerseMarkers() throws {
        let defaults = try makeDefaults()
        register(defaults)

        #expect(defaults.bool(forKey: AppStorageKey.readerShowsFullReferences) == false)
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsVerseMarkersKey))
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsFavoriteMarkersKey))
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsBookmarkMarkersKey))
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsPinnedVerseMarkerKey))
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsNoteMarkersKey))
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsCrossReferenceMarkersKey))
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsReadProgressKey) == false)
        #expect(defaults.bool(forKey: AppStorageKey.focusReadingEnabled) == false)
        #expect(defaults.bool(forKey: RedLetterText.suppliedWordsInItalicsKey) == false)
    }

    @Test
    func aNewInstallGetsRequestedHomeAndGeneralDefaults() throws {
        let defaults = try makeDefaults()
        register(defaults)

        let visibleCards = Set(HomeCardID.allCases).subtracting(HomeLayoutStore.baselineHidden)
        #expect(visibleCards == Set([.setup, .verseOfDay, .resumeReading]))
        #expect(defaults.bool(forKey: AppStorageKey.homeQuickSearchVisible))
        #expect(defaults.bool(forKey: AppStorageKey.homeCustomizeButtonVisible))
        #expect(defaults.string(forKey: AppStorageKey.colorSchemePreference) == "system")
        #expect(defaults.string(forKey: LaunchTabPreference.defaultsKey) == LaunchTabPreference.home.rawValue)
        #expect(defaults.bool(forKey: AppStorageKey.contextualTipsEnabled))
        #expect(BibleTranslation.default == .kjv)
        #expect(defaults.integer(forKey: AppStorageKey.dailyGoalMinutes) == 30)
        #expect(defaults.string(forKey: AppStorageKey.verseOfDayScope) == "whole")
        #expect(defaults.string(forKey: AppStorageKey.verseOfDayRefreshFrequency) == VOTDRefreshFrequency.custom.rawValue)
        #expect(defaults.integer(forKey: AppStorageKey.verseOfDayRefresh1Hour) == 6)
        #expect(defaults.integer(forKey: AppStorageKey.verseOfDayRefresh2Hour) == 18)
        #expect(defaults.integer(forKey: AppStorageKey.verseOfDayRefresh1Minute) == 0)
        #expect(defaults.integer(forKey: AppStorageKey.verseOfDayRefresh2Minute) == 0)
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
    func anExistingInstallKeepsTheRecentMarkerDefaults() throws {
        let defaults = try makeDefaults()
        defaults.set(true, forKey: AppStorageKey.didCleanupAppTimeKeys)
        defaults.set(true, forKey: AppStorageKey.didKeepPreviousReaderDefaultsV1)
        register(defaults)

        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsBookmarkMarkersKey) == false)
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsFavoriteMarkersKey) == false)
        #expect(defaults.bool(forKey: ReaderDisplaySettings.showsPinnedVerseMarkerKey) == false)
    }

    @Test
    func anExistingInstallKeepsItsHomeCards() throws {
        let defaults = try makeDefaults()
        defaults.set(true, forKey: AppStorageKey.didCleanupAppTimeKeys)
        register(defaults)

        let raw = try #require(defaults.string(forKey: AppStorageKey.homeCardHidden))
        let ids = try JSONDecoder().decode([String].self, from: Data(raw.utf8))
        #expect(ids.contains(HomeCardID.savedVerses.rawValue))
        #expect(!ids.contains(HomeCardID.today.rawValue))
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
