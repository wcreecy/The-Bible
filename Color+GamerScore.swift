import SwiftUI

public extension Color {
    /// Discrete 10-band color mapping for gamer score percentages.
    /// Bins: 0..<10, 10..<20, …, 90...100 (100% maps to the last bin).
    static func gamerScoreColor(for percentage: Double) -> Color {
        let p = max(0.0, min(100.0, percentage))
        switch p {
        case ..<10:  return Color(hex: 0x000000) // black
        case ..<20:  return Color(hex: 0x808080) // gray
        case ..<30:  return Color(hex: 0xFF0000) // red
        case ..<40:  return Color(hex: 0xFFA500) // orange
        case ..<50:  return Color(hex: 0xFFFF00) // yellow
        case ..<60:  return Color(hex: 0x008000) // green
        case ..<70:  return Color(hex: 0xCD7F32) // bronze
        case ..<80:  return Color(hex: 0xC0C0C0) // silver
        case ..<90:  return Color(hex: 0xFFD700) // gold (fixed from teal to true gold)
        default:     return Color(hex: 0xD6D6D6) // platinum (slightly darker for readability)
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
