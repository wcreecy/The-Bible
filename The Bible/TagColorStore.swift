import SwiftUI
import Foundation
import UIKit

struct TagColorStore {
    private static let defaultsKey = "tagColorMap"

    // Normalize tags for consistent keying
    private static func normalized(_ tag: String) -> String {
        tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Retrieve stored dictionary
    private static func loadMap() -> [String: [Double]] {
        let obj = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: [Double]]
        return obj ?? [:]
    }

    // Save dictionary
    private static func saveMap(_ map: [String: [Double]]) {
        UserDefaults.standard.set(map, forKey: defaultsKey)
    }

    // Public API
    static func color(for tag: String) -> Color? {
        let key = normalized(tag)
        let map = loadMap()
        guard let comps = map[key], comps.count == 4 else { return nil }
        let r = CGFloat(comps[0])
        let g = CGFloat(comps[1])
        let b = CGFloat(comps[2])
        let a = CGFloat(comps[3])
        return Color(red: r, green: g, blue: b).opacity(Double(a))
    }

    static func setColor(_ color: Color?, for tag: String) {
        let key = normalized(tag)
        var map = loadMap()
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
}

