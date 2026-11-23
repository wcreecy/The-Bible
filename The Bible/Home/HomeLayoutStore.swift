import Foundation
import SwiftUI
import UIKit

// Centralized persistence for Home card order/visibility and a single "favorite" layout snapshot.
// This store owns the @AppStorage keys and JSON (de)serialization so Views don’t duplicate logic.
@MainActor
struct HomeLayoutStore {
    // Keys (kept identical to existing usage)
    private static let keyOrder = AppStorageKey.homeCardOrder
    private static let keyHidden = AppStorageKey.homeCardHidden
    private static let keyFavOrder = "homeCardFavoriteOrder"
    private static let keyFavHidden = "homeCardFavoriteHidden"
    private static let keyFavSavedAt = "homeCardFavoriteSavedAt"
    private static let keyTodayVisibilityMigrated = "homeTodayVisibilityMigratedV1"
    private static let keyFavoriteTodayVisibilityMigrated = "homeFavoriteTodayVisibilityMigratedV1"
    static let keyColumns = "homeDashboardColumns"
    static let keyFavColumns = "homeCardFavoriteDashboardColumns"
    static let keyReaderPanelRemovalMigrated = "homeReaderPanelRemovalMigratedV1"
    /// Settings for the iPad Today's Reading panel, since removed. Read once to rearrange
    /// layouts built around it, then deleted.
    static let retiredReaderPanelKeys = [
        "homeBibleReaderVisible",
        "homeCardFavoriteBibleReaderVisible",
        "homeBibleReaderColumn",
        "homeCardFavoriteBibleReaderColumn",
        "homeBibleReaderOnLeft",
        "homeCardFavoriteBibleReaderOnLeft",
        "homeReaderSource",
        "homeBibleReaderContentHeight"
    ]

    // Underlying storage
    @AppStorage(Self.keyOrder) private var orderRaw: String = ""
    @AppStorage(Self.keyHidden) private var hiddenRaw: String = ""
    @AppStorage(Self.keyFavOrder) private var favOrderRaw: String = ""
    @AppStorage(Self.keyFavHidden) private var favHiddenRaw: String = ""
    // Seconds since 1970 when "My Layout" was last saved; 0 for layouts saved before dates were kept.
    @AppStorage(Self.keyFavSavedAt) private var favSavedAt: Double = 0
    @AppStorage(Self.keyTodayVisibilityMigrated) private var todayVisibilityMigrated = false
    @AppStorage(Self.keyFavoriteTodayVisibilityMigrated) private var favoriteTodayVisibilityMigrated = false
    @AppStorage(Self.keyColumns) private var columnsRaw: String = ""
    @AppStorage(Self.keyFavColumns) private var favColumnsRaw: String = ""
    @AppStorage(Self.keyReaderPanelRemovalMigrated) private var readerPanelRemovalMigrated = false

    // Baseline hidden set used when no hidden config exists
    static var baselineOrder: [HomeCardID] {
        // iPad: `baselineColumns` in the order narrow widths use: the full-width verse,
        // then the columns row by row (left, middle, right).
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [
                .verseOfDay,
                .setup,
                .resumeReading,
                .today,
                .timer,
                .readingPlan,
                .streaks,
                .savedVerses,
                .study,
                .dailyFocus
            ]
        }

