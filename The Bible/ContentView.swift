//
//  ContentView.swift
//  The Bible
//
//  Shows the Books list on launch.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = ColorSchemePreference.system.rawValue
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue
    
    private var preferredScheme: ColorScheme? { (ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme }
    private var preferredDynamicType: DynamicTypeSize? { (FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system).dynamicTypeSize }
    private var preferredFontDesign: Font.Design? { (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system).fontDesign }
    private var preferredCustomFontName: String? { (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system).customFontName }
    
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
                    .navigationTitle("Word of God")
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                BooksView(books: BibleData.books)
                    .navigationTitle("Bible")
            }
            .tabItem { Label("Bible", systemImage: "book") }

            NavigationStack {
                SearchView()
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }

            NavigationStack {
                FavoritesView()
            }
            .tabItem { Label("Favorites", systemImage: "heart") }

            NavigationStack {
                BookmarksView()
            }
            .tabItem { Label("Bookmarks", systemImage: "bookmark") }

            NavigationStack {
                Text("Notes")
                    .navigationTitle("Notes")
            }
            .tabItem { Label("Notes", systemImage: "note.text") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
        .preferredColorScheme(preferredScheme)
        .dynamicTypeSize(preferredDynamicType ?? .medium)
        .font(preferredCustomFontName != nil ? .custom(preferredCustomFontName!, size: 17) : .body)
        .fontDesign(preferredFontDesign ?? .default)
    }
}

#Preview {
    ContentView()
}

