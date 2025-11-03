import SwiftUI
import Combine

struct SettingsView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue
    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""
    @AppStorage("quizScope") private var quizScopeRaw: String = "whole"
    @AppStorage("quizDifficulty") private var quizDifficulty: String = "easy"
    @AppStorage("timerSoundSelection") private var timerSoundSelection: String = TimerSound.default.rawValue
    @State private var showingResetQuizAlert: Bool = false

    @AppStorage("appTotalActiveSeconds") private var appTotalActiveSeconds: Int = 0
    @AppStorage("appActiveStart") private var appActiveStart: Double = 0
    @State private var liveNowSeconds: Int = 0
    @State private var showResetAppTimeAlert: Bool = false
    @State private var appTimeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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

    var body: some View {
        Form {
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
                    Label("Text Size", systemImage: "textformat.size")
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
                Text("Adjust the overall text size used throughout the app.")
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
            Section(header: Text("Reading"), footer: Text("Keeping the screen on may increase battery usage.")) {
                Toggle(isOn: $keepScreenOn) {
                    Label("Keep Screen On While Reading", systemImage: "display.sleep")
                }
                .accessibilityIdentifier("keepScreenOnToggle")
            }
            .headerProminence(.increased)
            Section(header: Text("Verse of the Day"), footer: Text("Choose which part of the Bible the Verse of the Day is selected from.")) {
                VStack(spacing: 8) {
                    // Custom segmented control with vertical separators
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
                        Picker(selection: $verseSpecificBook) {
                            ForEach(BibleData.books.map { $0.name }, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        } label: {
                            Label("Choose Book", systemImage: "text.book.closed")
                        }
                        .accessibilityIdentifier("verseOfDaySpecificBookPicker")
                    }
                }
            }
            .headerProminence(.increased)
            Section(header: Text("Timer"), footer: Text("Choose the sound that plays when the prayer/study timer finishes.")) {
                Picker(selection: Binding<String>(
                    get: { timerSoundSelection },
                    set: { timerSoundSelection = $0 }
                )) {
                    ForEach(TimerSound.allCases) { sound in
                        Text(sound.title).tag(sound.rawValue)
                    }
                } label: {
                    Label("Timer Sound", systemImage: "speaker.wave.2")
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("timerSoundPicker")
            }
            .headerProminence(.increased)
            Section(header: Text("Quiz Data"), footer: Text("Reset your all-time quiz statistics. This action cannot be undone.")) {
                Button(role: .destructive) {
                    showingResetQuizAlert = true
                } label: {
                    Label("Reset All-time Quiz Stats", systemImage: "trash")
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
                    }
                } message: {
                    Text("Your all-time quiz scores will be reset. Would you like to continue?")
                }
            }
            .headerProminence(.increased)
            Section(header: Text("Time with God (via this app)")) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Time in App", systemImage: "clock")
                        .font(.headline)

                    // Grid of units with labels above numbers styled as flip cards
                    let b = timeBreakdown()
                    let items: [(String, Int)] = [
                        ("Years", b.years),
                        ("Months", b.months),
                        ("Weeks", b.weeks),
                        ("Days", b.days),
                        ("Hours", b.hours),
                        ("Minutes", b.minutes),
                        ("Seconds", b.seconds)
                    ]
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(items, id: \.0) { label, value in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                flipCard(value)
                            }
                        }
                    }
                    .accessibilityIdentifier("appTotalTimeLabel")

                    HStack {
                        Spacer()
                        Label("Reset Time in App", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.red)
                            .onLongPressGesture(minimumDuration: 0.6) {
                                showResetAppTimeAlert = true
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint("Long press to reset time in app")
                            .alert("Reset Time in App?", isPresented: $showResetAppTimeAlert) {
                                Button("Cancel", role: .cancel) {}
                                Button("Reset", role: .destructive) {
                                    appTotalActiveSeconds = 0
                                    appActiveStart = Date().timeIntervalSince1970
                                }
                            } message: {
                                Text("This will reset the total time you've spent in the app.")
                            }
                    }
                }
            }
            .headerProminence(.increased)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .onReceive(appTimeTimer) { _ in
            liveNowSeconds = currentSessionElapsed()
        }
        .onAppear {
            liveNowSeconds = currentSessionElapsed()
        }
    }

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

    private func flipCard(_ value: Int) -> some View {
        Text("\(value)")
            .font(.title3)
            .monospacedDigit()
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 1),
                alignment: .center
            )
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
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
    
    private func currentSessionElapsed() -> Int {
        guard appActiveStart > 0 else { return 0 }
        let start = Date(timeIntervalSince1970: appActiveStart)
        return max(0, Int(Date().timeIntervalSince(start)))
    }

    private func timeBreakdown() -> (years: Int, months: Int, weeks: Int, days: Int, hours: Int, minutes: Int, seconds: Int) {
        let total = appTotalActiveSeconds + liveNowSeconds
        var remaining = total
        let years = remaining / (365 * 24 * 3600); remaining %= (365 * 24 * 3600)
        let months = remaining / (30 * 24 * 3600); remaining %= (30 * 24 * 3600)
        let weeks = remaining / (7 * 24 * 3600); remaining %= (7 * 24 * 3600)
        let days = remaining / (24 * 3600); remaining %= (24 * 3600)
        let hours = remaining / 3600; remaining %= 3600
        let minutes = remaining / 60
        let seconds = remaining % 60
        return (years, months, weeks, days, hours, minutes, seconds)
    }

    private func formattedTotalAppTime() -> String {
        let total = appTotalActiveSeconds + liveNowSeconds
        // Define units: years (365d), months (30d), weeks (7d), days, hours, minutes, seconds
        var remaining = total
        let years = remaining / (365 * 24 * 3600); remaining %= (365 * 24 * 3600)
        let months = remaining / (30 * 24 * 3600); remaining %= (30 * 24 * 3600)
        let weeks = remaining / (7 * 24 * 3600); remaining %= (7 * 24 * 3600)
        let days = remaining / (24 * 3600); remaining %= (24 * 3600)
        let hours = remaining / 3600; remaining %= 3600
        let minutes = remaining / 60
        let seconds = remaining % 60
        // Build human-readable string omitting zero-leading units except to show zeros up to minutes if needed
        var parts: [String] = []
        parts.append("\(years) year\(years == 1 ? "" : "s")")
        parts.append("\(months) month\(months == 1 ? "" : "s")")
        parts.append("\(weeks) week\(weeks == 1 ? "" : "s")")
        parts.append("\(days) day\(days == 1 ? "" : "s")")
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        parts.append("\(seconds) second\(seconds == 1 ? "" : "s")")
        return parts.joined(separator: ", ")
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
