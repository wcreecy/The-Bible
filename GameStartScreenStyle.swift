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
    let systemImage: String
    let tint: Color

    func body(content: Content) -> some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: tint.opacity(0.24), radius: 12, y: 7)

            content
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .padding(.top, 8)
    }
}

struct GameStartOptionsStyle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .padding(horizontalSizeClass == .regular ? 0 : 16)
            .background(
                horizontalSizeClass == .regular ? AnyShapeStyle(.clear) : AnyShapeStyle(.regularMaterial),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                if horizontalSizeClass != .regular {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                }
            }
    }
}

struct GameStartInfoLayout<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsHelp = false

    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        Button {
            showsHelp = true
        } label: {
            Label("How to Play", systemImage: "questionmark.circle")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showsHelp) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: spacing) {
                        content
                    }
                    .disclosureGroupStyle(ExpandedGameHelpDisclosureStyle())
                    .padding()
                    .frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
                }
                .navigationTitle("How to Play")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showsHelp = false }
                    }
                }
            }
            .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
        }
        .accessibilityHint("Opens game instructions and difficulty details")
    }
}

private struct ExpandedGameHelpDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.headline)

            configuration.content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GameStartCurrentGameCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        EmptyView()
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

struct GameSetupSummary: View {
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    let summary: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checklist")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 32, height: 32)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Game")
                        .font(.subheadline.weight(.bold))

                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: 620, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)

            if contextualTipsEnabled {
                ContextualTipView(
                    title: "Customize your game",
                    message: "Choose Game Settings above to change how this game will play before you start.",
                    systemImage: "slider.horizontal.3"
                )
                .frame(maxWidth: 620)
            }
        }
        .padding(.horizontal)
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
                previewOrderRow("1", "Genesis")
                previewOrderRow("2", "Exodus")
                previewOrderRow("3", "Leviticus")
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

struct GameStartCurrentGameRow: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct GameStartSettingsStyle: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            GroupBox("Game Settings") {
                content
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity)
            }
        } else {
            content
        }
    }
}

struct GameStartSettingsLayout<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showsSettings = false

    @ViewBuilder let content: Content

    var body: some View {
        Button {
            showsSettings = true
        } label: {
            Label("Game Settings", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        content
                    }
                    .padding()
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .navigationTitle("Game Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showsSettings = false }
                    }
                }
            }
            .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
        }
        .accessibilityHint("Opens settings for this game")
    }
}

struct GameStartSettingCard<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        if horizontalSizeClass == .regular {
            GroupBox(title) {
                content
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        } else {
            content
        }
    }
}

struct GameStartPickerCard<Value: Hashable, Label: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: LocalizedStringKey
    @Binding var selection: Value
    let options: [Value]
    @ViewBuilder let label: (Value) -> Label

    var body: some View {
        if horizontalSizeClass == .regular {
            GroupBox(title) {
                VStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection = option
                        } label: {
                            HStack(spacing: 12) {
                                label(option)
                                    .font(.body.weight(selection == option ? .semibold : .regular))
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: selection == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selection == option ? Color.accentColor : Color.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(
                                selection == option ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == option ? .isSelected : [])
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        } else {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    label(option).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }
}

struct GameStartMultiPickerCard<Value: Hashable, OptionLabel: View>: View {
    let title: LocalizedStringKey
    @Binding var selection: Set<Value>
    let options: [Value]
    @ViewBuilder let label: (Value) -> OptionLabel

    @State private var isExpanded = false

    var body: some View {
        GroupBox(title) {
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
                                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(
                                isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .top)
            } label: {
                Label {
                    Text(selection.count == options.count ? "All" : "\(selection.count) selected")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
                .font(.body.weight(.semibold))
            }
        }
    }
}

extension View {
    func gameStartScreenStyle() -> some View {
        modifier(GameStartScreenStyle())
    }

    func gameStartDescriptionStyle(
        systemImage: String = "gamecontroller.fill",
        tint: Color = .accentColor
    ) -> some View {
        modifier(GameStartDescriptionStyle(systemImage: systemImage, tint: tint))
    }

    func gameStartOptionsStyle() -> some View {
        modifier(GameStartOptionsStyle())
    }

    func gameStartSettingsStyle() -> some View {
        modifier(GameStartSettingsStyle())
    }
}
