import SwiftUI

struct SettingsAppearanceSection: View {
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw: String = "system"
    @AppStorage("fontSizePreference") private var fontSizePreferenceRaw: String = FontSizePreference.system.rawValue
    @AppStorage("fontFamilyPreference") private var fontFamilyPreferenceRaw: String = FontFamilyPreference.system.rawValue

    var body: some View {
        Section(header: Text("Appearance").foregroundStyle(.white)) {
            VStack(alignment: .leading, spacing: 8) {
                Label("App Appearance", systemImage: "paintbrush")
                HStack(spacing: 0) {
                    appearanceSegmentButton(.system)
                    verticalSeparator()
                    appearanceSegmentButton(.light)
                    verticalSeparator()
                    appearanceSegmentButton(.dark)
                }
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .accessibilityIdentifier("appearancePicker")
            }
            Text("Choose Light, Dark, or follow the System setting for the app's appearance.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("App Text Size", systemImage: "textformat.size")
                HStack(spacing: 0) {
                    fontSizeSegmentButton(.system)
                    verticalSeparator()
                    fontSizeSegmentButton(.small)
                    verticalSeparator()
                    fontSizeSegmentButton(.medium)
                    verticalSeparator()
                    fontSizeSegmentButton(.large)
                    verticalSeparator()
                    fontSizeSegmentButton(.extraLarge)
                }
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .accessibilityIdentifier("textSizePicker")
            }
            Text("This affects all app UI. Bible text size is controlled in the Reader.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                Label("Font", systemImage: "textformat")
                HStack(spacing: 0) {
                    fontFamilySegmentButton(.system)
                    verticalSeparator()
                    fontFamilySegmentButton(.serif)
                    verticalSeparator()
                    fontFamilySegmentButton(.rounded)
                    verticalSeparator()
                    fontFamilySegmentButton(.monospaced)
                    verticalSeparator()
                    fontFamilySegmentButton(.georgia)
                }
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
                )
                .accessibilityIdentifier("fontFamilyPicker")
            }
            Text("Choose an easy-to-read typeface for the interface and reading.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .headerProminence(.increased)
    }

    private func verticalSeparator() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 1, height: 24)
    }

    private func appearanceSegmentButton(_ pref: ColorSchemePreference) -> some View {
        let isSelected = (ColorSchemePreference(rawValue: colorSchemePreferenceRaw) ?? .system) == pref
        return Button(action: { colorSchemePreferenceRaw = pref.rawValue }) {
            Text(pref.title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func fontSizeSegmentButton(_ pref: FontSizePreference) -> some View {
        let isSelected = (FontSizePreference(rawValue: fontSizePreferenceRaw) ?? .system) == pref
        return Button(action: { fontSizePreferenceRaw = pref.rawValue }) {
            Text(pref.title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    private func fontFamilySegmentButton(_ pref: FontFamilyPreference) -> some View {
        let isSelected = (FontFamilyPreference(rawValue: fontFamilyPreferenceRaw) ?? .system) == pref
        return Button(action: { fontFamilyPreferenceRaw = pref.rawValue }) {
            Text(pref.title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
