import SwiftUI
import Foundation
import UIKit

struct TagColorStore {
    private static let defaultsKey = "tagColorMap"

    // In-memory cache to avoid hot-path UserDefaults reads
    private static var cachedMap: [String: [Double]] = {
        let obj = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [Double]]
        return obj ?? [:]
    }()

    // Register once to observe remote merges and refresh our cache
    private static var didRegisterObserver: Bool = {
        NotificationCenter.default.addObserver(
            forName: .init("TagColorMapDidChange"),
            object: nil,
            queue: .main
        ) { _ in
            cachedMap = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [Double]]) ?? [:]
        }
        return true
    }()

    private static func ensureObserver() {
        _ = didRegisterObserver
    }

    // Normalize tags for consistent keying
    private static func normalized(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Save dictionary (and keep cache in sync)
    private static func saveMap(_ map: [String: [Double]]) {
        ensureObserver()
        cachedMap = map
        let defaults = UserDefaults.standard
        defaults.set(map, forKey: defaultsKey)

        // Mirror to iCloud KVS and request a push via coordinator
        let kvs = NSUbiquitousKeyValueStore.default
        kvs.set(map, forKey: defaultsKey)
        iCloudSyncCoordinator.shared.pushKey(defaultsKey)
    }

    // Public API
    static func color(for tag: String) -> Color? {
        ensureObserver()
        let key = normalized(tag)
        guard let comps = cachedMap[key], comps.count == 4 else { return nil }
        let r = CGFloat(comps[0])
        let g = CGFloat(comps[1])
        let b = CGFloat(comps[2])
        let a = CGFloat(comps[3])
        return Color(red: r, green: g, blue: b).opacity(Double(a))
    }

    static func setColor(_ color: Color?, for tag: String) {
        ensureObserver()
        let key = normalized(tag)
        var map = cachedMap
        if let color {
            // Convert Color to RGBA using UIColor
            let ui = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
                map[key] = [Double(r), Double(g), Double(b), Double(a)]
            } else {
                // Fallback: store black if conversion fails
                map[key] = [0, 0, 0, 1]
            }
        } else {
            // Remove stored color
            map.removeValue(forKey: key)
        }
        saveMap(map)
    }

    static func removeColor(for tag: String) {
        setColor(nil, for: tag)
    }

    // New: expose all normalized keys currently known in the synced color map
    static func allKeys() -> [String] {
        ensureObserver()
        return Array(cachedMap.keys)
    }
}
