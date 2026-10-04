import SwiftUI

struct SettingsLaunchTabSection: View {
    @AppStorage(LaunchTabPreference.defaultsKey) private var selection = LaunchTabPreference.home.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Launch Page", selection: $selection) {
                    ForEach(LaunchTabPreference.allCases) { page in
                        Text(page.title).tag(page.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .accessibilityIdentifier("launchPagePicker")
            } header: {
                Text("Launch Page")
            } footer: {
                Text("This choice applies only to this device and only when the app launches. It does not affect navigation while the app is already open.")
            }
        }
        .navigationTitle("Launch Page")
        .navigationBarTitleDisplayMode(.inline)
        .formStyle(.grouped)
    }
}
