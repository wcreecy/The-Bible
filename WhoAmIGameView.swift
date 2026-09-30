import SwiftUI

struct WhoAmIGameView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var vm = WhoAmIGameViewModel()
    @State private var maxChoiceHeight: CGFloat = 0
    @State private var timerOnLeading = false
    @State private var usesMutedTimerStyle = false

    // Sheet state for reference preview
    @State private var refSheetRequest: ReferenceSheetRequest?
    @State private var refChoices: [ScriptureRef] = []
    @State private var selectedRef: ScriptureRef? = nil
    @State private var loadedPreview: (title: String, verses: [Verse])? = nil
    @State private var currentRefIndex: Int = 0
    @State private var selectionNonce: UUID = UUID()

    private struct ReferenceSheetRequest: Identifiable {
        let id = UUID()
        let references: [ScriptureRef]
    }

    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    private struct ChoiceHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !vm.started {
                    Spacer(minLength: 24)
                    Text("Match Bible names and descriptions.")
                        .gameStartDescriptionStyle()

                    GameStartInfoLayout {
                        GroupBox {
                            DisclosureGroup(isExpanded: $vm.howToExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Choose a mode and difficulty, then tap Start.")
                                    Text("• Names: You’ll see a name; pick the correct description.")
                                    Text("• Reverse: You’ll see a description; pick the correct name.")
                                    Text("• In timed modes, answer before the clock runs out.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("How to Play").font(.headline)
                            }
                        }

                        GroupBox {
                            DisclosureGroup(isExpanded: $vm.difficultyExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Easy: No timer.")
                                    Text("• Normal: 30 seconds per question.")
                                    Text("• Hard: 15 seconds per question.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Difficulty Settings").font(.headline)
                            }
                        }
                    }
                    .gameStartOptionsStyle()
                    .expandGameStartCardsOnIPad(
                        howTo: $vm.howToExpanded,
                        difficulty: $vm.difficultyExpanded
                    )
                    .padding(.horizontal)

                    GameStartSettingsLayout {
                        GameStartPickerCard(
                            title: "Question Type",
                            selection: $vm.mode,
                            options: WhoAmIGameViewModel.Mode.allCases
                        ) { mode in
                            Text(mode.rawValue)
                        }

                        GameStartPickerCard(
                            title: "Difficulty",
                            selection: $vm.difficulty,
                            options: WhoAmIGameViewModel.Difficulty.allCases
                        ) { difficulty in
                            switch difficulty {
                            case .easy: Text("Easy")
                            case .normal: Text("Normal")
                            case .hard: Text("Hard")
                            }
                        }
                    }
                    .padding(.horizontal)

                    Button("Start") { vm.startGame() }
                        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                        .controlSize(.large)
                        .frame(maxWidth: 240)
                    Spacer(minLength: 24)
                } else if horizontalSizeClass == .regular {
                    WhoAmIIPadGameBoard(
                        score: vm.score,
                        answered: vm.answered,
                        streak: vm.currentStreak,
                        promptTitle: vm.promptTitle,
                        promptIsName: vm.mode == .names,
                        choices: vm.choices,
                        roundOver: vm.roundOver,
                        correctChoice: vm.correctChoice,
                        selectedChoice: vm.selectedChoice,
                        isTimed: vm.difficulty.timeLimit > 0,
                        remainingSeconds: vm.remainingSeconds,
                        timerTint: timerTint(vm.remainingSeconds),
                        timerIsActive: whoAmITimerIsActive,
                        timerIsPulsing: vm.pulseOn,
                        timerOnLeading: $timerOnLeading,
                        usesMutedTimerStyle: $usesMutedTimerStyle,
                        showsDebugWin: debugAutoWinEnabled && vm.selectedChoice == nil,
                        onChoose: { choice in
                            if vm.roundOver {
                                presentReferences(for: choice)
                            } else {
                                vm.select(choice)
                            }
                        },
                        onSkip: { vm.skipOrTimeout() },
                        onNext: { vm.nextRound() },
                        onDebugWin: { vm.select(vm.correctChoice) }
                    )
                } else {
                    GameScoreboardCard(
                        currentCorrect: vm.score,
                        currentAnswered: vm.answered,
                        currentStreak: vm.currentStreak,
                        game: .whoami
                    )

                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(vm.mode == .names ? "Name" : "Description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            Text(vm.promptTitle)
                                .font(vm.mode == .names ? .title2.weight(.semibold) : .body)
                                .lineLimit(6)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(whoAmIQuestionBorderColor, lineWidth: whoAmIQuestionBorderWidth)
                    )
                    .animation(.easeInOut(duration: 0.25), value: vm.remainingSeconds)

                    if whoAmITimerIsActive {
                        GameTimerCard(
                            remainingSeconds: vm.remainingSeconds,
                            tint: timerTint(vm.remainingSeconds),
                            isPulsing: vm.pulseOn
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose one:")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(vm.choices, id: \.self) { choice in
                                Button {
                                    if vm.roundOver {
                                        presentReferences(for: choice)
                                    } else {
                                        vm.select(choice)
                                    }
                                } label: {
                                    Text(choice)
                                        .font(.footnote)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(6)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(
                                            maxWidth: .infinity,
                                            minHeight: max(maxChoiceHeight, 96),
                                            maxHeight: max(maxChoiceHeight, 96),
                                            alignment: .leading
                                        )
                                        .padding()
                                        .foregroundStyle(.primary)
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear
                                                    .preference(key: ChoiceHeightKey.self, value: geo.size.height)
                                            }
                                        )
                                }
                                .buttonStyle(.plain)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(backgroundColor(for: choice))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            borderColor(for: choice),
                                            lineWidth: vm.roundOver && choice == vm.correctChoice ? 2 : 1
                                        )
                                )
                            }
                        }
                        .onPreferenceChange(ChoiceHeightKey.self) { value in
                            maxChoiceHeight = value
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Skip") { vm.skipOrTimeout() }
                            .buttonStyle(ModernPillButtonStyle(tint: .orange))
                            .disabled(vm.roundOver)
                        Button("Next") { vm.nextRound() }
                            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                            .disabled(!vm.roundOver)
                    }

                    if vm.roundOver {
                        Label("Tap an answer to see its references", systemImage: "hand.tap.fill")
                            .font(.headline)
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if debugAutoWinEnabled, vm.started, !vm.roundOver, vm.selectedChoice == nil {
                        Button("WIN") {
                            vm.select(vm.correctChoice)
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .red))
                        .controlSize(.large)
                        .padding(.top, 6)
                        .accessibilityLabel("Win this round")
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Who am I?")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.onAppear() }
        .onChange(of: vm.choices) { _, _ in
            maxChoiceHeight = 0
        }
        .sheet(item: $refSheetRequest, onDismiss: {
            selectedRef = nil
            loadedPreview = nil
            refChoices = []
            currentRefIndex = 0
        }) { request in
            let displayedRefs = request.references
            let content = NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    if displayedRefs.isEmpty {
                        ContentUnavailableView("No reference available", systemImage: "book")
                    } else {
                        HStack(spacing: 12) {
                            Button { moveRefIndex(-1) } label: { Image(systemName: "chevron.left") }
                                .buttonStyle(.plain)
                                .disabled(displayedRefs.count <= 1)

                            Text("\(currentRefIndex + 1) of \(displayedRefs.count)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button { moveRefIndex(+1) } label: { Image(systemName: "chevron.right") }
                                .buttonStyle(.plain)
                                .disabled(displayedRefs.count <= 1)

                            Spacer()
                        }

                        ScriptureLinksList(refs: displayedRefs, onTap: { ref in
                            if let idx = refChoices.firstIndex(where: { $0 == ref }) {
                                setCurrentRefIndex(idx)
                            } else {
                                selectedRef = ref
                                selectionNonce = UUID()
                            }
                        }, onCopy: { ref in
                            let s: String
                            if let end = ref.endVerse, end != ref.startVerse {
                                s = "\(ref.bookName) \(ref.chapter):\(ref.startVerse)-\(end)"
                            } else {
                                s = "\(ref.bookName) \(ref.chapter):\(ref.startVerse)"
                            }
                            UIPasteboard.general.string = s
                        })
                        .padding(.bottom, 4)

                        if let preview = loadedPreview {
                            ScripturePreviewCard(
                                content: preview,
                                refContext: selectedRef,
                                onCopy: {
                                    let text = preview.verses.map { $0.text }.joined(separator: " ")
                                    UIPasteboard.general.string = "\(preview.title) — \(text)"
                                },
                                onClose: {
                                    selectedRef = nil
                                    loadedPreview = nil
                                }
                            )
                        } else {
                            Text("Tap a reference to preview verses.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .navigationTitle("Reference")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { refSheetRequest = nil }
                    }
                }
                .presentationDetents([.medium, .large])
                .onAppear {
                    if !displayedRefs.isEmpty, selectedRef == nil {
                        currentRefIndex = max(0, min(currentRefIndex, displayedRefs.count - 1))
                        selectedRef = displayedRefs[currentRefIndex]
                        selectionNonce = UUID()
                    }
                    if let sr = selectedRef, loadedPreview == nil {
                        loadedPreview = BibleReferenceLinker.loadVerses(for: sr)
                    }
                }
            }

            content
                .task(id: selectionNonce) {
                    if let sr = selectedRef {
                        loadedPreview = BibleReferenceLinker.loadVerses(for: sr)
                    } else {
                        loadedPreview = nil
                    }
                }
        }
    }

    private func backgroundColor(for choice: String) -> Color {
        guard vm.roundOver else { return Color(.secondarySystemBackground) }
        if choice == vm.correctChoice { return .green.opacity(0.25) }
        if let sel = vm.selectedChoice, sel == choice, choice != vm.correctChoice { return .red.opacity(0.25) }
        return Color(.secondarySystemBackground)
    }

    private func borderColor(for choice: String) -> Color {
        guard vm.roundOver else { return Color.primary.opacity(0.15) }
        if choice == vm.correctChoice { return .green }
        if let sel = vm.selectedChoice, sel == choice, choice != vm.correctChoice { return .red }
        return Color.primary.opacity(0.15)
    }

    private var whoAmITimerIsActive: Bool {
        vm.difficulty.timeLimit > 0 && !vm.roundOver && vm.selectedChoice == nil
    }

    private var whoAmIQuestionBorderColor: Color {
        whoAmITimerIsActive ? timerTint(vm.remainingSeconds) : Color.primary.opacity(0.12)
    }

    private var whoAmIQuestionBorderWidth: CGFloat {
        whoAmITimerIsActive ? 2 : 1
    }

    private func timerTint(_ secs: Int) -> Color {
        if secs <= 5 { return .red }
        if secs <= 10 { return .yellow }
        return .green
    }

    // MARK: - Reference presentation

    private func hasReference(for choice: String) -> Bool {
        if let s = vm.referenceString(for: choice) {
            return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
    }

    private func presentReferences(for choice: String) {
        guard var refStr = vm.referenceString(for: choice),
              !refStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            refChoices = []
            selectedRef = nil
            loadedPreview = nil
            currentRefIndex = 0
            refSheetRequest = ReferenceSheetRequest(references: [])
            return
        }

        let nbspChars: [Character] = ["\u{00A0}", "\u{202F}", "\u{2007}"]
        for ch in nbspChars {
            refStr = refStr.replacingOccurrences(of: String(ch), with: " ")
        }

        let separators = CharacterSet(charactersIn: ",;")
        let parts = refStr.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var all: [ScriptureRef] = []
        for part in parts {
            let attributed = BibleReferenceLinker.linkify(part)
            let refs = ScriptureRefExtractor.refs(in: attributed)
            for r in refs {
                if !all.contains(where: { $0 == r }) {
                    all.append(r)
                }
            }
        }

        if all.isEmpty {
            let attributed = BibleReferenceLinker.linkify(refStr)
            let refs = ScriptureRefExtractor.refs(in: attributed)
            for r in refs {
                if !all.contains(where: { $0 == r }) {
                    all.append(r)
                }
            }
        }

        refChoices = all
        currentRefIndex = 0

        selectedRef = all.first
        selectionNonce = UUID()
        loadedPreview = nil
        refSheetRequest = ReferenceSheetRequest(references: all)
    }

    private func setCurrentRefIndex(_ idx: Int) {
        guard !refChoices.isEmpty else {
            selectedRef = nil
            loadedPreview = nil
            return
        }
        let clamped = max(0, min(idx, refChoices.count - 1))
        currentRefIndex = clamped
        let ref = refChoices[clamped]
        selectedRef = ref
        selectionNonce = UUID()
        loadedPreview = nil
    }

    private func moveRefIndex(_ delta: Int) {
        guard !refChoices.isEmpty else { return }
        let n = refChoices.count
        let newIndex = (currentRefIndex + delta % n + n) % n
        setCurrentRefIndex(newIndex)
    }
}

