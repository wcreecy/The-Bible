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
    @State private var started: Bool = false
    @AppStorage("wordleMode") private var mode: Mode = .practice
    @State private var isAnswerBankPrepared: Bool = false

    @State private var target: String = ""
    @State private var guesses: [String] = Array(repeating: "", count: 6)
    @State private var evaluations: [[KeyState]] = Array(repeating: Array(repeating: .unknown, count: 5), count: 6)
    @State private var rowIndex: Int = 0
    @State private var currentInput: String = ""
    @State private var didWin: Bool = false
    @State private var roundOver: Bool = false
    @State private var message: String? = nil
    @State private var keyboardStates: [Character: KeyState] = [:]
    nonisolated private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    // Pinned letters stay fixed in the active row until cleared with the × button.
    @State private var pinned: [[Character?]] = Array(repeating: Array(repeating: nil, count: 5), count: 6)

    // Session stats (for the scoreboard’s Current section)
    @State private var score: Int = 0
    @State private var answered: Int = 0
    @State private var currentStreak: Int = 0
    @State private var currentBestStreak: Int = 0
    @State private var practiceStreak: Int = 0
    @State private var practiceBestStreak: Int = 0

    // Hard Mode toggle (persisted locally; stats still aggregate with normal mode)
    @AppStorage(AppStorageKey.wordleHardModeEnabled) private var hardModeEnabled: Bool = false

    // Difficulty captured when a round starts, so a round keeps its rules even if the setting changes.
    @State private var roundHardMode: Bool = false

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }
    @AppStorage(AppStorageKey.contextualTipsEnabled) private var contextualTipsEnabled = false

    // Daily
    /// Daily results are stored by day and read back by `GameStats`, so both use its day key.
    private var todayKey: String { GameStats.localDayKey(for: Date()) }
    private var dailyCompletedToday: Bool {
        UserDefaults.standard.string(forKey: AppStorageKey.wordleDailyCompletedDay) == todayKey
    }

    // Toggle for keyboard layout
    @State private var useABCLayout: Bool = false
    @State private var showsOnScreenKeyboard: Bool = true
    @State private var showsBoardCardSecond: Bool = false
    @State private var hardwareKeyboardConnected: Bool = false
    /// Height of the tip banner above the game (0 once dismissed), so the iPad layout
    /// leaves room for it.
    @State private var tipHeight: CGFloat = 0
    /// Height of the scoreboard on phones, measured so the board and keyboard can be sized
    /// to fit above the tab bar.
    @State private var compactScoreboardHeight: CGFloat = 0

    // timing for each round
    /// Solve time. It only runs while the app is in front, so time away doesn't count.
    @State private var roundClock = GameActiveClock()
    // store elapsed seconds for the last round to show in the bottom chip
    @State private var lastRoundElapsedSeconds: Int? = nil

    // confirmation for reveal
    @State private var confirmReveal: Bool = false

    // End-of-round result
    /// True when the round just finished raised the best streak for its mode.
    @State private var isNewBestStreak: Bool = false
    /// All-time wins by guess count for the round's mode, read once when the round ends.
    @State private var guessDistribution: [Int] = []

    // MARK: - Persistent WORD streak (overall, survives app relaunch)
    private let persistentStreak = PersistentGameStreak(game: "wordle")
    /// The Practice streak: solved Practice words in a row, kept until a Practice word is missed.
    private let practicePersistentStreak = PersistentGameStreak(game: "wordle", variant: "practice")
    private let practiceWordBagKey = AppStorageKey.wordlePracticeWordBag
    private let lastPracticeWordKey = AppStorageKey.wordleLastPracticeWord
    private let dailyWordAssignmentKey = AppStorageKey.wordleDailyWordAssignment
    private let recentDailyWordsKey = AppStorageKey.wordleRecentDailyWords
    private let recentDailyWordLimit = 365
    private let dailyProgressKey = AppStorageKey.wordleDailyProgress

    // MARK: - Spell-check language for guess validation
    #if canImport(UIKit)
    private static var spellCheckLanguage: String {
        let languages = UITextChecker.availableLanguages

        return languages.first {
            $0.replacingOccurrences(of: "-", with: "_")
                .caseInsensitiveCompare("en_US") == .orderedSame
        } ?? languages.first {
            $0.lowercased().hasPrefix("en")
        } ?? "en_US"
    }
    #endif

    // MARK: - Answer verse
    private struct VerseRefInfo: Sendable {
        let bookName: String
        let chapter: Int
        let verse: Int
        let text: String
        var display: String { "\(bookName) \(chapter):\(verse)" }
    }

    // The answer pool and a verse reference for each word.
    private struct AnswerBank: Sendable {
        let words: [String]
        let verseIndex: [String: VerseRefInfo]
    }

    // MARK: - Curated answers (WORDCuratedWordList.json)

    /// One entry in the bundled curated list; `verse_source` is editorial metadata and is ignored.
    private struct CuratedWord: Decodable, Sendable {
        let word: String
        let reference: String
        let verse: String
    }

    /// Hand-curated answers, each with a verse that contains the word. Nil when the file
    /// is missing or yields no usable entries.
    nonisolated private static let curatedAnswerBank: AnswerBank? = {
        guard let url = Bundle.main.url(forResource: "WORDCuratedWordList", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = PersistedDecoding.decode([CuratedWord].self, from: data, name: "WORDCuratedWordList.json") else {
            print("⚠️ WORDCuratedWordList.json could not be loaded or decoded.")
            return nil
        }

        var index: [String: VerseRefInfo] = [:]
        for entry in entries {
            let word = entry.word.uppercased()
            guard word.count == 5, word.allSatisfy({ alphabet.contains($0) }),
                  let ref = parseReference(entry.reference, text: entry.verse) else {
                print("⚠️ WORD: skipping curated entry \(entry.word) (\(entry.reference))")
                continue
            }
            index[word] = ref
        }
        guard !index.isEmpty else { return nil }
        return AnswerBank(words: index.keys.sorted(), verseIndex: index)
    }()

    /// Parses "Book C:V" (e.g. "1 Timothy 2:9", "Song of Solomon 8:7").
    nonisolated private static func parseReference(_ reference: String, text: String) -> VerseRefInfo? {
        guard let space = reference.lastIndex(of: " ") else { return nil }
        let bookName = String(reference[..<space])
        let parts = reference[reference.index(after: space)...].split(separator: ":")
        guard !bookName.isEmpty, parts.count == 2,
              let chapter = Int(parts[0]), let verse = Int(parts[1]) else { return nil }
        return VerseRefInfo(bookName: bookName, chapter: chapter, verse: verse, text: text)
    }

    /// Used only if the curated list is missing or unreadable. These words have no verse,
    /// so the end-of-round Reference button stays disabled.
    private static let fallbackAnswerBank = AnswerBank(
        words: ["JESUS", "GRACE", "FAITH", "ANGEL", "CROSS", "MOSES", "DAVID", "PEACE", "MERCY", "GLORY"],
        verseIndex: [:]
    )

    private static var answerBank: AnswerBank { curatedAnswerBank ?? fallbackAnswerBank }
    private static var filteredAnswerWords: [String] { answerBank.words }
    private static var verseIndex: [String: VerseRefInfo] { answerBank.verseIndex }
    /// Every curated answer is accepted as a guess, so names like MOSES aren't rejected
    /// by the spell checker.
    private static let curatedWordSet = Set(answerBank.words)

    /// Loads and indexes the bundled answer list before gameplay begins, off the main actor.
    private static func prewarmAnswerBank() async {
        _ = await Task.detached(priority: .userInitiated) {
            curatedAnswerBank
        }.value
    }

    // State for showing reference button and navigating
    @State private var roundRef: VerseRefInfo? = nil

    // Smart link style preview state
    @State private var showRefSheet: Bool = false
    @State private var selectedRef: ScriptureRef? = nil
    @State private var loadedPreview: (title: String, verses: [Verse])? = nil

  var body: some View {
    GeometryReader { geometry in
      let usesWideLayout = started && geometry.size.width >= 900
      let usesCompactPhoneLayout = started && geometry.size.width < 600
      let compactSizes = compactGameSizes(
        availableHeight: geometry.size.height
          - (contextualTipsEnabled && tipHeight > 0 ? tipHeight + 12 : 0)
      )
      let lettersInWord = Self.alphabet.filter {
        keyboardStates[$0] == .correct || keyboardStates[$0] == .present
      }
      let otherTriedLetters = Self.alphabet.filter { keyboardStates[$0] == .absent }

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

          if !started {
            startScreen()
          } else {
            #if canImport(UIKit)
              if hardwareKeyboardConnected {
              KeyCaptureRepresentable(
                onKey: { ch in tapLetter(ch) },
                onBackspace: { deleteLetter() },
                onEnter: {
                  if !roundOver, isCurrentRowFull() {
                    submitGuess()
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
              showsKeyboardCard: roundOver || showsOnScreenKeyboard,
              showsBoardCardSecond: showsBoardCardSecond,
              toggleKeyboardCard: {
                showsOnScreenKeyboard.toggle()
              },
              swapCards: {
                showsBoardCardSecond.toggle()
              }
            ) {
              GameScoreboardCard(
                currentCorrect: score,
                currentAnswered: answered,
                currentStreak: mode == .daily ? currentStreak : practiceStreak,
                game: .wordle,
                wordMode: roundHardMode ? .hard : .normal,
                style: usesWideLayout ? .dashboard : .compact
              )
              .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { compactScoreboardHeight = $0 }
            } board: {
              VStack(alignment: .trailing, spacing: 4) {
                boardView(
                  tileSize: usesWideLayout && !(roundOver || showsOnScreenKeyboard)
                    ? 68
                    : (usesCompactPhoneLayout ? compactSizes.tile : 48)
                )
              }
            } feedback: {
              VStack(spacing: 10) {
                // Once the round ends, the result card below the board covers the outcome.
                if !roundOver, let msg = message {
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
              .frame(height: usesCompactPhoneLayout && !roundOver ? Self.compactMessageHeight : nil)
            } letterTray: {
              WordTriedLettersCard(
                lettersInWord: lettersInWord,
                otherTriedLetters: otherTriedLetters
              )
            } inputControls: { wideKeyHeight in
              VStack(spacing: usesCompactPhoneLayout ? 6 : 10) {
                if roundOver {
                  endOfRoundActionArea()
                } else {
                  keyboardView(
                    keyHeight: wideKeyHeight ?? (usesCompactPhoneLayout ? compactSizes.key : 52)
                  )

                  if debugAutoWinEnabled {
                    Button("WIN") {
                      endRound(win: true)
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
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        if started {
          GameNavigationTitle(title: "Word", systemImage: "textformat.abc", tint: .mint)
        }
      }
      ToolbarItem(placement: .topBarTrailing) {
        if started && !roundOver {
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
      await Self.prewarmAnswerBank()
      isAnswerBankPrepared = true
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
      guard started, !roundOver else { return }
      if isActive {
        roundClock.resume()
      } else {
        roundClock.pause()
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
                guard !roundOver else { return }
                didWin = false
                endRound(win: false)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will reveal the answer and count this round as a loss.")
        }
        // Seed session streaks from persistent values so they survive navigation/relaunch
        .onAppear {
            // Daily streaks count consecutive solved days, derived from the synced solved-days map.
            currentStreak = GameStats.shared.wordleDailyWinStreak()
            currentBestStreak = max(currentBestStreak, persistentStreak.best)
            practiceStreak = practicePersistentStreak.current
            practiceBestStreak = practicePersistentStreak.best
        }
    }

    // MARK: - Start screen
    @ViewBuilder
    private func startScreen() -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            Text("Guess the 5‑letter word in 6 tries.\nUse the on‑screen keyboard or a connected keyboard.")
                .gameStartDescriptionStyle(title: "Word", systemImage: "textformat.abc", tint: .mint)

            GameSplashLaunchLayout(
                tint: .mint,
                isStartEnabled: isAnswerBankPrepared
                    && (mode != .daily || !dailyCompletedToday),
                startAction: { startNewRound(practice: mode == .practice) }
            ) {
                GameLobbyPreview(kind: .wordle)
            } configuration: {
                WordSetupControls(
                    mode: $mode,
                    hardModeEnabled: $hardModeEnabled
                )

                if mode == .daily && dailyCompletedToday {
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
                let allowsUnlimitedPlays = mode == .practice
                GameSplashFacts(
                    first: (mode.icon, String(localized: mode.title), String(localized: "Game type")),
                    second: (
                        hardModeEnabled ? "flame" : "circle",
                        hardModeEnabled ? String(localized: "Hard") : String(localized: "Normal"),
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

    // Compose the current row’s 5 letters by merging pinned letters at fixed indices
    // with the typed letters (currentInput) in the remaining slots, left-to-right.
    private func composedCurrentRow() -> [Character?] {
        var result: [Character?] = Array(repeating: nil, count: 5)
        guard pinned.indices.contains(rowIndex) else { return result }

        let pins = pinned[rowIndex]
        for c in result.indices where pins.indices.contains(c) {
            result[c] = pins[c]
        }
        var typed = Array(currentInput)
        for c in 0..<5 {
            if result[c] == nil, !typed.isEmpty {
                result[c] = typed.removeFirst()
            }
        }
        return result
    }

    private func isCurrentRowFull() -> Bool {
        guard !roundOver else { return false }
        let row = composedCurrentRow()
        return row.allSatisfy { $0 != nil }
    }

    // Find the next empty, unlocked column for normal left-to-right typing.
    private func nextAvailableColumn() -> Int? {
        guard pinned.indices.contains(rowIndex) else { return nil }

        let row = composedCurrentRow()
        for c in row.indices where pinned[rowIndex].indices.contains(c) {
            if pinned[rowIndex][c] == nil && row[c] == nil {
                return c
            }
        }
        return nil
    }

    // Remove the last non-pinned typed letter; locked letters stay in place.
    private func removeLastNonPinnedTypedLetter() {
        _ = currentInput.popLast()
    }

    // MARK: - Board
    private func boardView(tileSize: CGFloat) -> some View {
        WordleBoardView(
            guesses: guesses,
            evaluations: evaluations,
            activeRow: composedCurrentRow(),
            rowIndex: rowIndex,
            isRoundOver: roundOver,
            pinned: $pinned,
            nextInputColumn: nextAvailableColumn(),
            tileSize: tileSize,
            onReuseCorrectLetter: reuseCorrectLetter
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
            keyStates: keyboardStates,
            isRoundOver: roundOver,
            isCurrentRowFull: isCurrentRowFull(),
            canDelete: !currentInput.isEmpty,
            keyHeight: keyHeight,
            onLetter: tapLetter,
            onDelete: deleteLetter,
            onEnter: submitGuess
        )
    }

    // MARK: - Input helpers

    private func tapLetter(_ ch: Character) {
        guard !roundOver else { return }
        let up = Character(String(ch).uppercased())
        guard up.isLetter else { return }

        if nextAvailableColumn() != nil {
            currentInput.append(up)
            message = nil
        }
    }

    private func reuseCorrectLetter(_ letter: Character, at column: Int) {
        guard !roundOver, rowIndex < pinned.count, pinned[rowIndex].indices.contains(column) else { return }

        // Preserve letters already typed in their visible positions while replacing this column.
        let rowBeforePinning = composedCurrentRow()
        pinned[rowIndex][column] = letter
        currentInput = String(rowBeforePinning.indices.compactMap { index in
            guard pinned[rowIndex][index] == nil else { return nil }
            return rowBeforePinning[index]
        })
        message = nil
    }

    private func deleteLetter() {
        guard !roundOver else { return }
        // Remove last non-pinned typed letter only; do not clear pinned letters
        if currentInput.isEmpty {
            // Nothing typed to remove (all filled might be pinned); do nothing
            return
        }
        removeLastNonPinnedTypedLetter()
    }

    private func submitGuess() {
        guard !roundOver else { return }
        // Compose guess from pins + typed
        let row = composedCurrentRow()
        guard row.count == 5, row.allSatisfy({ $0 != nil }) else { return }
        let guess = String(row.compactMap { $0 }).uppercased()

        // Accept the target, any curated answer, or any correctly spelled 5-letter English word
        guard guess == target || Self.curatedWordSet.contains(guess) || isValidWord(guess) else {
            message = "Not in word list"
            return
        }

        // Hard Mode validation (must keep greens; must use yellows elsewhere)
        if roundHardMode, rowIndex > 0 {
            if let violation = hardModeViolation(for: guess) {
                message = violation
                return
            }
        }

        applyGuess(guess)

        if guess == target {
            endRound(win: true)
            return
        }
        if rowIndex >= 6 {
            endRound(win: false)
            return
        }
        // Prepare the next row and ensure its locked-letter slots are empty.
        currentInput = ""
        if rowIndex < pinned.count {
            pinned[rowIndex] = Array(repeating: nil, count: 5)
        }
        message = nil

        if mode == .daily {
            saveDailyProgress()
        }
    }

    /// Records a guess on the board, updates the keyboard colors, and advances to the next row.
    @discardableResult
    private func applyGuess(_ guess: String) -> [KeyState] {
        let eval = WordleRules.evaluate(guess: guess, against: target)
        evaluations[rowIndex] = eval
        guesses[rowIndex] = guess
        rowIndex += 1
        mergeKeyboardStates(guess: guess, evaluation: eval)
        return eval
    }

    // Update keyboard states with precedence
    private func mergeKeyboardStates(guess: String, evaluation: [KeyState]) {
        keyboardStates = WordleRules.mergedKeyboardStates(keyboardStates, guess: guess, evaluation: evaluation)
    }

    // MARK: - Rules
    // The game's rules live in `WordleRules` and `WordleWordPicker`, where they are tested.

    private func hardModeViolation(for guess: String) -> String? {
        WordleRules.hardModeViolation(for: guess, guesses: guesses, evaluations: evaluations, playedRows: rowIndex)
    }

    private var wordPicker: WordleWordPicker {
        WordleWordPicker(
            defaults: .standard,
            practiceBagKey: practiceWordBagKey,
            lastPracticeWordKey: lastPracticeWordKey,
            dailyAssignmentKey: dailyWordAssignmentKey,
            recentDailyWordsKey: recentDailyWordsKey,
            recentDailyWordLimit: recentDailyWordLimit
        )
    }

    private func nextPracticeWord() -> String {
        var generator = SystemRandomNumberGenerator()
        return wordPicker.nextPracticeWord(pool: Self.filteredAnswerWords, using: &generator)
    }

    /// Today's Daily word: picked at random the first time Daily is played each day and kept for the rest of that day.
    private func wordOfDay() -> String {
        var generator = SystemRandomNumberGenerator()
        return wordPicker.wordOfDay(pool: Self.filteredAnswerWords, dayKey: todayKey, using: &generator)
    }

    // MARK: - Daily progress
    // An unfinished Daily is saved after every guess, so leaving and returning resumes
    // the same board instead of granting a fresh set of guesses.
    private struct DailyProgress: Codable {
        let dayKey: String
        let word: String
        let hardMode: Bool
        let guesses: [String]
        let elapsedSeconds: Int
    }

    private func saveDailyProgress() {
        let elapsed = roundClock.elapsedSeconds()
        let progress = DailyProgress(
            dayKey: todayKey,
            word: target,
            hardMode: roundHardMode,
            guesses: Array(guesses.prefix(rowIndex)),
            elapsedSeconds: elapsed
        )
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: dailyProgressKey)
        }
    }

    /// Restores today's unfinished Daily, if any. Returns true when guesses were restored.
    @discardableResult
    private func restoreDailyProgress() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: dailyProgressKey),
              let progress = PersistedDecoding.decode(DailyProgress.self, from: data, key: dailyProgressKey, keepingUnreadableIn: .standard),
              progress.dayKey == todayKey,
              progress.word == target else {
            UserDefaults.standard.removeObject(forKey: dailyProgressKey)
            return false
        }

        // The round keeps the difficulty it was started with.
        roundHardMode = progress.hardMode
        roundClock.start(alreadyElapsed: Double(progress.elapsedSeconds))
        for guess in progress.guesses.prefix(6) where guess.count == 5 {
            applyGuess(guess)
        }

        // Shouldn't happen (finished rounds clear their progress), but never leave a solved board open.
        if guesses.prefix(rowIndex).contains(target) || rowIndex >= 6 {
            endRound(win: guesses.prefix(rowIndex).contains(target))
        }
        return !progress.guesses.isEmpty
    }

    // MARK: - Rounds
    private func startNewRound(practice: Bool) {
        roundHardMode = hardModeEnabled

        guesses = Array(repeating: "", count: 6)
        evaluations = Array(repeating: Array(repeating: .unknown, count: 5), count: 6)
        rowIndex = 0
        currentInput = ""
        didWin = false
        roundOver = false
        message = nil
        keyboardStates.removeAll()
        roundRef = nil
        isNewBestStreak = false

        // Reset locked letters.
        pinned = Array(repeating: Array(repeating: nil, count: 5), count: 6)

        // Start timing
        roundClock.start()
        lastRoundElapsedSeconds = nil

        if practice {
            target = nextPracticeWord()
        } else {
            target = wordOfDay()
            restoreDailyProgress()
        }

        started = true
    }

    private func endRound(win: Bool) {
        roundOver = true
        didWin = win
        // Clear current input to avoid duplicate rendering.
        currentInput = ""

        roundClock.pause()
        let elapsedSeconds = roundClock.elapsedSeconds()

        lastRoundElapsedSeconds = elapsedSeconds

        if win {
            let tries = rowIndex == 1 ? "1 guess" : "\(rowIndex) guesses"
            message = mode == .daily
                ? "You got it in \(tries)! See you tomorrow."
                : "You got it in \(tries)!"
        } else {
            // The answer box below shows the word, so the message only explains how the round ended.
            message = rowIndex < 6 ? "Word revealed." : "Out of guesses."
        }

        if mode == .daily {
            UserDefaults.standard.removeObject(forKey: dailyProgressKey)
            answered += 1

            if win {
                score += 1

                // Counts today plus the run of solved days immediately before it.
                let bestBefore = persistentStreak.best
                let streak = persistentStreak.recordWin(
                    reaching: GameStats.shared.wordleDailyWinStreak(treatingTodayAsSolved: true)
                )
                currentStreak = streak.current
                currentBestStreak = max(currentBestStreak, streak.best)
                isNewBestStreak = streak.best > bestBefore
            } else {
                // A Daily loss, including Reveal, ends the tracked streak.
                persistentStreak.reset()
                currentStreak = 0
            }

            GameStats.shared.recordWordleResult(
                type: .daily,
                mode: roundHardMode ? .hard : .normal,
                won: win,
                guesses: rowIndex,
                currentBestStreak: currentBestStreak
            )
            GameStats.shared.recordWordleTime(
                type: .daily,
                mode: roundHardMode ? .hard : .normal,
                won: win,
                elapsedSeconds: elapsedSeconds
            )
        } else {
            answered += 1

            if win {
                score += 1
                let bestBefore = practicePersistentStreak.best
                let streak = practicePersistentStreak.recordWin()
                practiceStreak = streak.current
                practiceBestStreak = streak.best
                isNewBestStreak = streak.best > bestBefore
            } else {
                // A Practice loss, including Reveal, ends the Practice streak.
                practicePersistentStreak.reset()
                practiceStreak = 0
            }

            GameStats.shared.recordWordleResult(
                type: .free,
                mode: roundHardMode ? .hard : .normal,
                won: win,
                guesses: rowIndex,
                currentBestStreak: practiceBestStreak
            )
            GameStats.shared.recordWordleTime(
                type: .free,
                mode: roundHardMode ? .hard : .normal,
                won: win,
                elapsedSeconds: elapsedSeconds
            )
        }

        roundRef = Self.verseIndex[target]
        guessDistribution = GameStats.shared.wordleWinGuessStats(type: mode == .daily ? .daily : .free).winsByGuess

        if mode == .daily {
            UserDefaults.standard.set(todayKey, forKey: AppStorageKey.wordleDailyCompletedDay)
            UserDefaults.standard.set(target, forKey: AppStorageKey.wordleDailyTarget)
            // Push daily flags to iCloud KVS so other devices see completion/target
            iCloudSyncCoordinator.shared.pushKey("wordleDailyCompletedDay")
            iCloudSyncCoordinator.shared.pushKey("wordleDailyTarget")

            // Persist a per-day result summary for the Games list row
            let defaults = UserDefaults.standard
            let key = AppStorageKey.wordleDailyResultMap
            struct DailyResult: Codable { let won: Bool; let guesses: Int; let elapsed: Int; let word: String }
            var map: [String: DailyResult] = [:]
            if let data = defaults.data(forKey: key),
               let decoded = PersistedDecoding.decode([String: DailyResult].self, from: data, key: key, keepingUnreadableIn: defaults) {
                map = decoded
            }
            map[todayKey] = DailyResult(won: win, guesses: rowIndex, elapsed: elapsedSeconds, word: target)
            if let data = try? JSONEncoder().encode(map) {
                defaults.set(data, forKey: key)
                // Mirror to iCloud KVS so other devices see the same-day result
                iCloudSyncCoordinator.shared.pushKey(key)
            }

            // Nudge any listeners that might want to update immediately
            NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
        }
    }

    // MARK: - Word validity (system dictionary)
    private func isValidWord(_ uppercasedWord: String) -> Bool {
        let lower = uppercasedWord.lowercased()
        guard lower.count == 5, lower.unicodeScalars.allSatisfy({ CharacterSet.lowercaseLetters.contains($0) }) else {
            return false
        }
        #if canImport(UIKit)
        let lang = Self.spellCheckLanguage
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: lower.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(in: lower, range: range, startingAt: 0, wrap: false, language: lang)
        return misspelled.location == NSNotFound
        #else
        return true
        #endif
    }

    // MARK: - Reference preview presentation
    private func presentReferencePreview(_ ref: VerseRefInfo) {
        let sr = ScriptureRef(bookName: ref.bookName, chapter: ref.chapter, startVerse: ref.verse, endVerse: nil)
        selectedRef = sr
        loadedPreview = nil
        showRefSheet = true
    }

    // MARK: - End-of-round result

    private var resultTitle: String {
        if didWin {
            return rowIndex == 1 ? String(localized: "Solved in 1 guess") : String(localized: "Solved in \(rowIndex) guesses")
        }
        return rowIndex < 6 ? String(localized: "Word revealed") : String(localized: "Out of guesses")
    }

    private var resultFacts: [GameSplashFacts.Fact] {
        [
            ("square.grid.3x2", didWin ? "\(rowIndex)/6" : "X/6", String(localized: "Guesses")),
            ("stopwatch", lastRoundElapsedSeconds.map(formatElapsed) ?? "—", String(localized: "Time")),
            (mode.icon, String(localized: mode.title), String(localized: "Puzzle")),
            (roundHardMode ? "flame" : "circle", roundHardMode ? String(localized: "Hard") : String(localized: "Normal"), String(localized: "Mode"))
        ]
    }

    private var resultStreak: GamePuzzleStreak {
        mode == .daily
            ? GamePuzzleStreak(current: currentStreak, best: currentBestStreak, isNewBest: isNewBestStreak)
            : GamePuzzleStreak(current: practiceStreak, best: practiceBestStreak, isNewBest: isNewBestStreak)
    }

    private func resultCard() -> some View {
        GamePuzzleResultCard(
            title: resultTitle,
            systemImage: didWin ? "checkmark.seal.fill" : (rowIndex < 6 ? "eye.fill" : "xmark.octagon.fill"),
            tint: didWin ? .green : .red,
            facts: resultFacts,
            streak: resultStreak,
            scripture: roundRef.map { ref in
                GamePuzzleScripture(reference: ref.display, text: ref.text) {
                    presentReferencePreview(ref)
                }
            }
        ) {
            answerTiles

            if guessDistribution.contains(where: { $0 > 0 }) {
                GamePuzzleResultSection(title: "Guess Distribution", systemImage: "chart.bar.fill") {
                    WordGuessDistributionView(
                        winsByGuess: guessDistribution,
                        highlightedGuess: didWin ? rowIndex : nil,
                        tint: .green
                    )
                }
            }
        }
    }

    /// The answer spelled out in tiles, green when solved and red otherwise.
    private var answerTiles: some View {
        HStack(spacing: 6) {
            ForEach(Array(target.uppercased().enumerated()), id: \.offset) { _, letter in
                Text(String(letter))
                    .font(.title2.weight(.heavy).monospaced())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        (didWin ? Color.green : Color.red).opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Answer: \(target)")
    }

    /// Midnight tonight, when the next Daily word is available.
    private var nextDailyDate: Date {
        let calendar = Calendar.autoupdatingCurrent
        let startOfToday = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday.addingTimeInterval(86_400)
    }

    // MARK: - End-of-round action area (replaces keyboard)
    @ViewBuilder
    private func endOfRoundActionArea() -> some View {
        VStack(spacing: 12) {
            resultCard()

            HStack(spacing: 12) {
                ShareLink(item: shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(ModernPillButtonStyle(tint: .mint))

                if mode == .practice {
                    Button("Next Word", systemImage: "arrow.right") {
                        startNewRound(practice: true)
                    }
                    .buttonStyle(GameProminentButtonStyle(tint: .mint))
                } else if dailyCompletedToday {
                    Label {
                        Text("Next word in \(Text(nextDailyDate, style: .relative))")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "calendar.badge.clock")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                } else {
                    Button("Play Again", systemImage: "arrow.clockwise") {
                        startNewRound(practice: false)
                    }
                    .buttonStyle(GameProminentButtonStyle(tint: .mint))
                }
            }
        }
    }

    /// Spoiler-free result summary with an emoji grid of the guesses.
    private var shareText: String {
        let title = mode == .daily ? "Word Daily \(todayKey)" : "Word Practice"
        let score = didWin ? "\(rowIndex)/6" : "X/6"
        let difficulty = roundHardMode ? " (Hard)" : ""
        let grid = evaluations.prefix(rowIndex).map { row in
            row.map { state -> String in
                switch state {
                case .correct: "🟩"
                case .present: "🟨"
                case .absent, .unknown: "⬛"
                }
            }.joined()
        }.joined(separator: "\n")
        return "\(title) \(score)\(difficulty)\n\n\(grid)"
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
