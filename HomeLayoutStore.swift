import Foundation
import SwiftUI
import UIKit

// Centralized persistence for Home card order/visibility and a single "favorite" layout snapshot.
// This store owns the @AppStorage keys and JSON (de)serialization so Views don’t duplicate logic.
@MainActor
struct HomeLayoutStore {
    // Keys (kept identical to existing usage)
    private static let keyOrder = "homeCardOrder"
    private static let keyHidden = "homeCardHidden"
    private static let keyBibleReaderVisible = "homeBibleReaderVisible"
    private static let keyFavOrder = "homeCardFavoriteOrder"
    private static let keyFavHidden = "homeCardFavoriteHidden"
    private static let keyFavBibleReaderVisible = "homeCardFavoriteBibleReaderVisible"
    private static let keyTodayVisibilityMigrated = "homeTodayVisibilityMigratedV1"
    private static let keyFavoriteTodayVisibilityMigrated = "homeFavoriteTodayVisibilityMigratedV1"
    static let keyColumns = "homeDashboardColumns"
    static let keyFavColumns = "homeCardFavoriteDashboardColumns"
    static let keyBibleReaderColumn = "homeBibleReaderColumn"
    static let keyFavBibleReaderColumn = "homeCardFavoriteBibleReaderColumn"
    // Replaced by the column keys above; read once to carry over a left-side choice.
    static let legacyKeyBibleReaderOnLeft = "homeBibleReaderOnLeft"
    static let legacyKeyFavBibleReaderOnLeft = "homeCardFavoriteBibleReaderOnLeft"
    static let defaultBibleReaderColumn: HomeColumn = .right

    // Underlying storage
    @AppStorage(Self.keyOrder) private var orderRaw: String = ""
    @AppStorage(Self.keyHidden) private var hiddenRaw: String = ""
    @AppStorage(Self.keyBibleReaderVisible) private var bibleReaderVisible: Bool = Self.defaultBibleReaderVisible
    @AppStorage(Self.keyFavOrder) private var favOrderRaw: String = ""
    @AppStorage(Self.keyFavHidden) private var favHiddenRaw: String = ""
    @AppStorage(Self.keyFavBibleReaderVisible) private var favBibleReaderVisible: Bool = Self.defaultBibleReaderVisible
    @AppStorage(Self.keyTodayVisibilityMigrated) private var todayVisibilityMigrated = false
    @AppStorage(Self.keyFavoriteTodayVisibilityMigrated) private var favoriteTodayVisibilityMigrated = false
    @AppStorage(Self.keyColumns) private var columnsRaw: String = ""
    @AppStorage(Self.keyFavColumns) private var favColumnsRaw: String = ""
    @AppStorage(Self.keyBibleReaderColumn) private var bibleReaderColumn: HomeColumn = Self.defaultBibleReaderColumn
    @AppStorage(Self.keyFavBibleReaderColumn) private var favBibleReaderColumn: HomeColumn = Self.defaultBibleReaderColumn

