import SwiftUI

struct SettingsView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue
    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"
    @AppStorage("verseOfDaySpecificBook") private var verseSpecificBook: String = ""

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
                Picker(selection: selectionBinding) {
                    ForEach(ColorSchemePreference.allCases) { pref in
                        Text(pref.title).tag(pref)
                    }
                } label: {
                    Label("App Appearance", systemImage: "paintbrush")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("appearancePicker")
                Text("Choose Light, Dark, or follow the System setting for the app's appearance.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Picker(selection: fontSizeBinding) {
                    ForEach(FontSizePreference.allCases) { pref in
                        Text(pref.title).tag(pref)
                    }
                } label: {
                    Label("Text Size", systemImage: "textformat.size")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("textSizePicker")
                Text("Adjust the overall text size used throughout the app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Picker(selection: fontFamilyBinding) {
                    ForEach(FontFamilyPreference.allCases) { pref in
                        Text(pref.title).tag(pref)
                    }
                } label: {
                    Label("Font", systemImage: "textformat")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("fontFamilyPicker")
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

    private func verticalSeparator() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 1, height: 24)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
