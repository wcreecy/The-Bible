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
        /// Set only on the retired ledger: the installations folded into it. Older app
        /// versions ignore this and read the retired ledger as one more device.
        var retiredInstallations: [String]? = nil
    }

    struct Diagnostics: Equatable {
        let installationID: String
        let deviceLedgerCount: Int
        let localContributionCount: Int
    }

    private enum Kind {
        case sum
        case max
    }

    static let kvsKeyPrefix = "gameStatsLedger_v1_"
    /// Ledgers from installations that stopped changing (usually deleted or replaced
    /// apps) are folded into this one, so each old install doesn't keep its own key.
    static let retiredKVSKey = kvsKeyPrefix + "retired"
    /// How long a ledger has to stay unchanged before it counts as inactive.
    static let inactivityInterval: TimeInterval = 365 * 24 * 60 * 60

    private let ownPayloadKey = AppStorageKey.gameStatsLedgerOwnPayloadV1
    private let ownInstallationKey = AppStorageKey.gameStatsLedgerOwnInstallationV1
    private let snapshotKey = AppStorageKey.gameStatsLedgerSnapshotV1
    private let activityKey = AppStorageKey.gameStatsLedgerActivityV1
    private let resetEpochKVSKey = AppStorageKey.gameStatsResetEpoch
    private let lastSeenEpochKey = AppStorageKey.gameStatsLastSeenResetEpoch

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
                + iCloudSyncCoordinator.bibleTriviaKeys
                + iCloudSyncCoordinator.bookOrderKeys
                + iCloudSyncCoordinator.whoAmIKeys
                + iCloudSyncCoordinator.wordleKeys
                + iCloudSyncCoordinator.wordSearchKeys
                + iCloudSyncCoordinator.scrambleKeys
                + iCloudSyncCoordinator.crosswordKeys
                + iCloudSyncCoordinator.gamePlayTimeCounterKeys
        )
    }

    /// `[String: Int]` maps summed per entry.
    static var sumMapKeys: Set<String> {
        Set(
            ["gamesDailyAnswered", "gamesDailyCorrect"]
                + iCloudSyncCoordinator.perGameDailyMapKeys
                + iCloudSyncCoordinator.quizPerBookMapKeys
                + iCloudSyncCoordinator.triviaPerBookMapKeys
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
        Set(
            iCloudSyncCoordinator.quizPerBookDailyMapKeys
                + iCloudSyncCoordinator.triviaPerBookDailyMapKeys
                + iCloudSyncCoordinator.verseMatchPerBookDailyMapKeys
        )
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
        // Before capturing new plays, so the plays already folded in aren't counted twice.
        acknowledgeRetirementIfNeeded(of: &own, epoch: epoch)
        captureLocalChanges(into: &own.contributions)
        own.baseline = Self.trimmed(own.baseline, before: cutoff)
        own.contributions = Self.trimmed(own.contributions, before: cutoff)
        saveOwnPayload(own)
        retireInactiveLedgers(epoch: epoch, cutoff: cutoff)

        let totals = computeTotals(own: own, epoch: epoch, cutoff: cutoff)
        let changed = apply(totals)
        saveSnapshot(totals)

        if changed {
            AppDataChanges.shared.gameStatsChanged()
        }
    }

    var diagnostics: Diagnostics {
        let installationID = LedgerInstallationIdentity.current
        let epoch = defaults.double(forKey: lastSeenEpochKey)
        let payload = loadOrCreateOwnPayload(epoch: epoch)
        let contributionCount = Self.contributionCount(in: payload.contributions)
        let ledgerCount = kvs.dictionaryRepresentation.keys.count {
            $0.hasPrefix(Self.kvsKeyPrefix) && $0 != Self.retiredKVSKey
        }
        return Diagnostics(
            installationID: installationID,
            deviceLedgerCount: ledgerCount,
            localContributionCount: contributionCount
        )
    }

    private static func contributionCount(in section: Section) -> Int {
        var total = section.counters.values.reduce(0, +)
        for map in section.maps.values {
            total += map.values.reduce(0, +)
        }
        for nestedMap in section.nestedMaps.values {
            for map in nestedMap.values {
                total += map.values.reduce(0, +)
            }
        }
        return total
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
        defaults.removeObject(forKey: activityKey)

        // Rebuild totals so any ledgers already recorded under this epoch are kept.
        if iCloudSyncCoordinator.shared.isInitialDownloadComplete {
            let totals = computeTotals(own: own, epoch: epoch, cutoff: StatsHistoryRetention.cutoffDayKey())
            _ = apply(totals)
            saveSnapshot(totals)
        }
        AppDataChanges.shared.gameStatsChanged()
    }

    // MARK: - Retiring inactive ledgers

    private struct LedgerActivity: Codable {
        /// A checksum of the ledger as last seen, to notice when it changes.
        var fingerprint: UInt64
        /// When this device first saw the ledger as it is now.
        var since: Date
    }

    /// A ledger this installation published before being retired was folded into the
    /// retired ledger. Start its contributions over and take it off the retired list.
    private func acknowledgeRetirementIfNeeded(of own: inout Payload, epoch: Double) {
        let installation = LedgerInstallationIdentity.current
        guard var retired = decodePayload(kvs.data(forKey: Self.retiredKVSKey)),
              retired.epoch >= epoch,
              let installations = retired.retiredInstallations,
              installations.contains(installation) else { return }

        own.contributions = Section()
        retired.retiredInstallations = installations.filter { $0 != installation }
        writeRetired(retired)
    }

    /// Folds ledgers that haven't changed in a year into the retired ledger and removes
    /// their keys. Totals don't change: the retired ledger holds the same counts.
    ///
    /// Only the active installation with the lowest identifier does this, so two devices
    /// don't fold at the same time and overwrite each other's retired ledger.
    private func retireInactiveLedgers(epoch: Double, cutoff: String, now: Date = Date()) {
        let ownKey = ownKVSKey
        var activity = loadActivity()
        var activeInstallations: Set<String> = [LedgerInstallationIdentity.current]
        var inactive: [(key: String, installation: String, payload: Payload)] = []
        var seenKeys: Set<String> = []

        for (key, value) in kvs.dictionaryRepresentation where key.hasPrefix(Self.kvsKeyPrefix) {
            guard key != ownKey, key != Self.retiredKVSKey, let data = value as? Data else { continue }
            seenKeys.insert(key)
            let fingerprint = Self.fingerprint(of: data)
            if activity[key]?.fingerprint != fingerprint {
                activity[key] = LedgerActivity(fingerprint: fingerprint, since: now)
            }
            let installation = String(key.dropFirst(Self.kvsKeyPrefix.count))
            let unchangedFor = now.timeIntervalSince(activity[key]?.since ?? now)
            if unchangedFor < Self.inactivityInterval {
                activeInstallations.insert(installation)
            } else if let payload = decodePayload(data), payload.epoch >= epoch {
                inactive.append((key, installation, payload))
            }
        }

        // Forget ledgers that are gone, so the record doesn't grow.
        activity = activity.filter { seenKeys.contains($0.key) }
        saveActivity(activity)

        guard !inactive.isEmpty,
              activeInstallations.min() == LedgerInstallationIdentity.current else { return }

        var retired = decodePayload(kvs.data(forKey: Self.retiredKVSKey))
            .flatMap { $0.epoch >= epoch ? $0 : nil }
            ?? Payload(epoch: epoch, baseline: Section(), contributions: Section(), retiredInstallations: [])
        var installations = retired.retiredInstallations ?? []
        for ledger in inactive.sorted(by: { $0.key < $1.key }) {
            retired = Self.folding(ledger.payload, into: retired)
            if !installations.contains(ledger.installation) {
                installations.append(ledger.installation)
            }
        }
        retired.epoch = epoch
        retired.retiredInstallations = installations
        retired.baseline = Self.trimmed(retired.baseline, before: cutoff)
        retired.contributions = Self.trimmed(retired.contributions, before: cutoff)

        // The retired ledger is written before the old keys go, so no counts are dropped.
        writeRetired(retired)
        for ledger in inactive {
            kvs.removeObject(forKey: ledger.key)
            activity[ledger.key] = nil
        }
        saveActivity(activity)
        iCloudSyncCoordinator.shared.requestSynchronize()
    }

    /// Combines `payload` into `retired` the way `mergedTotals` would count them apart:
    /// baselines by maximum, and contributions summed (or by maximum for best streaks and
    /// other max values).
    static func folding(_ payload: Payload, into retired: Payload) -> Payload {
        var result = retired
        result.baseline = combined(retired.baseline, payload.baseline, summing: false)
        result.contributions = combined(retired.contributions, payload.contributions, summing: true)
        return result
    }

    private static func combined(_ lhs: Section, _ rhs: Section, summing: Bool) -> Section {
        var result = lhs
        for (key, value) in rhs.counters {
            let current = result.counters[key] ?? 0
            let sums = summing && counterKind(key) == .sum
            result.counters[key] = sums ? current + max(0, value) : max(current, max(0, value))
        }
        for (key, map) in rhs.maps {
            let sums = summing && !maxMapKeys.contains(key)
            var merged = result.maps[key] ?? [:]
            for (entry, value) in map {
                let current = merged[entry] ?? 0
                merged[entry] = sums ? current + max(0, value) : max(current, max(0, value))
            }
            result.maps[key] = merged
        }
        for (key, nested) in rhs.nestedMaps {
            var merged = result.nestedMaps[key] ?? [:]
            for (outer, inner) in nested {
                var mergedInner = merged[outer] ?? [:]
                for (entry, value) in inner {
                    let current = mergedInner[entry] ?? 0
                    mergedInner[entry] = summing ? current + max(0, value) : max(current, max(0, value))
                }
                merged[outer] = mergedInner
            }
            result.nestedMaps[key] = merged
        }
        return result
    }

    private func writeRetired(_ retired: Payload) {
        guard let data = try? JSONEncoder().encode(retired),
              kvs.data(forKey: Self.retiredKVSKey) != data else { return }
        kvs.set(data, forKey: Self.retiredKVSKey)
        iCloudSyncCoordinator.shared.requestSynchronize()
    }

    private func loadActivity() -> [String: LedgerActivity] {
        guard let data = defaults.data(forKey: activityKey) else { return [:] }
        return PersistedDecoding.decode([String: LedgerActivity].self, from: data, name: "gameStatsLedgerActivity") ?? [:]
    }

    private func saveActivity(_ activity: [String: LedgerActivity]) {
        guard let data = try? JSONEncoder().encode(activity),
              defaults.data(forKey: activityKey) != data else { return }
        defaults.set(data, forKey: activityKey)
    }

    /// A checksum that stays the same across launches (FNV-1a), unlike `hashValue`.
    private static func fingerprint(of data: Data) -> UInt64 {
        data.reduce(14_695_981_039_346_656_037) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
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
              let section = PersistedDecoding.decode(Section.self, from: data, key: snapshotKey, keepingUnreadableIn: defaults) else {
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
        return PersistedDecoding.decode(Payload.self, from: data, name: "gameStatsLedgerPayload")
    }

    private func decodeMap(_ data: Data?) -> [String: Int]? {
        guard let data else { return nil }
        return PersistedDecoding.decode([String: Int].self, from: data, name: "gameStatsLedgerMap")
    }

    private func decodeNestedMap(_ data: Data?) -> [String: [String: Int]]? {
        guard let data else { return nil }
        return PersistedDecoding.decode([String: [String: Int]].self, from: data, name: "gameStatsLedgerNestedMap")
    }
}

/// Identifies this installation's game ledger. The identifier is tied to the device's
/// vendor identifier so restoring a backup onto another device starts a separate
/// ledger instead of sharing one, which would let the two devices overwrite each other.
@MainActor
enum LedgerInstallationIdentity {
    private static let identifierKey = AppStorageKey.gameStatsLedgerInstallationID
    private static let vendorKey = AppStorageKey.gameStatsLedgerInstallationVendorID

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
