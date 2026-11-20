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
        GameSegmentedSetting(
            title: Text(title),
            tint: tint,
            selection: $selection,
            options: GameExperienceLevel.allCases,
            label: { Text($0.title) },
            detail: { Text(details?.detail(for: $0) ?? $0.detail) },
            icon: \.icon
        )
    }
}

/// A game's one-tap setting: difficulty, or another short choice people change often (such as
/// WORD's Daily or Practice). Every option shows in a segmented control, with the chosen one's
/// description underneath. Everything else on a start screen uses a list picker
/// (`GameChoiceSetting`) to stay tidy.
///
/// At accessibility text sizes the segment labels would be cut off, so it becomes a list
/// picker row instead.
struct GameSegmentedSetting<Value: Hashable>: View {
    let title: Text
    let tint: Color
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> Text
    let detail: (Value) -> Text?
    let icon: (Value) -> String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            listPicker
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Picker(selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        label(option).tag(option)
                    }
                } label: {
                    title
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel(title)

                if let detail = detail(selection) {
                    Label {
                        detail
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: icon(selection))
                            .foregroundStyle(tint)
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// The same choice as a settings row that opens a menu, for large text.
    private var listPicker: some View {
        GameSettingsGroup {
            Menu {
                Picker(selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Label { label(option) } icon: { Image(systemName: icon(option)) }
                            .tag(option)
                    }
                } label: {
                    title
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        GameSettingBadge(systemImage: icon(selection), tint: tint)
                        title
                            .foregroundStyle(.primary)
                    }
                    HStack(spacing: 4) {
                        label(selection)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.leading, 42)
                    if let detail = detail(selection) {
                        detail
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 42)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
        }
    }
}