private struct WhoAmIIPadGameBoard: View {
    let score: Int
    let answered: Int
    let streak: Int
    let promptTitle: String
    let promptIsName: Bool
    let choices: [String]
    let roundOver: Bool
    let correctChoice: String
    let selectedChoice: String?
    let isTimed: Bool
    let remainingSeconds: Int
    let timerTint: Color
    let timerIsActive: Bool
    let timerIsPulsing: Bool
    @Binding var timerOnLeading: Bool
    @Binding var usesMutedTimerStyle: Bool
    let showsDebugWin: Bool
    let onChoose: (String) -> Void
    let onSkip: () -> Void
    let onNext: () -> Void
    let onDebugWin: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            if timerOnLeading {
                timerCard
                playCard
            } else {
                playCard
                timerCard
            }
        }
        .frame(maxWidth: .infinity, minHeight: 620, alignment: .top)
        .animation(.snappy, value: timerOnLeading)
    }

    private var playCard: some View {
        WhoAmIPlayCard(
            score: score,
            answered: answered,
            streak: streak,
            promptTitle: promptTitle,
            promptIsName: promptIsName,
            choices: choices,
            roundOver: roundOver,
            correctChoice: correctChoice,
            selectedChoice: selectedChoice,
            showsDebugWin: showsDebugWin,
            onChoose: onChoose,
            onSkip: onSkip,
            onNext: onNext,
            onDebugWin: onDebugWin
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var timerCard: some View {
        WhoAmITimerCard(
            isTimed: isTimed,
            remainingSeconds: remainingSeconds,
            tint: timerTint,
            isActive: timerIsActive,
            isPulsing: timerIsPulsing,
            usesMutedStyle: $usesMutedTimerStyle,
            onSwapSides: { timerOnLeading.toggle() }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WhoAmIPlayCard: View {
    let score: Int
    let answered: Int
    let streak: Int
    let promptTitle: String
    let promptIsName: Bool
    let choices: [String]
    let roundOver: Bool
    let correctChoice: String
    let selectedChoice: String?
    let showsDebugWin: Bool
    let onChoose: (String) -> Void
    let onSkip: () -> Void
    let onNext: () -> Void
    let onDebugWin: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            GameScoreboardCard(
                currentCorrect: score,
                currentAnswered: answered,
                currentStreak: streak,
                game: .whoami
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(promptIsName ? "Name" : "Description")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(promptTitle)
                    .font(promptIsName ? .title.weight(.semibold) : .title3.weight(.medium))
                    .lineLimit(7)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(choices, id: \.self) { choice in
                    Button {
                        onChoose(choice)
                    } label: {
                        Text(choice)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                            .padding()
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .background(
                        backgroundColor(for: choice),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                borderColor(for: choice),
                                lineWidth: roundOver && choice == correctChoice ? 2 : 1
                            )
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Skip", action: onSkip)
                    .buttonStyle(ModernPillButtonStyle(tint: .orange))
                    .disabled(roundOver)

                Button("Next", action: onNext)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .disabled(!roundOver)
            }

            if roundOver {
                Label("Tap an answer to see its references", systemImage: "hand.tap.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if showsDebugWin && !roundOver {
                Button("WIN", action: onDebugWin)
                    .buttonStyle(ModernPillButtonStyle(tint: .red))
                    .accessibilityLabel("Win this round")
            }
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }

    private func backgroundColor(for choice: String) -> Color {
        guard roundOver else {
            return Color(.secondarySystemBackground)
        }
        if choice == correctChoice {
            return .green.opacity(0.25)
        }
        if choice == selectedChoice, choice != correctChoice {
            return .red.opacity(0.25)
        }
        return Color(.secondarySystemBackground)
    }

    private func borderColor(for choice: String) -> Color {
        guard roundOver else {
            return Color.primary.opacity(0.15)
        }
        if choice == correctChoice {
            return .green
        }
        if choice == selectedChoice, choice != correctChoice {
            return .red
        }
        return Color.primary.opacity(0.15)
    }
}

private struct WhoAmITimerCard: View {
    let isTimed: Bool
    let remainingSeconds: Int
    let tint: Color
    let isActive: Bool
    let isPulsing: Bool
    @Binding var usesMutedStyle: Bool
    let onSwapSides: () -> Void

    private var usesVividStyle: Bool {
        isTimed && !usesMutedStyle
    }

    private var timerTextColor: Color {
        remainingSeconds > 5 && remainingSeconds <= 10 ? .black : .white
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: statusSystemImage)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(
                        usesVividStyle
                            ? timerTextColor.opacity(0.85)
                            : statusTint
                    )

                Text(statusTitle)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(
                        usesVividStyle
                            ? timerTextColor.opacity(0.85)
                            : statusTint
                    )

                if isTimed && isActive {
                    Text("\(remainingSeconds)s")
                        .font(.system(size: 180, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(usesVividStyle ? timerTextColor : tint)
                }
            }
            .scaleEffect(isPulsing ? 1.04 : 1)
            .animation(.easeOut(duration: 0.18), value: isPulsing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statusTitle)
            .accessibilityValue(isTimed && isActive ? "\(remainingSeconds) seconds" : "")

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button(
                    "Swap card sides",
                    systemImage: "arrow.left.arrow.right",
                    action: onSwapSides
                )

                if isTimed {
                    Button(
                        usesMutedStyle ? "Use vivid timer background" : "Use muted timer background",
                        systemImage: "circle.lefthalf.filled"
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            usesMutedStyle.toggle()
                        }
                    }
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass(.clear))
            .controlSize(.small)
            .tint(usesVividStyle ? timerTextColor : tint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(
            usesVividStyle ? tint : Color.clear,
            in: RoundedRectangle(
                cornerRadius: AppDesignMetrics.cardCornerRadius,
                style: .continuous
            )
        )
        .heroCardSurface()
    }

    private var statusTitle: LocalizedStringKey {
        if !isTimed {
            return "Untimed"
        }
        return isActive ? "Time Remaining" : "Round Complete"
    }

    private var statusSystemImage: String {
        if !isTimed {
            return "infinity"
        }
        return isActive ? "timer" : "checkmark.circle.fill"
    }

    private var statusTint: Color {
        if !isTimed {
            return .secondary
        }
        return isActive ? tint : .green
    }
}

#Preview {
    NavigationStack {
        WhoAmIGameView()
    }
}
