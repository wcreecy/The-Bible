import Foundation
import SwiftUI

// Centralized persistence for Home card order/visibility and a single "favorite" layout snapshot.
// This store owns the @AppStorage keys and JSON (de)serialization so Views don’t duplicate logic.
@MainActor
struct HomeLayoutStore {
    // Keys (kept identical to existing usage)
    private static let keyOrder = "homeCardOrder"
    private static let keyHidden = "homeCardHidden"
    private static let keyFavOrder = "homeCardFavoriteOrder"
    private static let keyFavHidden = "homeCardFavoriteHidden"

    // Underlying storage
    @AppStorage(Self.keyOrder) private var orderRaw: String = ""
    @AppStorage(Self.keyHidden) private var hiddenRaw: String = ""
    @AppStorage(Self.keyFavOrder) private var favOrderRaw: String = ""
    @AppStorage(Self.keyFavHidden) private var favHiddenRaw: String = ""

    // Baseline hidden set used when no hidden config exists
    static let baselineHidden: Set<SettingsView.HomeCardID> = [.games, .streaks, .bibleStats]

    init() {}

    // MARK: - Core load/save

    func load() -> (order: [SettingsView.HomeCardID], hidden: Set<SettingsView.HomeCardID>) {
        // Decode order
        let order: [SettingsView.HomeCardID] = {
            if let data = orderRaw.data(using: .utf8),
               let ids = try? JSONDecoder().decode([String].self, from: data) {
                let mapped = ids.compactMap { SettingsView.HomeCardID(rawValue: $0) }
                // Append any newly added IDs to the end
                let missing = SettingsView.HomeCardID.allCases.filter { !mapped.contains($0) }
                return mapped + missing
            } else {
                return SettingsView.HomeCardID.allCases
            }
        }()

        // Decode hidden
        let hidden: Set<SettingsView.HomeCardID> = {
            if let data = hiddenRaw.data(using: .utf8),
               let ids = try? JSONDecoder().decode([String].self, from: data) {
                return Set(ids.compactMap { SettingsView.HomeCardID(rawValue: $0) })
            } else {
                return Self.baselineHidden
            }
        }()

        return (order, hidden)
    }

    func save(order: [SettingsView.HomeCardID], hidden: Set<SettingsView.HomeCardID>) {
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

        notifyChanged()
    }

    // MARK: - Favorite snapshot

    var hasFavorite: Bool {
        !favOrderRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveFavorite(order: [SettingsView.HomeCardID], hidden: Set<SettingsView.HomeCardID>) {
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
    }

    func loadFavorite() -> (order: [SettingsView.HomeCardID], hidden: Set<SettingsView.HomeCardID>)? {
        guard let orderData = favOrderRaw.data(using: .utf8),
              let orderIDs = try? JSONDecoder().decode([String].self, from: orderData) else {
            return nil
        }
        var order = orderIDs.compactMap { SettingsView.HomeCardID(rawValue: $0) }
        // Ensure newly-added IDs are appended
        let missing = SettingsView.HomeCardID.allCases.filter { !order.contains($0) }
        order.append(contentsOf: missing)

        var hidden: Set<SettingsView.HomeCardID> = []
        if let hiddenData = favHiddenRaw.data(using: .utf8),
           let hiddenIDs = try? JSONDecoder().decode([String].self, from: hiddenData) {
            hidden = Set(hiddenIDs.compactMap { SettingsView.HomeCardID(rawValue: $0) })
        }
        return (order, hidden)
    }

    // Applies favorite to current layout and notifies listeners
    func applyFavoriteIfAvailable() {
        guard let fav = loadFavorite() else { return }
        save(order: fav.order, hidden: fav.hidden)
    }

    // MARK: - Defaults

    func resetToDefaults() {
        // Clear current and favorite to return to baseline
        orderRaw = ""
        hiddenRaw = ""
        favOrderRaw = ""
        favHiddenRaw = ""
        notifyChanged()
    }

    // MARK: - Notification

    private func notifyChanged() {
        NotificationCenter.default.post(name: .init("homeLayoutChanged"), object: nil)
    }
}
