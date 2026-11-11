import SwiftUI

struct GameStartScreenStyle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? 980 : 620)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 24)
    }
}

struct GameStartDescriptionStyle: ViewModifier {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color

    func body(content: Content) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: tint.opacity(0.2), radius: 8, y: 4)

                Text(title)
                    .font(.title.weight(.bold))
                    .fontDesign(.rounded)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            content
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 520, alignment: .leading)
        }
        .padding(.top, 4)
    }
}

struct GameStartActionBar: View {
    let title: LocalizedStringKey
    let tint: Color?
    let isEnabled: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringKey = "Start Game",
        tint: Color? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.tint = tint
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .controlSize(.large)
        .tint(tint)
        .disabled(!isEnabled)
    }
}

struct GameSplashLaunchLayout<Preview: View, Configuration: View, Facts: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let tint: Color
    let experienceLevel: Binding<GameExperienceLevel>?
    let experienceDetails: GameExperienceDetails?
    let experienceTitle: LocalizedStringKey
    let isConfigurationEnabled: Bool
    let isStartEnabled: Bool
    /// The start button's label, e.g. "Resume" when an unfinished round is waiting.
    let startTitle: LocalizedStringKey
    let startSubtitle: LocalizedStringKey
    let startAction: () -> Void
    @ViewBuilder let preview: Preview
    @ViewBuilder let configuration: Configuration
    @ViewBuilder let facts: Facts

    init(
        tint: Color,
        experienceLevel: Binding<GameExperienceLevel>? = nil,
        experienceDetails: GameExperienceDetails? = nil,
        experienceTitle: LocalizedStringKey = "How you’ll play",
        isConfigurationEnabled: Bool = true,
        isStartEnabled: Bool = true,
        startTitle: LocalizedStringKey = "Start Game",
        startSubtitle: LocalizedStringKey = "Begin your challenge.",
        startAction: @escaping () -> Void,
        @ViewBuilder preview: () -> Preview,
        @ViewBuilder configuration: () -> Configuration,
        @ViewBuilder facts: () -> Facts
    ) {
        self.tint = tint
        self.experienceLevel = experienceLevel
        self.experienceDetails = experienceDetails
        self.experienceTitle = experienceTitle
        self.isConfigurationEnabled = isConfigurationEnabled
        self.isStartEnabled = isStartEnabled
        self.startTitle = startTitle
        self.startSubtitle = startSubtitle
        self.startAction = startAction
        self.preview = preview()
        self.configuration = configuration()
        self.facts = facts()
    }

    var body: some View {
        VStack(spacing: 12) {
            preview

            if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 16) {
                    GameSplashConfigurationCard(minimumHeight: 360) {
                        if let experienceLevel {
                            GameExperienceCompactPicker(
                                tint: tint,
                                selection: experienceLevel,
                                details: experienceDetails,
                                title: experienceTitle
                            )
                        }
                        configuration
                            .disabled(!isConfigurationEnabled)
                        facts
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GameSplashStartButton(
                        tint: tint,
                        isEnabled: isStartEnabled,
                        title: startTitle,
                        subtitle: startSubtitle,
                        action: startAction
                    )
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 360)
                }
            } else {
                // Phone layout: everything the player touches sits above the fold, with
                // Start directly under the settings instead of behind a disclosure.
                VStack(spacing: 16) {
                    facts

                    if let experienceLevel {
                        GameExperienceCompactPicker(
                            tint: tint,
                            selection: experienceLevel,
                            details: experienceDetails,
                            title: experienceTitle
                        )
                    }

                    configuration
                        .disabled(!isConfigurationEnabled)

                    GameStartActionBar(startTitle, tint: tint, isEnabled: isStartEnabled, action: startAction)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct GameSplashConfigurationCard<Content: View>: View {
    let minimumHeight: CGFloat?
    @ViewBuilder let content: Content

    init(
        minimumHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.minimumHeight = minimumHeight
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            minHeight: minimumHeight,
            alignment: .topLeading
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

struct GameSplashStartButton: View {
    let tint: Color
    let isEnabled: Bool
    var title: LocalizedStringKey = "Start Game"
    var subtitle: LocalizedStringKey = "Begin your challenge."
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.largeTitle)
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(tint.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
    }
}

struct GameSplashFacts: View {
    typealias Fact = (icon: String, value: String, label: String)

    let first: Fact
    let second: Fact
    let third: Fact
    let fourth: Fact?

    init(first: Fact, second: Fact, third: Fact, fourth: Fact? = nil) {
        self.first = first
        self.second = second
        self.third = third
        self.fourth = fourth
    }

    var body: some View {
        // One flat strip with hairline dividers instead of three separate tiles.
        HStack(spacing: 0) {
            fact(first)
            Divider().padding(.vertical, 8)
            fact(second)
            Divider().padding(.vertical, 8)
            fact(third)
            if let fourth {
                Divider().padding(.vertical, 8)
                fact(fourth)
            }
        }
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func fact(_ fact: Fact) -> some View {
        VStack(spacing: 3) {
            Text(fact.value)
                .font(.headline)
                .fontDesign(.rounded)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(fact.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }
}

struct GameStartMultiPickerCard<Value: Hashable, OptionLabel: View>: View {
    let title: LocalizedStringKey
    let tint: Color
    @Binding var selection: Set<Value>
    let options: [Value]
    @ViewBuilder let label: (Value) -> OptionLabel

    @State private var isExpanded = false

    init(
        title: LocalizedStringKey,
        tint: Color = .accentColor,
        selection: Binding<Set<Value>>,
        options: [Value],
        @ViewBuilder label: @escaping (Value) -> OptionLabel
    ) {
        self.title = title
        self.tint = tint
        _selection = selection
        self.options = options
        self.label = label
    }

    var body: some View {
        // A settings row that expands in place into a plain checklist.
        VStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    GameSettingBadge(systemImage: "square.grid.2x2.fill", tint: tint)

                    Text(title)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Text(selection.count == options.count ? "All" : "\(selection.count) selected")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.contains(option)
                    Divider().padding(.leading, 56)
                    Button {
                        if isSelected {
                            guard selection.count > 1 else { return }
                            selection.remove(option)
                        } else {
                            selection.insert(option)
                        }
                    } label: {
                        HStack(spacing: 12) {
                            label(option)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(tint)
                                .opacity(isSelected ? 1 : 0)
                        }
                        .padding(.leading, 56)
                        .padding(.trailing, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func gameStartScreenStyle() -> some View {
        modifier(GameStartScreenStyle())
    }

    func gameStartDescriptionStyle(
        title: LocalizedStringKey,
        systemImage: String = "gamecontroller.fill",
        tint: Color = .accentColor
    ) -> some View {
        modifier(GameStartDescriptionStyle(title: title, systemImage: systemImage, tint: tint))
    }

}
