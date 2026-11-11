import SwiftUI

enum GameExperienceLevel: String, CaseIterable, Identifiable {
    case learn
    case standard
    case challenge

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .learn: "Easy"
        case .standard: "Normal"
        case .challenge: "Hard"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .learn: "Untimed practice with guidance."
        case .standard: "The balanced default challenge."
        case .challenge: "Fewer assists and tougher prompts."
        }
    }

    var icon: String {
        switch self {
        case .learn: "lightbulb.fill"
        case .standard: "target"
        case .challenge: "flame.fill"
        }
    }
}

struct GameExperienceDetails {
    let learn: LocalizedStringKey
    let standard: LocalizedStringKey
    let challenge: LocalizedStringKey

    func detail(for level: GameExperienceLevel) -> LocalizedStringKey {
        switch level {
        case .learn: learn
        case .standard: standard
        case .challenge: challenge
        }
    }
}

/// The one place on each game lobby where players choose its difficulty: a
/// segmented control with a single line explaining the selected level.
struct GameExperienceCompactPicker: View {
    let tint: Color
    @Binding var selection: GameExperienceLevel
    let details: GameExperienceDetails?
    let title: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(title, selection: $selection) {
                ForEach(GameExperienceLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel(title)

            Label {
                Text(details?.detail(for: selection) ?? selection.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: selection.icon)
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
