import SwiftUI
import AudioToolbox

struct SettingsView: View {
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

    // Live Activities master toggle
    @AppStorage("liveActivitiesEnabled") private var liveActivitiesEnabled: Bool = true

    // MARK: - Home layout configuration
    // Identifiers for reorderable/hideable cards on Home (NOT including the title card)
    private enum HomeCardID: String, CaseIterable, Identifiable {
        case verseOfDay
        case dailyFocus
        case timer
        case resumeReading

        var id: String { rawValue }
        var title: String {
            switch self {
            case .verseOfDay: return "Verse of the Day"
            case .dailyFocus: return "Daily Focus"
            case .timer: return "Prayer Timer / Stopwatch"
            case .resumeReading: return "Continue Reading"
            }
        }
        var systemImage: String {
            switch self {
            case .verseOfDay: return "sun.max" // will be night/day on Home, but fine here
            case .dailyFocus: return "target"
            case .timer: return "timer"
            case .resumeReading: return "bookmark.fill"
            }
        }
    }

    // Persist order and hidden set in AppStorage
    @AppStorage("homeCardOrder") private var homeCardOrderRaw: String = "" // JSON array of strings
    @AppStorage("homeCardHidden") private var homeCardHiddenRaw: String = "" // JSON array of strings

    // Local state mirrors that decode/encode to AppStorage
    @State private var layoutOrder: [HomeCardID] = HomeCardID.allCases
    @State private var hiddenSet: Set<HomeCardID> = []

    // Decode on appear; encode on change
    private func loadHomeLayout() {
        // Decode order
        if let data = homeCardOrderRaw.data(using: .utf8),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            let mapped = ids.compactMap { HomeCardID(rawValue: $0) }
            // Ensure we include any new cards that weren’t saved yet
            let missing = HomeCardID.allCases.filter { !mapped.contains($0) }
            layoutOrder = mapped + missing
        } else {
            layoutOrder = HomeCardID.allCases
        }

        // Decode hidden
        if let data = homeCardHiddenRaw.data(using: .utf8),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            hiddenSet = Set(ids.compactMap { HomeCardID(rawValue: $0) })
        } else {
            hiddenSet = []
        }
    }

    private func saveHomeLayout() {
        // Encode order
        let orderIDs = layoutOrder.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(orderIDs),
           let raw = String(data: data, encoding: .utf8) {
            homeCardOrderRaw = raw
        }
        // Encode hidden
        let hiddenIDs = Array(hiddenSet).map { $0.rawValue }
        if let data = try? JSONEncoder().encode(hiddenIDs),
           let raw = String(data: data, encoding: .utf8) {
            homeCardHiddenRaw = raw
        }
        // Nudge widgets if needed (optional)
        // WidgetCenter.shared.reloadAllTimelines() // only if home layout affects widgets
        // Also notify HomeView to refresh layout (optional via NotificationCenter)
        NotificationCenter.default.post(name: .init("homeLayoutChanged"), object: nil)
    }

    private var selectionBinding: Binding<ColorSchemePreference> {
        Binding<ColorSchemePreference>(
            get: { ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system },
            set: { colorSchemePreferenceRaw = $0.rawValue }
        )
    }

    private var fontSizeBinding: Binding<FontSizePreference> {
        Binding<FontSizePreference>(
            get: { FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system },
            set: { fontSizePreferenceRaw = $0.rawValue }
        )
    }

    private var fontFamilyBinding: Binding<FontFamilyPreference> {
        Binding<FontFamilyPreference>(
            get: { FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system },
            set: { fontFamilyPreferenceRaw = $0.rawValue }
        )
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
                let c = cal.dateComponents([.hour, .minute], from: newDate)
                votdRefresh2Hour = c.hour ?? 18
                votdRefresh2Minute = c.minute ?? 0
            }
        )
    }

    var body: some View {
        Form {
            // MARK: Home Layout section
            Section(header: Text("Home Layout"), footer: Text("Reorder or hide sections on the Home page. The title card always stays at the top.").font(.footnote).foregroundStyle(.secondary)) {
                // Reorderable list with toggles
                List {
                    ForEach(layoutOrder) { card in
                        HStack {
                            Label(card.title, systemImage: card.systemImage)
                            Spacer()
                            Toggle(isOn: Binding<Bool>(
                                get: { !hiddenSet.contains(card) },
                                set: { newValue in
                                    if newValue {
                                        hiddenSet.remove(card)
                                    } else {
                                        hiddenSet.insert(card)
                                    }
                                    saveHomeLayout()
                                }
                            )) {
                                EmptyView()
                            }
                            .labelsHidden()
                        }
                        .contentShape(Rectangle())
                    }
                    .onMove { indices, newOffset in
                        layoutOrder.move(fromOffsets: indices, toOffset: newOffset)
                        saveHomeLayout()
                    }
                }
                .environment(\.editMode, .constant(.active)) // always show drag handles
                .frame(minHeight: 44 * CGFloat(layoutOrder.count))
                .listStyle(.insetGrouped)

                Button("Restore Default Order") {
                    layoutOrder = HomeCardID.allCases
                    hiddenSet = []
                    saveHomeLayout()
                }
                .buttonStyle(.bordered)
            }
            .headerProminence(.increased)
            .onAppear(perform: loadHomeLayout)

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
                // Removed the old local "Preview" block so changes apply live to this screen and the app.
            }
            .headerProminence(.increased)

            // Live Activities master toggle
            Section(header: Text("Live Activities"), footer: Text("Show your Prayer Timer, Stopwatch, or Daily Focus on the Lock Screen and Dynamic Island. You can turn this off anytime.").font(.footnote).foregroundStyle(.secondary)) {
                Toggle(isOn: $liveActivitiesEnabled) {
                    Label("Enable Live Activities", systemImage: "livephoto.play")
                }
                .accessibilityIdentifier("liveActivitiesToggle")
            }
            .onChange(of: liveActivitiesEnabled) { _, enabled in
                if !enabled {
                    // Cancel any currently running live activities immediately
                    PrayerTimerActivityController.shared.cancel()
                    StopwatchActivityController.shared.cancel()
                }
            }
            .headerProminence(.increased)

            Section(header: Text("Verse of the Day"), footer: Text("Choose which part of the Bible the Verse of the Day is selected from. You can also set two daily auto-refresh times; the verse will refresh at those times unless paused on the Home page.").font(.footnote).foregroundStyle(.secondary)) {
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
                        UserDefaults.standard.set(0, forKey: "hangmanAllTimeCorrect")
                        UserDefaults.standard.set(0, forKey: "hangmanAllTimeAnswered")
                        UserDefaults.standard.set(0, forKey: "hangmanAllTimeBestStreak")
                        UserDefaults.standard.set(0, forKey: "refmatchAllTimeCorrect")
                        UserDefaults.standard.set(0, forKey: "refmatchAllTimeAnswered")
                        UserDefaults.standard.set(0, forKey: "refmatchAllTimeBestStreak")
                    }
                } message: {
                    Text("Your all-time quiz scores will be reset. Would you like to continue?")
                }
            }
            .headerProminence(.increased)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        // Apply appearance, text size, and font family live to this Settings screen so users see changes instantly
        .preferredColorScheme((ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme)
        .dynamicTypeSize((FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system).dynamicTypeSize ?? .large)
        .modifier(FontFamilyEnvironmentModifier(prefRaw: fontFamilyPreferenceRaw))
        .onAppear {
            loadHomeLayout()
        }
    }

    // MARK: - Existing UI helpers

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

// Helper modifier to apply chosen font family live to the whole Settings screen.
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