        // iPhone: Welcome, the daily verse, and your place to continue reading.
        return [
            .setup,
            .verseOfDay,
            .resumeReading,
            .readingPlan,
            .today,
            .savedVerses,
            .study,
            .streaks,
            .timer,
            .dailyFocus
        ]
    }
    static var baselineHidden: Set<HomeCardID> {
        Set(HomeCardID.allCases).subtracting([.setup, .verseOfDay, .resumeReading])
    }
    /// Only iPad saves its own column arrangement. Elsewhere (such as a large iPhone in
    /// landscape) the dashboard columns follow the single card order.
    static var storesColumns: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static var baselineColumns: HomeColumnLayout {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Verse of the Day heads the page at full width. Welcome and Continue Reading
            // sit below it; hidden cards retain positions for later customization.
            return HomeColumnLayout(
                left: [.verseOfDay, .setup, .timer, .savedVerses],
                middle: [.resumeReading, .readingPlan, .study],
                right: [.today, .streaks, .dailyFocus],
                verseOfDayWidth: .allColumns
            )
        }

        return HomeColumnLayout.seeded(from: baselineOrder, hidden: baselineHidden)
    }

    /// The iPad Today's Reading panel kept its column clear of cards. Layouts saved while it
    /// was showing, and now left with a column of no shown cards, spread their cards across
    /// all three columns once. Then the panel's settings are deleted.
    private func migrateRemovedReaderPanelIfNeeded() {
        guard !readerPanelRemovalMigrated else { return }
        readerPanelRemovalMigrated = true
        let defaults = UserDefaults.standard

        func rebalancedIfPanelWasShowing(
            columnsRaw: String,
            hiddenRaw: String,
            visibleKey: String
        ) -> String? {
            // The panel was on unless it had been turned off.
            guard Self.storesColumns,
                  defaults.object(forKey: visibleKey) as? Bool ?? true,
                  let columns = HomeColumnLayout(storageString: columnsRaw) else { return nil }
            let hidden = Set(
                (PersistedDecoding.decode([String].self, fromText: hiddenRaw, key: Self.keyHidden) ?? [])
                    .compactMap(HomeCardID.init(rawValue:))
            )
            let leavesAColumnEmpty = HomeColumn.allCases.contains { column in
                columns.stackedCards(in: column).allSatisfy(hidden.contains)
            }
            return leavesAColumnEmpty ? columns.rebalanced(hidden: hidden).storageString : nil
        }

        if let rebalanced = rebalancedIfPanelWasShowing(
            columnsRaw: columnsRaw,
            hiddenRaw: hiddenRaw,
            visibleKey: "homeBibleReaderVisible"
        ) {
            columnsRaw = rebalanced
        }
        if let rebalanced = rebalancedIfPanelWasShowing(
            columnsRaw: favColumnsRaw,
            hiddenRaw: favHiddenRaw,
            visibleKey: "homeCardFavoriteBibleReaderVisible"
        ) {
            favColumnsRaw = rebalanced
        }
        Self.retiredReaderPanelKeys.forEach(defaults.removeObject(forKey:))
    }

    init() {}

    // MARK: - Core load/save

    func load() -> (order: [HomeCardID], hidden: Set<HomeCardID>, columns: HomeColumnLayout) {
        migrateRemovedReaderPanelIfNeeded()

        // Decode order
        let savedOrderIDs = PersistedDecoding.decode([String].self, fromText: orderRaw, key: Self.keyOrder)
        let order: [HomeCardID] = {
            if let ids = savedOrderIDs {
                let mapped = ids.compactMap { HomeCardID(rawValue: $0) }
                // Append any newly added IDs to the end
                let missing = HomeCardID.allCases.filter { !mapped.contains($0) }
                return mapped + missing
            } else {
                return Self.baselineOrder
            }
        }()

        // Decode hidden
        let hidden: Set<HomeCardID> = {
            if let ids = PersistedDecoding.decode([String].self, fromText: hiddenRaw, key: Self.keyHidden) {
                var hidden = Set(ids.compactMap { HomeCardID(rawValue: $0) })
                if !todayVisibilityMigrated && !ids.contains(HomeCardID.today.rawValue) {
                    hidden.insert(.today)
                }
                todayVisibilityMigrated = true
                Self.showProgressIfStatsWasShown(&hidden, savedOrder: savedOrderIDs ?? [], savedHidden: ids)
                return hidden
            } else {
                return Self.baselineHidden
            }
        }()

        // Nothing saved yet: iPad starts from the default columns; elsewhere the columns
        // follow the order.
        let savedColumns = Self.storesColumns
            ? HomeColumnLayout(storageString: columnsRaw)
            : nil
        let columns = savedColumns
            ?? (Self.storesColumns && savedOrderIDs == nil
                ? Self.baselineColumns.normalized()
                : HomeColumnLayout.seeded(from: order, hidden: hidden))

        return (order, hidden, columns)
    }

    /// Saves the layout. On iPad the columns are saved too; callers editing columns should
    /// pass `columns.flatOrder` as the order so narrow widths read in a matching order.
    func save(order: [HomeCardID], hidden: Set<HomeCardID>, columns: HomeColumnLayout) {
        let previous = load()
        if order != previous.order || hidden != previous.hidden || columns.storageString != previous.columns.storageString {
            ContextualTipView.complete("home.customization")
            ContextualTipView.complete("home.layoutEditor")
        }
        if Self.storesColumns {
            columnsRaw = columns.storageString
        }

        // Encode order
        do {
            let rawIDs = order.map { $0.rawValue }
            let data = try JSONEncoder().encode(rawIDs)
            orderRaw = String(data: data, encoding: .utf8) ?? ""
        } catch {
            // Keep prior value on failure
        }

        // Encode hidden
        do {
            let rawIDs = Array(hidden).map { $0.rawValue }
            let data = try JSONEncoder().encode(rawIDs)
            hiddenRaw = String(data: data, encoding: .utf8) ?? ""
        } catch {
            // Keep prior value on failure
        }

        todayVisibilityMigrated = true

        notifyChanged()
    }

    // MARK: - Favorite snapshot

    var hasFavorite: Bool {
        !favOrderRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// When "My Layout" was last saved, if known.
    var favoriteSavedAt: Date? {
        favSavedAt > 0 ? Date(timeIntervalSince1970: favSavedAt) : nil
    }

    func saveFavorite(
        order: [HomeCardID],
        hidden: Set<HomeCardID>,
        columns: HomeColumnLayout
    ) {
        // Encode order
        do {
            let rawIDs = order.map { $0.rawValue }
            let data = try JSONEncoder().encode(rawIDs)
            favOrderRaw = String(data: data, encoding: .utf8) ?? ""
        } catch {
            // Keep prior value on failure
        }

        // Encode hidden
        do {
            let rawIDs = Array(hidden).map { $0.rawValue }
            let data = try JSONEncoder().encode(rawIDs)
            favHiddenRaw = String(data: data, encoding: .utf8) ?? ""
        } catch {
            // Keep prior value on failure
        }

        favSavedAt = Date().timeIntervalSince1970
        favoriteTodayVisibilityMigrated = true
        if Self.storesColumns {
            favColumnsRaw = columns.storageString
        }
    }

    func loadFavorite() -> (order: [HomeCardID], hidden: Set<HomeCardID>, columns: HomeColumnLayout)? {
        migrateRemovedReaderPanelIfNeeded()
        guard let orderIDs = PersistedDecoding.decode([String].self, fromText: favOrderRaw, key: Self.keyFavOrder) else {
            return nil
        }
        var order = orderIDs.compactMap { HomeCardID(rawValue: $0) }
        // Ensure newly-added IDs are appended
        let missing = HomeCardID.allCases.filter { !order.contains($0) }
        order.append(contentsOf: missing)

        var hidden: Set<HomeCardID> = []
        if let hiddenIDs = PersistedDecoding.decode([String].self, fromText: favHiddenRaw, key: Self.keyFavHidden) {
            hidden = Set(hiddenIDs.compactMap { HomeCardID(rawValue: $0) })
            if !favoriteTodayVisibilityMigrated && !hiddenIDs.contains(HomeCardID.today.rawValue) {
                hidden.insert(.today)
            }
            favoriteTodayVisibilityMigrated = true
            Self.showProgressIfStatsWasShown(&hidden, savedOrder: orderIDs, savedHidden: hiddenIDs)
        } else if !favoriteTodayVisibilityMigrated {
            hidden.insert(.today)
            favoriteTodayVisibilityMigrated = true
        }
        // Layouts saved before columns existed are arranged from their order.
        let columns = (Self.storesColumns ? HomeColumnLayout(storageString: favColumnsRaw) : nil)
            ?? HomeColumnLayout.seeded(from: order, hidden: hidden)
        return (order, hidden, columns)
    }

    // Applies favorite to current layout and notifies listeners
    func applyFavoriteIfAvailable() {
        guard let fav = loadFavorite() else { return }
        save(order: fav.order, hidden: fav.hidden, columns: fav.columns)
    }

    // MARK: - Retired cards

    /// The Your Stats card ("bibleStats") was merged into the streak card, now Your Progress.
    /// A layout that showed Your Stats shows Your Progress instead, so no one loses their stats
    /// from Home. The Search card was removed outright; its saved ID no longer decodes.
    static func showProgressIfStatsWasShown(
        _ hidden: inout Set<HomeCardID>,
        savedOrder: [String],
        savedHidden: [String]
    ) {
        let retiredStats = "bibleStats"
        guard savedOrder.contains(retiredStats), !savedHidden.contains(retiredStats) else { return }
        hidden.remove(.streaks)
    }

    // MARK: - Notification

    private func notifyChanged() {
        NotificationCenter.default.post(name: .homeLayoutChanged, object: nil)
    }
}
