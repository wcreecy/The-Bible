// FontFamilyEnvironmentModifier.swift
import SwiftUI

struct FontFamilyEnvironmentModifier: ViewModifier {
    let prefRaw: String

    func body(content: Content) -> some View {
        let pref = FontFamilyPreference(rawValue: prefRaw) ?? .system
        if let custom = pref.customFontName {
            content
                .font(.custom(custom, size: 17, relativeTo: .body))
                .fontDesign(.default)
        } else {
            let design = pref.fontDesign ?? .default
            content
                .fontDesign(design)
        }
    }
}
