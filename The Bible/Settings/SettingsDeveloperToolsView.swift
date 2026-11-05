#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// Debug-only tools for testing the app: streaks, onboarding, notifications, sync, storage
/// fallbacks, large content, translations, and diagnostics.
struct SettingsDeveloperToolsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.persistenceStoreMode) private var persistenceStoreMode
    @Environment(CloudKitManager.self) private var cloudKitManager
    @AppStorage("debugForcedStoreMode") private var forcedStoreMode = ""

    @State private var streak = StreakTracker.summary()
    @State private var translationReports: [TranslationReport] = []
    @State private var libraryCounts: [(title: String, count: Int)] = []
    @State private var syncSnapshotID = 0
    @State private var toastText = ""
    @State private var isShowingToast = false
    @State private var isConfirmingRemoveSeededNotes = false
    @State private var showingSampleDataConfirmation = false
    @State private var showingSampleDataCompletion = false
    @State private var showingSettingsResetConfirmation = false
    @State private var showingSettingsResetCompletion = false
    @State private var isConfirmingDeleteAll = false
    @State private var deleteAllConfirmationText = ""

    var body: some View {
        Form {
            dataSection
            streakSection
            onboardingSection
            notificationsSection
            syncSection
            storageSection
            contentSection
            translationsSection
            diagnosticsSection
        }
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
        .appToast(isPresented: $isShowingToast, symbol: "checkmark.circle.fill", text: toastText, tint: .green)
        .alert("Delete All Data?", isPresented: $isConfirmingDeleteAll) {
            TextField("Type delete", text: $deleteAllConfirmationText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                deleteAllConfirmationText = ""
            }
            Button("Delete Everything", role: .destructive) {
                deleteAllConfirmationText = ""
                deleteAllData()
            }
            .disabled(deleteAllConfirmationText != "delete")
        } message: {
            Text("This permanently deletes all notes, favorites, highlights, bookmarks, saved cross references, reading progress, and reading and game stats, and resets every setting. Because iCloud sync is on, the deletions also reach your other devices. Type delete to continue.")
        }
        .task {
            refreshLibraryCounts()
            await loadTranslationReports()
        }
    }

    private func show(_ message: String) {
        toastText = message
        withAnimation(.snappy) { isShowingToast = true }
    }

    // MARK: - Data and resets

    private var dataSection: some View {
        Section {
            Button {
                showingSampleDataConfirmation = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generate Sample Data")
                        Text("Fill charts, favorites, and notes with sample data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "wand.and.stars")
                        .foregroundStyle(.purple)
                }
            }
            .accessibilityIdentifier("generateDeveloperSampleStatsButton")
            .confirmationDialog(
                "Generate Sample Data?",
                isPresented: $showingSampleDataConfirmation,
                titleVisibility: .visible
            ) {
                Button("Generate Data") {
                    Task {
                        await DeveloperSampleData.generate(in: modelContext)
                        refreshLibraryCounts()
                        streak = StreakTracker.summary()
                        showingSampleDataCompletion = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This adds about 90 days of randomized reading and game activity, 30 days of study, game, and prayer & study timer time, at least 10 favorite verses, and sample notes. Reading, study, and game data can be removed later from Reset Data.")
            }
            .alert("Sample Data Created", isPresented: $showingSampleDataCompletion) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The Home, Stats, Favorites, and Notes views now have sample data to display.")
            }

            Button(role: .destructive) {
                showingSettingsResetConfirmation = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset Permissions & Settings")
                        Text("Restore app defaults and cancel permission-based features")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.counterclockwise.circle")
                }
            }
            .accessibilityIdentifier("resetDeveloperPermissionsAndSettingsButton")
            .confirmationDialog(
                "Reset Permissions and Settings?",
                isPresented: $showingSettingsResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    DeveloperSettingsReset.perform()
                    showingSettingsResetCompletion = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This restores every app preference to its default, cancels pending notifications and prayer alarms, and ends Live Activities. iOS authorization decisions must still be changed in System Settings.")
            }
            .alert("App Settings Reset", isPresented: $showingSettingsResetCompletion) {
                Button("Open System Settings") {
                    DeveloperSettingsReset.openSystemSettings()
                }
                Button("Done", role: .cancel) {}
            } message: {
                Text("App settings are back to their defaults. To make Notifications, Prayer & Study Timer Alarms, Mindful Minutes, or Live Activities appear not requested again, reset them in iOS Settings or reset privacy on the simulator. Photo Selection uses the system picker and has no persistent library permission.")
            }

            Button(role: .destructive) {
                deleteAllConfirmationText = ""
                isConfirmingDeleteAll = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete All Data")
                        Text("Erase the library, stats, and settings for a fresh start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .accessibilityIdentifier("deleteAllDeveloperDataButton")
        } header: {
            Label("Data & Resets", systemImage: "externaldrive")
        } footer: {
            Text("Delete All Data also deletes the iCloud copies, so other devices signed in to this account lose their data too.")
        }
    }

    private func deleteAllData() {
        Task {
            do {
                try await DeveloperTools.deleteAllData(in: modelContext)
                refreshLibraryCounts()
                streak = StreakTracker.summary()
                show("All data deleted")
            } catch {
                show("Failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Streak and goal

    private var streakSection: some View {
        Section {
            LabeledContent("Current streak", value: "\(streak.current) days (best \(streak.best))")
            LabeledContent("Today", value: "\(streak.todaySeconds / 60) of \(streak.todayGoalSeconds / 60) min")

            Menu {
                ForEach([1, 3, 7, 30, 100], id: \.self) { days in
                    Button("\(days) day\(days == 1 ? "" : "s")") {
                        DeveloperTools.setStreak(days: days)
                        refreshStreak("Streak set to \(days) day\(days == 1 ? "" : "s")")
                    }
                }
            } label: {
                Label("Set Streak…", systemImage: "flame")
            }

            Button("Complete Today's Goal", systemImage: "checkmark.circle") {
                DeveloperTools.completeTodaysGoal()
                refreshStreak("Today's goal completed")
            }

            Button("Break Streak", systemImage: "flame.fill") {
                DeveloperTools.breakStreak()
                refreshStreak("Yesterday cleared; streak broken")
            }
        } header: {
            Label("Streak & Goal", systemImage: "flame")
        } footer: {
            Text("Edits reading time to produce the streak, ending yesterday; today adds one more once its goal is met. Reading time added this way appears in Stats too.")
        }
    }

    private func refreshStreak(_ message: String) {
        streak = StreakTracker.summary()
        show(message)
    }

    // MARK: - Onboarding and tips

    private var onboardingSection: some View {
        Section {
            Button("Reset Welcome Checklist", systemImage: "list.bullet.clipboard") {
                DeveloperTools.resetWelcomeChecklist()
                show("Welcome checklist reset")
            }
            Button("Reset Contextual Tips", systemImage: "lightbulb") {
                DeveloperTools.resetContextualTips()
                show("Tips on and reset")
            }
        } header: {
            Label("Onboarding & Tips", systemImage: "sparkles")
        } footer: {
            Text("The checklist returns to Home from its first step. Tips are turned on and every dismissed tip comes back.")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Button("Verse of the Day in 5 seconds", systemImage: "book.pages") {
                send(.verseOfDay)
            }
            Button("Streak Reminder in 5 seconds", systemImage: "flame") {
                send(.streakReminder)
            }
            Button("Timer Alarm in 10 seconds", systemImage: "alarm") {
                Task {
                    let scheduled = await DeveloperTools.sendTestTimerAlarm()
                    show(scheduled ? "Alarm in 10 seconds" : "Alarms aren't allowed or available")
                }
            }
        } header: {
            Label("Test Notifications", systemImage: "bell.badge")
        } footer: {
            Text("Send one, then lock the device or leave the app. Tapping a test notification opens the same destination as the real one.")
        }
    }

    private func send(_ kind: DeveloperTools.TestNotification) {
        Task {
            let scheduled = await DeveloperTools.sendTestNotification(kind)
            show(scheduled ? "Arriving in 5 seconds" : "Notifications aren't allowed")
        }
    }

    // MARK: - iCloud sync

    private var syncSection: some View {
        let coordinator = iCloudSyncCoordinator.shared
        return Section {
            LabeledContent("Account", value: cloudKitManager.accountState.description)
            LabeledContent("Key-value state", value: coordinator.syncState.rawValue)
            LabeledContent("Last synchronize", value: coordinator.lastSynchronizeSucceeded.map { $0 ? "Succeeded" : "Failed" } ?? "None yet")
            LabeledContent("Last push", value: dateText(coordinator.lastPushDate))
            LabeledContent("Last merge", value: dateText(coordinator.lastMergeDate))
            LabeledContent("Cloud keys", value: "\(coordinator.cloudKeyCount) (\(coordinator.approximateCloudBytes / 1024) KB)")
            if let error = coordinator.lastErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button("Sync Now", systemImage: "arrow.triangle.2.circlepath") {
                coordinator.refreshNow()
                syncSnapshotID += 1
                show("Sync requested")
            }
            Button("Push All Local Values", systemImage: "icloud.and.arrow.up") {
                coordinator.pushAllNow { syncSnapshotID += 1 }
                show("Pushing all keys")
            }
            Button("Forget First-Sync Bootstrap", systemImage: "arrow.counterclockwise") {
                UserDefaults.standard.removeObject(forKey: coordinator.bootstrapFlagKey)
                show("Next launch will push everything again")
            }
            Button("Refresh Status", systemImage: "arrow.clockwise") {
                syncSnapshotID += 1
            }
        } header: {
            Label("iCloud Sync", systemImage: "icloud")
        } footer: {
            Text("Status is read when this page opens or you tap Refresh. It covers the key-value channel for stats and settings; notes and favorites sync through CloudKit.")
        }
        .id(syncSnapshotID)
    }

    private func dateText(_ date: Date?) -> String {
        date?.formatted(date: .abbreviated, time: .standard) ?? "Never"
    }

    // MARK: - Storage fallback

    private var storageSection: some View {
        Section {
            Picker("Simulate", selection: $forcedStoreMode) {
                Text("Normal").tag("")
                Text("Local only (not syncing)").tag("localOnly")
                Text("In memory (not saving)").tag("inMemory")
            }
            LabeledContent("Showing", value: String(describing: persistenceStoreMode))
        } header: {
            Label("Store Fallback", systemImage: "externaldrive.badge.exclamationmark")
        } footer: {
            Text("Shows the fallback banner and the iCloud page as if the library had failed to open. Only the display changes; the real store isn't touched.")
        }
    }

    // MARK: - Edge-case content

    private var contentSection: some View {
        Section {
            ForEach(libraryCounts, id: \.title) { item in
                LabeledContent(item.title, value: item.count.formatted())
            }

            Button("Add 10 Notes", systemImage: "note.text.badge.plus") {
                run("10 notes added") { try DeveloperTools.seedStressNotes(count: 10, in: modelContext) }
            }
            Button("Add 10 Random Favorites", systemImage: "heart") {
                Task {
                    do {
                        let added = try await DeveloperTools.seedRandomFavorites(in: modelContext)
                        show("\(added) favorites added")
                    } catch {
                        show("Failed: \(error.localizedDescription)")
                    }
                    refreshLibraryCounts()
                }
            }
            Button("Add 10 Random Highlights", systemImage: "highlighter") {
                Task {
                    do {
                        let added = try await DeveloperTools.seedRandomHighlights(in: modelContext)
                        show("\(added) highlights added")
                    } catch {
                        show("Failed: \(error.localizedDescription)")
                    }
                    refreshLibraryCounts()
                }
            }
            Button("Add 500 Notes", systemImage: "note.text.badge.plus") {
                run("500 notes added") { try DeveloperTools.seedStressNotes(in: modelContext) }
            }
            Button("Add One Very Long Note", systemImage: "text.alignleft") {
                run("Long note added") { try DeveloperTools.seedLongNote(in: modelContext) }
            }
            Button("Remove Seeded Notes", systemImage: "trash", role: .destructive) {
                isConfirmingRemoveSeededNotes = true
            }
            .confirmationDialog("Remove Seeded Notes?", isPresented: $isConfirmingRemoveSeededNotes, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    do {
                        let removed = try DeveloperTools.removeSeededNotes(in: modelContext)
                        show("Removed \(removed) notes")
                    } catch {
                        show("Failed: \(error.localizedDescription)")
                    }
                    refreshLibraryCounts()
                }
            } message: {
                Text("Removes the notes and highlights made by Generate Sample Data and the buttons above. Anything you wrote with the same titles goes too. Stats and saved verses aren't tagged; clear them with Reset Data.")
            }
        } header: {
            Label("Test Content", systemImage: "square.stack.3d.up")
        } footer: {
            Text("Large and long content for checking lists, search, editing, and sync. To check empty states, use a fresh install or Reset Data.")
        }
    }

    private func run(_ message: String, _ work: () throws -> Void) {
        do {
            try work()
            show(message)
        } catch {
            show("Failed: \(error.localizedDescription)")
        }
        refreshLibraryCounts()
    }

    private func refreshLibraryCounts() {
        libraryCounts = [
            ("Favorites", (try? modelContext.fetchCount(FetchDescriptor<Favorite>())) ?? 0),
            ("Verse notes & highlights", (try? modelContext.fetchCount(FetchDescriptor<VerseNote>())) ?? 0),
            ("Notes", (try? modelContext.fetchCount(FetchDescriptor<UserNote>())) ?? 0),
            ("Bookmarks", (try? modelContext.fetchCount(FetchDescriptor<Bookmark>())) ?? 0)
        ]
    }

    // MARK: - Translations

    struct TranslationReport: Identifiable {
        let translation: BibleTranslation
        let isBundled: Bool
        let books: Int
        let chapters: Int
        let verses: Int

        var id: String { translation.rawValue }
    }

    private var translationsSection: some View {
        Section {
            if translationReports.isEmpty {
                ProgressView()
            }
            ForEach(translationReports) { report in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(report.translation.name) (\(report.translation.abbreviation))")
                        .font(.headline)
                    if report.isBundled {
                        Text("\(report.books) books · \(report.chapters.formatted()) chapters · \(report.verses.formatted()) verses")
                            .font(.subheadline)
                        if let baseline = translationReports.first, baseline.id != report.id, baseline.verses != report.verses {
                            Text("Differs from \(baseline.translation.abbreviation) by \(abs(report.verses - baseline.verses).formatted()) verses (versification)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("Text file missing or unreadable")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    Text("\(report.translation.notice)\(report.translation.hasMarkedWords ? " Marks words of Jesus." : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Label("Translations", systemImage: "books.vertical")
        } footer: {
            Text("Read from the bundled text files, so this checks what ships. Counts that differ between translations are normal for a few verses; large gaps point to a bad build.")
        }
    }

    private func loadTranslationReports() async {
        var reports: [TranslationReport] = []
        for translation in BibleTranslation.allCases {
            let isBundled = Bundle.main.url(forResource: translation.resourceName, withExtension: "json") != nil
            let books = isBundled ? await BibleRepository.shared.loadBooksWithoutCaching(for: translation) : []
            reports.append(TranslationReport(
                translation: translation,
                isBundled: isBundled && !books.isEmpty,
                books: books.count,
                chapters: books.reduce(0) { $0 + $1.chapters.count },
                verses: books.reduce(0) { $0 + $1.chapters.reduce(0) { $0 + $1.verses.count } }
            ))
        }
        translationReports = reports
    }

    // MARK: - Diagnostics

    private var diagnosticsText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current
        var lines = [
            "The Bible \(version) (\(build)) debug",
            "\(device.model), \(device.systemName) \(device.systemVersion)",
            "Store: \(String(describing: persistenceStoreMode)), iCloud account: \(cloudKitManager.accountState.description)",
            "Translation: \(BibleTranslation.saved.abbreviation)",
            "Streak: \(streak.current) (best \(streak.best)), today \(streak.todaySeconds / 60)/\(streak.todayGoalSeconds / 60) min"
        ]
        lines += libraryCounts.map { "\($0.title): \($0.count)" }
        lines.append("Saved defaults keys: \(UserDefaults.standard.dictionaryRepresentation().count)")
        return lines.joined(separator: "\n")
    }

    private var diagnosticsSection: some View {
        Section {
            Text(diagnosticsText)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
            Button("Copy Diagnostics", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = diagnosticsText
                show("Copied")
            }
        } header: {
            Label("Diagnostics", systemImage: "stethoscope")
        } footer: {
            Text("A summary to paste into a bug report.")
        }
    }
}
#endif
