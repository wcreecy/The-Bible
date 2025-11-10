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
        do {
            // Preferred: let SwiftData choose default store location
            let container = try ModelContainer(for: 
                ReaderSettings.self,
                ReadingProgress.self,
                Favorite.self,
                Bookmark.self,
                VerseNote.self,
                JournalEntry.self
            )
            return container
        } catch {
            print("⚠️ Failed to create default SwiftData ModelContainer: \(error)")
        }

        // Final fallback: in-memory so the app can still run
        do {
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: 
                ReaderSettings.self,
                ReadingProgress.self,
                Favorite.self,
                Bookmark.self,
                VerseNote.self,
                JournalEntry.self,
            configurations: memoryConfig)
            print("ℹ️ Falling back to in-memory SwiftData store. Data will not persist across launches.")
            return container
        } catch {
            fatalError("Could not create any ModelContainer (including in-memory): \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

