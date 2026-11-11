import SwiftUI

struct SettingsAppearanceDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Appearance") {
            SettingsAppearanceSection()
            SettingsBackgroundSection()
        }
    }
}

struct SettingsLaunchTabDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Launch Page") {
            SettingsLaunchTabSection()
        }
    }
}

struct SettingsBibleReaderDetailView: View {
    let highlightFocusReading: Bool

    init(highlightFocusReading: Bool = false) {
        self.highlightFocusReading = highlightFocusReading
    }

    var body: some View {
        SettingsDetailForm(title: "Bible Reader") {
            SettingsReadingProgressSection(highlightFocusReading: highlightFocusReading)
        }
    }
}

struct SettingsVerseOfTheDayDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Verse of the Day") {
            SettingsVOTDSection()
        }
    }
}

struct SettingsDailyGoalDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Daily Goal") {
            SettingsDailyGoalSection()
        }
    }
}

struct SettingsTimerDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Prayer & Study Timer") {
            SettingsTimerSection()
            SettingsPrayerTimerAccessSection()
        }
    }
}

struct SettingsNotificationsDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Notifications") {
            SettingsNotificationsSection()
        }
    }
}

struct SettingsPermissionsDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Permissions") {
            SettingsPermissionsSection()
        }
    }
}

struct SettingsiCloudDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "iCloud Sync") {
            SettingsiCloudSection()
        }
    }
}

struct SettingsResetDataDetailView: View {
    var body: some View {
        SettingsDetailForm(title: "Reset Data") {
            SettingsResetDataSection()
        }
    }
}

struct SettingsDetailForm<Content: View>: View {
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
