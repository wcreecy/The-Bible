import SwiftUI

struct SettingsView: View {
    // Global appearance modifiers still applied at the top level
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue

    var body: some View {
        ZStack {
            AppBackgroundView(tab: .more, defaultImageName: "blackleather")

            Form {
                // Sections split into dedicated views
                SettingsVOTDSection()
                SettingsAppearanceSection()
                SettingsBackgroundSection()
                SettingsTimerSection()
                SettingsDailyGoalSection()
                SettingsLiveActivitiesSection()
                SettingsHomeLayoutSection()

                SettingsiCloudSection()
                SettingsResetDataSection()

                #if DEBUG
                SettingsDebugUtilitiesView()
                #endif
            }
            .scrollContentBackground(.hidden)   // hide Form’s default background
            .background(Color.clear)            // keep it transparent
            .listRowBackground(Color.clear)     // rows float above the image
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .preferredColorScheme((ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme)
        .modifier(FontFamilyEnvironmentModifier(prefRaw: fontFamilyPreferenceRaw))
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
