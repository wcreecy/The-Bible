#if DEBUG
import SwiftUI
import SwiftData

struct SettingsDebugUtilitiesView: View {
    @EnvironmentObject private var cloudKitManager: CloudKitManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Favorite.createdAt, order: .reverse) private var favorites: [Favorite]
    @Query private var journalEntries: [JournalEntry]

    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""
    @AppStorage("swiftdataCloudKitEnabled") private var swiftdataCloudKitEnabled: Bool = false

    // NEW: Debug flag to allow replaying Daily Wordle
    @AppStorage("wordleAllowDailyReplay") private var wordleAllowDailyReplay: Bool = false

    @State private var debugAlertTitle: String = ""
    @State private var debugAlertMessage: String = ""
    @State private var showDebugAlert: Bool = false
    @State private var debugUtilitiesExpanded: Bool = false

    var body: some View {
        Section {
            if debugUtilitiesExpanded {
                // NEW: Wordle debug toggle
                Group {
                    Toggle("Allow Daily Wordle Replay (Debug)", isOn: $wordleAllowDailyReplay)
                        .tint(.green)
                    Text("When enabled, the Daily Wordle can be played again even after completing it today.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // SwiftData/CloudKit test buttons
                Group {
                    Button {
                        let randVerse = Int.random(in: 1...36)
                        let fav = Favorite(
                            bookName: "John",
                            chapterNumber: 3,
                            verseNumber: randVerse,
                            verseText: "Test Sync … \(UUID().uuidString)"
                        )
                        modelContext.insert(fav)
                        do {
                            try modelContext.save()
                            print("Inserted Favorite -> book: \(fav.bookName), chapter: \(fav.chapterNumber), verse: \(fav.verseNumber), text: \(fav.verseText), createdAt: \(fav.createdAt)")
                            print("Favorites count after insert: \(favorites.count + 0)")
                        } catch {
                            print("Error saving test favorite: \(error)")
                        }
                    } label: {
                        Label("Insert Test Favorite (CloudKit Sync)", systemImage: "plus.circle")
                    }

                    Button {
                        let count = favorites.count
                        if let latest = favorites.first {
                            print("Favorites count: \(count)")
                            print("Latest -> book: \(latest.bookName), chapter: \(latest.chapterNumber), verse: \(latest.verseNumber), text: \(latest.verseText), createdAt: \(latest.createdAt)")
                        } else {
                            print("Favorites count: \(count) (no items)")
                        }
                    } label: {
                        Label("List Favorite Count", systemImage: "list.number")
                    }
                }

                // iCloud KVS tools
                Group {
                    Button {
                        iCloudSyncCoordinator.shared.pushAllNow()
                        debugShow("iCloud KVS", "Pushed all known keys.\nLast push: \(DateFormatters.shortDateTimeString(iCloudSyncCoordinator.shared.lastPushDate))")
                    } label: {
                        Label("Force KVS Push", systemImage: "icloud.and.arrow.up")
                    }

                    Button {
                        let lastPush = DateFormatters.shortDateTimeString(iCloudSyncCoordinator.shared.lastPushDate)
                        let lastMerge = DateFormatters.shortDateTimeString(iCloudSyncCoordinator.shared.lastMergeDate)
                        debugShow("KVS Timestamps", "Last Push: \(lastPush)\nLast Merge: \(lastMerge)")
                    } label: {
                        Label("Show KVS Last Push/Merge", systemImage: "clock")
                    }

                    Button {
                        let kvs = NSUbiquitousKeyValueStore.default
                        let tempKey = "debug.temp.\(UUID().uuidString)"
                        kvs.set(Date().timeIntervalSince1970, forKey: tempKey)
                        kvs.synchronize()
                        NotificationCenter.default.post(
                            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                            object: kvs,
                            userInfo: [
                                NSUbiquitousKeyValueStoreChangedKeysKey: [tempKey],
                                NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreServerChange
                            ]
                        )
                        debugShow("KVS Simulation", "Posted didChangeExternallyNotification for key:\n\(tempKey)")
                    } label: {
                        Label("Simulate External KVS Change", systemImage: "wave.3.right")
                    }
                }

                // Reading sessions + totals
                Group {
                    Button {
                        ReadingSessionsStore.shared.seedSampleSessionsLast7Days()
                        debugShow("Seeded Sessions", "Inserted random sessions for the last 7 days.")
                    } label: {
                        Label("Seed Reading Sessions (Last 7 Days)", systemImage: "clock.badge.plus")
                    }

                    Button(role: .destructive) {
                        ReadingSessionsStore.shared.clearAll()
                        debugShow("Reading Sessions", "Cleared all reading sessions.")
                    } label: {
                        Label("Clear Reading Sessions Only", systemImage: "trash")
                    }

                    Button {
                        let last7 = BibleStatsStore.shared.totalForLast(days: 7)
                        let last30 = BibleStatsStore.shared.totalForLast(days: 30)
                        let thisMonth = BibleStatsStore.shared.totalForMonth(containing: Date())
                        print("DEBUG Totals -> last7: \(last7)s, last30: \(last30)s, thisMonth: \(thisMonth)s")
                        debugShow("Reading Totals",
                                  "Last 7 Days: \(BibleStatsStore.shared.format(last7))\n" +
                                  "Last 30 Days: \(BibleStatsStore.shared.format(last30))\n" +
                                  "This Month: \(BibleStatsStore.shared.format(thisMonth))")
                    } label: {
                        Label("Dump Reading Totals", systemImage: "text.justify.left")
                    }

                    Button {
                        BibleStatsStore.shared.seedRandomReadingStatsPast31Days()
                        debugShow("Seed Stats", "Seeded random reading stats for the past 31 days.")
                    } label: {
                        Label("Seed Random Reading Stats (31 Days)", systemImage: "sparkles")
                    }
                }

                // Games
                Group {
                    Button {
                        GameStats.shared.seedRandomStatsAllGames()
                        debugShow("Games", "Seeded random stats across all games and difficulties.")
                    } label: {
                        Label("Seed Random Game Stats", systemImage: "gamecontroller")
                    }

                    // NEW: Clear Wordle only
                    Button(role: .destructive) {
                        iCloudSyncCoordinator.shared.resetWordleCountersToZero()
                        debugShow("Games", "Cleared Wordle stats only.")
                    } label: {
                        Label("Clear Wordle Stats Only", systemImage: "trash")
                    }

                    Button(role: .destructive) {
                        iCloudSyncCoordinator.shared.resetAllGameCountersToZero()
                        debugShow("Games", "Reset all game counters to zero.")
                    } label: {
                        Label("Reset All Game Counters", systemImage: "trash")
                    }
                }

                // Chapter/verse progress
                Group {
                    Button {
                        BibleStatsStore.shared.markFirstThreeChaptersCompleteDefaultBook()
                        debugShow("Chapters", "Marked first 3 chapters complete for default book.")
                    } label: {
                        Label("Mark First 3 Chapters as Read (Book)", systemImage: "checkmark.circle")
                    }

                    Button(role: .destructive) {
                        BibleStatsStore.shared.clearChapterOneForDefaultBook()
                        debugShow("Chapters", "Cleared Chapter 1 seen verses for default book.")
                    } label: {
                        Label("Clear Chapter 1 Seen Verses (Book)", systemImage: "xmark.circle")
                    }

                    Button {
                        let summary = BibleStatsStore.shared.verseCoverageSummaryForDefaultBook(firstNChapters: 5)
                        print("DEBUG Coverage:\n\(summary)")
                        debugShow("Chapters", summary.isEmpty ? "—" : summary)
                    } label: {
                        Label("Log Verse Coverage (Book)", systemImage: "chart.bar.doc.horizontal")
                    }
                }

                // SwiftData / CloudKit helpers
                Group {
                    Button(role: .destructive) {
                        deleteAllFavorites()
                    } label: {
                        Label("Delete All Favorites", systemImage: "trash")
                    }

                    Button {
                        print("Favorites: \(favorites.count)")
                        print("Journal entries: \(journalEntries.count)")
                        for e in journalEntries.prefix(5) {
                            print("• \(e.title)")
                        }
                        debugShow("Counts",
                                  "Favorites: \(favorites.count)\nJournal entries: \(journalEntries.count)")
                    } label: {
                        Label("Count Favorites & Journal", systemImage: "number")
                    }

                    Button {
                        Task {
                            await cloudKitManager.refresh()
                            debugShow("CloudKit", "Refreshed CloudKit status.")
                        }
                    } label: {
                        Label("Refresh CloudKit Status", systemImage: "arrow.clockwise")
                    }
                }

                // NEW: SwiftData cleanup (App Group)
                Group {
                    Button(role: .destructive) {
                        let deleted = deleteAppGroupSwiftDataStoreFiles()
                        let lines = deleted.isEmpty ? "No files found." : deleted.joined(separator: "\n")
                        debugShow("SwiftData Store (App Group)", "Deleted files:\n\(lines)")
                    } label: {
                        Label("Delete App Group SwiftData Store Files", systemImage: "trash.circle")
                    }
                    Text("Deletes default.store, -wal, -shm in group.bible.app/Library/Application Support. Use if you hit SQLite 256 errors.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Home layout
                Group {
                    Button {
                        let store = HomeLayoutStore()
                        let order = HomeCardID.allCases
                        let hidden = HomeLayoutStore.baselineHidden
                        store.save(order: order, hidden: hidden)
                        debugShow("Home Layout", "Restored default order and hidden set.")
                    } label: {
                        Label("Reset Home Layout to Defaults", systemImage: "arrow.counterclockwise")
                    }

                    Button {
                        let store = HomeLayoutStore()
                        let hidden = HomeLayoutStore.baselineHidden
                        let loaded = store.load()
                        store.save(order: loaded.order, hidden: hidden)
                        debugShow("Home Layout", "Set hidden to baseline: Games, Streaks, Bible Stats.")
                    } label: {
                        Label("Apply Hidden Baseline", systemImage: "eye.slash")
                    }
                }

                // Journal
                Group {
                    Button {
                        insertSampleJournalEntry()
                    } label: {
                        Label("Insert Sample Journal Entry", systemImage: "square.and.pencil")
                    }

                    Button {
                        let count = journalEntries.count
                        print("Journal entries count: \(count)")
                        for e in journalEntries.prefix(10) {
                            print("• \(e.title)")
                        }
                        debugShow("Journal", "Entries count: \(count)")
                    } label: {
                        Label("Count Journal Entries", systemImage: "list.bullet.rectangle")
                    }
                }

                // Verse of the Day / Widgets
                Group {
                    Button {
                        writeTestVOTDToDefaultsAndAppGroup()
                    } label: {
                        Label("Write Test Verse of the Day to App Group", systemImage: "square.and.arrow.down.on.square")
                    }
                }

                // Build/env diagnostics
                Group {
                    Button {
                        Task {
                            let cfg = ProcessInfo.processInfo.environment["CONFIGURATION"] ?? "<unknown>"
                            let bundleID = Bundle.main.bundleIdentifier ?? "<unknown>"
                            let appIDPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String ?? "<unknown>"
                            let container = "iCloud.creecy.bible"
                            let cloudKitFlag = swiftdataCloudKitEnabled ? "enabled" : "disabled"
                            // Avoid StoreKit here to prevent Simulator auth logs.
                            let storeHint = The_Bible__iOS_App.buildEnvHintFallback()
                            let msg = """
                            Build configuration: \(cfg)
                            Bundle ID: \(bundleID)
                            AppIdentifierPrefix: \(appIDPrefix)
                            CloudKit container: \(container)
                            SwiftData CloudKit: \(cloudKitFlag)
                            Store environment hint: \(storeHint)
                            """
                            print("DEBUG Build/Env:\n\(msg)")
                            debugShow("Build/Environment", msg)
                        }
                    } label: {
                        Label("Show Build/Environment Diagnostics", systemImage: "info.circle")
                    }
                }
            }
        } header: {
            Button {
                debugUtilitiesExpanded.toggle()
            } label: {
                HStack {
                    Text("Debug Utilities")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .rotationEffect(debugUtilitiesExpanded ? .degrees(90) : .degrees(0))
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: debugUtilitiesExpanded)
                }
            }
            .buttonStyle(.plain)
        }
        .alert(debugAlertTitle, isPresented: $showDebugAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(debugAlertMessage)
        }
        .headerProminence(.increased)
    }

    // MARK: - Local helpers

    private func debugShow(_ title: String, _ message: String) {
        debugAlertTitle = title
        debugAlertMessage = message
        showDebugAlert = true
    }

    private func deleteAllFavorites() {
        do {
            for f in favorites {
                modelContext.delete(f)
            }
            try modelContext.save()
            debugShow("Favorites", "Deleted all favorites.")
        } catch {
            debugShow("Favorites", "Error deleting: \(error.localizedDescription)")
        }
    }

    private func insertSampleJournalEntry() {
        let entry = JournalEntry()
        entry.title = "Sample Entry \(Int.random(in: 100...999))"
        entry.body = "This is a sample journal entry created from Settings debug."
        entry.tags = ["sample", "debug"]
        entry.updatedAt = Date()
        modelContext.insert(entry)
        do {
            try modelContext.save()
            debugShow("Journal", "Inserted a sample entry.")
        } catch {
            debugShow("Journal", "Save failed: \(error.localizedDescription)")
        }
    }

    private func writeTestVOTDToDefaultsAndAppGroup() {
        let scopeRaw = verseScopeRaw
        let specificBook = verseSpecificBook
        let (book, chapter, verse, text) = pickRandomVerse(scopeRaw: scopeRaw, specificBook: specificBook)

        let defaults = UserDefaults.standard
        defaults.set(book, forKey: "verseOfDayBook")
        defaults.set(chapter, forKey: "verseOfDayChapter")
        defaults.set(verse, forKey: "verseOfDayNumber")
        defaults.set(text, forKey: "verseOfDayText")

        if let shared = UserDefaults(suiteName: "group.bible.app") {
            shared.set(book, forKey: "verseOfDayBook")
            shared.set(chapter, forKey: "verseOfDayChapter")
            shared.set(verse, forKey: "verseOfDayNumber")
            shared.set(text, forKey: "verseOfDayText")
        }

        debugShow("Verse of the Day", "Wrote a test VOTD to defaults and app group.")
    }

    private func pickRandomVerse(scopeRaw: String, specificBook: String) -> (book: String, chapter: Int, verse: Int, text: String) {
        let allBooks = BibleData.books
        guard !allBooks.isEmpty else { return ("", 0, 0, "") }

        enum Scope { case old, new, whole, book }
        let scope: Scope
        switch scopeRaw {
        case "old": scope = .old
        case "new": scope = .new
        case "book": scope = .book
        default: scope = .whole
        }

        let books: [Book]
        switch scope {
        case .old:
            books = allBooks.filter { Canon.old.contains($0.name) }
        case .new:
            books = allBooks.filter { Canon.new.contains($0.name) }
        case .book:
            if let chosen = allBooks.first(where: { $0.name == specificBook }) {
                books = [chosen]
            } else {
                books = allBooks
            }
        case .whole:
            books = allBooks
        }

        guard let book = books.randomElement(),
              let chapter = book.chapters.randomElement(),
              let verse = chapter.verses.randomElement() else {
            return ("", 0, 0, "")
        }
        return (book.name, chapter.number, verse.number, verse.text)
    }

    // NEW: Delete App Group SwiftData store files
    private func deleteAppGroupSwiftDataStoreFiles() -> [String] {
        var deleted: [String] = []
        let fm = FileManager.default
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.bible.app") else {
            print("DEBUG: App Group container not found.")
            return deleted
        }
        let support = groupURL.appendingPathComponent("Library").appendingPathComponent("Application Support")
        let targets = ["default.store", "default.store-wal", "default.store-shm"].map { support.appendingPathComponent($0) }
        for url in targets {
            if fm.fileExists(atPath: url.path) {
                do {
                    try fm.removeItem(at: url)
                    deleted.append(url.path)
                    print("DEBUG: Deleted \(url.path)")
                } catch {
                    print("DEBUG: Failed to delete \(url.path): \(error)")
                }
            }
        }
        return deleted
    }
}
#endif
