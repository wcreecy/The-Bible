import Foundation
import SwiftUI

// Centralized persistence for Home card order/visibility and a single "favorite" layout snapshot.
// This store owns the @AppStorage keys and JSON (de)serialization so Views don’t duplicate logic.
@MainActor
struct HomeLayoutStore {
    // Keys (kept identical to existing usage)
    private static let keyOrder = "homeCardOrder"
    private static let keyHidden = "homeCardHidden"
    private static let keyMain = "homeCardMain"
    private static let keyFavOrder = "homeCardFavoriteOrder"
    private static let keyFavHidden = "homeCardFavoriteHidden"
    private static let keyFavMain = "homeCardFavoriteMain"

    // Underlying storage
    @AppStorage(Self.keyOrder) private var orderRaw: String = ""
    @AppStorage(Self.keyHidden) private var hiddenRaw: String = ""
    @AppStorage(Self.keyMain) private var mainRaw: String = ""
    @AppStorage(Self.keyFavOrder) private var favOrderRaw: String = ""
    @AppStorage(Self.keyFavHidden) private var favHiddenRaw: String = ""
    @AppStorage(Self.keyFavMain) private var favMainRaw: String = ""

    // Baseline hidden set used when no hidden config exists
    static let baselineHidden: Set<HomeCardID> = []
    static let baselineMain: Set<HomeCardID> = [.verseOfDay, .resumeReading]

    init() {}

    // MARK: - Core load/save

    func load() -> (order: [HomeCardID], hidden: Set<HomeCardID>, main: Set<HomeCardID>) {
        // Decode order
        let order: [HomeCardID] = {
            if let data = orderRaw.data(using: .utf8),
               let ids = try? JSONDecoder().decode([String].self, from: data) {
                let mapped = ids.compactMap { HomeCardID(rawValue: $0) }
                // Append any newly added IDs to the end
                let missing = HomeCardID.allCases.filter { !mapped.contains($0) }
                return mapped + missing
            } else {
                return HomeCardID.allCases
            }
        }()

        // Decode hidden
        let hidden: Set<HomeCardID> = {
            if let data = hiddenRaw.data(using: .utf8),
               let ids = try? JSONDecoder().decode([String].self, from: data) {
                return Set(ids.compactMap { HomeCardID(rawValue: $0) })
            } else {
                return Self.baselineHidden
            }
        }()

        let main = decodeSet(from: mainRaw) ?? Self.baselineMain
        return (order, hidden, main)
    }

    func save(order: [HomeCardID], hidden: Set<HomeCardID>, main: Set<HomeCardID>) {
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

        mainRaw = encode(main)

        notifyChanged()
    }

    // MARK: - Favorite snapshot

    var hasFavorite: Bool {
        !favOrderRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveFavorite(order: [HomeCardID], hidden: Set<HomeCardID>, main: Set<HomeCardID>) {
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

        favMainRaw = encode(main)
    }

    func loadFavorite() -> (order: [HomeCardID], hidden: Set<HomeCardID>, main: Set<HomeCardID>)? {
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
        }
        let main = decodeSet(from: favMainRaw) ?? Self.baselineMain
        return (order, hidden, main)
    }

    // Applies favorite to current layout and notifies listeners
    func applyFavoriteIfAvailable() {
        guard let fav = loadFavorite() else { return }
        save(order: fav.order, hidden: fav.hidden, main: fav.main)
    }

    private func encode(_ ids: Set<HomeCardID>) -> String {
        let rawIDs = ids.map(\.rawValue)
        guard let data = try? JSONEncoder().encode(rawIDs) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func decodeSet(from rawValue: String) -> Set<HomeCardID>? {
        guard !rawValue.isEmpty,
              let data = rawValue.data(using: .utf8),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return nil }
        return Set(ids.compactMap(HomeCardID.init(rawValue:)))
    }

    // MARK: - Notification

    private func notifyChanged() {
        NotificationCenter.default.post(name: .init("homeLayoutChanged"), object: nil)
    }
}