    // Baseline hidden set used when no hidden config exists
    static var baselineOrder: [HomeCardID] {
        // iPad: read row by row into the dashboard's left and middle columns (see
        // `baselineColumns`), with the Today's Reading panel in the right column.
        if UIDevice.current.userInterfaceIdiom == .pad {
            return [
                .verseOfDay,
                .setup,
                .today,
                .savedVerses,
                .study,
                .streaks,
                .timer,
                .dailyFocus,
                .resumeReading,
                .search,
                .bibleStats
            ]
        }

        // iPhone: get back into the text and what it's about first, then the daily verse and challenges.
        // Search, Your Stats and Daily Focus are opt-in. Get Started leads until it's dismissed.
        return [
            .setup,
            .resumeReading,
            .study,
            .verseOfDay,
            .savedVerses,
            .today,
            .streaks,
            .timer,
            .search,
            .bibleStats,
            .dailyFocus
        ]
    }
    static var baselineHidden: Set<HomeCardID> {
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Today's Reading covers Continue Reading, and the header has a Search button.
            return [.resumeReading, .search, .bibleStats]
        }
        // Search duplicates the header's Search button; Your Stats and Daily Focus are opt-in.
        return [.search, .bibleStats, .dailyFocus]
    }
    // The iPad Today's Reading panel; iPhone does not show it.
    static let defaultBibleReaderVisible = true

    /// Only iPad saves its own column arrangement. Elsewhere (such as a large iPhone in
    /// landscape) the dashboard columns follow the single card order.
    static var storesColumns: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static var baselineColumns: HomeColumnLayout {
        HomeColumnLayout.seeded(
            from: baselineOrder,
            hidden: baselineHidden,
            readerColumn: defaultBibleReaderVisible ? defaultBibleReaderColumn : nil
        )
    }

    /// The column the Today's Reading panel occupies, or nil when it's hidden.
    private var visibleReaderColumn: HomeColumn? {
        bibleReaderVisible ? bibleReaderColumn : nil
    }

    /// Carries a Left/Right reader choice saved before the panel could use any column.
    private func migrateReaderSideIfNeeded() {
        let defaults = UserDefaults.standard
        for (legacyKey, newKey) in [
            (Self.legacyKeyBibleReaderOnLeft, Self.keyBibleReaderColumn),
            (Self.legacyKeyFavBibleReaderOnLeft, Self.keyFavBibleReaderColumn)
        ] where defaults.object(forKey: legacyKey) != nil {
            if defaults.object(forKey: newKey) == nil {
                let column: HomeColumn = defaults.bool(forKey: legacyKey) ? .left : .right
                defaults.set(column.rawValue, forKey: newKey)
            }
            defaults.removeObject(forKey: legacyKey)
        }
    }

    init() {}

    // MARK: - Core load/save

    func load() -> (order: [HomeCardID], hidden: Set<HomeCardID>, columns: HomeColumnLayout) {
        migrateReaderSideIfNeeded()

        // Decode order
        let order: [HomeCardID] = {
            if let data = orderRaw.data(using: .utf8),
               let ids = try? JSONDecoder().decode([String].self, from: data) {
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
            if let data = hiddenRaw.data(using: .utf8),
               let ids = try? JSONDecoder().decode([String].self, from: data) {
                var hidden = Set(ids.compactMap { HomeCardID(rawValue: $0) })
                if !todayVisibilityMigrated && !ids.contains(HomeCardID.today.rawValue) {
                    hidden.insert(.today)
                }
                todayVisibilityMigrated = true
                return hidden
            } else {
                return Self.baselineHidden
            }
        }()

        // First launch with columns: build them from the order so nothing moves.
        let columns = (Self.storesColumns ? HomeColumnLayout(storageString: columnsRaw, readerColumn: visibleReaderColumn) : nil)
            ?? HomeColumnLayout.seeded(from: order, hidden: hidden, readerColumn: visibleReaderColumn)

        return (order, hidden, columns)
    }

    /// Saves the layout. On iPad the columns are saved too; callers editing columns should
    /// pass `columns.flatOrder` as the order so narrow widths read in a matching order.
    func save(order: [HomeCardID], hidden: Set<HomeCardID>, columns: HomeColumnLayout) {
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

    func saveFavorite(
        order: [HomeCardID],
        hidden: Set<HomeCardID>,
        columns: HomeColumnLayout,
        bibleReaderVisible: Bool
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

        favBibleReaderVisible = bibleReaderVisible
        favoriteTodayVisibilityMigrated = true
        if Self.storesColumns {
            favColumnsRaw = columns.storageString
            favBibleReaderColumn = bibleReaderColumn
        }
    }

    func loadFavorite() -> (
        order: [HomeCardID],
        hidden: Set<HomeCardID>,
        columns: HomeColumnLayout,
        bibleReaderVisible: Bool,
        bibleReaderColumn: HomeColumn
    )? {
        guard let orderData = favOrderRaw.data(using: .utf8),
              let orderIDs = try? JSONDecoder().decode([String].self, from: orderData) else {
            return nil
        }
        var order = orderIDs.compactMap { HomeCardID(rawValue: $0) }
        // Ensure newly-added IDs are appended
        let missing = HomeCardID.allCases.filter { !order.contains($0) }
        order.append(contentsOf: missing)

        var hidden: Set<HomeCardID> = []
        if let hiddenData = favHiddenRaw.data(using: .utf8),
           let hiddenIDs = try? JSONDecoder().decode([String].self, from: hiddenData) {
            hidden = Set(hiddenIDs.compactMap { HomeCardID(rawValue: $0) })
            if !favoriteTodayVisibilityMigrated && !hiddenIDs.contains(HomeCardID.today.rawValue) {
                hidden.insert(.today)
            }
            favoriteTodayVisibilityMigrated = true
        } else if !favoriteTodayVisibilityMigrated {
            hidden.insert(.today)
            favoriteTodayVisibilityMigrated = true
        }
        // Layouts saved before columns existed are arranged from their order.
        migrateReaderSideIfNeeded()
        let favReaderColumn = favBibleReaderVisible ? favBibleReaderColumn : nil
        let columns = (Self.storesColumns ? HomeColumnLayout(storageString: favColumnsRaw, readerColumn: favReaderColumn) : nil)
            ?? HomeColumnLayout.seeded(from: order, hidden: hidden, readerColumn: favReaderColumn)
        return (order, hidden, columns, favBibleReaderVisible, favBibleReaderColumn)
    }

    // Applies favorite to current layout and notifies listeners
    func applyFavoriteIfAvailable() {
        guard let fav = loadFavorite() else { return }
        bibleReaderVisible = fav.bibleReaderVisible
        bibleReaderColumn = fav.bibleReaderColumn
        save(order: fav.order, hidden: fav.hidden, columns: fav.columns)
    }

    // MARK: - Notification

    private func notifyChanged() {
        NotificationCenter.default.post(name: .homeLayoutChanged, object: nil)
    }
}
