import SwiftUI
import GameController
#if canImport(UIKit)
import UIKit
#endif

struct WordleView: View {
    // MARK: - Mode
    enum Mode: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case practice = "Practice"

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .daily: "Daily"
            case .practice: "Practice"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .daily: "One puzzle on this device each day. Completion locks it until tomorrow and affects your Daily streak."
            case .practice: "Unlimited new puzzles with a separate Practice streak."
            }
        }

        var icon: String {
            switch self {
            case .daily: "calendar"
            case .practice: "arrow.clockwise"
            }
        }
    }

    // MARK: - Key state
    typealias KeyState = WordleKeyState

    // MARK: - State
    @State private var vm = WordleGameViewModel()

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }
    @AppStorage(AppStorageKey.contextualTipsEnabled) private var contextualTipsEnabled = false

    // Toggle for keyboard layout
    @State private var useABCLayout: Bool = false
    @State private var showsOnScreenKeyboard: Bool = true
    @State private var showsBoardCardSecond: Bool = false
    @State private var hardwareKeyboardConnected: Bool = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Height of the tip banner above the game (0 once dismissed), so the iPad layout
    /// leaves room for it.
    @State private var tipHeight: CGFloat = 0
    /// Height of the scoreboard on phones, measured so the board and keyboard can be sized
    /// to fit above the tab bar.
    @State private var compactScoreboardHeight: CGFloat = 0

    // confirmation for reveal
    @State private var confirmReveal: Bool = false

    // MARK: - Spell-check language for guess validation

    // MARK: - Curated answers (WORDCuratedWordList.json)

    // Smart link style preview state
    @State private var showRefSheet: Bool = false
    @State private var selectedRef: ScriptureRef? = nil
    @State private var loadedPreview: (title: String, verses: [Verse])? = nil

  var body: some View {
    GeometryReader { geometry in
      let usesWideLayout = vm.started && geometry.size.width >= 900
      let usesCompactPhoneLayout = vm.started && geometry.size.width < 600
      let compactSizes = compactGameSizes(
        availableHeight: geometry.size.height
          - (contextualTipsEnabled && tipHeight > 0 ? tipHeight + 12 : 0)
      )
      let lettersInWord = WordleGameViewModel.alphabet.filter {
        vm.keyboardStates[$0] == .correct || vm.keyboardStates[$0] == .present
      }
      let otherTriedLetters = WordleGameViewModel.alphabet.filter { vm.keyboardStates[$0] == .absent }

      ScrollView(.vertical) {
        VStack(spacing: 12) {
          if contextualTipsEnabled {
            ContextualTipView(
              id: "wordle.reuseLetter",
              title: "Reuse a correct letter",
              message: "Tap a correctly placed letter from an earlier guess to reuse it in your current guess.",
              systemImage: "hand.tap"
            )
            .padding(.horizontal)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { tipHeight = $0 }
          }

          if !vm.started {
            startScreen()
          } else {
            #if canImport(UIKit)
              if hardwareKeyboardConnected {
              KeyCaptureRepresentable(
                onKey: { ch in vm.tapLetter(ch) },
                onBackspace: { vm.deleteLetter() },
                onEnter: {
                  if !vm.roundOver, vm.isCurrentRowFull() {
                    vm.submitGuess()
                  }
                }
              )
              .frame(width: 0, height: 0)
              .accessibilityHidden(true)
              }
            #endif

            WordGameResponsiveLayout(
              usesWideLayout: usesWideLayout,
              // Height left for the game: minus the scroll padding (24), the gap after the
              // hidden key-capture view (12), and the tip banner with its gap when shown.
              availableHeight: geometry.size.height - 24 - 12
                - (contextualTipsEnabled && tipHeight > 0 ? tipHeight + 12 : 0),
              showsKeyboardCard: vm.roundOver || showsOnScreenKeyboard,
              showsBoardCardSecond: showsBoardCardSecond,
              toggleKeyboardCard: {
                showsOnScreenKeyboard.toggle()
              },
              swapCards: {
                showsBoardCardSecond.toggle()
              }
            ) {
              GameScoreboardCard(
                currentCorrect: vm.score,
                currentAnswered: vm.answered,
                currentStreak: vm.mode == .daily ? vm.currentStreak : vm.practiceStreak,
                game: .wordle,
                wordMode: vm.roundHardMode ? .hard : .normal,
                style: usesWideLayout ? .dashboard : .compact
              )
              .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { compactScoreboardHeight = $0 }
            } board: {
              VStack(alignment: .trailing, spacing: 4) {
                boardView(
                  tileSize: usesWideLayout && !(vm.roundOver || showsOnScreenKeyboard)
                    ? 68
                    : (usesCompactPhoneLayout ? compactSizes.tile : 48)
                )
              }
            } feedback: {
              VStack(spacing: 10) {
                // Once the round ends, the result card below the board covers the outcome.
                if !vm.roundOver, let msg = vm.message {
                  Text(msg)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    // On phones the message keeps to its one-line slot below.
                    .lineLimit(usesCompactPhoneLayout ? 1 : nil)
                    .minimumScaleFactor(usesCompactPhoneLayout ? 0.75 : 1)
                }
              }
              // On phones the message always has its own slot, so the keyboard doesn't
              // jump down when "Not in word list" appears.
              .frame(height: usesCompactPhoneLayout && !vm.roundOver ? Self.compactMessageHeight : nil)
            } letterTray: {
              WordTriedLettersCard(
                lettersInWord: lettersInWord,
                otherTriedLetters: otherTriedLetters
              )
            } inputControls: { wideKeyHeight in
              VStack(spacing: usesCompactPhoneLayout ? 6 : 10) {
                if vm.roundOver {
                  endOfRoundActionArea(pinsNextWord: horizontalSizeClass == .compact)
                } else {
                  keyboardView(
                    keyHeight: wideKeyHeight ?? (usesCompactPhoneLayout ? compactSizes.key : 52)
                  )

                  if debugAutoWinEnabled {
                    Button("WIN") {
                      vm.endRound(win: true)
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .red))
                    .controlSize(.large)
                    .accessibilityLabel("Win this round")
                  }
                }
              }
            }
          }
        }
        .padding(.top, 8)
        .padding(.bottom, usesCompactPhoneLayout ? 0 : 16)
      }
    }
    .tabBarContentClearance()
    .pinnedGameActionButton(
      isShown: horizontalSizeClass == .compact && vm.roundOver && vm.mode == .practice
    ) {
      Button("Next Word", systemImage: "arrow.right") {
        vm.startNewRound(practice: true)
      }
      .buttonStyle(GameProminentButtonStyle(tint: .mint))
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        if vm.started {
          GameNavigationTitle(title: "WORD", systemImage: "textformat.abc", tint: .mint)
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        if vm.started && !vm.roundOver {
          Menu {
            Button(role: .destructive) {
              confirmReveal = true
            } label: {
              Label("Give Up", systemImage: "flag.fill")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
          .accessibilityLabel("WORD options")
          .accessibilityHint("Includes an option to give up the current round")
        }
      }
    }
    .task {
      hardwareKeyboardConnected = GCKeyboard.coalesced != nil
      showsOnScreenKeyboard = !hardwareKeyboardConnected
    }
    .task {
      await WordleGameViewModel.prewarmAnswerBank()
      vm.isAnswerBankPrepared = true
    }
    .task {
      for await _ in NotificationCenter.default.notifications(named: .GCKeyboardDidConnect) {
        hardwareKeyboardConnected = true
        showsOnScreenKeyboard = false
      }
    }
    .task {
      for await _ in NotificationCenter.default.notifications(named: .GCKeyboardDidDisconnect) {
        hardwareKeyboardConnected = false
        showsOnScreenKeyboard = true
      }
    }
    // Time away from the app doesn't count toward the solve time.
    .onAppActiveChange { isActive in
      guard vm.started, !vm.roundOver else { return }
      if isActive {
        vm.roundClock.resume()
      } else {
        vm.roundClock.pause()
      }
    }
    .sheet(
      isPresented: $showRefSheet,
      onDismiss: {
        selectedRef = nil
        loadedPreview = nil
      }
    ) {
            NavigationStack {
                // A ScrollView keeps the verse directly under the title (instead of centered
                // in the sheet with a blank gap above it) and lets long passages scroll.
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let preview = loadedPreview {
                            ScripturePreviewCard(
                                content: preview,
                                refContext: selectedRef,
                                onCopy: {
                                    let verseLines = preview.verses.map { $0.text }.joined(separator: " ")
                                    UIPasteboard.general.string = "\(preview.title) — \(verseLines)"
                                },
                                onClose: {
                                    showRefSheet = false
                                }
                            )
                        } else {
                            ContentUnavailableView("No reference available", systemImage: "book")
                        }
                    }
                    .padding()
                }
                .navigationTitle("Reference")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showRefSheet = false }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .task(id: selectedRef) {
                guard let sr = selectedRef else { return }
                loadedPreview = BibleReferenceLinker.loadVerses(for: sr)
            }
        }
        .confirmationDialog(
            "Reveal the word?",
            isPresented: $confirmReveal,
            titleVisibility: .visible
        ) {
            Button("Reveal", role: .destructive) {
                guard !vm.roundOver else { return }
                vm.didWin = false
                vm.endRound(win: false)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reveal the answer and count this round as a loss.")
        }
        // Seed session streaks from persistent values so they survive navigation/relaunch
        .onAppear {
            // Daily streaks count consecutive solved days, derived from the synced solved-days map.
            vm.currentStreak = GameStats.shared.wordleDailyWinStreak()
            vm.currentBestStreak = max(vm.currentBestStreak, vm.persistentStreak.best)
            vm.practiceStreak = vm.practicePersistentStreak.current
            vm.practiceBestStreak = vm.practicePersistentStreak.best
        }
    }

    // MARK: - Start screen
    @ViewBuilder
    private func startScreen() -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            Text("Guess the 5‑letter word in 6 tries.\nUse the on‑screen keyboard or a connected keyboard.")
                .gameStartDescriptionStyle(title: "WORD", systemImage: "textformat.abc", tint: .mint)

            GameSplashLaunchLayout(
                tint: .mint,
                isStartEnabled: vm.isAnswerBankPrepared
                    && (vm.mode != .daily || !vm.dailyCompletedToday),
                startAction: { vm.startNewRound(practice: vm.mode == .practice) }
            ) {
                GameLobbyPreview(kind: .wordle)
            } configuration: {
                WordSetupControls(
                    mode: $vm.mode,
                    hardModeEnabled: $vm.hardModeEnabled
                )

                if vm.mode == .daily && vm.dailyCompletedToday {
                    Label(
                        "Daily completed. Come back tomorrow.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(12)
                    .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } facts: {
                // Game type, difficulty, and how many puzzles can be played today.
                let allowsUnlimitedPlays = vm.mode == .practice
                GameSplashFacts(
                    first: (vm.mode.icon, String(localized: vm.mode.title), String(localized: "Game type")),
                    second: (
                        vm.hardModeEnabled ? "flame" : "circle",
                        vm.hardModeEnabled ? String(localized: "Hard") : String(localized: "Normal"),
                        String(localized: "Difficulty")
                    ),
                    third: (
                        allowsUnlimitedPlays ? "infinity" : "1.circle",
                        allowsUnlimitedPlays ? String(localized: "Unlimited") : String(localized: "Once"),
                        String(localized: "Plays today")
                    )
                )
            }
            Spacer(minLength: 24)
        }
        .gameStartScreenStyle()
    }

    // MARK: - Board helpers (composition with pinned letters)

    // MARK: - Board
    private func boardView(tileSize: CGFloat) -> some View {
        WordleBoardView(
            guesses: vm.guesses,
            evaluations: vm.evaluations,
            activeRow: vm.composedCurrentRow(),
            rowIndex: vm.rowIndex,
            isRoundOver: vm.roundOver,
            pinned: $vm.pinned,
            nextInputColumn: vm.nextAvailableColumn(),
            tileSize: tileSize,
            onReuseCorrectLetter: vm.reuseCorrectLetter
        )
    }

    // MARK: - Phone sizing

    /// Tile and key sizes that fit the scoreboard, board, and whole keyboard (including the
    /// Enter row) above the tab bar on a phone. Phones with room keep the full sizes; shorter
    /// ones shrink tiles and keys together, but keys never get too small to tap reliably.
    /// Height of the one-line message slot between the board and the keyboard on phones.
    private static let compactMessageHeight: CGFloat = 20

    /// How far the keyboard may extend into the space kept clear above the tab bar. That
    /// space is 80 points, but the tab bar itself only reaches about 31 points into it, so
    /// this still leaves a gap above the tab bar.
    private static let compactTabBarAllowance: CGFloat = 20

    private func compactGameSizes(availableHeight: CGFloat) -> (tile: CGFloat, key: CGFloat) {
        let fullTile: CGFloat = 42
        let fullKey: CGFloat = 40
        // Top padding (8), the three gaps between scoreboard, board, message and keyboard
        // (3 × 12), and the message slot. The allowance gives back part of the tab bar space.
        let reserved = 8 + compactScoreboardHeight + 36 + Self.compactMessageHeight
            - Self.compactTabBarAllowance
        // Board: 6 tiles + 5 gaps of 6. Keyboard: 4 rows of (key + 16 padding), 3 gaps of 8,
        // and 6 of top padding.
        let fixed: CGFloat = 30 + 4 * 16 + 3 * 8 + 6
        let budget = availableHeight - reserved - fixed
        let fullSize = 6 * fullTile + 4 * fullKey
        guard compactScoreboardHeight > 0, budget < fullSize else { return (fullTile, fullKey) }

        // Shrink both by the same proportion so the board and keyboard stay balanced.
        let scale = max(0, budget) / fullSize
        return (max(32, (fullTile * scale).rounded(.down)), max(33, (fullKey * scale).rounded(.down)))
    }

    // MARK: - On-screen keyboard
    private func keyboardView(keyHeight: CGFloat) -> some View {
        WordleKeyboardView(
            usesABCLayout: $useABCLayout,
            keyStates: vm.keyboardStates,
            isRoundOver: vm.roundOver,
            isCurrentRowFull: vm.isCurrentRowFull(),
            canDelete: !vm.currentInput.isEmpty,
            keyHeight: keyHeight,
            onLetter: vm.tapLetter,
            onDelete: vm.deleteLetter,
            onEnter: vm.submitGuess
        )
    }

    // MARK: - Input helpers

    // MARK: - Reference preview presentation
    private func presentReferencePreview(_ ref: WordleGameViewModel.VerseRefInfo) {
        let sr = ScriptureRef(bookName: ref.bookName, chapter: ref.chapter, startVerse: ref.verse, endVerse: nil)
        selectedRef = sr
        loadedPreview = nil
        showRefSheet = true
    }

    // MARK: - End-of-round result

    private var resultTitle: String {
        if vm.didWin {
            return vm.rowIndex == 1 ? String(localized: "Solved in 1 guess") : String(localized: "Solved in \(vm.rowIndex) guesses")
        }
        return vm.rowIndex < 6 ? String(localized: "Word revealed") : String(localized: "Out of guesses")
    }

    private var resultFacts: [GameSplashFacts.Fact] {
        [
            ("square.grid.3x2", vm.didWin ? "\(vm.rowIndex)/6" : "X/6", String(localized: "Guesses")),
            ("stopwatch", vm.lastRoundElapsedSeconds.map(formatElapsed) ?? "—", String(localized: "Time")),
            (vm.mode.icon, String(localized: vm.mode.title), String(localized: "Puzzle")),
            (vm.roundHardMode ? "flame" : "circle", vm.roundHardMode ? String(localized: "Hard") : String(localized: "Normal"), String(localized: "Mode"))
        ]
    }

    private var resultStreak: GamePuzzleStreak {
        vm.mode == .daily
            ? GamePuzzleStreak(current: vm.currentStreak, best: vm.currentBestStreak, isNewBest: vm.isNewBestStreak)
            : GamePuzzleStreak(current: vm.practiceStreak, best: vm.practiceBestStreak, isNewBest: vm.isNewBestStreak)
    }

    private func resultCard() -> some View {
        GamePuzzleResultCard(
            title: resultTitle,
            systemImage: vm.didWin ? "checkmark.seal.fill" : (vm.rowIndex < 6 ? "eye.fill" : "xmark.octagon.fill"),
            tint: vm.didWin ? .green : .red,
            facts: resultFacts,
            streak: resultStreak,
            scripture: vm.roundRef.map { ref in
                GamePuzzleScripture(reference: ref.display, text: ref.text) {
                    presentReferencePreview(ref)
                }
            }
        ) {
            answerTiles

            if vm.guessDistribution.contains(where: { $0 > 0 }) {
                GamePuzzleResultSection(title: "Guess Distribution", systemImage: "chart.bar.fill") {
                    WordGuessDistributionView(
                        winsByGuess: vm.guessDistribution,
                        highlightedGuess: vm.didWin ? vm.rowIndex : nil,
                        tint: .green
                    )
                }
            }
        }
    }

    /// The answer spelled out in tiles, green when solved and red otherwise.
    private var answerTiles: some View {
        HStack(spacing: 6) {
            ForEach(Array(vm.target.uppercased().enumerated()), id: \.offset) { _, letter in
                Text(String(letter))
                    .font(.title2.weight(.heavy).monospaced())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        (vm.didWin ? Color.green : Color.red).opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Answer: \(vm.target)")
    }

    /// Midnight tonight, when the next Daily word is available.
    private var nextDailyDate: Date {
        let calendar = Calendar.autoupdatingCurrent
        let startOfToday = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)
    }

    // MARK: - End-of-round action area (replaces keyboard)
    @ViewBuilder
    private func endOfRoundActionArea(pinsNextWord: Bool) -> some View {
        VStack(spacing: 12) {
            resultCard()

            HStack(spacing: 12) {
                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(ModernPillButtonStyle(tint: .mint))

                if vm.mode == .practice && !pinsNextWord {
                    Button("Next Word", systemImage: "arrow.right") {
                        vm.startNewRound(practice: true)
                    }
                    .buttonStyle(GameProminentButtonStyle(tint: .mint))
                } else if vm.dailyCompletedToday {
                    Label {
                        Text("Next daily WORD \(Text(nextDailyDate, style: .relative))")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "calendar.badge.clock")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                } else {
                    Button("Play Again", systemImage: "arrow.clockwise") {
                        vm.startNewRound(practice: false)
                    }
                    .buttonStyle(GameProminentButtonStyle(tint: .mint))
                }
            }
        }
    }

    /// Spoiler-free result summary with an emoji grid of the guesses.
    private var shareText: String {
        let title = vm.mode == .daily ? "WORD Daily \(vm.todayKey)" : "WORD Practice"
        let scoreText = vm.didWin ? "\(vm.rowIndex)/6" : "X/6"
        let difficulty = vm.roundHardMode ? " (Hard)" : ""
        let grid = vm.evaluations.prefix(vm.rowIndex).map { row in
            row.map { state -> String in
                switch state {
                case .correct: "🟩"
                case .present: "🟨"
                case .absent, .unknown: "⬛"
                }
            }.joined()
        }.joined(separator: "\n")
        return "\(title) \(scoreText)\(difficulty)\n\n\(grid)"
    }

  private func formatElapsed(_ s: Int) -> String {
    let seconds = max(0, s)
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let sec = seconds % 60
    if h > 0 {
      return String(format: "%d:%02d:%02d", h, m, sec)
    } else {
      return String(format: "%d:%02d", m, sec)
    }
  }
}
