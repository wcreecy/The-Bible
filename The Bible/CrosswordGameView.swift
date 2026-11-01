import SwiftUI

struct CrosswordGameView: View {
    static let title: LocalizedStringKey = "Crossword"
    static let systemImage = "squareshape.split.3x3"
    static let tint = Color.orange.mix(with: .red, by: 0.35)

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var vm = CrosswordGameViewModel()
    @State private var confirmReveal = false
    @State private var checkMessage: String?
    @State private var previewRef: ScriptureRef?
    @FocusState private var isBoardFocused: Bool

    private static let scrollTopID = "crosswordTop"
    private var isPad: Bool { horizontalSizeClass == .regular }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    switch vm.phase {
                    case .setup:
                        startScreen
                    case .loading:
                        ProgressView("Building your puzzle…")
                            .frame(maxWidth: .infinity, minHeight: 300)
                    case .unavailable:
                        unavailableView
                    case .playing, .finished:
                        if let puzzle = vm.puzzle {
                            gameArea(puzzle)
                        }
                    }
                }
                .padding()
                .id(Self.scrollTopID)
            }
            .onChange(of: vm.phase) { _, phase in
                if phase != .finished { proxy.scrollTo(Self.scrollTopID, anchor: .top) }
            }
        }
        .tabBarContentClearance()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.phase != .setup {
                    GameNavigationTitle(title: Self.title, systemImage: Self.systemImage, tint: Self.tint)
                }
            }
        }
        .confirmationDialog("Reveal the puzzle?", isPresented: $confirmReveal, titleVisibility: .visible) {
            Button("Reveal", role: .destructive) { vm.revealPuzzle() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This fills in every answer and counts this puzzle as a loss.")
        }
        .sheet(item: $previewRef) { ref in
            CrosswordReferenceSheet(ref: ref)
        }
    }

    // MARK: - Start

    private var startScreen: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)

            Text("Solve a crossword of Bible people, places, and words.")
                .gameStartDescriptionStyle(title: "Crossword", systemImage: Self.systemImage, tint: Self.tint)

            GameSplashLaunchLayout(
                tint: Self.tint,
                experienceLevel: Binding(
                    get: { vm.difficulty.experienceLevel },
                    set: { vm.difficulty = .init(experienceLevel: $0) }
                ),
                experienceDetails: GameExperienceDetails(
                    learn: "A 9×9 board of familiar names and words.",
                    standard: "An 11×11 board with a broader mix of clues.",
                    challenge: "A 13×13 board with the toughest clues."
                ),
                startAction: startPuzzle
            ) {
                GameLobbyPreview(kind: .crossword)
            } configuration: {
                Text("Tap a square to choose it, and tap it again to switch between Across and Down.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } facts: {
                GameSplashFacts(
                    first: ("puzzlepiece.extension", String(localized: "1 puzzle"), String(localized: "This session")),
                    second: ("square.grid.3x3", "\(vm.difficulty.boardSize)×\(vm.difficulty.boardSize)", String(localized: "Board")),
                    third: ("lightbulb", String(localized: "Letter & word"), String(localized: "Hints")),
                    fourth: ("flame", "\(vm.currentStreak)", String(localized: "Current streak"))
                )
            }

            Spacer(minLength: 24)
        }
        .gameStartScreenStyle()
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Puzzle Unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text("A crossword couldn’t be built from the clue list.")
            )
            Button("Try Again", systemImage: "arrow.clockwise", action: startPuzzle)
                .buttonStyle(GameProminentButtonStyle(tint: Self.tint))
            Button("Change Settings") { vm.changeSettings() }
                .buttonStyle(.bordered)
        }
    }

    private func startPuzzle() {
        Task {
            await vm.start()
            isBoardFocused = true
        }
    }

    // MARK: - Playing

    @ViewBuilder
    private func gameArea(_ puzzle: CrosswordPuzzle) -> some View {
        if isPad {
            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 12) {
                    if vm.phase == .playing { clueBar }
                    board(puzzle)
                    if vm.phase == .playing {
                        hintBar
                        keyboard
                    }
                }
                .frame(maxWidth: 560)

                VStack(spacing: 16) {
                    if vm.phase == .finished {
                        resultCard(puzzle)
                    } else {
                        clueList(puzzle)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 12) {
                if vm.phase == .playing { clueBar }
                board(puzzle)
                if vm.phase == .playing {
                    hintBar
                    keyboard
                    clueList(puzzle)
                } else {
                    resultCard(puzzle)
                }
            }
        }
    }

    private func board(_ puzzle: CrosswordPuzzle) -> some View {
        CrosswordBoardView(
            puzzle: puzzle,
            guesses: vm.guesses,
            revealedCells: vm.revealedCells,
            selectedCell: vm.selectedCell,
            selectedDirection: vm.direction,
            wrongCells: vm.wrongCells,
            onTapCell: { cell in
                vm.select(cell)
                isBoardFocused = true
            }
        )
        // A hardware keyboard types straight into the board.
        .focusable(vm.phase == .playing)
        .focused($isBoardFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down, action: handleKeyPress)
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .delete:
            vm.deleteBackward()
        case .tab:
            vm.moveToEntry(offset: press.modifiers.contains(.shift) ? -1 : 1)
        case .space:
            vm.toggleDirection()
        default:
            guard let letter = press.characters.first, letter.isLetter else { return .ignored }
            vm.type(letter)
        }
        return .handled
    }

    private var clueBar: some View {
        HStack(spacing: 8) {
            Button("Previous clue", systemImage: "chevron.left") { vm.moveToEntry(offset: -1) }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)

            Button {
                vm.toggleDirection()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    if let entry = vm.currentEntry {
                        Text(entryLabel(entry))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Self.tint)
                        Text(entry.clue)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Switches between Across and Down")

            Button("Next clue", systemImage: "chevron.right") { vm.moveToEntry(offset: 1) }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
        }
        .padding(10)
        .background(Self.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var hintBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button("Letter", systemImage: "character.cursor.ibeam") { vm.revealLetter() }
                    .disabled(!vm.canUseLetterHint)
                Button("Word", systemImage: "text.cursor") { vm.revealWord() }
                    .disabled(!vm.canUseWordHint)
                Button("Check", systemImage: "checkmark.circle") {
                    let wrong = vm.checkPuzzle()
                    checkMessage = wrong == 0
                        ? String(localized: "No mistakes so far.")
                        : String(localized: "\(wrong) letters to fix.")
                }
                Button("Reveal", systemImage: "eye") { confirmReveal = true }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(Self.tint)
            .controlSize(.small)

            if vm.isFilledWithMistakes {
                Text("The board is full, but some letters are wrong. Tap Check to find them.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else if let checkMessage {
                Text(checkMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: vm.guesses) { checkMessage = nil }
    }

    private var keyboard: some View {
        CrosswordKeyboardView(
            onLetter: { vm.type($0) },
            onDelete: { vm.deleteBackward() }
        )
    }

    private func clueList(_ puzzle: CrosswordPuzzle) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            clueSection("Across", entries: puzzle.acrossEntries)
            clueSection("Down", entries: puzzle.downEntries)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clueSection(_ title: LocalizedStringKey, entries: [CrosswordPuzzle.Entry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            ForEach(entries) { entry in
                let isCurrent = entry == vm.currentEntry
                let isFilled = entry.cells.allSatisfy { vm.guesses[$0] != nil }
                Button {
                    vm.select(entry)
                    isBoardFocused = true
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(entry.number)")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .frame(minWidth: 24, alignment: .trailing)
                        Text(entry.clue)
                            .font(.subheadline)
                            .strikethrough(isFilled, color: .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(isFilled ? .secondary : .primary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .background(isCurrent ? Self.tint.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("\(entryLabel(entry)): \(entry.clue)"))
                .accessibilityAddTraits(isCurrent ? .isSelected : [])
            }
        }
    }

    private func entryLabel(_ entry: CrosswordPuzzle.Entry) -> String {
        switch entry.direction {
        case .across: String(localized: "\(entry.number) Across")
        case .down: String(localized: "\(entry.number) Down")
        }
    }

    // MARK: - Results

    private func resultCard(_ puzzle: CrosswordPuzzle) -> some View {
        let solved = vm.outcome == .solved
        let hints = vm.letterHintsUsed + vm.wordHintsUsed
        return VStack(spacing: 12) {
            GamePuzzleResultCard(
                title: solved ? String(localized: "Puzzle solved!") : String(localized: "Puzzle revealed"),
                subtitle: solved && hints == 0 ? String(localized: "No hints needed.") : nil,
                systemImage: solved ? "checkmark.seal.fill" : "eye.fill",
                tint: solved ? .green : Self.tint,
                facts: [
                    ("timer", GameTimeFormat.short(seconds: vm.elapsedSeconds), String(localized: "Time")),
                    ("text.word.spacing", "\(puzzle.entries.count)", String(localized: "Answers")),
                    ("character.cursor.ibeam", "\(vm.letterHintsUsed)", String(localized: "Letter hints")),
                    ("text.cursor", "\(vm.wordHintsUsed)", String(localized: "Word hints")),
                ],
                streak: GamePuzzleStreak(current: vm.currentStreak)
            ) {
                GamePuzzleResultSection(title: "Answers", systemImage: "book.closed", tint: Self.tint) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(puzzle.entries) { entry in
                            answerRow(entry)
                        }
                    }
                }
            }

            Button("New Puzzle", systemImage: "arrow.clockwise", action: startPuzzle)
                .buttonStyle(GameProminentButtonStyle(tint: Self.tint))
            Button("Change Settings") { vm.changeSettings() }
                .buttonStyle(.bordered)
        }
    }

    private func answerRow(_ entry: CrosswordPuzzle.Entry) -> some View {
        let solvedByPlayer = vm.wasSolvedWithoutHints(entry)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(entryLabel(entry))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(entry.answer)
                    .font(.subheadline.weight(.bold).monospaced())
                if !solvedByPlayer {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .accessibilityLabel("Revealed")
                }
            }
            Text(entry.clue)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            if let ref = BibleReferenceLinker.parse(entry.reference) {
                Button(entry.reference, systemImage: "book") { previewRef = ref }
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderless)
                    .tint(Self.tint)
                    .accessibilityHint("Shows the verse")
            } else {
                Text(entry.reference)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Keyboard

/// An on-screen QWERTY keyboard for typing into the crossword.
private struct CrosswordKeyboardView: View {
    let onLetter: (Character) -> Void
    let onDelete: () -> Void

    private let rows: [[Character]] = [Array("QWERTYUIOP"), Array("ASDFGHJKL"), Array("ZXCVBNM")]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 4) {
                    ForEach(rows[index], id: \.self) { letter in
                        Button(String(letter)) { onLetter(letter) }
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
                    }
                    if index == rows.count - 1 {
                        Button(action: onDelete) {
                            Image(systemName: "delete.left")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(GameKeyButtonStyle(tint: .red))
                        .frame(maxWidth: 64)
                        .accessibilityLabel("Delete")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Reference

private struct CrosswordReferenceSheet: View {
    let ref: ScriptureRef
    @Environment(\.dismiss) private var dismiss
    @State private var content: (title: String, verses: [Verse])?
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let content {
                        ScripturePreviewCard(content: content, refContext: ref)
                    } else if didLoad {
                        ContentUnavailableView("No reference available", systemImage: "book")
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            content = await BibleReferenceLinker.loadVersesEnsuringLoaded(for: ref)
            didLoad = true
        }
    }
}

#Preview {
    NavigationStack { CrosswordGameView() }
}
