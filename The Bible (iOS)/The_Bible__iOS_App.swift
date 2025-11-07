//
//  The_Bible__iOS_App.swift
//  The Bible (iOS)
//
//  Created by William Creecy on 11/7/25.
//

import SwiftUI
import SwiftData

@main
struct The_Bible__iOS_App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ReaderSettings.self,
            ReadingProgress.self,
            Favorite.self,
            Bookmark.self,
            VerseNote.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
