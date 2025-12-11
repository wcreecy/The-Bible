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
    enum HomeCardID: String, CaseIterable, Identifiable, Codable, Hashable {
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

    // Favorite layout storage is now managed by HomeLayoutStore; keep raw keys only if needed elsewhere
    @AppStorage("homeCardOrder") private var homeCardOrderRaw: String = ""
    @AppStorage("homeCardHidden") private var homeCardHiddenRaw: String = ""
    @AppStorage("homeCardFavoriteOrder") private var homeCardFavoriteOrderRaw: String = ""
    @AppStorage("homeCardFavoriteHidden") private var homeCardFavoriteHiddenRaw: String = ""

    // Local UI state
    @State private var layoutOrder: [HomeCardID] = HomeCardID.allCases
    @State private var hiddenSet: Set<HomeCardID> = []

    // Track if SwiftData store is CloudKit-backed (set at app startup)
    @AppStorage("swiftdataCloudKitEnabled") private var swiftdataCloudKitEnabled: Bool = false

    // New centralized layout store
    private let layoutStore = HomeLayoutStore()

    private func loadHomeLayout() {
        let loaded = layoutStore.load()
        layoutOrder = loaded.order
        hiddenSet = loaded.hidden
    }

    private func saveHomeLayout() {
        layoutStore.save(order: layoutOrder, hidden: hiddenSet)
    }

    // Favorite layout helpers via store
    private var hasFavoriteLayout: Bool { layoutStore.hasFavorite }

    private func saveFavoriteLayout() {
        layoutStore.saveFavorite(order: layoutOrder, hidden: hiddenSet)
    }

    private func applyFavoriteLayout() {
        layoutStore.applyFavoriteIfAvailable()
        let loaded = layoutStore.load()
        layoutOrder = loaded.order
        hiddenSet = loaded.hidden
    }

    // MARK: - VOTD DatePicker bindings using VOTDSchedule

    private var refresh1DateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let now = Date()
                return VOTDSchedule.dateForToday(hour: votdRefresh1Hour, minute: votdRefresh1Minute, from: now) ?? now
            },
            set: { newDate in
                let cal = Calendar.autoupdatingCurrent
                let c = cal.dateComponents([.hour, .minute], from: newDate)
                votdRefresh1Hour = c.hour ?? 6
                votdRefresh1Minute = c.minute ?? 0
            }
        )
    }

    private var refresh2DateBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let now = Date()
                return VOTDSchedule.dateForToday(hour: votdRefresh2Hour, minute: votdRefresh2Minute, from: now) ?? now
            },
            set: { newDate in
                let cal = Calendar.autoupdatingCurrent
                let c = cal.dateComponents([.hour, .minute], from: newDate)
                votdRefresh2Hour = c.hour ?? 18
                votdRefresh2Minute = c.minute ?? 0
            }
        )
    }

    // Derived “Next auto refresh” text for Settings
    private var nextVOTDDescription: String {
        VOTDSchedule.nextAutoRefreshDescription(
            first: (votdRefresh1Hour, votdRefresh1Minute),
            second: (votdRefresh2Hour, votdRefresh2Minute)
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

    // Debug alerts
    #if DEBUG
    @State private var debugAlertTitle: String = ""
    @State private var debugAlertMessage: String = ""
    @State private var showDebugAlert: Bool = false
    @State private var debugUtilitiesExpanded: Bool = false
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

            // MARK: - Debug Utilities (collapsible)
            #if DEBUG
            Section {
                if debugUtilitiesExpanded {
                    // Moved from the old "Debug" section: SwiftData/CloudKit test buttons
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
                                print("Latest -> book: \(latest.bookName), chapter: \(latest.chapterNumber), verse: \(latest.verseText), text: \(latest.verseText), createdAt: \(latest.createdAt)")
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

                        // NEW: Seed randomized reading stats for the past 31 days
                        Button {
                            seedRandomReadingStatsPast31Days()
                        } label: {
                            Label("Seed Random Reading Stats (31 Days)", systemImage: "sparkles")
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
                            hiddenSet = HomeLayoutStore.baselineHidden
                            saveHomeLayout()
                            debugShow("Home Layout", "Restored default order and hidden set.")
                        } label: {
                            Label("Reset Home Layout to Defaults", systemImage: "arrow.counterclockwise")
                        }

                        Button {
                            // Toggle to baseline hidden set
                            hiddenSet = HomeLayoutStore.baselineHidden
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
            } header: {
                // Custom header with caret chevron
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
                            // Push to iCloud KVS immediately so other devices get it fast
                            iCloudSyncCoordinator.shared.pushKey("dailyGoalMinutes")
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

                    // Live “Next auto refresh” preview
                    Text(nextVOTDDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("votdNextRefreshDescription")
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
                HomeLayoutEditorView(
                    order: $layoutOrder,
                    hiddenSet: $hiddenSet,
                    onDone: { saveHomeLayout() },
                    onSaveFavorite: {
                        saveFavoriteLayout()
                    },
                    onResetToFavorite: {
                        applyFavoriteLayout()
                    },
                    hasFavorite: hasFavoriteLayout
                )
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
                    // Centralized reset: zero all known game scoreboard keys and push to iCloud KVS with fresh timestamps.
                    iCloudSyncCoordinator.shared.resetAllGameCountersToZero()
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

    private func clearReadingSessionsOnly() {
        ReadingSessionsStore.shared.clearAll()
        debugShow("Reading Sessions", "Cleared all reading sessions.")
    }

    // Seed 1–3 sessions per day over the last 7 days with random books/chapters and 5–25 minute durations (local time).
    private func seedSampleSessionsLast7Days() {
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent

        // Build a list of candidate books (fallback if BibleData is empty)
        let bookNames: [String] = {
            let fromData = BibleData.books.map { $0.name }
            if !fromData.isEmpty { return fromData }
            return ["Genesis", "Psalms", "Proverbs", "Isaiah", "Matthew", "Mark", "Luke", "John", "Acts", "Romans"]
        }()

        let today = Date()
        for dayOffset in 0..<7 {
            guard let baseDay = cal.date(byAdding: .day, value: -dayOffset, to: cal.startOfDay(for: today)) else { continue }
            let sessionsCount = Int.random(in: 1...3)
            for _ in 0..<sessionsCount {
                // Pick a book and an optional chapter if available
                let book = bookNames.randomElement() ?? "John"
                let chapter: Int? = {
                    if let b = BibleData.books.first(where: { $0.name == book }), !b.chapters.isEmpty {
                        return b.chapters.randomElement()?.number
                    }
                    return nil
                }()

                // Choose a random start time during the day and a duration 5–25 minutes (local)
                let startSeconds = Int.random(in: 8*3600...22*3600) // somewhere between 8:00 and 22:00 local
                let duration = Int.random(in: 5*60...25*60)
                let start = cal.date(byAdding: .second, value: startSeconds, to: baseDay) ?? baseDay
                let end = start.addingTimeInterval(TimeInterval(duration))

                let session = ReadingSessionsStore.Session(start: start, end: end, book: book, chapter: chapter)
                ReadingSessionsStore.shared.appendSession(session)
            }
        }

        debugShow("Seeded Sessions", "Inserted random sessions for the last 7 days.")
    }

    private func seedRandomReadingStatsPast31Days() {
        // For the last 31 days, randomly add small reading totals to daily totals by book and sessions (local time).
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent
        let books = BibleData.books
        guard !books.isEmpty else {
            debugShow("Seed Stats", "No Bible data available.")
            return
        }

        for dayOffset in 0..<31 {
            guard let day = cal.date(byAdding: .day, value: -dayOffset, to: cal.startOfDay(for: Date())) else { continue }
            // Pick 1–3 books and assign 3–20 minutes each
            let pickCount = Int.random(in: 1...3)
            let picks = (0..<pickCount).compactMap { _ in books.randomElement() }
            for b in picks {
                let seconds = Int.random(in: 3*60...20*60)
                BibleStatsStore.shared.addToToday(bookName: b.name, seconds: seconds, calendar: cal)

                // Also add a session to reflect in charts
                let start = day.addingTimeInterval(TimeInterval(Int.random(in: 7*3600...21*3600)))
                let end = start.addingTimeInterval(TimeInterval(seconds))
                let chapter = b.chapters.randomElement()?.number
                let s = ReadingSessionsStore.Session(start: start, end: end, book: b.name, chapter: chapter)
                ReadingSessionsStore.shared.appendSession(s)
            }
        }

        debugShow("Seed Stats", "Seeded random reading stats for the past 31 days.")
    }

    private func defaultBook() -> Book? {
        if let john = BibleData.books.first(where: { $0.name == "John" }) { return john }
        return BibleData.books.first
    }

    private func markFirstThreeChaptersComplete() {
        guard let book = defaultBook() else {
            debugShow("Chapters", "No book available.")
            return
        }
        let chapters = book.chapters.prefix(3)
        for chap in chapters {
            let totalVerses = chap.verses.count
            let verses = chap.verses.map { $0.number }
            BibleStatsStore.shared.saveSeenVerses(verses, bookName: book.name, chapter: chap.number)
        }
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
        debugShow("Chapters", "Marked first 3 chapters of \(book.name) complete.")
    }

    private func clearChapterOneForDefaultBook() {
        guard let book = defaultBook() else {
            debugShow("Chapters", "No book available.")
            return
        }
        BibleStatsStore.shared.saveSeenVerses([], bookName: book.name, chapter: 1)
        var visited = BibleStatsStore.shared.loadVisitedChapters()
        visited.remove("\(book.name):1")
        BibleStatsStore.shared.saveVisitedChapters(visited)
        NotificationCenter.default.post(name: .chapterProgressChanged, object: nil)
        debugShow("Chapters", "Cleared Chapter 1 seen verses for \(book.name).")
    }

    private func logVerseCoverageForDefaultBook() {
        guard let book = defaultBook() else {
            debugShow("Coverage", "No book available.")
            return
        }
        var lines: [String] = []
        for chap in book.chapters.prefix(5) {
            let total = chap.verses.count
            let seen = BibleStatsStore.shared.loadSeenVerses(bookName: book.name, chapter: chap.number)
            let pct = total > 0 ? Int(round(Double(seen.count) / Double(total) * 100.0)) : 0
            lines.append("Chapter \(chap.number): \(seen.count)/\(total) (\(pct)%)")
        }
        let msg = lines.joined(separator: "\n")
        print("DEBUG Coverage for \(book.name):\n\(msg)")
        debugShow("Coverage (\(book.name))", msg)
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
        // Use a random verse similar to RefreshVerseOfDayIntent
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
    #endif
}

// MARK: - Minimal Home Layout Editor

private struct HomeLayoutEditorView: View {
    @Binding var order: [SettingsView.HomeCardID]
    @Binding var hiddenSet: Set<SettingsView.HomeCardID>
    var onDone: () -> Void

    // New: favorite handlers & state
    var onSaveFavorite: () -> Void
    var onResetToFavorite: () -> Void
    var hasFavorite: Bool

    // Force edit mode so drag handles are available immediately
    @State private var editMode: EditMode = .active

    private func isVisible(_ id: SettingsView.HomeCardID) -> Bool {
        !hiddenSet.contains(id)
    }

    private func toggleVisibility(_ id: SettingsView.HomeCardID) {
        if hiddenSet.contains(id) {
            hiddenSet.remove(id)
        } else {
            hiddenSet.insert(id)
        }
        onDone() // auto-save on toggle
    }

    private func resetToDefault() {
        order = SettingsView.HomeCardID.allCases
        hiddenSet = HomeLayoutStore.baselineHidden
        onDone() // auto-save
    }

    private func showAll() {
        hiddenSet.removeAll()
        onDone() // auto-save
    }

    // Uniform footer button factory
    @ViewBuilder
    private func footerButton(title: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .tint(.accentColor)
        .controlSize(.large)
        .font(.subheadline)
        .disabled(disabled)
    }

    var body: some View {
        List {
            Section {
                ForEach(order) { id in
                    HStack {
                        Image(systemName: id.systemImage)
                            .foregroundStyle(.secondary)
                        Text(id.title)
                        Spacer()
                        Button {
                            toggleVisibility(id)
                        } label: {
                            Image(systemName: isVisible(id) ? "eye" : "eye.slash")
                                .foregroundStyle(isVisible(id) ? .blue : .secondary)
                                .accessibilityLabel(isVisible(id) ? "Hide" : "Show")
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Toggles visibility on the Home page")
                    }
                }
                .onMove { indices, newOffset in
                    order.move(fromOffsets: indices, toOffset: newOffset)
                    onDone() // auto-save on reorder
                }
            } header: {
                Text("Order & Visibility")
            } footer: {
                VStack(alignment: .leading, spacing: 10) {
                    // Refactored: full-width, vertically stacked buttons for readability
                    footerButton(title: "Reset Order", systemImage: "arrow.counterclockwise") {
                        resetToDefault()
                    }
                    footerButton(title: "Show All Cards", systemImage: "eye") {
                        showAll()
                    }
                    footerButton(title: "Apply Favorite", systemImage: "star", disabled: !hasFavorite) {
                        onResetToFavorite()
                    }

                    Text("Drag to reorder. Tap the eye to show or hide a card on the Home page.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .environment(\.editMode, $editMode) // present in edit mode automatically
        .navigationTitle("Home Layout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // New: Save as Favorite button
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save as Favorite") {
                    onSaveFavorite()
                }
            }
        }
        // No additional toolbar edit/done buttons
    }
}

// MARK: - Font family environment modifier

private struct FontFamilyEnvironmentModifier: ViewModifier {
    let prefRaw: String

    func body(content: Content) -> some View {
        let pref = FontFamilyPreference(rawValue: prefRaw) ?? .system
        let baseSize: CGFloat = 17 // base; ContentView overrides for non-Settings tabs

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

#Preview {
    NavigationStack { SettingsView() }
}
