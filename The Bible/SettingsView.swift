import SwiftUI
import SwiftData

struct SettingsView: View {
    // Global appearance modifiers still applied at the top level
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue

    // Journal entries for the Tag Manager count (kept in SettingsView)
    @Query private var journalEntries: [JournalEntry]

    var body: some View {
        Form {
            // Sections split into dedicated views
            SettingsVOTDSection()
            SettingsAppearanceSection()
            SettingsTimerSection()
            SettingsDailyGoalSection()
            SettingsLiveActivitiesSection()
            SettingsHomeLayoutSection()

            // Journal Tags manager (kept here)
            Section(header: Text("Journal")) {
                let uniqueCount: Int = {
                    let unique = Set(
                        journalEntries
                            .flatMap { $0.tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() } }
                            .filter { !$0.isEmpty }
                    )
                    return unique.count
                }()

                NavigationLink {
                    TagManagerView()
                } label: {
                    Label("Manage Tags (\(uniqueCount))", systemImage: "tag")
                }
                .accessibilityIdentifier("tagManagerLink")
            }
            .headerProminence(.increased)

            SettingsiCloudSection()
            SettingsResetDataSection()

            #if DEBUG
            SettingsDebugUtilitiesView()
            #endif
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .preferredColorScheme((ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme)
        .dynamicTypeSize((FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system).dynamicTypeSize ?? .large)
        .modifier(FontFamilyEnvironmentModifier(prefRaw: fontFamilyPreferenceRaw))
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
