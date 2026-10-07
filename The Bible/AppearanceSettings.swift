import SwiftUI

enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum FontFamilyPreference: String, CaseIterable, Identifiable {
    case system
    case serif
    case rounded
    case monospaced
    case georgia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        case .monospaced: return "Monospaced"
        case .georgia: return "Georgia"
        }
    }

    // System designs for built-in families; custom font for Georgia
    var fontDesign: Font.Design? {
        switch self {
        case .system: return .default
        case .serif: return .serif
        case .rounded: return .rounded
        case .monospaced: return .monospaced
        case .georgia: return nil
        }
    }

    var customFontName: String? {
        switch self {
        case .georgia: return "Georgia"
        default: return nil
        }
    }
}
