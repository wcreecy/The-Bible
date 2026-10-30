import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WordSetupControls: View {
    @Binding var mode: WordleView.Mode
    @Binding var hardModeEnabled: Bool

    var body: some View {
        GameSettingsGroup {
            GameChoiceSetting(
                title: "Game type",
                systemImage: "calendar",
                tint: .mint,
                selection: $mode,
                choices: [
                    GameChoice(
                        value: WordleView.Mode.daily,
                        title: WordleView.Mode.daily.title,
                        detail: "One puzzle a day. Counts toward your Daily streak.",
                        icon: WordleView.Mode.daily.icon
                    ),
                    GameChoice(
                        value: WordleView.Mode.practice,
                        title: WordleView.Mode.practice.title,
                        detail: "Unlimited puzzles with a separate streak.",
                        icon: WordleView.Mode.practice.icon
                    )
                ]
            )

            GameToggleSetting(
                title: "Hard Mode",
                detail: "Reuse confirmed letters in every guess.",
                systemImage: "flame.fill",
                tint: .mint,
                isOn: $hardModeEnabled
            )
        }
    }
}

struct WordGameResponsiveLayout<
  Scoreboard: View, Board: View, Feedback: View, LetterTray: View, InputControls: View
>: View {
  let usesWideLayout: Bool
  let availableHeight: CGFloat
  let showsKeyboardCard: Bool
  let showsBoardCardSecond: Bool
  let toggleKeyboardCard: () -> Void
  let swapCards: () -> Void
  let scoreboard: Scoreboard
  let board: Board
  let feedback: Feedback
  let letterTray: LetterTray
  /// Builds the keyboard (or end-of-round controls) for a given key height. The wide
  /// layout passes a height that fits the space left under the cards; the stacked
  /// layout passes nil and the caller uses its own size.
  let inputControls: (_ wideKeyHeight: CGFloat?) -> InputControls

  /// Measured height of the board and letter-tray row, which can grow past its minimum.
  @State private var mainRowHeight: CGFloat = 0

  init(
    usesWideLayout: Bool,
    availableHeight: CGFloat,
    showsKeyboardCard: Bool,
    showsBoardCardSecond: Bool,
    toggleKeyboardCard: @escaping () -> Void,
    swapCards: @escaping () -> Void,
    @ViewBuilder scoreboard: () -> Scoreboard,
    @ViewBuilder board: () -> Board,
    @ViewBuilder feedback: () -> Feedback,
    @ViewBuilder letterTray: () -> LetterTray,
    @ViewBuilder inputControls: @escaping (_ wideKeyHeight: CGFloat?) -> InputControls
  ) {
    self.usesWideLayout = usesWideLayout
    self.availableHeight = availableHeight
    self.showsKeyboardCard = showsKeyboardCard
    self.showsBoardCardSecond = showsBoardCardSecond
    self.toggleKeyboardCard = toggleKeyboardCard
    self.swapCards = swapCards
    self.scoreboard = scoreboard()
    self.board = board()
    self.feedback = feedback()
    self.letterTray = letterTray()
    self.inputControls = inputControls
  }

  /// Key height that lets all four keyboard rows, including Enter, fit below the cards.
  /// Subtracts the space between the row and the keyboard card (18), the card's padding
  /// (32), the keyboard's top padding (6), and the gaps between rows (3 × 8); each key
  /// also adds 16 of vertical padding.
  private func wideKeyHeight(mainCardHeight: CGFloat) -> CGFloat {
    let rowHeight = max(mainRowHeight, mainCardHeight)
    let keyboardSpace = availableHeight - rowHeight - 18 - 32 - 6 - 24
    return min(64, max(40, keyboardSpace / 4 - 16))
  }

  var body: some View {
    if usesWideLayout {
      let mainCardHeight = showsKeyboardCard
        ? max(360, availableHeight * 0.56)
        : max(600, availableHeight * 0.92)

      VStack(spacing: 18) {
        HStack(alignment: .top, spacing: 18) {
          if showsBoardCardSecond {
            letterTrayCard(height: mainCardHeight)
            boardCard(height: mainCardHeight)
          } else {
            boardCard(height: mainCardHeight)
            letterTrayCard(height: mainCardHeight)
          }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { mainRowHeight = $0 }

        if showsKeyboardCard {
          VStack(spacing: 14) {
            inputControls(wideKeyHeight(mainCardHeight: mainCardHeight))
          }
          .padding(AppDesignMetrics.cardPadding)
          // Sized to its content: the keyboard while playing, and just the two rows of
          // end-of-round buttons afterward (a fixed minimum left the lower half blank).
          .frame(maxWidth: .infinity, alignment: .top)
          .heroCardSurface()
        }
      }
      .frame(maxWidth: 1_180)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 20)
    } else {
      VStack(spacing: 12) {
        scoreboard
        board
        feedback
        inputControls(nil)
      }
      .frame(maxWidth: 680)
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 16)
    }
  }

  private func boardCard(height: CGFloat) -> some View {
    VStack(spacing: 16) {
      HStack {
        Spacer()

        Button(action: swapCards) {
          Label("Swap Cards", systemImage: "arrow.left.arrow.right")
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityHint("Switches the game board and letter tray cards to opposite sides")

        Button(action: toggleKeyboardCard) {
          if showsKeyboardCard {
            Label("Hide Keyboard", systemImage: "keyboard.chevron.compact.down")
          } else {
            Label("Show Keyboard", systemImage: "keyboard")
          }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .controlSize(.small)
      }

      Spacer(minLength: 0)
      board
      feedback
      Spacer(minLength: 0)
    }
    .padding(AppDesignMetrics.cardPadding)
    .frame(maxWidth: .infinity, minHeight: height)
    .heroCardSurface()
  }

  private func letterTrayCard(height: CGFloat) -> some View {
    VStack(spacing: 16) {
      letterTray
      Spacer(minLength: 0)
      scoreboard
    }
    .padding(AppDesignMetrics.cardPadding)
    .frame(maxWidth: .infinity, minHeight: height)
    .heroCardSurface()
  }
}

struct WordTriedLettersCard: View {
  let lettersInWord: [Character]
  let otherTriedLetters: [Character]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      WordLetterBox(
        title: "Letters in Word",
        letters: lettersInWord,
        allowsShuffle: true
      )
      WordLetterBox(
        title: "Other Tried Letters",
        letters: otherTriedLetters,
        allowsShuffle: false
      )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct WordLetterBox: View {
  let title: LocalizedStringResource
  let letters: [Character]
  let allowsShuffle: Bool

  @State private var shuffledOrder: [Character] = []

  private let columns = [GridItem(.adaptive(minimum: 42), spacing: 8)]

  private var displayedLetters: [Character] {
    let retained = shuffledOrder.filter { letters.contains($0) }
    let additions = letters.filter { !retained.contains($0) }
    return retained + additions
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title)
          .font(.subheadline.weight(.semibold))

        Spacer()

        Text(letters.count, format: .number)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)

        if allowsShuffle {
          Button {
            shuffledOrder = letters.shuffled()
          } label: {
            Label("Shuffle Letters in Word", systemImage: "shuffle")
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.bordered)
          .controlSize(.small)
          .disabled(letters.count < 2)
        }
      }

      if letters.isEmpty {
        Text("No letters yet")
          .font(.footnote)
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
      } else {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
          ForEach(displayedLetters, id: \.self) { letter in
            Text(String(letter))
              .font(.headline.monospaced().weight(.bold))
              .frame(maxWidth: .infinity, minHeight: 42)
              .background(
                Color.secondary.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
              )
              .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                  .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
              }
              .accessibilityLabel("Letter \(String(letter))")
          }
        }
      }
    }
    .padding(12)
    .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
  }
}

