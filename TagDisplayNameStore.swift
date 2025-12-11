// TagDisplayNameStore.swift
import Foundation

struct TagDisplayNameStore {
    private static let defaultsKey = "tagDisplayNameMap"

    // In-memory cache
    private static var cached: [String: String] = {
        (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String]) ?? [:]
    }()

    private static func normalized(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func save(_ map: [String: String]) {
        cached = map
        UserDefaults.standard.set(map, forKey: defaultsKey)
    }

    static func displayName(for tag: String) -> String? {
        cached[normalized(tag)]
    }

    static func setDisplayName(_ name: String?, for tag: String) {
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
        let oldNorm = normalized(oldKey)
        let newNorm = normalized(newKey)
        guard oldNorm != newNorm else { return }
        var map = cached
        if let val = map.removeValue(forKey: oldNorm) {
            map[newNorm] = val
        }
        save(map)
    }
}
