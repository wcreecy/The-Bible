//
//  ContentView.swift
//  The Bible
//
//  Shows the Books list on launch.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                Text("Home")
                    .navigationTitle("Home")
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
                Text("Bookmarks")
                    .navigationTitle("Bookmarks")
            }
            .tabItem { Label("Bookmarks", systemImage: "bookmark") }

            NavigationStack {
                Text("Notes")
                    .navigationTitle("Notes")
            }
            .tabItem { Label("Notes", systemImage: "note.text") }

            NavigationStack {
                Text("Settings")
                    .navigationTitle("Settings")
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

#Preview {
    ContentView()
}
