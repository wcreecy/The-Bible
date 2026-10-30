import SwiftUI

struct HangmanSetupControls: View {
    @Binding var theme: HangmanTheme

    var body: some View {
        GameSettingsGroup {
            GameChoiceSetting(
                title: "Word types",
                systemImage: "text.word.spacing",
                tint: .teal,
                selection: $theme,
                choices: HangmanTheme.allCases.map {
                    GameChoice(value: $0, title: $0.title, detail: $0.detail, icon: $0.systemImage)
                }
            )
        }
    }
}

struct HangmanRevealCard: View {
    let didWin: Bool
    let answer: String
    let qualifier: String?
    let clue: String
    let reference: String?
    let onShowReference: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                didWin ? "You got it!" : "Out of guesses",
                systemImage: didWin ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(didWin ? Color.green : Color.red)

            if let qualifier {
                Text("\(answer) (\(qualifier))")
                    .font(.title3.weight(.bold))
            } else {
                Text(answer)
                    .font(.title3.weight(.bold))
            }

            if !clue.isEmpty {
                Text(clue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let reference {
                Button {
                    onShowReference(reference)
                } label: {
                    Label(reference, systemImage: "book.closed")
                }
                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                .accessibilityHint("Shows the scripture passage")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            (didWin ? Color.green : Color.red).opacity(0.1),
            in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }
}

struct HangmanResultsCard: View {
    let score: Int
    let total: Int
    let bestStreak: Int
    let bestGameScore: Int
    let isNewBest: Bool
    let onPlayAgain: () -> Void
    let onChangeSettings: () -> Void

    private var accuracy: Int {
        guard total > 0 else { return 0 }
        return Int((Double(score) / Double(total) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isNewBest ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(isNewBest ? Color.yellow : Color.teal)

            VStack(spacing: 6) {
                Text(isNewBest ? "New Best Game!" : "Game Over")
                    .font(.title.weight(.bold))

                Text("\(score) of \(total) words solved")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GameSplashFacts(
                first: ("percent", "\(accuracy)%", String(localized: "Accuracy")),
                second: ("flame.fill", "\(bestStreak)", String(localized: "Best streak")),
                third: ("trophy", "\(bestGameScore)/\(total)", String(localized: "Best game"))
            )

            VStack(spacing: 10) {
                Button("Play Again", systemImage: "arrow.clockwise", action: onPlayAgain)
                    .buttonStyle(GameProminentButtonStyle(tint: .teal))

                Button("Change Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .heroCardSurface()
    }
}

struct HangmanKeyboardView: View {
    @Binding var usesAlphabeticalLayout: Bool
    let guessedLetters: Set<Character>
    let correctLetters: Set<Character>
    let wrongLetters: Set<Character>
    let isRoundOver: Bool
    let keyHeight: CGFloat
    let onGuess: (Character) -> Void

    private var rows: [[Character]] {
        let layout = usesAlphabeticalLayout
            ? ["ABCDEFG", "HIJKLMN", "OPQRSTU", "VWXYZ"]
            : ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
        return layout.map(Array.init)
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(rows[rowIndex], id: \.self) { character in
                        let upper = Character(String(character).uppercased())
                        Button {
                            onGuess(upper)
                        } label: {
                            Text(String(character))
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: keyHeight)
                                .accessibilityLabel("Letter \(String(character))")
                        }
                        .buttonStyle(GameKeyButtonStyle(tint: tint(for: upper)))
                        // Not .disabled: that would grey out the green and red played keys.
                        .allowsHitTesting(!guessedLetters.contains(upper) && !isRoundOver)
                        .opacity(isRoundOver ? 0.6 : 1)
                        .accessibilityValue(keyState(for: upper))

                        if !usesAlphabeticalLayout,
                           rowIndex == rows.count - 1,
                           character == "M" {
                            layoutToggle(title: "A-Z")
                        }
                    }

                    if usesAlphabeticalLayout, rowIndex == rows.count - 1 {
                        layoutToggle(title: "QWERTY")
                    }
                }
            }
        }
    }

    private func keyState(for character: Character) -> String {
        if correctLetters.contains(character) { return String(localized: "In the word") }
        if wrongLetters.contains(character) { return String(localized: "Not in the word") }
        return ""
    }

    private func tint(for character: Character) -> Color {
        if correctLetters.contains(character) {
            return .green
        }
        return wrongLetters.contains(character) ? .red : .accentColor
    }

    private func layoutToggle(title: String) -> some View {
        Button {
            usesAlphabeticalLayout.toggle()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .accessibilityLabel("Toggle keyboard layout")
        }
        .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
        .disabled(isRoundOver)
        .opacity(isRoundOver ? 0.6 : 1)
    }
}

struct HangmanResponsiveLayout<
    Header: View,
    Word: View,
    Drawing: View,
    Scoreboard: View,
    Keyboard: View
>: View {
    let usesWideLayout: Bool
    let availableHeight: CGFloat
    let showsKeyboardCard: Bool
    let allowsKeyboardVisibilityToggle: Bool
    let showsHangmanCardFirst: Bool
    let toggleKeyboardCard: () -> Void
    let swapCards: () -> Void
    let header: Header
    let word: Word
    let drawing: Drawing
    let scoreboard: Scoreboard
    let keyboard: Keyboard

    init(
        usesWideLayout: Bool,
        availableHeight: CGFloat,
        showsKeyboardCard: Bool,
        allowsKeyboardVisibilityToggle: Bool,
        showsHangmanCardFirst: Bool,
        toggleKeyboardCard: @escaping () -> Void,
        swapCards: @escaping () -> Void,
        @ViewBuilder header: () -> Header,
        @ViewBuilder word: () -> Word,
        @ViewBuilder drawing: () -> Drawing,
        @ViewBuilder scoreboard: () -> Scoreboard,
        @ViewBuilder keyboard: () -> Keyboard
    ) {
        self.usesWideLayout = usesWideLayout
        self.availableHeight = availableHeight
        self.showsKeyboardCard = showsKeyboardCard
        self.allowsKeyboardVisibilityToggle = allowsKeyboardVisibilityToggle
        self.showsHangmanCardFirst = showsHangmanCardFirst
        self.toggleKeyboardCard = toggleKeyboardCard
        self.swapCards = swapCards
        self.header = header()
        self.word = word()
        self.drawing = drawing()
        self.scoreboard = scoreboard()
        self.keyboard = keyboard()
    }

    var body: some View {
        if usesWideLayout {
            let mainCardHeight = showsKeyboardCard
                ? max(360, availableHeight * 0.56)
                : max(600, availableHeight * 0.92)

            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 18) {
                    if showsHangmanCardFirst {
                        hangmanCard(height: mainCardHeight)
                        gameCard(height: mainCardHeight)
                    } else {
                        gameCard(height: mainCardHeight)
                        hangmanCard(height: mainCardHeight)
                    }
                }

                if showsKeyboardCard {
                    VStack(spacing: 14) {
                        keyboard
                    }
                    .padding(AppDesignMetrics.cardPadding)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: max(250, availableHeight * 0.32),
                        alignment: .top
                    )
                    .heroCardSurface()
                }
            }
            .frame(maxWidth: 1_180)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)
        } else {
            VStack(spacing: 12) {
                header
                scoreboard
                drawing
                word

                if allowsKeyboardVisibilityToggle {
                    compactKeyboardToggle
                }

                if !allowsKeyboardVisibilityToggle || showsKeyboardCard {
                    keyboard
                }
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
    }

    private var compactKeyboardToggle: some View {
        Button(action: toggleKeyboardCard) {
            Label(
                showsKeyboardCard ? "Hide Keyboard" : "Show Keyboard",
                systemImage: showsKeyboardCard
                    ? "keyboard.chevron.compact.down"
                    : "keyboard"
            )
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityHint(
            showsKeyboardCard
                ? "Hides the on-screen keyboard and enlarges the hangman figure"
                : "Shows the on-screen keyboard"
        )
    }

    private func gameCard(height: CGFloat) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                header
                Spacer(minLength: 8)
                Button(action: toggleKeyboardCard) {
                    Label(
                        showsKeyboardCard ? "Hide Keyboard" : "Show Keyboard",
                        systemImage: showsKeyboardCard
                            ? "keyboard.chevron.compact.down"
                            : "keyboard"
                    )
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer(minLength: 0)
            word
            Spacer(minLength: 0)
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: height)
        .heroCardSurface()
    }

    private func hangmanCard(height: CGFloat) -> some View {
        VStack(spacing: 16) {
            scoreboard

            HStack {
                Spacer()
                Button(action: swapCards) {
                    Label("Swap Cards", systemImage: "arrow.left.arrow.right")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityHint("Switches the game and hangman cards to opposite sides")
            }

            Spacer(minLength: 0)
            drawing
            Spacer(minLength: 0)
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, minHeight: height)
        .heroCardSurface()
    }
}

// MARK: - Hangman Drawing

struct HangmanDrawing: View {
    let progress: Double
    let maximumCharacterHeight: CGFloat

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var fillColor: Color {
        if clampedProgress >= 0.75 { return .red }
        if clampedProgress >= 0.4 { return .orange }
        return .teal
    }

    var body: some View {
        GeometryReader { geo in
            let characterHeight = min(geo.size.height, maximumCharacterHeight)
            let characterWidth = min(geo.size.width * 0.72, characterHeight * 0.62)

            ZStack {
                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.secondary.opacity(0.16))

                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(fillColor.gradient)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: characterHeight * clampedProgress)
                    }
            }
            .frame(width: characterWidth, height: characterHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.35), value: clampedProgress)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mistake meter")
        .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent filled")
    }
}

