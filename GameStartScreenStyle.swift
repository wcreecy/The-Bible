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

// MARK: - Settings rows

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
            HStack(spacing: 12) {
                GameSettingBadge(systemImage: selected?.icon ?? systemImage, tint: tint)

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

                Spacer(minLength: 8)

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

struct GameSplashLaunchLayout<Preview: View, Configuration: View, Facts: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let tint: Color
    let experienceLevel: Binding<GameExperienceLevel>?
    let experienceDetails: GameExperienceDetails?
    let experienceTitle: LocalizedStringKey
    let isConfigurationEnabled: Bool
    let isStartEnabled: Bool
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

                    GameStartActionBar(tint: tint, isEnabled: isStartEnabled, action: startAction)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.largeTitle)
                Text("Start Game")
                    .font(.title2.weight(.semibold))
                Text("Begin your challenge.")
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
        .accessibilityLabel("Start Game")
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

enum GameLobbyPreviewKind {
    case quiz
    case hangman
    case beatTheClock
    case verseMatch
    case bookOrder
    case wordSearch
    case scramble
    case whoAmI
    case wordle
    case trivia
}

struct GameLobbyPreview: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let kind: GameLobbyPreviewKind
    var bookOrderBooks: [String] = ["Genesis", "Exodus", "Leviticus"]

    var body: some View {
        if horizontalSizeClass == .regular {
            GroupBox("Game Preview") {
                preview
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 180)
            }
            .padding(.horizontal)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch kind {
        case .quiz:
            HStack(spacing: 24) {
                previewPrompt(icon: "text.quote", title: "For God so loved the world…", subtitle: "Which book is this from?")
                VStack(spacing: 8) {
                    previewChoice("Matthew")
                    previewChoice("John", selected: true)
                    previewChoice("Romans")
                }
            }
        case .hangman:
            HStack(spacing: 36) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 62, weight: .light))
                    .foregroundStyle(.teal)
                VStack(spacing: 18) {
                    Text("_  _  _  _  _")
                        .font(.title.weight(.bold).monospaced())
                    Text("A   E   I   O   U")
                        .font(.headline.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        case .beatTheClock:
            HStack(spacing: 30) {
                ZStack {
                    Circle().stroke(Color.indigo.opacity(0.18), lineWidth: 12)
                    Circle().trim(from: 0, to: 0.68).stroke(Color.indigo, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text("15").font(.title.bold().monospacedDigit())
                }
                .frame(width: 96, height: 96)
                previewPrompt(icon: "person.fill", title: "Moses", subtitle: "Name a book that mentions this person")
            }
        case .verseMatch:
            HStack(spacing: 24) {
                previewPrompt(icon: "bookmark.fill", title: "Psalm 23:1", subtitle: "Choose the matching verse")
                VStack(spacing: 8) {
                    previewChoice("The Lord is my shepherd…", selected: true)
                    previewChoice("In the beginning…")
                    previewChoice("Rejoice evermore.")
                }
            }
        case .bookOrder:
            VStack(spacing: 7) {
                ForEach(Array(bookOrderBooks.prefix(3).enumerated()), id: \.offset) { index, bookName in
                    previewOrderRow("\(index + 1)", bookName)
                }
            }
            .frame(maxWidth: 400)
        case .wordSearch:
            VStack(spacing: 4) {
                ForEach(["F A I T H", "G R A C E", "P E A C E", "L O V E S", "H O P E R"], id: \.self) { row in
                    Text(row)
                        .font(.headline.monospaced().weight(.semibold))
                        .foregroundStyle(row == "G R A C E" ? .green : .primary)
                        .padding(.horizontal, 10)
                        .background(row == "G R A C E" ? Color.green.opacity(0.14) : .clear, in: Capsule())
                }
            }
        case .scramble:
            HStack(spacing: 24) {
                previewPrompt(icon: "text.line.first.and.arrowtriangle.forward", title: "H E S O J P", subtitle: "Unscramble the Bible word")
                Text("JOSEPH")
                    .font(.title2.weight(.bold).monospaced())
                    .foregroundStyle(.pink)
            }
        case .whoAmI:
            HStack(spacing: 24) {
                previewPrompt(icon: "person.crop.circle.fill", title: "Who?", subtitle: "I built an ark before the flood.")
                VStack(spacing: 8) {
                    previewChoice("Abraham")
                    previewChoice("Noah", selected: true)
                    previewChoice("Moses")
                }
            }
        case .wordle:
            VStack(spacing: 6) {
                wordleRow(["G", "R", "A", "C", "E"], colors: [.green, .secondary, .yellow, .secondary, .green])
                wordleRow(["F", "A", "I", "T", "H"], colors: Array(repeating: .secondary, count: 5))
                wordleRow(["", "", "", "", ""], colors: Array(repeating: .secondary, count: 5))
            }
        case .trivia:
            HStack(spacing: 24) {
                previewPrompt(icon: "questionmark.text.page.fill", title: "Who built the ark?", subtitle: "Choose the correct answer")
                VStack(spacing: 8) {
                    previewChoice("Abraham")
                    previewChoice("Noah", selected: true)
                    previewChoice("Moses")
                }
            }
        }
    }

    private func previewPrompt(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.tint)
            Text(title).font(.headline).multilineTextAlignment(.center)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: 310)
    }

    private func previewChoice(_ title: String, selected: Bool = false) -> some View {
        HStack {
            Text(title).lineLimit(1)
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
        }
        .font(.subheadline.weight(selected ? .semibold : .regular))
        .foregroundStyle(selected ? Color.accentColor : Color.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
        .frame(maxWidth: 330)
    }

    private func previewCard(rotation: Double, offset: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(color)
            .frame(width: 280, height: 118)
            .rotationEffect(.degrees(rotation))
            .offset(x: offset)
    }

    private func previewOrderRow(_ number: String, _ title: String) -> some View {
        HStack {
            Text(number).font(.caption.bold()).foregroundStyle(.secondary).frame(width: 24)
            Text(title).font(.headline)
            Spacer()
            Image(systemName: "line.3.horizontal").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func wordleRow(_ letters: [String], colors: [Color]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                Text(letter)
                    .font(.headline.bold())
                    .foregroundStyle(letter.isEmpty ? Color.primary : .white)
                    .frame(width: 38, height: 38)
                    .background(letter.isEmpty ? Color.clear : colors[index], in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.35)))
            }
        }
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
