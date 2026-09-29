import SwiftUI

struct ContextualTipView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .font(.title3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}
