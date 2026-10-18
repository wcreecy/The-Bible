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
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(tint.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: tint.opacity(0.24), radius: 12, y: 7)

                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .multilineTextAlignment(.leading)
            }
            .accessibilityElement(children: .combine)

            content
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .padding(.top, 8)
    }
}

struct GameStartActionBar: View {
    let title: LocalizedStringKey
    let isEnabled: Bool
    let action: () -> Void

    init(
        _ title: LocalizedStringKey = "Start Game",
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
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
        .disabled(!isEnabled)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

enum GameExperienceLevel: String, CaseIterable, Identifiable {
    case learn
    case standard
    case challenge

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .learn: "Learn"
        case .standard: "Standard"
        case .challenge: "Challenge"
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

struct GameSplashLaunchLayout<Preview: View, Configuration: View, Facts: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let tint: Color
    let experienceLevel: Binding<GameExperienceLevel>?
    let isStartEnabled: Bool
    let startAction: () -> Void
    @ViewBuilder let preview: Preview
    @ViewBuilder let configuration: Configuration
    @ViewBuilder let facts: Facts

    init(
        tint: Color,
        experienceLevel: Binding<GameExperienceLevel>? = nil,
        isStartEnabled: Bool = true,
        startAction: @escaping () -> Void,
        @ViewBuilder preview: () -> Preview,
        @ViewBuilder configuration: () -> Configuration,
        @ViewBuilder facts: () -> Facts
    ) {
        self.tint = tint
        self.experienceLevel = experienceLevel
        self.isStartEnabled = isStartEnabled
        self.startAction = startAction
        self.preview = preview()
        self.configuration = configuration()
        self.facts = facts()
    }

    var body: some View {
        VStack(spacing: 16) {
            preview

            if horizontalSizeClass == .regular {
                HStack(alignment: .top, spacing: 16) {
                    GameSplashConfigurationCard(minimumHeight: 360) {
                        if let experienceLevel {
                            GameExperienceStandardsCard(tint: tint, selection: experienceLevel)
                        }
                        configuration
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
                GameSplashConfigurationCard {
                    if let experienceLevel {
                        GameExperienceStandardsCard(tint: tint, selection: experienceLevel)
                    }
                    configuration
                    facts
                }

                GameStartActionBar(isEnabled: isStartEnabled, action: startAction)
            }
        }
    }
}

/// The one place on each supported game lobby where players choose its difficulty.
struct GameExperienceStandardsCard: View {
    let tint: Color
    @Binding var selection: GameExperienceLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("How you’ll play", systemImage: "gamecontroller.fill")
                .font(.headline)
                .foregroundStyle(tint)

            HStack(alignment: .top, spacing: 8) {
                ForEach(GameExperienceLevel.allCases) { level in
                    Button {
                        selection = level
                    } label: {
                        rule(level)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(level.title)
                    .accessibilityValue(selection == level ? "Selected" : "Not selected")
                    .accessibilityAddTraits(selection == level ? .isSelected : [])
                }
            }

        }
    }

    private func rule(_ level: GameExperienceLevel) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: level.icon)
                .foregroundStyle(selection == level ? .white : tint)
            Text(level.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selection == level ? .white : .primary)
            Text(level.detail)
                .font(.caption2)
                .foregroundStyle(selection == level ? .white.opacity(0.9) : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            selection == level ? tint : tint.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selection == level ? tint : .clear, lineWidth: 2)
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
    let first: (icon: String, value: String, label: String)
    let second: (icon: String, value: String, label: String)
    let third: (icon: String, value: String, label: String)

    var body: some View {
        HStack(spacing: 8) {
            fact(first)
            fact(second)
            fact(third)
        }
    }

    private func fact(_ fact: (icon: String, value: String, label: String)) -> some View {
        VStack(spacing: 5) {
            Image(systemName: fact.icon)
                .font(.subheadline)
                .foregroundStyle(.tint)
            Text(fact.value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(fact.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

enum GameLobbyPreviewKind {
    case quiz
    case hangman
    case beatTheClock
    case verseMatch
    case bookOrder
    case wordSearch
    case whoAmI
    case wordle
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
        case .whoAmI:
            HStack(spacing: 24) {
                previewPrompt(icon: "person.crop.circle.fill", title: "Who am I?", subtitle: "I built an ark before the flood.")
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
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "square.grid.2x2.fill")
                .font(.headline)
                .foregroundStyle(tint)

            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = selection.contains(option)
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
                                    .font(.body.weight(isSelected ? .semibold : .regular))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(isSelected ? tint : Color.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(
                                isSelected ? tint.opacity(0.12) : Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.top, 10)
            } label: {
                Label {
                    Text(selection.count == options.count ? "All categories" : "\(selection.count) categories")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(tint)
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.2), lineWidth: 1)
        }
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
