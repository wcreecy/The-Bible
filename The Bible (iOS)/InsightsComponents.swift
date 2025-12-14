import SwiftUI

struct InsightChipModel: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

struct InsightTile: View {
    let model: InsightChipModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(model.tint.opacity(0.12))
                Image(systemName: model.icon)
                    .foregroundStyle(model.tint)
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.subheadline.weight(.semibold))
                Text(model.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(model.tint.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.title). \(model.detail)")
    }
}
