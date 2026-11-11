import SwiftUI

struct SettingsView: View {
    @AppStorage(AppStorageKey.colorSchemePreference) private var colorSchemePreferenceRaw: String = "system"
    var body: some View {
        Form {
            SettingsAppLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsReadingAndPrayerLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsNotificationsAndPermissionsSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsDataManagementLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsAboutSection()
                .listRowBackground(HeroCardListRowBackground())

            #if DEBUG
            SettingsDeveloperSection()
                .listRowBackground(HeroCardListRowBackground())
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .defaultScrollAnchor(.top)
        .preferredColorScheme((ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environment(
            CloudKitManager(containerIdentifier: "iCloud.creecy.bible")
        )
}
