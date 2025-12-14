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

    // Keep HomeCardID nested so HomeLayoutEditorView can reference SettingsView.HomeCardID
    enum HomeCardID: String, CaseIterable, Identifiable, Codable, Hashable {
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
}

#Preview {
    NavigationStack { SettingsView() }
}
