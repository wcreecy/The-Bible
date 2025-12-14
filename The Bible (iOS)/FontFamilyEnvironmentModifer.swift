import SwiftUI

struct FontFamilyEnvironmentModifier: ViewModifier {
    let prefRaw: String

    func body(content: Content) -> some View {
        let pref = FontFamilyPreference(rawValue: prefRaw) ?? .system
        let baseSize: CGFloat = 17

        if let custom = pref.customFontName {
            content
                .font(.custom(custom, size: baseSize))
                .fontDesign(.default)
        } else {
            let design = pref.fontDesign ?? .default
            content
                .font(.system(size: baseSize))
                .fontDesign(design)
        }
    }
}
