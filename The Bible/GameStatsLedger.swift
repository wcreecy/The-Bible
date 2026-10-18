import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Syncs game statistics as per-installation contributions so plays from different
/// devices add together instead of overwriting each other.
///
/// Each installation publishes one iCloud key containing only what it recorded itself.
/// The values the rest of the app reads from `UserDefaults` are totals rebuilt from all
/// published ledgers:
/// - Sum counters and maps: largest carried-over baseline + every device's contributions.
/// - Max counters and maps (best streaks, solved days): the largest value seen anywhere.
///
/// Local writes keep going straight to `UserDefaults`. On each reconcile the ledger
/// captures the difference from the last totals it wrote and adds it to this device's
/// contributions, so game code does not need to know about syncing.
@MainActor
final class GameStatsLedger {
    static let shared = GameStatsLedger()

    struct Section: Codable, Equatable {
        var counters: [String: Int] = [:]
        var maps: [String: [String: Int]] = [:]
        var nestedMaps: [String: [String: [String: Int]]] = [:]
    }

    struct Payload: Codable, Equatable {
        /// The game reset epoch this ledger belongs to. Older ledgers are ignored.
        var epoch: Double
        /// Totals this installation held before per-device sync. Merged by maximum
        /// across devices, because each device had a copy of the same shared history.
        var baseline: Section
        /// Increments recorded on this installation since it joined the ledger.
        var contributions: Section
    }

    private enum Kind {
        case sum
        case max
    }

    static let kvsKeyPrefix = "gameStatsLedger_v1_"

    private let ownPayloadKey = "gameStatsLedgerOwnPayload_v1"
    private let ownInstallationKey = "gameStatsLedgerOwnInstallation_v1"
    private let snapshotKey = "gameStatsLedgerSnapshot_v1"
    private let resetEpochKVSKey = "gameStatsResetEpoch"
    private let lastSeenEpochKey = "gameStatsLastSeenResetEpoch"

    private let kvs = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var flushTask: Task<Void, Never>?

    private init() {}

    // MARK: - Managed keys

    /// Integer counters managed by the ledger. Best-streak keys keep the maximum.
    static var counterKeys: Set<String> {
        Set(
            iCloudSyncCoordinator.hangmanKeys
                + iCloudSyncCoordinator.beatClockKeys
                + iCloudSyncCoordinator.refMatchKeys
                + iCloudSyncCoordinator.verseMatchKeys
                + iCloudSyncCoordinator.quizKeys
                + iCloudSyncCoordinator.bookOrderKeys
                + iCloudSyncCoordinator.whoAmIKeys
                + iCloudSyncCoordinator.wordleKeys
                + iCloudSyncCoordinator.wordSearchKeys
                + iCloudSyncCoordinator.gamePlayTimeCounterKeys
        )
    }

    /// `[String: Int]` maps summed per entry.
    static var sumMapKeys: Set<String> {
        Set(
            ["gamesDailyAnswered", "gamesDailyCorrect"]
                + iCloudSyncCoordinator.perGameDailyMapKeys
                + iCloudSyncCoordinator.quizPerBookMapKeys
                + iCloudSyncCoordinator.verseMatchPerBookMapKeys
                + iCloudSyncCoordinator.hangmanPerCategoryMapKeys
                + iCloudSyncCoordinator.beatClockPerTypeMapKeys
                + iCloudSyncCoordinator.gamePlayTimeMapKeys
        )
    }

    /// `[String: Int]` maps that keep the largest value per entry.
    static var maxMapKeys: Set<String> {
        Set(iCloudSyncCoordinator.wordleSolvedMapKeys)
    }

    /// `[String: [String: Int]]` maps summed per inner entry.
    static var nestedMapKeys: Set<String> {
        Set(iCloudSyncCoordinator.quizPerBookDailyMapKeys + iCloudSyncCoordinator.verseMatchPerBookDailyMapKeys)
    }

