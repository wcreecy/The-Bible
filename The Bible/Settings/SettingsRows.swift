import SwiftUI

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