#if canImport(UIKit)
/// Captures hardware-keyboard letters, Delete and Return without showing any UI.
struct HangmanKeyCapture: UIViewRepresentable {
    var onKey: (Character) -> Void
    var onBackspace: () -> Void
    var onEnter: () -> Void

    final class KeyView: UIView {
        var onKey: ((Character) -> Void)?
        var onBackspace: (() -> Void)?
        var onEnter: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        // Claim hardware-keyboard focus once, when the view appears on screen.
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil {
                DispatchQueue.main.async { self.becomeFirstResponder() }
            }
        }

        override var keyCommands: [UIKeyCommand]? {
            var cmds: [UIKeyCommand] = []
            let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            for ch in letters {
                cmds.append(UIKeyCommand(input: String(ch), modifierFlags: [], action: #selector(handleKey(_:))))
                cmds.append(UIKeyCommand(input: String(ch.lowercased()), modifierFlags: [], action: #selector(handleKey(_:))))
            }
            cmds.append(UIKeyCommand(input: UIKeyCommand.inputDelete, modifierFlags: [], action: #selector(handleDelete)))
            cmds.append(UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(handleEnter)))
            cmds.append(UIKeyCommand(input: "\n", modifierFlags: [], action: #selector(handleEnter)))
            return cmds
        }

        @objc private func handleKey(_ sender: UIKeyCommand) {
            guard let s = sender.input, let first = s.uppercased().first, first.isLetter else { return }
            onKey?(first)
        }

        @objc private func handleDelete() { onBackspace?() }
        @objc private func handleEnter() { onEnter?() }
    }

    func makeUIView(context: Context) -> KeyView {
        let v = KeyView()
        v.isUserInteractionEnabled = false
        v.onKey = onKey
        v.onBackspace = onBackspace
        v.onEnter = onEnter
        return v
    }

    func updateUIView(_ uiView: KeyView, context: Context) {
        uiView.onKey = onKey
        uiView.onBackspace = onBackspace
        uiView.onEnter = onEnter
    }
}
#endif
