import Foundation

@MainActor
extension iCloudSyncCoordinator {
    // Settings keys to sync across devices
    // - dailyGoalMinutes: simple Int
    // - tagDisplayNameMap: [String: String]
    // - tagColorMap: [String: [Double]] (RGBA components)
    static let settingsKeys: [String] = [
        "dailyGoalMinutes",
        "tagDisplayNameMap",
        "tagColorMap"
    ]

    // Local -> KVS
    func mirrorSettingsKeyToKVS(_ key: String) {
        guard Self.settingsKeys.contains(key) else { return }

        switch key {
        case "dailyGoalMinutes":
            let local = defaults.integer(forKey: key)
            let remoteObj = kvs.object(forKey: key) as? NSNumber
            let remote = remoteObj?.intValue
            if remote == nil || remote != local {
                kvs.set(local, forKey: key)
            }

        case "tagDisplayNameMap":
            // Stored as [String: String] in UserDefaults
            let local = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
            // KVS returns Any?; coerce to [String: String] if possible
            let remote = kvs.dictionary(forKey: key) as? [String: String] ?? [:]
            if local != remote {
                kvs.set(local, forKey: key)
            }

        case "tagColorMap":
            // Stored as [String: [Double]] in UserDefaults (RGBA)
            let local = (defaults.dictionary(forKey: key) as? [String: [Double]]) ?? [:]
            let remote = kvs.dictionary(forKey: key) as? [String: [Double]] ?? [:]
            if local != remote {
                kvs.set(local, forKey: key)
            }

        default:
            break
        }
    }

    // KVS -> Local
    func mergeSettingsIncoming(forKey key: String) {
        guard Self.settingsKeys.contains(key) else { return }

        switch key {
        case "dailyGoalMinutes":
            let remoteVal = Int(kvs.longLong(forKey: key))
            if defaults.integer(forKey: key) != remoteVal {
                defaults.set(remoteVal, forKey: key)
            }

        case "tagDisplayNameMap":
            // Prefer exact type match; ignore malformed payloads
            if let remote = kvs.dictionary(forKey: key) as? [String: String] {
                let local = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]
                if local != remote {
                    defaults.set(remote, forKey: key)
                    // Also refresh in-memory cache inside TagDisplayNameStore if needed
                    NotificationCenter.default.post(name: .init("TagDisplayNameMapDidChange"), object: nil)
                }
            }

        case "tagColorMap":
            if let remote = kvs.dictionary(forKey: key) as? [String: [Double]] {
                let local = (defaults.dictionary(forKey: key) as? [String: [Double]]) ?? [:]
                if local != remote {
                    defaults.set(remote, forKey: key)
                    // Also refresh in-memory cache inside TagColorStore if needed
                    NotificationCenter.default.post(name: .init("TagColorMapDidChange"), object: nil)
                }
            }

        default:
            break
        }
    }
}
