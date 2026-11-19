import SwiftUI

/// Lays a settings label out as an icon column beside its text. A list's default label style
/// lets a multi-line subtitle wrap back under the icon at large text sizes.
struct SettingsRowLabelStyle: LabelStyle {
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            configuration.icon
                .frame(width: iconWidth)
            configuration.title
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension LabelStyle where Self == SettingsRowLabelStyle {
    static var settingsRow: SettingsRowLabelStyle { SettingsRowLabelStyle() }
}

struct SettingsNavigationRow: View {
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
        .labelStyle(.settingsRow)
    }
}

/// A settings row that opens a web page or the App Store outside the app.
struct SettingsExternalLinkRow: View {
    let url: URL
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let systemImage: String

    var body: some View {
        Link(destination: url) {
            HStack {
                SettingsNavigationRow(title: title, subtitle: subtitle, systemImage: systemImage)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityAddTraits(.isLink)
    }
}
