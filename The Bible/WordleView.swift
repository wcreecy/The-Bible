import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct WordleView: View {
    // MARK: - Mode
    enum Mode: String, CaseIterable, Identifiable {
        case daily = "Daily"
        case freePlay = "Free Play"
        var id: String { rawValue }
    }

    // MARK: - Key state
    private enum KeyState: Int {
        case unknown = 0
        case absent   // gray
        case present  // yellow
        case correct  // green

        // Keep the “max” precedence when merging states (correct > present > absent > unknown)
        static func merged(_ a: KeyState, _ b: KeyState) -> KeyState {
            return (a.rawValue >= b.rawValue) ? a : b
        }

        var tint: Color {
            switch self {
            case .unknown: return .blue
            case .absent:  return .gray
            case .present: return .yellow
            case .correct: return .green
            }
        }
    }

    // MARK: - State
    @State private var started: Bool = false
    @State private var mode: Mode = .freePlay

    @State private var target: String = ""
    @State private var guesses: [String] = Array(repeating: "", count: 6)
    @State private var evaluations: [[KeyState]] = Array(repeating: Array(repeating: .unknown, count: 5), count: 6)
    @State private var rowIndex: Int = 0
    @State private var currentInput: String = ""
    @State private var didWin: Bool = false
    @State private var roundOver: Bool = false
    @State private var message: String? = nil
    @State private var keyboardStates: [Character: KeyState] = [:]

    // NEW: selected tile (row, col) for pinning — active row only
    @State private var selectedCell: (row: Int, col: Int)? = nil
    // NEW: pinned letters (locked) per row/col; non-nil means locked until cleared via 'x'
    @State private var pinned: [[Character?]] = Array(repeating: Array(repeating: nil, count: 5), count: 6)

    // Session stats (for the scoreboard’s Current section)
    @State private var score: Int = 0
    @State private var answered: Int = 0
    @State private var currentStreak: Int = 0
    @State private var currentBestStreak: Int = 0

    // NEW: Debug flag to allow replaying Daily Wordle (matches Settings/Games)
    @AppStorage("wordleAllowDailyReplay") private var wordleAllowDailyReplay: Bool = false

    // NEW: Hard Mode toggle (persisted locally; stats still aggregate with normal mode)
    @AppStorage("wordleHardModeEnabled") private var hardModeEnabled: Bool = false

    // All-time (per mode) — unchanged: still per-type for the scoreboard
    private var allTimeSuffix: String { mode == .daily ? "daily" : "free" }
    private var allTimeCorrect: Int { UserDefaults.standard.integer(forKey: "wordleAllTimeCorrect_\(allTimeSuffix)") }
    private var allTimeAnswered: Int { UserDefaults.standard.integer(forKey: "wordleAllTimeAnswered_\(allTimeSuffix)") }
    private var allTimeBestStreak: Int { UserDefaults.standard.integer(forKey: "wordleAllTimeBestStreak_\(allTimeSuffix)") }

    // Daily
    private var todayKey: String { Self.localDayKey(for: Date()) }
    private var dailyCompletedToday: Bool {
        UserDefaults.standard.string(forKey: "wordleDailyCompletedDay") == todayKey
    }

    // Toggle for keyboard layout
    @State private var useABCLayout: Bool = false

    // NEW: timing for each round
    @State private var roundStartAt: Date? = nil
    // NEW: store elapsed seconds for the last round to show in the bottom chip
    @State private var lastRoundElapsedSeconds: Int? = nil

    // NEW: confirmation for reveal
    @State private var confirmReveal: Bool = false

    // MARK: - Helpers for tokenization
    private static func sanitizeLetters(_ s: String) -> String {
        // Keep only A–Z letters; replace everything else with spaces
        String(s.map { ch -> Character in
            if let u = ch.unicodeScalars.first, ch.unicodeScalars.count == 1, u.value >= 65 && u.value <= 90 {
                return ch
            } else {
                return " "
            }
        })
    }

    private static func tokens5(from uppercasedVerse: String) -> [String] {
        let sanitized = sanitizeLetters(uppercasedVerse)
        return sanitized.split(separator: " ").compactMap { tok in
            tok.count == 5 ? String(tok) : nil
        }
    }

    private static func verseContainsWord(_ verseText: String, word: String) -> Bool {
        let upper = word.uppercased()
        let toks = tokens5(from: verseText.uppercased())
        return toks.contains(upper)
    }

    // MARK: - Answer pool from KJV (5-letter A–Z words, filtered by spell checker when available)
    private static let kjvAnswerWords: [String] = {
        var set = Set<String>() // uppercase tokens
        for book in BibleData.books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    let upper = verse.text.uppercased()
                    for token in tokens5(from: upper) {
                        set.insert(token)
                    }
                }
            }
        }

        #if canImport(UIKit)
        let lang = UITextChecker.availableLanguages.first(where: { $0.hasPrefix("en") }) ?? "en_US"
        let checker = UITextChecker()
        func passesSpellCheck(_ upper: String) -> Bool {
            let lower = upper.lowercased()
            let range = NSRange(location: 0, length: lower.utf16.count)
            let miss = checker.rangeOfMisspelledWord(in: lower, range: range, startingAt: 0, wrap: false, language: lang)
            return miss.location == NSNotFound
        }
        let filtered = set.filter { passesSpellCheck($0) }
        let sortedFiltered = filtered.sorted()
        if !sortedFiltered.isEmpty {
            return sortedFiltered
        } else {
            let fallback = ["JESUS","GRACE","FAITH","ANGEL","CROSS","ABRAM","SARAH","JONAH","MOSES","DAVID","SALEM","TITUS","JAMES","PETER","JUDAH"]
            let fbFiltered = fallback.filter { passesSpellCheck($0) }
            return fbFiltered.isEmpty ? fallback : fbFiltered
        }
        #else
        let sorted = set.sorted()
        return sorted.isEmpty ? ["JESUS","GRACE","FAITH","ANGEL","CROSS","ABRAM","SARAH","JONAH","MOSES","DAVID","SALEM","TITUS","JAMES","PETER","JUDAH"] : sorted
        #endif
    }()

    // MARK: - Verse index (random occurrence for each 5-letter word) — exact tokens only
    private struct VerseRefInfo {
        let bookName: String
        let chapter: Int
        let verse: Int
        let text: String
        var display: String { "\(bookName) \(chapter):\(verse)" }
    }

    private static let verseIndex: [String: VerseRefInfo] = {
        var map: [String: VerseRefInfo] = [:]
        var counts: [String: Int] = [:]
        let allowed = Set(kjvAnswerWords)
        for book in BibleData.books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    let upper = verse.text.uppercased()
                    for token in tokens5(from: upper) {
                        guard allowed.contains(token) else { continue }
                        counts[token, default: 0] += 1
                        let k = counts[token]!
                        if Int.random(in: 1...k) == 1 {
                            map[token] = VerseRefInfo(bookName: book.name, chapter: chapter.number, verse: verse.number, text: verse.text)
                        }
                    }
                }
            }
        }
        return map
    }()

    private static let filteredAnswerWords: [String] = {
        let pool = kjvAnswerWords
        let filtered = pool.filter { verseIndex[$0] != nil }
        return filtered.isEmpty ? pool : filtered
    }()

    private static func findExactOccurrence(for word: String) -> VerseRefInfo? {
        let target = word.uppercased()
        for book in BibleData.books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    if tokens5(from: verse.text.uppercased()).contains(target) {
                        return VerseRefInfo(bookName: book.name, chapter: chapter.number, verse: verse.number, text: verse.text)
                    }
                }
            }
        }
        return nil
    }

    // State for showing reference button and navigating
    @State private var roundRef: VerseRefInfo? = nil

    // Smart link style preview state
    @State private var showRefSheet: Bool = false
    @State private var selectedRef: ScriptureRef? = nil
    @State private var loadedPreview: (title: String, verses: [Verse])? = nil

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 12) {
                if !started {
                    startScreen()
                } else {
                    #if canImport(UIKit)
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
                    #endif

                    GameScoreboardCard(
                        currentCorrect: score,
                        currentAnswered: answered,
                        currentStreak: currentStreak,
                        allTimeCorrect: allTimeCorrect,
                        allTimeAnswered: allTimeAnswered,
                        allTimeBestStreak: allTimeBestStreak
                    )
                    .padding(.horizontal)

                    boardView()
                        .padding(.horizontal)

                    if !roundOver, let msg = message {
                        Text(msg)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.top, 4)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if roundOver {
                        answerHighlightView()
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }

                    if roundOver {
                        endOfRoundActionArea()
                            .padding(.horizontal)
                            .padding(.top, 6)
                    } else {
                        keyboardView()
                            .padding(.horizontal)

                        HStack {
                            Button(action: {
                                submitGuess()
                            }) {
                                Label("Enter", systemImage: "return")
                                    .labelStyle(.titleAndIcon)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
                            .disabled(roundOver || !isCurrentRowFull())
                            .accessibilityLabel("Enter")
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)

                        HStack {
                            Button(role: .destructive, action: {
                                guard !roundOver else { return }
                                confirmReveal = true
                            }) {
                                Label("Reveal Word", systemImage: "eye")
                                    .labelStyle(.titleAndIcon)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GameKeyButtonStyle(tint: .red))
                            .disabled(roundOver)
                            .accessibilityLabel("Reveal Word. Counts as a loss.")
                        }
                        .padding(.horizontal)
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 6)
        }
        .navigationTitle("WORD")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRefSheet, onDismiss: {
            selectedRef = nil
            loadedPreview = nil
        }) {
            NavigationStack {
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
    }

    // MARK: - Start screen
    @ViewBuilder
    private func startScreen() -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            Image(systemName: "square.grid.3x3")
                .font(.largeTitle)
                .foregroundStyle(.mint)

            Text("WORD")
                .font(.title2.bold())

            Text("Guess the 5‑letter word in 6 tries.\nUse the on‑screen keyboard or a connected keyboard.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Toggle(isOn: $hardModeEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hard Mode")
                        .font(.headline)
                    Text("Must keep green letters fixed and include yellow letters in later guesses.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(.orange)
            .padding(.horizontal)

            if mode == .daily && dailyCompletedToday && !wordleAllowDailyReplay {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Daily completed")
                            .font(.subheadline.weight(.semibold))
                        Text("You’ve completed today’s daily. Come back tomorrow.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.yellow.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Daily completed. You’ve completed today’s daily. Come back tomorrow.")
            }

            Button("Start") {
                startNewRound(freePlay: mode == .freePlay)
            }
            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            .controlSize(.large)
            .frame(maxWidth: 240)
            .disabled(mode == .daily && dailyCompletedToday && !wordleAllowDailyReplay)

            Spacer(minLength: 24)
        }
        .padding()
    }

    // MARK: - Board helpers (composition with pinned letters)

    // Compose the current row’s 5 letters by merging pinned letters at fixed indices
    // with the typed letters (currentInput) in the remaining slots, left-to-right.
    private func composedCurrentRow() -> [Character?] {
        var result: [Character?] = Array(repeating: nil, count: 5)
        let pins = pinned[rowIndex]
        for c in 0..<5 {
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

    // Find next empty non-pinned column (left to right) for typing when nothing is selected
    private func nextAvailableColumn() -> Int? {
        let row = composedCurrentRow()
        for c in 0..<5 {
            if pinned[rowIndex][c] == nil && row[c] == nil {
                return c
            }
        }
        return nil
    }

    // Remove the last non-pinned typed letter (right to left)
    private func removeLastNonPinnedTypedLetter() {
        // Build which indices are filled by typed letters (not pinned)
        let pins = pinned[rowIndex]
        var typedIndices: [Int] = []
        var typed = Array(currentInput)
        // Walk columns left to right; when not pinned and slot is empty -> will be filled by next typed char
        // To reverse-map which columns are typed, we reconstruct composition and track where typed landed.
        var result: [Character?] = Array(repeating: nil, count: 5)
        for c in 0..<5 {
            if let p = pins[c] {
                result[c] = p
            } else if !typed.isEmpty {
                result[c] = typed.removeFirst()
                typedIndices.append(c)
            }
        }
        guard let lastTypedCol = typedIndices.last else { return }
        // Remove the last typed char from currentInput (popLast)
        if !currentInput.isEmpty {
            _ = currentInput.popLast()
        }
        // If the selection is on a pinned cell, keep it; otherwise update selection to the removed cell for clarity
        if selectedCell?.row == rowIndex, let sel = selectedCell, pinned[rowIndex][sel.col] == nil {
            selectedCell = (rowIndex, lastTypedCol)
        }
    }

    // MARK: - Board
    @ViewBuilder
    private func boardView() -> some View {
        VStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(0..<5, id: \.self) { c in
                        let ch: String = {
                            if r < rowIndex {
                                let g = guesses[r]
                                return c < g.count ? String(g[g.index(g.startIndex, offsetBy: c)]) : ""
                            } else if r == rowIndex && !roundOver {
                                let row = composedCurrentRow()
                                if let letter = row[c] {
                                    return String(letter)
                                } else {
                                    return ""
                                }
                            } else {
                                return ""
                            }
                        }()
                        let state: KeyState = (r < rowIndex) ? evaluations[r][c] : .unknown
                        tile(letter: ch, state: state, row: r, col: c)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !roundOver, r == rowIndex else { return }

                                // NEW: Toggle off if tapping the already-selected cell
                                if let sel = selectedCell, sel.row == r, sel.col == c {
                                    selectedCell = nil
                                    return
                                }

                                // NEW: If any selection exists and the tapped cell is blank, exit locked mode
                                if selectedCell != nil, ch.isEmpty {
                                    selectedCell = nil
                                    return
                                }

                                // Default behavior: select this cell
                                selectedCell = (row: r, col: c)
                            }
                    }
                }
            }
        }
    }

    private func tile(letter: String, state: KeyState, row: Int, col: Int) -> some View {
        let isPinnedHere: Bool = (row < pinned.count && col < pinned[row].count) ? (pinned[row][col] != nil) : false
        let isSelected: Bool = (selectedCell?.row == row && selectedCell?.col == col)

        let bg: Color = {
            switch state {
            case .unknown: return Color(.secondarySystemBackground)
            case .absent:  return .gray.opacity(0.35)
            case .present: return .yellow.opacity(0.45)
            case .correct: return .green.opacity(0.45)
            }
        }()
        let border: Color = {
            if row == rowIndex && !roundOver && isSelected {
                return Color.accentColor.opacity(0.9)
            }
            switch state {
            case .unknown: return Color.primary.opacity(0.08)
            case .absent:  return .gray.opacity(0.55)
            case .present: return .yellow.opacity(0.65)
            case .correct: return .green.opacity(0.65)
            }
        }()

        return ZStack(alignment: .topTrailing) {
            Text(letter)
                .font(.title2.weight(.bold))
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(bg))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(border, lineWidth: isSelected ? 2 : 1))

            // Show small 'x' to clear only for pinned cells in the active row during play
            if row == rowIndex, !roundOver, isPinnedHere {
                Button(action: {
                    pinned[row][col] = nil
                    // Keep selection on this cell to make it easy to type a replacement
                    selectedCell = (row, col)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear pinned letter")
            }
        }
        .foregroundStyle(.primary)
        .monospaced()
    }

    // MARK: - On-screen keyboard
    @ViewBuilder
    private func keyboardView() -> some View {
        let row1 = Array(useABCLayout ? "ABCDEFGHIJ" : "QWERTYUIOP")
        let row2 = Array(useABCLayout ? "KLMNOPQRS" : "ASDFGHJKL")
        let row3 = Array(useABCLayout ? "TUVWXYZ" : "ZXCVBNM")

        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(row1, id: \.self) { ch in
                    keyButton(for: ch)
                        .disabled(roundOver || isCurrentRowFull())
                }
            }
            HStack(spacing: 6) {
                ForEach(row2, id: \.self) { ch in
                    keyButton(for: ch)
                        .disabled(roundOver || isCurrentRowFull())
                }
            }
            HStack(spacing: 6) {
                Button(action: { useABCLayout.toggle() }) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
                .disabled(roundOver)
                .accessibilityLabel(useABCLayout ? "Switch to QWERTY layout" : "Switch to ABC layout")

                ForEach(row3, id: \.self) { ch in
                    keyButton(for: ch)
                        .disabled(roundOver || isCurrentRowFull())
                }

                Button(action: { deleteLetter() }) {
                    Image(systemName: "delete.left")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
                .disabled(roundOver || currentInput.isEmpty && !hasAnyTypedInCurrentRow())
                .accessibilityLabel("Backspace")
            }
        }
        .accessibilityElement(children: .contain)
        .padding(.top, 6)
    }

    private func hasAnyTypedInCurrentRow() -> Bool {
        // True if any non-pinned slot is filled by typed letters (currentInput not empty after considering pins)
        return !currentInput.isEmpty
    }

    @ViewBuilder
    private func keyButton(for ch: Character) -> some View {
        let state = keyboardStates[ch] ?? .unknown

        switch state {
            case .unknown:
                Button(action: { tapLetter(ch) }) {
                    Text(String(ch))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameKeyButtonStyle(tint: state.tint))

            case .absent:
                Button(action: { tapLetter(ch) }) {
                    Text(String(ch))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledGameKeyButtonStyle(fill: .gray, foreground: .white))

            case .present:
                Button(action: { tapLetter(ch) }) {
                    Text(String(ch))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledGameKeyButtonStyle(fill: .yellow, foreground: .black))

            case .correct:
                Button(action: { tapLetter(ch) }) {
                    Text(String(ch))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(FilledGameKeyButtonStyle(fill: .green, foreground: .white))
        }
    }

    // MARK: - Input helpers (respect pinned/selection)

    private func tapLetter(_ ch: Character) {
        guard !roundOver else { return }
        let up = Character(String(ch).uppercased())
        guard up.isLetter else { return }

        // If a cell is selected in the active row, handle pinning without staying in "pin mode"
        if let sel = selectedCell, sel.row == rowIndex {
            let isPinnedAtSel = pinned[rowIndex][sel.col] != nil
            if !isPinnedAtSel {
                // Pin here, then EXIT pin mode (clear selection) so subsequent typing is normal
                pinned[rowIndex][sel.col] = up
                message = nil
                selectedCell = nil
                return
            } else {
                // Already pinned: do NOT overwrite. Exit pin mode, then type normally into next free slot
                selectedCell = nil
                if let _ = nextAvailableColumn() {
                    currentInput.append(up)
                    message = nil
                }
                return
            }
        }

        // No active selection: fill the next available non-pinned empty slot left-to-right
        if let _ = nextAvailableColumn() {
            currentInput.append(up)
            message = nil
        }
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

        // Accept the target or any correctly spelled 5-letter English word
        guard guess == target || isValidWord(guess) else {
            message = "Not in word list"
            return
        }

        // NEW: Hard Mode validation (must keep greens; must use yellows elsewhere)
        if hardModeEnabled, rowIndex > 0 {
            if let violation = hardModeViolation(for: guess) {
                message = violation
                return
            }
        }

        // Evaluate
        let eval = evaluate(guess: guess, against: target)
        evaluations[rowIndex] = eval
        guesses[rowIndex] = guess
        rowIndex += 1

        // Update keyboard states with precedence
        for (i, ch) in guess.enumerated() {
            let newState = eval[i]
            let old = keyboardStates[ch] ?? .unknown
            keyboardStates[ch] = KeyState.merged(old, newState)
        }

        if guess == target {
            didWin = true
            endRound(win: true)
            return
        }
        if rowIndex >= 6 {
            didWin = false
            endRound(win: false)
            return
        }
        // Prepare next row input and clear selection/pins for next row only
        currentInput = ""
        selectedCell = nil
        // Do not clear previous row pins; they’re irrelevant now. Ensure next row pins are empty.
        if rowIndex < pinned.count {
            pinned[rowIndex] = Array(repeating: nil, count: 5)
        }
        message = nil
    }

    // Standard Wordle evaluation (two-pass to handle duplicates)
    private func evaluate(guess: String, against target: String) -> [KeyState] {
        var result = Array(repeating: KeyState.absent, count: 5)
        var targetChars = Array(target)
        let guessChars = Array(guess)

        // First pass: correct positions
        for i in 0..<5 {
            if guessChars[i] == targetChars[i] {
                result[i] = .correct
                targetChars[i] = "*" // mark used
            }
        }
        // Second pass: present letters
        for i in 0..<5 where result[i] != .correct {
            if let idx = targetChars.firstIndex(of: guessChars[i]) {
                result[i] = .present
                targetChars[idx] = "*" // mark used
            } else {
                result[i] = .absent
            }
        }
        return result
    }

    // MARK: - Hard Mode constraints (unchanged)

    private func buildHardModeConstraints() -> (greens: [Int: Character], minCount: [Character: Int], disallowedPositions: [Character: Set<Int>]) {
        var greens: [Int: Character] = [:]
        var minCount: [Character: Int] = [:]
        var disallowed: [Character: Set<Int>] = [:]

        for r in 0..<rowIndex {
            let g = guesses[r]
            guard g.count == 5 else { continue }
            let eval = evaluations[r]
            var perRowCounts: [Character: Int] = [:]

            for i in 0..<5 {
                let ch = Array(g)[i]
                switch eval[i] {
                case .correct:
                    greens[i] = ch
                    perRowCounts[ch, default: 0] += 1
                case .present:
                    disallowed[ch, default: []].insert(i)
                    perRowCounts[ch, default: 0] += 1
                case .absent, .unknown:
                    break
                }
            }

            for (ch, c) in perRowCounts {
                if let old = minCount[ch] {
                    if c > old { minCount[ch] = c }
                } else {
                    minCount[ch] = c
                }
            }
        }

        return (greens, minCount, disallowed)
    }

    private func hardModeViolation(for guess: String) -> String? {
        let (greens, minCount, disallowed) = buildHardModeConstraints()
        let guessChars = Array(guess)

        for (idx, ch) in greens {
            if guessChars[idx] != ch {
                return "Hard Mode: must keep \(ch) at position \(idx + 1)"
            }
        }

        var guessCounts: [Character: Int] = [:]
        for ch in guessChars {
            guessCounts[ch, default: 0] += 1
        }
        for (ch, required) in minCount {
            let have = guessCounts[ch] ?? 0
            if have < required {
                return "Hard Mode: must include \(required) \(ch)\(required > 1 ? "s" : "")"
            }
        }

        for (ch, badPositions) in disallowed {
            for idx in badPositions {
                if guessChars[idx] == ch {
                    return "Hard Mode: \(ch) cannot be at position \(idx + 1)"
                }
            }
        }

        return nil
    }

    // MARK: - Rounds
    private func startNewRound(freePlay: Bool) {
        guesses = Array(repeating: "", count: 6)
        evaluations = Array(repeating: Array(repeating: .unknown, count: 5), count: 6)
        rowIndex = 0
        currentInput = ""
        didWin = false
        roundOver = false
        message = nil
        keyboardStates.removeAll()
        roundRef = nil

        // Reset pinning/selection
        pinned = Array(repeating: Array(repeating: nil, count: 5), count: 6)
        selectedCell = nil

        // Start timing
        roundStartAt = Date()
        lastRoundElapsedSeconds = nil

        if freePlay {
            target = Self.filteredAnswerWords.randomElement() ?? "JESUS"
        } else {
            target = wordOfDay()
        }

        started = true
    }

    private func endRound(win: Bool) {
        roundOver = true
        // Clear current input and selection to avoid duplicate rendering
        currentInput = ""
        selectedCell = nil

        let elapsedSeconds: Int = {
            let start = roundStartAt ?? Date()
            let raw = Int(Date().timeIntervalSince(start))
            return max(0, raw)
        }()

        lastRoundElapsedSeconds = elapsedSeconds

        answered += 1
        if win {
            score += 1
            currentStreak += 1
            if currentStreak > currentBestStreak {
                currentBestStreak = currentStreak
            }
            message = (mode == .daily) ? "You got it! See you tomorrow." : "You got it!"
            GameStats.shared.recordWordleResult(
                type: (mode == .daily ? .daily : .free),
                mode: (hardModeEnabled ? .hard : .normal),
                won: true,
                guesses: rowIndex,
                currentBestStreak: currentBestStreak
            )
        } else {
            currentStreak = 0
            message = "The word was \(target)."
            GameStats.shared.recordWordleResult(
                type: (mode == .daily ? .daily : .free),
                mode: (hardModeEnabled ? .hard : .normal),
                won: false,
                guesses: rowIndex,
                currentBestStreak: currentBestStreak
            )
        }

        GameStats.shared.recordWordleTime(
            type: (mode == .daily ? .daily : .free),
            mode: (hardModeEnabled ? .hard : .normal),
            won: win,
            elapsedSeconds: elapsedSeconds
        )

        if let ref = Self.verseIndex[target], Self.verseContainsWord(ref.text, word: target) {
            roundRef = ref
        } else {
            roundRef = Self.findExactOccurrence(for: target)
            if roundRef == nil {
                print("WORD: No exact verse reference found for \(target)")
            }
        }

        if mode == .daily {
            UserDefaults.standard.set(todayKey, forKey: "wordleDailyCompletedDay")
            UserDefaults.standard.set(target, forKey: "wordleDailyTarget")
        }
    }

    // MARK: - Word validity (system dictionary)
    private func isValidWord(_ uppercasedWord: String) -> Bool {
        let lower = uppercasedWord.lowercased()
        guard lower.count == 5, lower.unicodeScalars.allSatisfy({ CharacterSet.lowercaseLetters.contains($0) }) else {
            return false
        }
        #if canImport(UIKit)
        let lang = UITextChecker.availableLanguages.first(where: { $0.hasPrefix("en") }) ?? "en_US"
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: lower.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(in: lower, range: range, startingAt: 0, wrap: false, language: lang)
        return misspelled.location == NSNotFound
        #else
        return true
        #endif
    }

    // MARK: - Word of day (from filtered pool with references)
    private func wordOfDay(date: Date = Date()) -> String {
        let pool = Self.filteredAnswerWords
        let idx = Self.dayIndex(for: date) % max(1, pool.count)
        return pool[idx]
    }

    private static func dayIndex(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let start = cal.startOfDay(for: date)
        let ref = cal.startOfDay(for: Date(timeIntervalSince1970: 1640995200)) // 2022-01-01
        let comps = cal.dateComponents([.day], from: ref, to: start)
        return max(0, comps.day ?? 0)
    }

    private static func localDayKey(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let start = cal.startOfDay(for: date)
        let comps = cal.dateComponents([.year, .month, .day], from: start)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    // MARK: - Reference preview presentation
    private func presentReferencePreview(_ ref: VerseRefInfo) {
        let sr = ScriptureRef(bookName: ref.bookName, chapter: ref.chapter, startVerse: ref.verse, endVerse: nil)
        selectedRef = sr
        loadedPreview = nil
        showRefSheet = true
    }

    // MARK: - Answer highlight
    @ViewBuilder
    private func answerHighlightView() -> some View {
        let bg = (didWin ? Color.green : Color.red).opacity(0.15)
        let border = (didWin ? Color.green : Color.red).opacity(0.45)
        VStack(spacing: 6) {
            Text("Answer")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(target.uppercased())
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityLabel("Answer: \(target)")
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(bg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - End-of-round action area (replaces keyboard)
    @ViewBuilder
    private func endOfRoundActionArea() -> some View {
        HStack(spacing: 10) {
            if let ref = roundRef {
                Button {
                    presentReferencePreview(ref)
                } label: {
                    Text(ref.display)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernPillButtonStyle(tint: .blue))
                .controlSize(.large)
            } else {
                Button { } label: {
                    Text("Reference")
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernPillButtonStyle(tint: .blue))
                .controlSize(.large)
                .disabled(true)
                .opacity(0.6)
                .accessibilityHidden(true)
            }

            if let secs = lastRoundElapsedSeconds {
                Button(action: { }) {
                    Text(formatElapsed(secs))
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernPillButtonStyle(tint: .purple))
                .controlSize(.large)
                .disabled(true)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Time \(formatElapsed(secs))")
            } else {
                Button(action: { }) {
                    Text("--:--")
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ModernPillButtonStyle(tint: .purple))
                .controlSize(.large)
                .disabled(true)
                .opacity(0.6)
                .accessibilityHidden(true)
            }

            if mode == .freePlay {
                Button("Next") { startNewRound(freePlay: true) }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.large)
            } else {
                if dailyCompletedToday && !wordleAllowDailyReplay {
                    Button("Daily") { }
                        .buttonStyle(ModernPillButtonStyle(tint: .gray))
                        .controlSize(.large)
                        .disabled(true)
                        .accessibilityLabel("Daily completed. Come back tomorrow.")
                } else {
                    Button("Play Daily") { startNewRound(freePlay: false) }
                        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                        .controlSize(.large)
                }
            }
        }
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

#if canImport(UIKit)
private struct KeyCaptureRepresentable: UIViewRepresentable {
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
private struct FilledGameKeyButtonStyle: ButtonStyle {
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
