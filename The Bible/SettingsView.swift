import SwiftUI

struct SettingsView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue
    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""
    @AppStorage("quizScope") private var quizScopeRaw: String = "whole"
    @State private var showingResetQuizAlert: Bool = false

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
            Section(header: Text("Quiz"), footer: Text("Choose which part of the Bible quiz questions are selected from.")) {
                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        quizSegmentButton(title: "OT", tag: "old")
                        verticalSeparator()
                        quizSegmentButton(title: "NT", tag: "new")
                        verticalSeparator()
                        quizSegmentButton(title: "OT/NT", tag: "whole")
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
                    .accessibilityIdentifier("quizScopePicker")
                }
            }
            Section(header: Text("Quiz Data"), footer: Text("Reset your all-time quiz statistics. This action cannot be undone.")) {
                Button(role: .destructive) {
                    showingResetQuizAlert = true
                } label: {
                    Label("Reset All-time Quiz Stats", systemImage: "trash")
                }
                .alert("Reset All-time Stats?", isPresented: $showingResetQuizAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) {
                        UserDefaults.standard.set(0, forKey: "quizAllTimeCorrect")
                        UserDefaults.standard.set(0, forKey: "quizAllTimeAnswered")
                        UserDefaults.standard.set(0, forKey: "quizAllTimeBestStreak")
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

    private func quizSegmentButton(title: String, tag: String) -> some View {
        Button(action: { quizScopeRaw = tag }) {
            Text(title)
                .font(.subheadline)
                .fontWeight(quizScopeRaw == tag ? .semibold : .regular)
                .foregroundStyle(quizScopeRaw == tag ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if quizScopeRaw == tag {
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

#Preview {
    NavigationStack { SettingsView() }
}
