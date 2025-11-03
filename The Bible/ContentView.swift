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
    
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appTotalActiveSeconds") private var appTotalActiveSeconds: Int = 0
    @AppStorage("appActiveStart") private var appActiveStart: Double = 0
    
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
                NotesView()
            }
            .tabItem { Label("Notes", systemImage: "note.text") }
            
            NavigationStack {
                GamesView()
                    .navigationTitle("Games")
            }
            .tabItem { Label("Games", systemImage: "gamecontroller") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
        .preferredColorScheme(preferredScheme)
        .dynamicTypeSize(preferredDynamicType ?? .large)
        .font(preferredCustomFontName != nil ? .custom(preferredCustomFontName!, size: 19) : .body)
        .fontDesign(preferredFontDesign ?? .default)
        .onAppear {
            // If app launches directly into active state, ensure we start tracking
            if appActiveStart == 0 {
                appActiveStart = Date().timeIntervalSince1970
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Start a new active session if not already started
                if appActiveStart == 0 {
                    appActiveStart = Date().timeIntervalSince1970
                }
            case .inactive, .background:
                // Accumulate the elapsed active time and clear the start marker
                if appActiveStart > 0 {
                    let start = Date(timeIntervalSince1970: appActiveStart)
                    let delta = max(0, Int(Date().timeIntervalSince(start)))
                    appTotalActiveSeconds += delta
                    appActiveStart = 0
                }
            @unknown default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
}

