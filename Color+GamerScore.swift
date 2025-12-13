import SwiftUI

public extension Color {
    /// Discrete 10-band color mapping for gamer score percentages.
    /// Bins: 0..<10, 10..<20, …, 90...100 (100% maps to the last bin).
    static func gamerScoreColor(for percentage: Double) -> Color {
        let p = max(0.0, min(100.0, percentage))
        switch p {
        case ..<10:  return Color(hex: 0xC6011F) // red
        case ..<20:  return Color(hex: 0xD64521) // red‑orange
        case ..<30:  return Color(hex: 0xFB4F14) // orange
        case ..<40:  return Color(hex: 0xFDB927) // gold
        case ..<50:  return Color(hex: 0x708238) // yellow‑green (olive)
        case ..<60:  return Color(hex: 0x9CD67A) // light green
        case ..<70:  return Color(hex: 0x2E7D32) // true green
        case ..<80:  return Color(hex: 0x2ECC71) // emerald
        case ..<90:  return Color(hex: 0x009688) // teal‑green
        default:     return Color(hex: 0x026937) // green (90–100)
        }
    }

    /// Convenience sRGB hex initializer (e.g., 0xRRGGBB).
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
