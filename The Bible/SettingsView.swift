import SwiftUI

enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

struct SettingsView: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = ColorSchemePreference.system.rawValue

    private var selectionBinding: Binding<ColorSchemePreference> {
        Binding<ColorSchemePreference>(
            get: { ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system },
            set: { colorSchemePreferenceRaw = $0.rawValue }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Picker("App Appearance", selection: selectionBinding) {
                    ForEach(ColorSchemePreference.allCases) { pref in
                        Text(pref.title).tag(pref)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("appearancePicker")
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
