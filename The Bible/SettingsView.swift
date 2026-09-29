import SwiftUI

struct SettingsView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue

    var body: some View {
        Form {
            SettingsPersonalizationLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsDailyExperienceLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsReadingProgressSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsAppAndDataLinksSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsTipsSection()
                .listRowBackground(HeroCardListRowBackground())
            SettingsDataManagementLinksSection()
                .listRowBackground(HeroCardListRowBackground())

            Section {
                SettingsCloudSyncFooter()
                    .listRowBackground(HeroCardListRowBackground())
                    .listRowSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .defaultScrollAnchor(.top)
        .preferredColorScheme((ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system).colorScheme)
        .modifier(FontFamilyEnvironmentModifier(prefRaw: fontFamilyPreferenceRaw))
    }
}

private struct SettingsPersonalizationLinksSection: View {
    var body: some View {
        Section("Personalization") {
            NavigationLink {
                SettingsAppearanceDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Appearance",
                    subtitle: "Theme, text, fonts, and Home background",
                    systemImage: "paintbrush"
                )
            }

            NavigationLink {
                SettingsHomeLayoutDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Home Layout",
                    subtitle: "Choose what appears on Home",
                    systemImage: "rectangle.grid.1x2"
                )
            }
        }
    }
}

private struct SettingsDailyExperienceLinksSection: View {
    var body: some View {
        Section("Daily Experience") {
            NavigationLink {
                SettingsVerseOfTheDayDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Verse of the Day",
                    subtitle: "Source, refresh schedule, and notifications",
                    systemImage: "book.pages"
                )
            }

            NavigationLink {
                SettingsDailyGoalDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Daily Goal",
                    subtitle: "Set your daily reading target",
                    systemImage: "target"
                )
            }

            NavigationLink {
                SettingsTimerDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Timer & Sounds",
                    subtitle: "Choose the timer completion sound",
                    systemImage: "timer"
                )
            }
        }
    }
}

private struct SettingsReadingProgressSection: View {
    @AppStorage("showReadVerseCheckmarks") private var showReadVerseCheckmarks = false

    var body: some View {
        Section {
            Toggle(isOn: $showReadVerseCheckmarks) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Read Verse Checkmarks")
                        Text("Show a green checkmark on verses you have read")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
            .accessibilityIdentifier("readVerseCheckmarksToggle")
        } header: {
            Text("Bible Reader")
        } footer: {
            Text("Checkmarks reflect your reading progress and disappear when reading statistics are reset.")
        }
    }
}

private struct SettingsAppAndDataLinksSection: View {
    var body: some View {
        Section("App & Data") {
            NavigationLink {
                SettingsPermissionsDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Permissions & Access",
                    subtitle: "Notifications, Health, and Live Activities",
                    systemImage: "hand.raised"
                )
            }

            NavigationLink {
                SettingsiCloudDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "iCloud Sync",
                    subtitle: "Account status and sync details",
                    systemImage: "icloud"
                )
            }
        }
    }
}

private struct SettingsTipsSection: View {
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    var body: some View {
        Section {
            Toggle(isOn: $contextualTipsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Contextual Tips")
                        Text("Show helpful hints while exploring features")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(.tint)
                }
            }
            .accessibilityIdentifier("contextualTipsToggle")
        } header: {
            Text("Help")
        } footer: {
            Text("Tips appear near features such as verse actions, widgets, timers, Health, and Home customization.")
        }
    }
}

private struct SettingsDataManagementLinksSection: View {
    var body: some View {
        Section("Data Management") {
            NavigationLink {
                SettingsResetDataDetailView()
            } label: {
                SettingsNavigationRow(
                    title: "Reset Data",
                    subtitle: "Reset game or reading statistics",
                    systemImage: "trash"
                )
            }
        }
    }
}

private struct SettingsNavigationRow: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
    }
}

private struct SettingsCloudSyncFooter: View {
    @EnvironmentObject private var cloudKitManager: CloudKitManager
    @State private var lastSyncActivity: Date?

    var body: some View {
        VStack(spacing: 4) {
            Label(iCloudStatusText, systemImage: "icloud")
            if let lastSyncActivity {
                Text("Last sync activity: \(lastSyncActivity, format: .dateTime.month(.abbreviated).day().year().hour().minute())")
                    .accessibilityIdentifier("settingsLastSyncActivity")
            } else {
                Text("No sync activity yet")
                    .accessibilityIdentifier("settingsLastSyncActivity")
            }
        }
        .frame(maxWidth: .infinity)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .task {
            updateLastSyncActivity()
            for await _ in NotificationCenter.default.notifications(
                named: UserDefaults.didChangeNotification
            ) {
                updateLastSyncActivity()
            }
        }
    }

    private var iCloudStatusText: LocalizedStringResource {
        switch cloudKitManager.accountState {
        case .available: "iCloud available"
        case .noAccount: "No iCloud account"
        case .restricted: "iCloud restricted"
        case .couldNotDetermine: "iCloud unavailable"
        case .unknown: "iCloud status unknown"
        }
    }

    private func updateLastSyncActivity() {
        let coordinator = iCloudSyncCoordinator.shared
        lastSyncActivity = [coordinator.lastPushDate, coordinator.lastMergeDate]
            .compactMap { $0 }
            .max()
    }
}

private struct SettingsAppearanceDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Appearance") {
            SettingsAppearanceSection()
            SettingsBackgroundSection()
        }
    }
}

private struct SettingsHomeLayoutDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Home Layout") {
            SettingsHomeLayoutSection()
        }
    }
}

private struct SettingsVerseOfTheDayDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Verse of the Day") {
            SettingsVOTDSection()
        }
    }
}

private struct SettingsDailyGoalDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Daily Goal") {
            SettingsDailyGoalSection()
        }
    }
}

private struct SettingsTimerDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Timer & Sounds") {
            SettingsTimerSection()
        }
    }
}

private struct SettingsPermissionsDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Permissions & Access") {
            SettingsPermissionsSection()
        }
    }
}

private struct SettingsiCloudDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "iCloud Sync") {
            SettingsiCloudSection()
        }
    }
}

private struct SettingsResetDataDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Reset Data") {
            SettingsResetDataSection()
        }
    }
}

private struct SettingsDetailForm<Content: View>: View {
    let title: LocalizedStringResource
    let content: Content

    init(
        title: LocalizedStringResource,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        Form {
            content
                .listRowBackground(HeroCardListRowBackground())
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .more))
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
        .defaultScrollAnchor(.top)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(
            CloudKitManager(containerIdentifier: "iCloud.creecy.bible")
        )
}
