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

    // Session stats (for the scoreboard’s Current section)
    @State private var score: Int = 0
    @State private var answered: Int = 0
    @State private var currentStreak: Int = 0
    @State private var currentBestStreak: Int = 0

    // NEW: Debug flag to allow replaying Daily Wordle (matches Settings/Games)
    @AppStorage("wordleAllowDailyReplay") private var wordleAllowDailyReplay: Bool = false

    // All-time (per mode)
    private var allTimeSuffix: String { mode == .daily ? "daily" : "free" }
    private var allTimeCorrect: Int { UserDefaults.standard.integer(forKey: "wordleAllTimeCorrect_\(allTimeSuffix)") }
    private var allTimeAnswered: Int { UserDefaults.standard.integer(forKey: "wordleAllTimeAnswered_\(allTimeSuffix)") }
    private var allTimeBestStreak: Int { UserDefaults.standard.integer(forKey: "wordleAllTimeBestStreak_\(allTimeSuffix)") }

    // Daily
    private var todayKey: String { Self.localDayKey(for: Date()) }
    private var dailyCompletedToday: Bool {
        UserDefaults.standard.string(forKey: "wordleDailyCompletedDay") == todayKey
    }

    // MARK: - Answer pool from KJV (5-letter A–Z words)
    private static let kjvAnswerWords: [String] = {
        var set = Set<String>()
        for book in BibleData.books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    let upper = verse.text.uppercased()
                    let sanitized = String(upper.map { ch -> Character in
                        if let s = ch.unicodeScalars.first, ch.unicodeScalars.count == 1, s.value >= 65 && s.value <= 90 {
                            return ch
                        } else {
                            return " "
                        }
                    })
                    for token in sanitized.split(separator: " ") {
                        if token.count == 5 && token.allSatisfy({ c in
                            if let s = c.unicodeScalars.first, c.unicodeScalars.count == 1 {
                                return s.value >= 65 && s.value <= 90
                            }
                            return false
                        }) {
                            set.insert(String(token))
                        }
                    }
                }
            }
        }
        let sorted = set.sorted()
        return sorted.isEmpty ? ["JESUS","GRACE","FAITH","ANGEL","CROSS","ABRAM","SARAH","JONAH","MOSES","DAVID","SALEM","TITUS","JAMES","PETER","JUDAH"] : sorted
    }()

    // MARK: - Verse index (first occurrence for each 5-letter word)
    private struct VerseRefInfo {
        let bookName: String
        let chapter: Int
        let verse: Int
        let text: String
        var display: String { "\(bookName) \(chapter):\(verse)" }
    }

    private static let verseIndex: [String: VerseRefInfo] = {
        var map: [String: VerseRefInfo] = [:]
        let allowed = Set(kjvAnswerWords) // uppercase
        for book in BibleData.books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    // Tokenize by A–Z only
                    let upper = verse.text.uppercased()
                    var word = ""
                    func flush() {
                        guard word.count == 5, allowed.contains(word), map[word] == nil else { word = ""; return }
                        map[word] = VerseRefInfo(bookName: book.name, chapter: chapter.number, verse: verse.number, text: verse.text)
                        word = ""
                    }
                    for ch in upper {
                        if let s = ch.unicodeScalars.first, ch.unicodeScalars.count == 1, s.value >= 65 && s.value <= 90 {
                            word.append(ch)
                            if word.count > 5 { word = String(word.suffix(5)) }
                        } else {
                            flush()
                        }
                    }
                    flush()
                }
            }
        }
        return map
    }()

    // State for showing reference button and navigating
    @State private var roundRef: VerseRefInfo? = nil

    // Smart link style preview state
    @State private var showRefSheet: Bool = false
    @State private var selectedRef: ScriptureRef? = nil
    @State private var loadedPreview: (title: String, verses: [Verse])? = nil

    var body: some View {
        VStack(spacing: 12) {
            if !started {
                startScreen()
            } else {
                #if canImport(UIKit)
                KeyCaptureRepresentable(
                    onKey: { ch in tapLetter(ch) },
                    onBackspace: { deleteLetter() },
                    onEnter: {
                        if !roundOver, currentInput.count == 5 {
                            submitGuess()
                        }
                    }
                )
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                #endif

                // Scoreboard
                GameScoreboardCard(
                    currentCorrect: score,
                    currentAnswered: answered,
                    currentStreak: currentStreak,
                    allTimeCorrect: allTimeCorrect,
                    allTimeAnswered: allTimeAnswered,
                    allTimeBestStreak: allTimeBestStreak
                )
                .padding(.horizontal)

                // Board
                boardView()
                    .padding(.horizontal)

                if let msg = message {
                    Text(msg)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // On-screen keyboard
                keyboardView()
                    .padding(.horizontal)

                // Dedicated Enter row
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
                    .disabled(roundOver || currentInput.count != 5)
                    .accessibilityLabel("Enter")
                }
                .padding(.horizontal)
                .padding(.top, 4)

                // Reference button (after round)
                if roundOver, let ref = roundRef {
                    Button {
                        presentReferencePreview(ref)
                    } label: {
                        Text(ref.display)
                            .lineLimit(1)
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .blue))
                    .controlSize(.small)
                    .padding(.top, 2)
                }

                // Bottom actions
                if roundOver {
                    HStack(spacing: 12) {
                        if mode == .freePlay {
                            Button("Next") { startNewRound(freePlay: true) }
                                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                        } else {
                            if dailyCompletedToday {
                                Text("Come back tomorrow for a new daily word.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Button("Play Daily") { startNewRound(freePlay: false) }
                                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                            }
                        }
                        Button("Change Mode") { started = false }
                            .buttonStyle(ModernPillButtonStyle(tint: .orange))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
            }
        }
        .navigationTitle("Wordle (Bible)")
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
    }

    // MARK: - Start screen
    @ViewBuilder
    private func startScreen() -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)
            Image(systemName: "square.grid.3x3")
                .font(.largeTitle)
                .foregroundStyle(.mint)

            Text("Wordle (Bible)")
                .font(.title2.bold())

            Text("Guess the 5‑letter word in 6 tries.\nUse the on‑screen keyboard or a connected keyboard.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Plain segmented Picker (glow removed)
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if mode == .daily && dailyCompletedToday && !wordleAllowDailyReplay {
                Text("You’ve completed today’s daily. Come back tomorrow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
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
                                return c < currentInput.count ? String(currentInput[currentInput.index(currentInput.startIndex, offsetBy: c)]) : ""
                            } else {
                                return ""
                            }
                        }()
                        let state: KeyState = (r < rowIndex) ? evaluations[r][c] : .unknown
                        tile(letter: ch, state: state)
                    }
                }
            }
        }
    }

    private func tile(letter: String, state: KeyState) -> some View {
        let bg: Color = {
            switch state {
            case .unknown: return Color(.secondarySystemBackground)
            case .absent:  return .gray.opacity(0.35)
            case .present: return .yellow.opacity(0.45)
            case .correct: return .green.opacity(0.45)
            }
        }()
        let border: Color = {
            switch state {
            case .unknown: return Color.primary.opacity(0.08)
            case .absent:  return .gray.opacity(0.55)
            case .present: return .yellow.opacity(0.65)
            case .correct: return .green.opacity(0.65)
            }
        }()
        return Text(letter)
            .font(.title2.weight(.bold))
            .frame(width: 48, height: 48)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(bg))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(border, lineWidth: 1))
            .foregroundStyle(.primary)
            .monospaced()
    }

    // MARK: - On-screen keyboard
    @ViewBuilder
    private func keyboardView() -> some View {
        let row1 = Array("QWERTYUIOP")
        let row2 = Array("ASDFGHJKL")
        let row3 = Array("ZXCVBNM")

        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(row1, id: \.self) { ch in
                    keyButton(for: ch)
                        .disabled(roundOver || currentInput.count >= 5)
                }
            }
            HStack(spacing: 6) {
                ForEach(row2, id: \.self) { ch in
                    keyButton(for: ch)
                        .disabled(roundOver || currentInput.count >= 5)
                }
            }
            HStack(spacing: 6) {
                // Enter (icon)
                Button(action: {
                    submitGuess()
                }) {
                    Image(systemName: "return")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
                .disabled(roundOver || currentInput.count != 5)
                .accessibilityLabel("Enter")

                ForEach(row3, id: \.self) { ch in
                    keyButton(for: ch)
                        .disabled(roundOver || currentInput.count >= 5)
                }

                // Backspace
                Button(action: { deleteLetter() }) {
                    Image(systemName: "delete.left")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GameKeyButtonStyle(tint: .accentColor))
                .disabled(roundOver || currentInput.isEmpty)
                .accessibilityLabel("Backspace")
            }
        }
        .accessibilityElement(children: .contain)
        .padding(.top, 6)
    }

    @ViewBuilder
    private func keyButton(for ch: Character) -> some View {
        let state = keyboardStates[ch] ?? .unknown

        switch state {
        case .unknown:
            // Keep default look for untouched keys
            Button(action: { tapLetter(ch) }) {
                Text(String(ch))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GameKeyButtonStyle(tint: state.tint))

        case .absent:
            // Fill entire key gray to match board
            Button(action: { tapLetter(ch) }) {
                Text(String(ch))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledGameKeyButtonStyle(fill: .gray, foreground: .white))

        case .present:
            // Fill entire key yellow (use dark text for contrast)
            Button(action: { tapLetter(ch) }) {
                Text(String(ch))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledGameKeyButtonStyle(fill: .yellow, foreground: .black))

        case .correct:
            // Fill entire key green
            Button(action: { tapLetter(ch) }) {
                Text(String(ch))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FilledGameKeyButtonStyle(fill: .green, foreground: .white))
        }
    }

    // MARK: - Input helpers
    private func tapLetter(_ ch: Character) {
        guard !roundOver else { return }
        guard currentInput.count < 5 else { return }
        let up = Character(String(ch).uppercased())
        guard up.isLetter else { return }
        currentInput.append(up)
        message = nil
    }

    private func deleteLetter() {
        guard !roundOver, !currentInput.isEmpty else { return }
        _ = currentInput.popLast()
    }

    private func submitGuess() {
        guard !roundOver, currentInput.count == 5 else { return }
        let guess = currentInput.uppercased()

        // Accept the target or any correctly spelled 5-letter English word
        guard guess == target || isValidWord(guess) else {
            message = "Not in word list"
            return
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
        // Prepare next row input
        currentInput = ""
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

        if freePlay {
            target = Self.kjvAnswerWords.randomElement() ?? "JESUS"
        } else {
            target = wordOfDay()
        }

        started = true
    }

    private func endRound(win: Bool) {
        roundOver = true
        // Clear current input to avoid duplicate rendering on the next row
        currentInput = ""

        answered += 1
        if win {
            score += 1
            currentStreak += 1
            if currentStreak > currentBestStreak {
                currentBestStreak = currentStreak
            }
            message = (mode == .daily) ? "You got it! See you tomorrow." : "You got it!"
            // NEW: record with guesses + histogram
            GameStats.shared.recordWordleResult(
                type: (mode == .daily ? .daily : .free),
                won: true,
                guesses: rowIndex, // number of guesses used (already incremented)
                currentBestStreak: currentBestStreak
            )
        } else {
            currentStreak = 0
            message = "The word was \(target)."
            // NEW: record loss through the same API (won: false). Guesses ignored for loss.
            GameStats.shared.recordWordleResult(
                type: (mode == .daily ? .daily : .free),
                won: false,
                guesses: rowIndex,
                currentBestStreak: currentBestStreak
            )
        }

        // Resolve a Bible reference for the target (first occurrence)
        roundRef = Self.verseIndex[target]

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

    // MARK: - Word of day (from KJV-derived pool)
    private func wordOfDay(date: Date = Date()) -> String {
        let pool = Self.kjvAnswerWords
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
        // Build ref and present immediately; load lazily in sheet task
        let sr = ScriptureRef(bookName: ref.bookName, chapter: ref.chapter, startVerse: ref.verse, endVerse: nil)
        selectedRef = sr
        loadedPreview = nil
        showRefSheet = true
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

