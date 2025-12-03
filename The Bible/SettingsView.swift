import SwiftUI
import AudioToolbox
import UniformTypeIdentifiers
internal import CloudKit
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var cloudKitManager: CloudKitManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Favorite.createdAt, order: .reverse) private var favorites: [Favorite]
    // Count Journal entries for status
    @Query private var journalEntries: [JournalEntry]

    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue
    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""
    @AppStorage("quizScope") private var quizScopeRaw: String = "whole"
    @AppStorage("quizDifficulty") private var quizDifficulty: String = "easy"
    @AppStorage("timerSoundSelection") private var timerSoundSelection: String = TimerSound.default.rawValue
    @State private var showingResetQuizAlert: Bool = false
    @State private var showingResetReadingAlert: Bool = false

    @AppStorage("votdRefresh1Hour") private var votdRefresh1Hour: Int = 6
    @AppStorage("votdRefresh1Minute") private var votdRefresh1Minute: Int = 0
    @AppStorage("votdRefresh2Hour") private var votdRefresh2Hour: Int = 18
    @AppStorage("votdRefresh2Minute") private var votdRefresh2Minute: Int = 0

    // Daily Goal (minutes)
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30

    // Use an Identifiable token for sheet presentation to avoid boolean re-entrancy races
    private struct SheetToken: Identifiable { let id = UUID() }
    @State private var dailyGoalSheetToken: SheetToken? = nil

    // Local, decoupled value used while the sheet is open
    @State private var localDailyGoalMinutes: Int = 30

    // Live Activities master toggle
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true

    // Spinning refresh state for iCloud refresh button
    @State private var isRefreshingCloudStatus: Bool = false

    // MARK: - Home layout configuration
    private enum HomeCardID: String, CaseIterable, Identifiable, Codable, Hashable {
        case verseOfDay, dailyFocus, timer, resumeReading, games, streaks, bibleStats
        var id: String { rawValue }
        var title: String {
            switch self {
            case .verseOfDay: return "Verse of the Day"
            case .dailyFocus: return "Daily Focus"
            case .timer: return "Prayer Timer / Stopwatch"
            case .resumeReading: return "Continue Reading"
            case .games: return "Games"
            case .streaks: return "Daily Bible Streak"
            case .bibleStats: return "Bible Stats"
            }
        }
        var systemImage: String {
            switch self {
            case .verseOfDay: return "sun.max"
            case .dailyFocus: return "target"
            case .timer: return "timer"
            case .resumeReading: return "bookmark.fill"
            case .games: return "gamecontroller"
            case .streaks: return "flame.fill"
            case .bibleStats: return "chart.bar.fill"
            }
        }
    }

    @AppStorage("homeCardOrder") private var homeCardOrderRaw: String = ""
    @AppStorage("homeCardHidden") private var homeCardHiddenRaw: String = ""

    @State private var layoutOrder: [HomeCardID] = HomeCardID.allCases
    @State private var hiddenSet: Set<HomeCardID> = []

    // Track if SwiftData store is CloudKit-backed (set at app startup)
    @AppStorage("swiftdataCloudKitEnabled") private var swiftdataCloudKitEnabled: Bool = false

    private func loadHomeLayout() {
        if let data = homeCardOrderRaw.data(using: .utf8),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            let mapped = ids.compactMap { HomeCardID(rawValue: $0) }
            let missing = HomeCardID.allCases.filter { !mapped.contains($0) }
            layoutOrder = mapped + missing
        } else {
            layoutOrder = HomeCardID.allCases
        }

        if let data = homeCardHiddenRaw.data(using: .utf8),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            hiddenSet = Set(ids.compactMap { HomeCardID(rawValue: $0) })
        } else {
            hiddenSet = [.games, .streaks, .bibleStats]
        }
    }

    private func saveHomeLayout() {
        let orderIDs = layoutOrder.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(orderIDs),
           let raw = String(data: data, encoding: .utf8) {
            homeCardOrderRaw = raw
        }
        let hiddenIDs = Array(hiddenSet).map { $0.rawValue }
        if let data = try? JSONEncoder().encode(hiddenIDs),
           let raw = String(data: data, encoding: .utf8) {
            homeCardHiddenRaw = raw
        }
        NotificationCenter.default.post(name: .init("homeLayoutChanged"), object: nil)
    }

    private var refresh1DateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var comps = DateComponents()
                let cal = Calendar.current
                let now = Date()
                let base = cal.dateComponents([.year, .month, .day], from: now)
                comps.year = base.year
                comps.month = base.month
                comps.day = base.day
                comps.hour = votdRefresh1Hour
                comps.minute = votdRefresh1Minute
                comps.second = 0
                return cal.date(from: comps) ?? now
            },
            set: { newDate in
                let cal = Calendar.current
                let c = cal.dateComponents([.hour, .minute], from: newDate)
                votdRefresh1Hour = c.hour ?? 6
                votdRefresh1Minute = c.minute ?? 0
            }
        )
    }

    private var refresh2DateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var comps = DateComponents()
                let cal = Calendar.current
                let now = Date()
                let base = cal.dateComponents([.year, .month, .day], from: now)
                comps.year = base.year
                comps.month = base.month
                comps.day = base.day
                comps.hour = votdRefresh2Hour
                comps.minute = votdRefresh2Minute
                comps.second = 0
                return cal.date(from: comps) ?? now
            },
            set: { newDate in
                let cal = Calendar.current
                let c: DateComponents = cal.dateComponents([.hour, .minute], from: newDate)
                votdRefresh2Hour = c.hour ?? 18
                votdRefresh2Minute = c.minute ?? 0
            }
        )
    }

    private var iCloudStatusText: String {
        switch cloudKitManager.accountState {
        case .available: return "Available"
        case .noAccount: return "No Account"
        case .restricted: return "Restricted"
        case .couldNotDetermine: return "Unavailable"
        case .unknown: return "Unknown"
        }
    }

    private var iCloudStatusColor: Color {
        switch cloudKitManager.accountState {
        case .available: return .green
        case .noAccount, .restricted, .couldNotDetermine: return .orange
        case .unknown: return .secondary
        }
    }

    // KVS helpers
    private var kvsAvailable: Bool {
        iCloudSyncCoordinator.shared.kvsAvailable
    }
    private var kvsStatusText: String {
        kvsAvailable ? "On" : "Unavailable"
    }
    private func formatDateTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df.string(from: date)
    }

    // Debug alerts
    #if DEBUG
    @State private var debugAlertTitle: String = ""
    @State private var debugAlertMessage: String = ""
    @State private var showDebugAlert: Bool = false
    #endif

    var body: some View {
        Form {
            // Reordered sections: move iCloud below, above Reset Data
            verseOfTheDaySection
            appearanceSection
            timerSection
            dailyGoalSection
            liveActivitiesSection
            homeLayoutSection

            // iCloud status indicator section (kept; Sync Status removed)
            Section {
                HStack {
                    Label("CloudKit", systemImage: "icloud")
                    Spacer()
                    Text(iCloudStatusText)
                        .foregroundStyle(iCloudStatusColor)
                        .accessibilityIdentifier("icloudStatusText")
                }
                if let id = cloudKitManager.userRecordID {
                    HStack {
                        Text("User Record")
                        Spacer()
                        Text(id.recordName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .accessibilityIdentifier("icloudUserRecord")
                }
                Button {
                    // Haptic confirmation
                    let h = UIImpactFeedbackGenerator(style: .light)
                    h.impactOccurred()

                    isRefreshingCloudStatus = true
                    Task {
                        await cloudKitManager.refresh()
                        // small delay so the spin is perceivable
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        await MainActor.run { isRefreshingCloudStatus = false }
                    }
                } label: {
                    Label {
                        Text(isRefreshingCloudStatus ? "Refreshing…" : "Refresh Status")
                    } icon: {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(isRefreshingCloudStatus ? .degrees(360) : .degrees(0))
                            .animation(
                                isRefreshingCloudStatus
                                ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                : .default,
                                value: isRefreshingCloudStatus
                            )
                    }
                }
                .disabled(isRefreshingCloudStatus)
                .accessibilityIdentifier("icloudRefreshButton")
            } header: {
                Text("iCloud")
            } footer: {
                Text("""
                iCloud keeps your data up to date across your devices using CloudKit.
                Status meanings:
                • Available: Signed in to iCloud and CloudKit is ready.
                • No Account: Not signed in to iCloud on this device.
                • Restricted: iCloud is restricted by system settings or parental controls.
                • Unavailable: The status couldn’t be determined right now.
                """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .headerProminence(.increased)

            gameDataSection

            // MARK: - Debug (hidden in non-DEBUG builds)
            #if DEBUG
            Section(header: Text("Debug")) {
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
            .headerProminence(.increased)

            // MARK: Debug Utilities
            Section(header: Text("Debug Utilities")) {

                // iCloud KVS tools
                Group {
                    Button {
                        iCloudSyncCoordinator.shared.pushAllNow()
                        debugShow("iCloud KVS", "Pushed all known keys.\nLast push: \(formatDateTime(iCloudSyncCoordinator.shared.lastPushDate))")
                    } label: {
                        Label("Force KVS Push", systemImage: "icloud.and.arrow.up")
                    }

                    Button {
                        let lastPush = formatDateTime(iCloudSyncCoordinator.shared.lastPushDate)
                        let lastMerge = formatDateTime(iCloudSyncCoordinator.shared.lastMergeDate)
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
                        seedSampleSessionsLast7Days()
                    } label: {
                        Label("Seed Reading Sessions (Last 7 Days)", systemImage: "clock.badge.plus")
                    }

                    Button(role: .destructive) {
                        clearReadingSessionsOnly()
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
                }

                // Chapter/verse progress
                Group {
                    Button {
                        markFirstThreeChaptersComplete()
                    } label: {
                        Label("Mark First 3 Chapters as Read (Book)", systemImage: "checkmark.circle")
                    }

                    Button(role: .destructive) {
                        clearChapterOneForDefaultBook()
                    } label: {
                        Label("Clear Chapter 1 Seen Verses (Book)", systemImage: "xmark.circle")
                    }

                    Button {
                        logVerseCoverageForDefaultBook()
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

                // Home layout
                Group {
                    Button {
                        layoutOrder = HomeCardID.allCases
                        hiddenSet = [.games, .streaks, .bibleStats]
                        saveHomeLayout()
                        debugShow("Home Layout", "Restored default order and hidden set.")
                    } label: {
                        Label("Reset Home Layout to Defaults", systemImage: "arrow.counterclockwise")
                    }

                    Button {
                        // Toggle to baseline hidden set
                        let baseline: Set<HomeCardID> = [.games, .streaks, .bibleStats]
                        hiddenSet = baseline
                        saveHomeLayout()
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

                // Verse of the Day / Widgets (no VerseProvider call)
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
                            let storeHint = await The_Bible__iOS_App.computeStoreEnvironmentHint() ?? The_Bible__iOS_App.buildEnvHintFallback()
                            let msg = """
                            Build configuration: \(cfg)
                            Bundle ID: \(bundleID)
                            AppIdentifierPrefix: \(appIDPrefix)
                            CloudKit container: \(container)
                            SwiftData CloudKit: \(cloudKitFlag)
                            StoreKit environment: \(storeHint)
                            """
                            print("DEBUG Build/Env:\n\(msg)")
                            debugShow("Build/Environment", msg)
                        }
                    } label: {
                        Label("Show Build/Environment Diagnostics", systemImage: "info.circle")
                    }
                }
            }
            .alert(debugAlertTitle, isPresented: $showDebugAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(debugAlertMessage)
            }
            #endif
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .preferredColorScheme((ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme)
        .dynamicTypeSize((FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system).dynamicTypeSize ?? .large)
        .modifier(FontFamilyEnvironmentModifier(prefRaw: fontFamilyPreferenceRaw))
        .onAppear { loadHomeLayout() }
        .sheet(item: $dailyGoalSheetToken, onDismiss: {
            // No-op; commit happens on Done
        }) { _ in
            NavigationStack {
                VStack {
                    Picker("", selection: $localDailyGoalMinutes) {
                        ForEach(1...240, id: \.self) { m in
                            Text("\(m) minute\(m == 1 ? "" : "s")").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .accessibilityIdentifier("dailyGoalMinutesWheel")
                }
                .navigationTitle("Daily Goal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dailyGoalSheetToken = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dailyGoalMinutes = localDailyGoalMinutes
                            dailyGoalSheetToken = nil
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Sections

    private var verseOfTheDaySection: some View {
        Section(
            header: Text("Verse of the Day"),
            footer: Text("Choose which part of the Bible the Verse of the Day is selected from. You can also set two daily auto-refresh times; the verse will refresh at those times unless paused on the Home page.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        ) {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    segmentButton(title: "OT", tag: "old")
                    verticalSeparator()
                    segmentButton(title: "NT", tag: "new")
                    verticalSeparator()
                    segmentButton(title: "OT/NT", tag: "whole")
                    verticalSeparator()
                    segmentButton(title: "Book", tag: "book")
                }
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .accessibilityIdentifier("verseOfDayScopePicker")

                if verseScopeRaw == "book" {
                    BookSelectionLink(
                        selectedBookName: Binding<String?>(
                            get: { verseSpecificBook.isEmpty ? nil : verseSpecificBook },
                            set: { verseSpecificBook = $0 ?? "" }
                        )
                    )
                    .accessibilityIdentifier("verseOfDaySpecificBookPicker")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Auto-Refresh Times", systemImage: "clock.arrow.2.circlepath")
                        .font(.headline)

                    DatePicker("Refresh Time 1", selection: refresh1DateBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("votdRefreshTime1")

                    DatePicker("Refresh Time 2", selection: refresh2DateBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .accessibilityIdentifier("votdRefreshTime2")
                }
                .padding(.top, 8)
            }
        }
        .headerProminence(.increased)
    }

    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            VStack(alignment: .leading, spacing: 8) {
                Label("App Appearance", systemImage: "paintbrush")
                HStack(spacing: 0) {
                    appearanceSegmentButton(.system)
                    verticalSeparator()
                    appearanceSegmentButton(.light)
                    verticalSeparator()
                    appearanceSegmentButton(.dark)
                }
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .accessibilityIdentifier("appearancePicker")
            }
            Text("Choose Light, Dark, or follow the System setting for the app's appearance.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("App Text Size", systemImage: "textformat.size")
                HStack(spacing: 0) {
                    fontSizeSegmentButton(.system)
                    verticalSeparator()
                    fontSizeSegmentButton(.small)
                    verticalSeparator()
                    fontSizeSegmentButton(.medium)
                    verticalSeparator()
                    fontSizeSegmentButton(.large)
                    verticalSeparator()
                    fontSizeSegmentButton(.extraLarge)
                }
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .accessibilityIdentifier("textSizePicker")
            }
            Text("This affects all app UI. Bible text size is controlled in the Reader.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("Font", systemImage: "textformat")
                HStack(spacing: 0) {
                    fontFamilySegmentButton(.system)
                    verticalSeparator()
                    fontFamilySegmentButton(.serif)
                    verticalSeparator()
                    fontFamilySegmentButton(.rounded)
                    verticalSeparator()
                    fontFamilySegmentButton(.monospaced)
                    verticalSeparator()
                    fontFamilySegmentButton(.georgia)
                }
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .accessibilityIdentifier("fontFamilyPicker")
            }
            Text("Choose an easy-to-read typeface for the interface and reading.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .headerProminence(.increased)
    }

    private var timerSection: some View {
        Section(header: Text("Timer"), footer: Text("Choose the sound that plays when the prayer/study timer finishes.").font(.footnote).foregroundStyle(.secondary)) {
            LabeledContent {
                HStack(spacing: 10) {
                    Picker("", selection: Binding<String>(
                        get: { timerSoundSelection },
                        set: { timerSoundSelection = $0 }
                    )) {
                        ForEach(TimerSound.allCases) { sound in
                            Text(sound.title).tag(sound.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("timerSoundPicker")

                    Button {
                        let sound = TimerSound(rawValue: timerSoundSelection) ?? .default
                        AudioServicesPlaySystemSound(sound.systemSoundID)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Play Preview")
                    .accessibilityHint("Plays the selected timer sound")
                }
            } label: {
                Label("Timer Sound", systemImage: "speaker.wave.2")
            }
        }
        .headerProminence(.increased)
    }

    private var dailyGoalSection: some View {
        Section(header: Text("Daily Goal"), footer: Text("Set the number of minutes you want to spend in the app each day. Your Daily Bible Streak is based on meeting this goal.").font(.footnote).foregroundStyle(.secondary)) {
            Button {
                localDailyGoalMinutes = dailyGoalMinutes
                if dailyGoalSheetToken == nil {
                    dailyGoalSheetToken = SheetToken()
                }
            } label: {
                HStack {
                    Label("Daily Goal", systemImage: "target")
                        .foregroundStyle(.blue)
                    Spacer()
                    Text("\(dailyGoalMinutes) min")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("dailyGoalMinutesPickerLink")
        }
        .headerProminence(.increased)
    }

    private var liveActivitiesSection: some View {
        Section(header: Text("Live Activities"), footer: Text("Show your Prayer Timer, Stopwatch, or Daily Focus on the Lock Screen and Dynamic Island. You can turn this off anytime.").font(.footnote).foregroundStyle(.secondary)) {
            Toggle(isOn: $liveActivitiesEnabled) {
                Label("Enable Live Activities", systemImage: "livephoto.play")
            }
            .accessibilityIdentifier("liveActivitiesToggle")
        }
        .onChange(of: liveActivitiesEnabled) { _, enabled in
            if !enabled {
                PrayerTimerActivityController.shared.cancel()
                StopwatchActivityController.shared.cancel()
            }
        }
        .headerProminence(.increased)
    }

    private var homeLayoutSection: some View {
        Section(header: Text("Home Layout"), footer: Text("Reorder or hide sections on the Home page. The title card always stays at the top.").font(.footnote).foregroundStyle(.secondary)) {

            NavigationLink {
                HomeLayoutEditorView(order: $layoutOrder, hidden: $hiddenSet) {
                    saveHomeLayout()
                }
            } label: {
                Label("Edit Order & Visibility", systemImage: "arrow.up.arrow.down")
            }
        }
        .headerProminence(.increased)
        .onAppear(perform: loadHomeLayout)
    }

    private var gameDataSection: some View {
        Section(header: Text("Reset Data"), footer: Text("Reset your all-time game statistics or reading stats. These actions cannot be undone.").font(.footnote).foregroundStyle(.secondary)) {
            Button(role: .destructive) {
                showingResetQuizAlert = true
            } label: {
                Label("Reset All-time Game Stats", systemImage: "trash")
            }
            .alert("Reset All-time Stats?", isPresented: $showingResetQuizAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    UserDefaults.standard.set(0, forKey: "quizAllTimeCorrect_easy")
                    UserDefaults.standard.set(0, forKey: "quizAllTimeAnswered_easy")
                    UserDefaults.standard.set(0, forKey: "quizAllTimeBestStreak_easy")
                    UserDefaults.standard.set(0, forKey: "quizAllTimeCorrect_normal")
                    UserDefaults.standard.set(0, forKey: "quizAllTimeAnswered_normal")
                    UserDefaults.standard.set(0, forKey: "quizAllTimeBestStreak_normal")
                    UserDefaults.standard.set(0, forKey: "quizAllTimeCorrect_hard")
                    UserDefaults.standard.set(0, forKey: "quizAllTimeAnswered_hard")
                    UserDefaults.standard.set(0, forKey: "quizAllTimeBestStreak_hard")
                    ["", "_easy", "_medium", "_hard"].forEach { suf in
                        UserDefaults.standard.set(0, forKey: "hangmanAllTimeCorrect\(suf)")
                        UserDefaults.standard.set(0, forKey: "hangmanAllTimeAnswered\(suf)")
                        UserDefaults.standard.set(0, forKey: "hangmanAllTimeBestStreak\(suf)")
                    }
                    ["", "_easy", "_medium", "_hard"].forEach { suf in
                        UserDefaults.standard.set(0, forKey: "refmatchAllTimeCorrect\(suf)")
                        UserDefaults.standard.set(0, forKey: "refmatchAllTimeAnswered\(suf)")
                        UserDefaults.standard.set(0, forKey: "refmatchAllTimeBestStreak\(suf)")
                    }
                    ["_easy", "_medium", "_hard"].forEach { suf in
                        UserDefaults.standard.set(0, forKey: "beatclockAllTimeCorrect\(suf)")
                        UserDefaults.standard.set(0, forKey: "beatclockAllTimeAnswered\(suf)")
                        UserDefaults.standard.set(0, forKey: "beatclockAllTimeBestStreak\(suf)")
                    }
                    UserDefaults.standard.set(0, forKey: "bookorderAllTimeCorrect")
                    UserDefaults.standard.set(0, forKey: "bookorderAllTimeAnswered")
                    UserDefaults.standard.set(0, forKey: "bookorderAllTimeBestStreak")
                    // Push game keys to iCloud KVS
                    iCloudSyncCoordinator.shared.pushAllNow()
                }
            } message: {
                Text("Your all-time game scores will be reset. Would you like to continue?")
            }

            // New: Reset all reading stats button
            Button(role: .destructive) {
                showingResetReadingAlert = true
            } label: {
                Label("Reset All Reading Stats", systemImage: "trash")
            }
            .alert("Reset All Reading Stats?", isPresented: $showingResetReadingAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    let defaults = BibleStatsStore.Defaults.provider
                    // Clear JSON-backed reading stats
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyTotals)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyDailyTotals)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyDailyTotalsByBook)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyVisitedChapters)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyLastRead)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keySeenVersesByChapter)
                    defaults.removeObject(forKey: BibleStatsStore.Defaults.keyChapterCompletionDates)
                    // Clear reading sessions
                    defaults.removeObject(forKey: "readingSessions")

                    // Reset in-memory caches
                    BibleStatsStore.shared.resetCaches()
                    // Notify listeners (StatsView, etc.)
                    NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
                    // Push cleared keys to iCloud KVS
                    iCloudSyncCoordinator.shared.pushAllNow()
                }
            } message: {
                Text("All reading statistics, progress, and sessions will be removed. This cannot be undone. Do you want to continue?")
            }
        }
        .headerProminence(.increased)
    }

    // MARK: - UI helpers

    private func segmentButton(title: String, tag: String) -> some View {
        Button(action: { verseScopeRaw = tag }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(verseScopeRaw == tag ? .semibold : .regular)
                .foregroundStyle(verseScopeRaw == tag ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if verseScopeRaw == tag {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func verticalSeparator() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 1, height: 24)
    }

    private func appearanceSegmentButton(_ pref: ColorSchemePreference) -> some View {
        let isSelected = (ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system) == pref
        return Button(action: { colorSchemePreferenceRaw = pref.rawValue }) {
            Text(pref.title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func fontSizeSegmentButton(_ pref: FontSizePreference) -> some View {
        let isSelected = (FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system) == pref
        return Button(action: { fontSizePreferenceRaw = pref.rawValue }) {
            Text(pref.title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func fontFamilySegmentButton(_ pref: FontFamilyPreference) -> some View {
        let isSelected = (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system) == pref
        return Button(action: { fontFamilyPreferenceRaw = pref.rawValue }) {
            Text(pref.title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    #if DEBUG
    // MARK: - Debug helpers

    private func debugShow(_ title: String, _ message: String) {
        debugAlertTitle = title
        debugAlertMessage = message
        showDebugAlert = true
    }

    private func defaultBookForDebug() -> Book? {
        if let john = BibleData.books.first(where: { $0.name == "John" }) {
            return john
        }
        return BibleData.books.first
    }

    private func seedSampleSessionsLast7Days() {
        guard let bookA = BibleData.books.first,
              let bookB = BibleData.books.dropFirst().first ?? BibleData.books.first else {
            debugShow("Seed Sessions", "No books available.")
            return
        }
        let cal = Calendar.current
        var created = 0
        for i in 0..<7 {
            guard let end = cal.date(byAdding: .day, value: -i, to: Date()) else { continue }
            let minutes = Int.random(in: 12...18)
            let duration = TimeInterval(minutes * 60)
            let start = end.addingTimeInterval(-duration)
            let pick = (i % 2 == 0) ? bookA : bookB
            let chapter = pick.chapters.randomElement()?.number
            let session = ReadingSessionsStore.Session(start: start, end: end, book: pick.name, chapter: chapter)
            ReadingSessionsStore.shared.appendSession(session)
            created += 1
        }
        debugShow("Seed Sessions", "Created \(created) sessions over the last 7 days.")
    }

    private func clearReadingSessionsOnly() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "readingSessions")
        // Let the store invalidate cache
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
        // Push cleared key to KVS
        iCloudSyncCoordinator.shared.pushKey("readingSessions")
        debugShow("Reading Sessions", "Cleared all sessions.")
    }

    private func markFirstThreeChaptersComplete() {
        guard let book = defaultBookForDebug() else {
            debugShow("Mark Chapters", "No book found.")
            return
        }
        let chapters = Array(book.chapters.prefix(3))
        var marked = 0
        for chap in chapters {
            let totalVerses = chap.verses.count
            guard totalVerses > 0 else { continue }
            let allVerses = Array(1...totalVerses)
            BibleStatsStore.shared.saveSeenVerses(allVerses, bookName: book.name, chapter: chap.number)
            BibleStatsStore.shared.markVisited(bookName: book.name, chapterNumber: chap.number)
            // also set last read to this chapter (optional debug convenience)
            BibleStatsStore.shared.saveLastRead(bookName: book.name, chapterNumber: chap.number, date: Date())
            marked += 1
        }
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
        debugShow("Mark Chapters", "Marked \(marked) chapters as read in \(book.name).")
    }

    private func clearChapterOneForDefaultBook() {
        guard let book = defaultBookForDebug() else {
            debugShow("Clear Chapter", "No book found.")
            return
        }
        let chapterNum = 1
        BibleStatsStore.shared.saveSeenVerses([], bookName: book.name, chapter: chapterNum)
        var visited = BibleStatsStore.shared.loadVisitedChapters()
        visited.remove("\(book.name):\(chapterNum)")
        BibleStatsStore.shared.saveVisitedChapters(visited)
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
        debugShow("Clear Chapter", "Cleared seen verses for \(book.name) \(chapterNum).")
    }

    private func logVerseCoverageForDefaultBook() {
        guard let book = defaultBookForDebug() else {
            debugShow("Coverage", "No book found.")
            return
        }
        var total = 0
        var completed = 0
        for chap in book.chapters {
            let count = chap.verses.count
            total += count
            let seen = BibleStatsStore.shared.loadSeenVerses(bookName: book.name, chapter: chap.number)
            completed += min(count, seen.count)
        }
        print("DEBUG Coverage for \(book.name): \(completed)/\(total) verses")
        debugShow("Coverage", "\(book.name): \(completed)/\(total) verses")
    }

    private func deleteAllFavorites() {
        var deleted = 0
        for f in favorites {
            modelContext.delete(f)
            deleted += 1
        }
        do {
            try modelContext.save()
            debugShow("Favorites", "Deleted \(deleted) favorites.")
        } catch {
            debugShow("Favorites", "Error deleting favorites: \(error.localizedDescription)")
        }
    }

    private func insertSampleJournalEntry() {
        let entry = JournalEntry()
        entry.title = "Debug Sample"
        entry.body = "This is a debug sample entry. John 3:16"
        entry.tags = ["debug", "sample"]
        entry.updatedAt = Date()
        modelContext.insert(entry)
        do {
            try modelContext.save()
            debugShow("Journal", "Inserted sample entry.")
        } catch {
            debugShow("Journal", "Failed to insert: \(error.localizedDescription)")
        }
    }

    private func writeTestVOTDToDefaultsAndAppGroup() {
        // Use a simple stable verse
        let book = "John"
        let chapter = 3
        let verse = 16
        let text = "For God so loved the world, that he gave his only begotten Son..."

        // Standard defaults (app UI)
        let std = UserDefaults.standard
        std.set(book, forKey: "verseOfDayBook")
        std.set(chapter, forKey: "verseOfDayChapter")
        std.set(verse, forKey: "verseOfDayNumber")
        std.set(text, forKey: "verseOfDayText")

        // Shared App Group (widget)
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            shared.set(book, forKey: "verseOfDayBook")
            shared.set(chapter, forKey: "verseOfDayChapter")
            shared.set(verse, forKey: "verseOfDayNumber")
            shared.set(text, forKey: "verseOfDayText")
        }

        debugShow("Verse of the Day", "Wrote test VOTD to app + App Group.")
    }
    #endif
}

extension SettingsView {
    private struct HomeLayoutEditorView: View {
        @Binding var order: [HomeCardID]
        @Binding var hidden: Set<HomeCardID>
        var save: () -> Void

        var body: some View {
            VStack(spacing: 12) {
                List {
                    ForEach(order, id: \.self) { card in
                        HStack {
                            Label(card.title, systemImage: card.systemImage)
                                .opacity(hidden.contains(card) ? 0.45 : 1.0)

                            Spacer()

                            Button {
                                if hidden.contains(card) {
                                    hidden.remove(card)
                                } else {
                                    hidden.insert(card)
                                }
                                save()
                            } label: {
                                Image(systemName: hidden.contains(card) ? "eye.slash" : "eye")
                                    .foregroundStyle(hidden.contains(card) ? .secondary : .primary)
                                    .imageScale(.medium)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(hidden.contains(card) ? "Show \(card.title)" : "Hide \(card.title)")
                        }
                    }
                    .onMove { indices, newOffset in
                        order.move(fromOffsets: indices, toOffset: newOffset)
                        save()
                    }
                }
                .environment(\.editMode, .constant(.active))

                HStack(spacing: 12) {
                    Button {
                        hidden.removeAll()
                        save()
                    } label: {
                        Label("Show All", systemImage: "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        order = HomeCardID.allCases
                        hidden = [.games, .streaks, .bibleStats]
                        save()
                    } label: {
                        Label("Restore Default", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Reorder Home")
            .onDisappear { save() }
        }
    }
}

private struct FontFamilyEnvironmentModifier: ViewModifier {
    let prefRaw: String
    func body(content: Content) -> some View {
        let pref = FontFamilyPreference(rawValue: prefRaw) ?? .system
        let fontDesign = pref.fontDesign ?? .default
        if let name = pref.customFontName {
            content
                .font(.custom(name, size: 17))
                .fontDesign(fontDesign)
        } else {
            content
                .font(.system(size: 17))
                .fontDesign(fontDesign)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