    /// Maps keyed by `yyyy-MM-dd` day (outer key for nested maps). Days older than the
    /// retention cutoff are dropped so the ledgers stay well under iCloud's 1 MB limit.
    /// All-time game counters are separate keys and aren't affected. WORD's solved days
    /// are kept in full because its streak is counted from them.
    static var dayKeyedMapKeys: Set<String> {
        Set(["gamesDailyAnswered", "gamesDailyCorrect"]
            + iCloudSyncCoordinator.perGameDailyMapKeys
            + iCloudSyncCoordinator.gamePlayTimeMapKeys)
    }

    static var managedKeys: Set<String> {
        counterKeys.union(sumMapKeys).union(maxMapKeys).union(nestedMapKeys)
    }

    static func isManaged(_ key: String) -> Bool {
        managedKeys.contains(key)
    }

    private static func counterKind(_ key: String) -> Kind {
        key.contains("BestStreak") ? .max : .sum
    }

    // MARK: - Public entry points

    /// Coalesces bursts of game writes into one reconcile.
    func scheduleFlush() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.reconcile()
        }
    }

    /// Captures local changes into this device's ledger, publishes it, and rebuilds
    /// the totals from every device's ledger.
    func reconcile() {
        flushTask?.cancel()
        flushTask = nil
        guard iCloudSyncCoordinator.shared.isInitialDownloadComplete else { return }

        // A newer remote reset is applied by the coordinator first; rebuilding totals
        // before that would mix pre-reset ledgers back in.
        let epoch = defaults.double(forKey: lastSeenEpochKey)
        guard kvs.double(forKey: resetEpochKVSKey) <= epoch else { return }

        let cutoff = StatsHistoryRetention.cutoffDayKey()
        var own = loadOrCreateOwnPayload(epoch: epoch)
        captureLocalChanges(into: &own.contributions)
        own.baseline = Self.trimmed(own.baseline, before: cutoff)
        own.contributions = Self.trimmed(own.contributions, before: cutoff)
        saveOwnPayload(own)

        let totals = computeTotals(own: own, epoch: epoch, cutoff: cutoff)
        let changed = apply(totals)
        saveSnapshot(totals)

        if changed {
            NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
        }
    }

    /// Starts an empty ledger for a new reset epoch and removes older ledgers from iCloud.
    func resetForNewEpoch() {
        flushTask?.cancel()
        flushTask = nil
        let epoch = defaults.double(forKey: lastSeenEpochKey)

        for key in kvs.dictionaryRepresentation.keys where key.hasPrefix(Self.kvsKeyPrefix) {
            guard key != ownKVSKey else { continue }
            if let payload = decodePayload(kvs.data(forKey: key)), payload.epoch >= epoch {
                continue
            }
            kvs.removeObject(forKey: key)
        }

        let own = Payload(epoch: epoch, baseline: Section(), contributions: Section())
        saveOwnPayload(own)
        saveSnapshot(Section())

        // Rebuild totals so any ledgers already recorded under this epoch are kept.
        if iCloudSyncCoordinator.shared.isInitialDownloadComplete {
            let totals = computeTotals(own: own, epoch: epoch, cutoff: StatsHistoryRetention.cutoffDayKey())
            _ = apply(totals)
            saveSnapshot(totals)
        }
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // MARK: - Own payload

    private var ownKVSKey: String {
        Self.kvsKeyPrefix + LedgerInstallationIdentity.current
    }

    private func loadOrCreateOwnPayload(epoch: Double) -> Payload {
        let installation = LedgerInstallationIdentity.current
        let storedInstallation = defaults.string(forKey: ownInstallationKey)

        if storedInstallation == installation,
           let stored = decodePayload(defaults.data(forKey: ownPayloadKey)) {
            if stored.epoch >= epoch {
                return stored
            }
            // A reset happened since this ledger was written.
            saveSnapshot(Section())
            return Payload(epoch: epoch, baseline: Section(), contributions: Section())
        }

        // First run with per-device sync on this installation. When local values were
        // already rebuilt from ledgers (for example after restoring a backup onto a new
        // device), they include other devices' contributions and must not become a
        // baseline. Otherwise they hold this device's pre-ledger history.
        let localWasLedgerDerived = defaults.data(forKey: snapshotKey) != nil
        let baseline = localWasLedgerDerived ? legacyCloudSection() : migrationBaseline()
        defaults.set(installation, forKey: ownInstallationKey)

        // Local values are either the baseline or totals about to be rebuilt, so nothing
        // is captured as a new contribution on this first pass.
        saveSnapshot(readLocalSection())
        return Payload(epoch: epoch, baseline: baseline, contributions: Section())
    }

    private func saveOwnPayload(_ payload: Payload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        if defaults.data(forKey: ownPayloadKey) != data {
            defaults.set(data, forKey: ownPayloadKey)
        }
        if kvs.data(forKey: ownKVSKey) != data {
            kvs.set(data, forKey: ownKVSKey)
            iCloudSyncCoordinator.shared.requestSynchronize()
        }
    }

    /// The larger of this device's values and the legacy shared iCloud values.
    private func migrationBaseline() -> Section {
        let local = readLocalSection()
        let legacy = legacyCloudSection()
        var baseline = local

        for (key, value) in legacy.counters {
            baseline.counters[key] = max(baseline.counters[key] ?? 0, value)
        }
        for (key, map) in legacy.maps {
            baseline.maps[key] = mergeMax(baseline.maps[key] ?? [:], map)
        }
        for (key, nested) in legacy.nestedMaps {
            var merged = baseline.nestedMaps[key] ?? [:]
            for (outer, inner) in nested {
                merged[outer] = mergeMax(merged[outer] ?? [:], inner)
            }
            baseline.nestedMaps[key] = merged
        }
        return baseline
    }

    /// Values written to the shared legacy keys before per-device sync. These keys are
    /// no longer written, so they describe the history each device started from.
    private func legacyCloudSection() -> Section {
        var section = Section()
        for key in Self.counterKeys {
            if let number = kvs.object(forKey: key) as? NSNumber, number.intValue > 0 {
                section.counters[key] = number.intValue
            }
        }
        for key in Self.sumMapKeys.union(Self.maxMapKeys) {
            if let map = decodeMap(kvs.data(forKey: key)), !map.isEmpty {
                section.maps[key] = map.mapValues { max(0, $0) }
            }
        }
        for key in Self.nestedMapKeys {
            if let nested = decodeNestedMap(kvs.data(forKey: key)), !nested.isEmpty {
                section.nestedMaps[key] = nested
            }
        }
        return section
    }

    // MARK: - Capture

    /// Adds values that grew locally since the last totals were written.
    private func captureLocalChanges(into contributions: inout Section) {
        let snapshot = loadSnapshot()
        let local = readLocalSection()

        for key in Self.counterKeys {
            let current = local.counters[key] ?? 0
            let previous = snapshot.counters[key] ?? 0
            guard current > previous else { continue }

            switch Self.counterKind(key) {
            case .sum:
                contributions.counters[key, default: 0] += current - previous
            case .max:
                contributions.counters[key] = max(contributions.counters[key] ?? 0, current)
            }
        }

        for key in Self.sumMapKeys {
            let current = local.maps[key] ?? [:]
            let previous = snapshot.maps[key] ?? [:]
            for (entry, value) in current {
                let delta = value - (previous[entry] ?? 0)
                if delta > 0 {
                    contributions.maps[key, default: [:]][entry, default: 0] += delta
                }
            }
        }

        for key in Self.maxMapKeys {
            let current = local.maps[key] ?? [:]
            let previous = snapshot.maps[key] ?? [:]
            for (entry, value) in current where value > (previous[entry] ?? 0) {
                contributions.maps[key, default: [:]][entry] = max(
                    contributions.maps[key]?[entry] ?? 0,
                    value
                )
            }
        }

        for key in Self.nestedMapKeys {
            let current = local.nestedMaps[key] ?? [:]
            let previous = snapshot.nestedMaps[key] ?? [:]
            for (outer, inner) in current {
                for (entry, value) in inner {
                    let delta = value - (previous[outer]?[entry] ?? 0)
                    if delta > 0 {
                        contributions.nestedMaps[key, default: [:]][outer, default: [:]][entry, default: 0] += delta
                    }
                }
            }
        }
    }

    // MARK: - Totals

    private func computeTotals(own: Payload, epoch: Double, cutoff: String) -> Section {
        var payloads: [Payload] = [own]
        for (key, value) in kvs.dictionaryRepresentation where key.hasPrefix(Self.kvsKeyPrefix) {
            guard key != ownKVSKey,
                  let payload = decodePayload(value as? Data) else { continue }
            payloads.append(payload)
        }
        return Self.mergedTotals(payloads: payloads, epoch: epoch, cutoff: cutoff)
    }

    /// Reduces per-installation game ledgers into the totals shown by the app.
    /// Keeping this pure makes concurrent-device behavior deterministic and testable.
    static func mergedTotals(payloads: [Payload], epoch: Double, cutoff: String) -> Section {
        // Devices that haven't updated to the current reset epoch cannot restore old data.
        let payloads = payloads
            .filter { $0.epoch >= epoch }
            .map { payload in
                var payload = payload
                payload.baseline = Self.trimmed(payload.baseline, before: cutoff)
                payload.contributions = Self.trimmed(payload.contributions, before: cutoff)
                return payload
            }

        var totals = Section()

        for key in Self.counterKeys {
            let baseline = payloads.map { $0.baseline.counters[key] ?? 0 }.max() ?? 0
            let total: Int
            switch Self.counterKind(key) {
            case .sum:
                total = baseline + payloads.reduce(0) { $0 + max(0, $1.contributions.counters[key] ?? 0) }
            case .max:
                total = max(baseline, payloads.map { $0.contributions.counters[key] ?? 0 }.max() ?? 0)
            }
            if total > 0 { totals.counters[key] = total }
        }

        for key in Self.sumMapKeys {
            var map: [String: Int] = [:]
            for payload in payloads {
                map = Self.mergedMaximum(map, payload.baseline.maps[key] ?? [:])
            }
            for payload in payloads {
                for (entry, value) in payload.contributions.maps[key] ?? [:] {
                    map[entry, default: 0] += max(0, value)
                }
            }
            if !map.isEmpty { totals.maps[key] = map }
        }

        for key in Self.maxMapKeys {
            var map: [String: Int] = [:]
            for payload in payloads {
                map = Self.mergedMaximum(map, payload.baseline.maps[key] ?? [:])
                map = Self.mergedMaximum(map, payload.contributions.maps[key] ?? [:])
            }
            if !map.isEmpty { totals.maps[key] = map }
        }

        for key in Self.nestedMapKeys {
            var nested: [String: [String: Int]] = [:]
            for payload in payloads {
                for (outer, inner) in payload.baseline.nestedMaps[key] ?? [:] {
                    nested[outer] = Self.mergedMaximum(nested[outer] ?? [:], inner)
                }
            }
            for payload in payloads {
                for (outer, inner) in payload.contributions.nestedMaps[key] ?? [:] {
                    for (entry, value) in inner {
                        nested[outer, default: [:]][entry, default: 0] += max(0, value)
                    }
                }
            }
            if !nested.isEmpty { totals.nestedMaps[key] = nested }
        }

        return totals
    }

    private static func mergedMaximum(_ lhs: [String: Int], _ rhs: [String: Int]) -> [String: Int] {
        var merged = lhs
        for (key, value) in rhs {
            merged[key] = max(merged[key] ?? 0, max(0, value))
        }
        return merged
    }

    /// Writes totals into `UserDefaults`. Returns whether any stored value changed.
    private func apply(_ totals: Section) -> Bool {
        var changed = false

        for key in Self.counterKeys {
            let total = totals.counters[key] ?? 0
            if total == 0 && defaults.object(forKey: key) == nil { continue }
            if defaults.integer(forKey: key) != total {
                defaults.set(total, forKey: key)
                changed = true
            }
        }

        for key in Self.sumMapKeys.union(Self.maxMapKeys) {
            let total = totals.maps[key] ?? [:]
            let current = decodeMap(defaults.data(forKey: key)) ?? [:]
            guard current != total else { continue }
            if total.isEmpty {
                defaults.removeObject(forKey: key)
            } else if let data = try? JSONEncoder().encode(total) {
                defaults.set(data, forKey: key)
            }
            changed = true
        }

        for key in Self.nestedMapKeys {
            let total = totals.nestedMaps[key] ?? [:]
            let current = decodeNestedMap(defaults.data(forKey: key)) ?? [:]
            guard current != total else { continue }
            if total.isEmpty {
                defaults.removeObject(forKey: key)
            } else if let data = try? JSONEncoder().encode(total) {
                defaults.set(data, forKey: key)
            }
            changed = true
        }

        return changed
    }

    // MARK: - Local values and snapshot

    private func readLocalSection() -> Section {
        var section = Section()
        for key in Self.counterKeys {
            let value = defaults.integer(forKey: key)
            if value > 0 { section.counters[key] = value }
        }
        for key in Self.sumMapKeys.union(Self.maxMapKeys) {
            if let map = decodeMap(defaults.data(forKey: key)), !map.isEmpty {
                section.maps[key] = map.mapValues { max(0, $0) }
            }
        }
        for key in Self.nestedMapKeys {
            if let nested = decodeNestedMap(defaults.data(forKey: key)), !nested.isEmpty {
                section.nestedMaps[key] = nested
            }
        }
        return section
    }

    private func loadSnapshot() -> Section {
        guard let data = defaults.data(forKey: snapshotKey),
              let section = try? JSONDecoder().decode(Section.self, from: data) else {
            return Section()
        }
        return section
    }

    private func saveSnapshot(_ section: Section) {
        if let data = try? JSONEncoder().encode(section) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    // MARK: - Helpers

    /// Removes day entries before `cutoff` from the day-keyed maps.
    private static func trimmed(_ section: Section, before cutoff: String) -> Section {
        var section = section
        for key in dayKeyedMapKeys {
            guard let map = section.maps[key] else { continue }
            let kept = map.filter { !StatsHistoryRetention.isBeforeCutoff($0.key, cutoff: cutoff) }
            section.maps[key] = kept.isEmpty ? nil : kept
        }
        for key in nestedMapKeys {
            guard let nested = section.nestedMaps[key] else { continue }
            let kept = nested.filter { !StatsHistoryRetention.isBeforeCutoff($0.key, cutoff: cutoff) }
            section.nestedMaps[key] = kept.isEmpty ? nil : kept
        }
        return section
    }

    private func mergeMax(_ lhs: [String: Int], _ rhs: [String: Int]) -> [String: Int] {
        var merged = lhs
        for (key, value) in rhs {
            merged[key] = max(merged[key] ?? 0, max(0, value))
        }
        return merged
    }

    private func decodePayload(_ data: Data?) -> Payload? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Payload.self, from: data)
    }

    private func decodeMap(_ data: Data?) -> [String: Int]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([String: Int].self, from: data)
    }

    private func decodeNestedMap(_ data: Data?) -> [String: [String: Int]]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([String: [String: Int]].self, from: data)
    }
}

/// Identifies this installation's game ledger. The identifier is tied to the device's
/// vendor identifier so restoring a backup onto another device starts a separate
/// ledger instead of sharing one, which would let the two devices overwrite each other.
@MainActor
enum LedgerInstallationIdentity {
    private static let identifierKey = "gameStatsLedgerInstallationID"
    private static let vendorKey = "gameStatsLedgerInstallationVendorID"

    static var current: String {
        let defaults = UserDefaults.standard
        #if canImport(UIKit)
        let vendor = UIDevice.current.identifierForVendor?.uuidString
        #else
        let vendor: String? = nil
        #endif

        if let stored = defaults.string(forKey: identifierKey) {
            let storedVendor = defaults.string(forKey: vendorKey)
            if let vendor, storedVendor != nil, storedVendor != vendor {
                // Restored onto a different device: fall through to a new identifier.
            } else {
                if storedVendor == nil, let vendor {
                    defaults.set(vendor, forKey: vendorKey)
                }
                return stored
            }
        }

        let identifier = UUID().uuidString
        defaults.set(identifier, forKey: identifierKey)
        if let vendor {
            defaults.set(vendor, forKey: vendorKey)
        }
        return identifier
    }
}
