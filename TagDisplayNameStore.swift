// TagDisplayNameStore.swift
import Foundation

struct TagDisplayNameStore {
    private static let defaultsKey = "tagDisplayNameMap"

    // In-memory cache
    private static var cached: [String: String] = {
        (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String]) ?? [:]
    }()

    // Register once to observe remote merges and refresh our cache
    private static var didRegisterObserver: Bool = {
        NotificationCenter.default.addObserver(
            forName: .init("TagDisplayNameMapDidChange"),
            object: nil,
            queue: .main
        ) { _ in
            // Refresh in-memory cache from UserDefaults after a KVS merge
            cached = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String]) ?? [:]
        }
        return true
    }()

    // Touch the observer registration at least once
    private static func ensureObserver() {
        _ = didRegisterObserver
    }

    private static func normalized(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func save(_ map: [String: String]) {
        ensureObserver()
        cached = map
        let defaults = UserDefaults.standard
        defaults.set(map, forKey: defaultsKey)

        // Mirror to iCloud KVS and request a push via coordinator
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.set(map, forKey: defaultsKey)
        iCloudSyncCoordinator.shared.pushKey(defaultsKey)
    }

    static func displayName(for tag: String) -> String? {
        ensureObserver()
        return cached[normalized(tag)]
    }

    static func setDisplayName(_ name: String?, for tag: String) {
        ensureObserver()
        var map = cached
        let key = normalized(tag)
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            map[key] = name.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            map.removeValue(forKey: key)
        }
        save(map)
    }

    static func removeDisplayName(for tag: String) {
        setDisplayName(nil, for: tag)
    }

    // Rename underlying normalized key (used if we change canonical key)
    static func migrateKey(from oldKey: String, to newKey: String) {
        ensureObserver()
        let oldNorm = normalized(oldKey)
        let newNorm = normalized(newKey)
        guard oldNorm != newNorm else { return }
        var map = cached
        if let val = map.removeValue(forKey: oldNorm) {
            map[newNorm] = val
        }
        save(map)
    }

    // New: expose all normalized keys currently known in the synced display-name map
    static func allKeys() -> [String] {
        ensureObserver()
        return Array(cached.keys)
    }
}
