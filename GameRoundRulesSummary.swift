import SwiftUI

struct GameRoundRule: Identifiable {
    let id: String
    let systemImage: String
    let title: LocalizedStringResource
    let detail: LocalizedStringResource
}

struct GameRoundRulesSummary: View {
    let tint: Color
    let rules: [GameRoundRule]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Round Rules", systemImage: "list.bullet.clipboard")
                .font(.headline)
                .foregroundStyle(tint)

            ForEach(rules) { rule in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: rule.systemImage)
                        .foregroundStyle(tint)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(rule.title)
                            .font(.subheadline.weight(.semibold))
                        Text(rule.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}
