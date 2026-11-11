import SwiftUI

/// A tinted, rounded icon used at the leading edge of every settings row.
struct GameSettingBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// An inset, rounded container that stacks settings rows and separates them with hairlines.
struct GameSettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(subviews.indices, id: \.self) { index in
                    if index > 0 {
                        Divider().padding(.leading, 56)
                    }
                    subviews[index]
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// One selectable value in a `GameChoiceSetting`.
struct GameChoice<Value: Hashable>: Identifiable {
    let value: Value
    let title: LocalizedStringResource
    var detail: LocalizedStringResource?
    var icon: String
    var isEnabled = true

    var id: Value { value }
}

/// A single settings row that shows the current choice and opens a menu to change it.
struct GameChoiceSetting<Value: Hashable>: View {
    let title: LocalizedStringResource
    let systemImage: String
    let tint: Color
    @Binding var selection: Value
    let choices: [GameChoice<Value>]
    /// Shown as the value when `selection` matches none of the choices, such as a custom category mix.
    var fallbackValue: LocalizedStringResource?

    private var selected: GameChoice<Value>? {
        choices.first { $0.value == selection }
    }

    private var titleColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            if let detail = selected?.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var valueLabel: some View {
        HStack(spacing: 4) {
            if let selected {
                Text(selected.title)
            } else if let fallbackValue {
                Text(fallbackValue)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .font(.body)
        .foregroundStyle(.secondary)
    }

    var body: some View {
        Menu {
            Picker(selection: $selection) {
                ForEach(choices) { choice in
                    Label {
                        Text(choice.title)
                    } icon: {
                        Image(systemName: choice.icon)
                    }
                    .tag(choice.value)
                    .disabled(!choice.isEnabled)
                }
            } label: {
                Text(title)
            }
        } label: {
            // Side by side when it fits. At large text sizes the title and the chosen value
            // can't share a line, so the value drops underneath instead of widening the row.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    GameSettingBadge(systemImage: selected?.icon ?? systemImage, tint: tint)
                    titleColumn
                    Spacer(minLength: 8)
                    valueLabel
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        GameSettingBadge(systemImage: selected?.icon ?? systemImage, tint: tint)
                        titleColumn
                    }
                    valueLabel
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

/// A settings row with an on/off switch and an optional one-line explanation.
struct GameToggleSetting: View {
    let title: LocalizedStringResource
    var detail: LocalizedStringResource?
    let systemImage: String
    let tint: Color
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                GameSettingBadge(systemImage: systemImage, tint: tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .tint(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
