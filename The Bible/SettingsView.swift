import SwiftUI

struct SettingsView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = false
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue

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
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