#if canImport(UIKit)
  struct KeyCaptureRepresentable: UIViewRepresentable {
    var onKey: (Character) -> Void
    var onBackspace: () -> Void
    var onEnter: () -> Void

    final class KeyView: UIView {
      var onKey: ((Character) -> Void)?
      var onBackspace: (() -> Void)?
      var onEnter: (() -> Void)?

      override var canBecomeFirstResponder: Bool { true }

      override var keyCommands: [UIKeyCommand]? {
        var cmds: [UIKeyCommand] = []
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        for ch in letters {
          cmds.append(
            UIKeyCommand(input: String(ch), modifierFlags: [], action: #selector(handleKey(_:))))
          cmds.append(
            UIKeyCommand(
              input: String(ch.lowercased()), modifierFlags: [], action: #selector(handleKey(_:))))
        }
        cmds.append(
          UIKeyCommand(
            input: UIKeyCommand.inputDelete, modifierFlags: [], action: #selector(handleDelete)))
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
      DispatchQueue.main.async { v.becomeFirstResponder() }
      return v
    }

    func updateUIView(_ uiView: KeyView, context: Context) {
        uiView.onKey = onKey
        uiView.onBackspace = onBackspace
        uiView.onEnter = onEnter
        DispatchQueue.main.async { uiView.becomeFirstResponder() }
    }
}
#endif

// MARK: - Filled key style for evaluated keys (absent/present/correct)
struct FilledGameKeyButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = .white
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(isEnabled ? foreground : .secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill.opacity(isEnabled ? 1.0 : 0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(pressed ? 0.06 : 0.12), radius: pressed ? 1 : 2, x: 0, y: pressed ? 0 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
    }
}
