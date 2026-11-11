import SwiftUI

struct SettingsAppearanceSection: View {
    @AppStorage(AppStorageKey.colorSchemePreference) private var colorSchemePreferenceRaw: String = ColorSchemePreference.system.rawValue

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("App Appearance", systemImage: "paintbrush")
                Picker("App Appearance", selection: $colorSchemePreferenceRaw) {
                    ForEach(ColorSchemePreference.allCases) { preference in
                        Text(preference.title).tag(preference.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("appearancePicker")
            }
        } header: {
            Text("Appearance")
                .foregroundStyle(.primary)
        } footer: {
            Text("Choose Light, Dark, or follow the System setting for the app's appearance.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .headerProminence(.increased)
    }
}
