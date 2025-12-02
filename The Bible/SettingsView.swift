import SwiftUI
import AudioToolbox
import UniformTypeIdentifiers
internal import CloudKit
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var cloudKitManager: CloudKitManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Favorite.createdAt, order: .reverse) private var favorites: [Favorite]

    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue
    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""
    @AppStorage("quizScope") private var quizScopeRaw: String = "whole"
    @AppStorage("quizDifficulty") private var quizDifficulty: String = "easy"
    @AppStorage("timerSoundSelection") private var timerSoundSelection: String = TimerSound.default.rawValue
    @State private var showingResetQuizAlert: Bool = false

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

    var body: some View {
        Form {
            // iCloud status indicator section
            Section(header: Text("iCloud")) {
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
                    Task { await cloudKitManager.refresh() }
                } label: {
                    Label("Refresh Status", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("icloudRefreshButton")
            }
            .headerProminence(.increased)

            verseOfTheDaySection
            appearanceSection
            timerSection
            dailyGoalSection
            liveActivitiesSection
            homeLayoutSection
            gameDataSection

            // MARK: - Debug
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
                        print("Favorites count after insert: \(favorites.count + 0)") // +0 to force evaluation
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
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .preferredColorScheme((ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme)
        .dynamicTypeSize((FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system).dynamicTypeSize ?? .large)
        .modifier(FontFamilyEnvironmentModifier(prefRaw: fontFamilyPreferenceRaw))
        .onAppear { loadHomeLayout() }
        // Present Daily Goal sheet using an Identifiable token
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
                            // Commit once, then dismiss
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
                // Initialize local copy and present the tokenized sheet
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
        Section(header: Text("Game Data"), footer: Text("Reset your all-time game statistics. This action cannot be undone.").font(.footnote).foregroundStyle(.secondary)) {
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
                }
            } message: {
                Text("Your all-time game scores will be reset. Would you like to continue?")
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
