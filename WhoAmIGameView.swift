import SwiftUI

struct WhoAmIGameView: View {
    @StateObject private var vm = WhoAmIGameViewModel()
    @State private var maxChoiceHeight: CGFloat = 0

    // Sheet state for reference preview
    @State private var showRefSheet: Bool = false
    @State private var refChoices: [ScriptureRef] = []
    @State private var selectedRef: ScriptureRef? = nil
    @State private var loadedPreview: (title: String, verses: [Verse])? = nil
    @State private var currentRefIndex: Int = 0

    // Collects the maximum measured height from all choice cells
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
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
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
                                Text("Difficulty Levels").font(.headline)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Picker("Mode", selection: $vm.mode) {
                        ForEach(WhoAmIGameViewModel.Mode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Picker("Difficulty", selection: $vm.difficulty) {
                        ForEach(WhoAmIGameViewModel.Difficulty.allCases) { d in
                            switch d {
                            case .easy: Text("Easy").tag(d)
                            case .normal: Text("Normal").tag(d)
                            case .hard: Text("Hard").tag(d)
                            }
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Button("Start") { vm.startGame() }
                        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                        .controlSize(.large)
                        .frame(maxWidth: 240)
                    Spacer(minLength: 24)
                } else {
                    // Scoreboard
                    GameScoreboardCard(
                        currentCorrect: vm.score,
                        currentAnswered: vm.answered,
                        currentStreak: vm.currentStreak,
                        allTimeCorrect: vm.allTimeCorrect,
                        allTimeAnswered: vm.allTimeAnswered,
                        allTimeBestStreak: vm.allTimeBestStreak
                    )

                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(vm.mode == .names ? "Name" : "Description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if vm.difficulty.timeLimit > 0 && !vm.roundOver && vm.selectedChoice == nil {
                                    HStack(spacing: 6) {
                                        Image(systemName: "timer")
                                        Text("\(vm.remainingSeconds)s")
                                            .monospacedDigit()
                                    }
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(timerTint(vm.remainingSeconds))
                                    .scaleEffect(vm.pulseOn ? 1.12 : 1.0)
                                    .animation(.easeInOut(duration: 0.25), value: vm.pulseOn)
                                }
                            }
                            Text(vm.promptTitle)
                                .font(vm.mode == .names ? .title2.weight(.semibold) : .body)
                                .lineLimit(6)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose one:")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(vm.choices, id: \.self) { choice in
                                let hasRef = vm.roundOver && hasReference(for: choice)
                                Button {
                                    vm.select(choice)
                                } label: {
                                    // Uniform-sized, leading-aligned, multi-line text inside each cell
                                    Text(choice)
                                        .font(.footnote)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(6)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(
                                            maxWidth: .infinity,
                                            minHeight: max(maxChoiceHeight, 78),
                                            maxHeight: max(maxChoiceHeight, 78),
                                            alignment: .leading
                                        )
                                        .padding()
                                        .foregroundStyle(.primary)
                                        .underline(hasRef, color: Color.blue.opacity(0.65))
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear
                                                    .preference(key: ChoiceHeightKey.self, value: geo.size.height)
                                            }
                                        )
                                }
                                .disabled(vm.roundOver)
                                .simultaneousGesture(TapGesture().onEnded {
                                    guard vm.roundOver else { return }
                                    presentReferences(for: choice)
                                })
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
        .sheet(isPresented: $showRefSheet, onDismiss: {
            selectedRef = nil
            loadedPreview = nil
            refChoices = []
            currentRefIndex = 0
        }) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    if refChoices.isEmpty {
                        ContentUnavailableView("No reference available", systemImage: "book")
                    } else {
                        HStack(spacing: 12) {
                            Button { moveRefIndex(-1) } label: { Image(systemName: "chevron.left") }
                                .buttonStyle(.plain)
                                .disabled(refChoices.count <= 1)

                            Text("\(currentRefIndex + 1) of \(refChoices.count)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button { moveRefIndex(+1) } label: { Image(systemName: "chevron.right") }
                                .buttonStyle(.plain)
                                .disabled(refChoices.count <= 1)

                            Spacer()
                        }

                        ScriptureLinksList(refs: refChoices, onTap: { ref in
                            if let idx = refChoices.firstIndex(where: { $0 == ref }) {
                                setCurrentRefIndex(idx)
                            } else {
                                selectedRef = ref
                                loadedPreview = BibleReferenceLinker.loadVerses(for: ref)
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
                        Button("Close") { showRefSheet = false }
                    }
                }
                .presentationDetents([.medium, .large])
                .onAppear {
                    if !refChoices.isEmpty {
                        setCurrentRefIndex(currentRefIndex)
                    }
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
            showRefSheet = true
            return
        }

        // Normalize non‑breaking/narrow spaces to regular spaces
        let nbspChars: [Character] = ["\u{00A0}", "\u{202F}", "\u{2007}"]
        for ch in nbspChars {
            refStr = refStr.replacingOccurrences(of: String(ch), with: " ")
        }

        // Split on commas/semicolons into parts, then linkify each part
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

        // Fallback: try whole string if parts yielded nothing
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

        if let first = all.first {
            selectedRef = first
            loadedPreview = BibleReferenceLinker.loadVerses(for: first)
        } else {
            selectedRef = nil
            loadedPreview = nil
        }

        showRefSheet = true
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
        loadedPreview = BibleReferenceLinker.loadVerses(for: ref)
    }

    private func moveRefIndex(_ delta: Int) {
        guard !refChoices.isEmpty else { return }
        let n = refChoices.count
        let newIndex = (currentRefIndex + delta % n + n) % n
        setCurrentRefIndex(newIndex)
    }
}

#Preview {
    NavigationStack {
        WhoAmIGameView()
    }
}
