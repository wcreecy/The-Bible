import SwiftUI

struct BookOrderGameView: View {
    @State private var vm = BookOrderGameViewModel()
    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false
    @State private var elapsedSeconds: Int = 0
    @State private var isTimerHidden: Bool = false

    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    var body: some View {
        GeometryReader { geometry in
        VStack {
            if !vm.started {
                VStack(spacing: 16) {
                    Text("Rearrange the books in the correct order.")
                        .gameStartDescriptionStyle()

                    GameStartInfoLayout {
                        GroupBox {
                            DisclosureGroup(isExpanded: $howToExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Choose a source (OT/NT) and difficulty, then tap Start.")
                                    Text("• Drag the rows to arrange the books in canonical order.")
                                    Text("• Tap Check to see results; then tap Next for a new round.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("How to Play").font(.headline)
                            }
                        }

                        GroupBox {
                            DisclosureGroup(isExpanded: $difficultyExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Easy: Arrange 5 books.")
                                    Text("• Normal: Arrange 10 books.")
                                    Text("• Hard: Arrange 15 books.")
                                    Text("• All Books: Arrange the entire selected canon.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Difficulty Settings").font(.headline)
                            }
                        }

                        GameStartCurrentGameCard {
                            GameStartCurrentGameRow(
                                label: "Source",
                                value: vm.source == .both ? "Old & New Testaments" : vm.source == .ot ? "Old Testament" : "New Testament"
                            )
                            GameStartCurrentGameRow(
                                label: "Difficulty",
                                value: vm.difficulty == .easy ? "Easy" : vm.difficulty == .normal ? "Normal" : vm.difficulty == .hard ? "Hard" : "All Books"
                            )
                            GameStartCurrentGameRow(
                                label: "Books per Round",
                                value: vm.difficulty == .easy ? "5" : vm.difficulty == .normal ? "10" : vm.difficulty == .hard ? "15" : "Entire selected canon"
                            )
                        }
                    }
                    .gameStartOptionsStyle()
                    .expandGameStartCardsOnIPad(
                        howTo: $howToExpanded,
                        difficulty: $difficultyExpanded
                    )
                    .padding(.horizontal)

                    GameStartSettingsLayout {
                        GameStartPickerCard(
                            title: "Book Source",
                            selection: $vm.source,
                            options: [.both, .ot, .nt]
                        ) { source in
                            switch source {
                            case .both: Text("OT & NT")
                            case .ot: Text("OT")
                            case .nt: Text("NT")
                            }
                        }

                        GameStartPickerCard(
                            title: "Difficulty",
                            selection: $vm.difficulty,
                            options: BookOrderDifficulty.allCases
                        ) { difficulty in
                            switch difficulty {
                            case .easy: Text("Easy")
                            case .normal: Text("Normal")
                            case .hard: Text("Hard")
                            case .all: Text("All Books")
                            }
                        }
                    }
                    .padding(.horizontal)

                    Button("Start") {
                        startGame()
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.large)
                    .frame(maxWidth: 240)
                }
                .padding()
                Spacer()
            } else if geometry.size.width >= 700 {
                iPadGameBoard(availableHeight: geometry.size.height)
            } else {
                VStack(spacing: 12) {
                    // Scoreboard (shared)
                    GameScoreboardCard(
                        currentCorrect: vm.score,
                        currentAnswered: vm.answered,
                        currentStreak: vm.currentStreak,
                        game: .bookorder
                    )

                    List {
                        ForEach(vm.currentItems, id: \.self) { item in
                            Text(item)
                                .font(.footnote)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onMove(perform: vm.move)
                    }
                    .environment(\.editMode, .constant(EditMode.active))

                    HStack(spacing: 16) {
                        Button(action: checkOrder) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Check")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                        .disabled(vm.showResult)
                        .controlSize(.regular)

                        if vm.showResult {
                            Button(action: advanceToNextRound) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Next")
                                }
                            }
                            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                            .controlSize(.regular)
                        }
                    }
                    .padding(.top)

                    if vm.showResult {
                        if vm.wasCorrect {
                            Text("Correct!")
                                .font(.headline)
                                .foregroundColor(.green)
                                .padding(.top)
                        } else {
                            VStack(spacing: 8) {
                                Text("Not quite.")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                if vm.showingCorrectOrder {
                                    GroupBox("Your Order vs Correct") {
                                        if vm.shouldShowComparison {
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack {
                                                    Text("Your order").font(.subheadline).foregroundStyle(.secondary)
                                                    Spacer()
                                                    Text("Correct order").font(.subheadline).foregroundStyle(.secondary)
                                                }
                                                ForEach(Array(vm.comparisonRows.enumerated()), id: \.offset) { _, row in
                                                    HStack {
                                                        Text(row.your)
                                                            .foregroundStyle(row.isMatch ? .green : .red)
                                                        Spacer()
                                                        Text(row.correct)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        } else {
                                            // Fallback: show only the correct order if we don't have a submission
                                            VStack(alignment: .leading, spacing: 4) {
                                                ForEach(vm.correctOrder, id: \.self) { book in
                                                    Text(book)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            }
                            .padding(.top)
                        }
                    }

                    // DEBUG: WIN button
                    if debugAutoWinEnabled, vm.started, !vm.showResult, !vm.correctOrder.isEmpty {
                        Button("WIN") {
                            vm.currentItems = vm.correctOrder
                            checkOrder()
                        }
                        .buttonStyle(ModernPillButtonStyle(tint: .red))
                        .controlSize(.large)
                        .padding(.top, 6)
                        .accessibilityLabel("Win this round")
                    }
                }
                .padding()
                Spacer()
            }
        }
        }
        .navigationTitle("Book Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                GameNavigationTitle(title: "Book Order", systemImage: "list.number")
            }

            if vm.started {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .task(id: vm.started && !vm.showResult) {
            guard vm.started, !vm.showResult else { return }

            while !Task.isCancelled, vm.started, !vm.showResult {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }

                guard !Task.isCancelled, vm.started, !vm.showResult else { return }
                elapsedSeconds += 1
            }
        }
    }

    private func iPadGameBoard(availableHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            BookOrderDashboardScoreboard(
                score: vm.score,
                answered: vm.answered,
                streak: vm.currentStreak,
                allTimeCorrect: vm.allTimeCorrect,
                allTimeAnswered: vm.allTimeAnswered,
                allTimeBestStreak: vm.allTimeBestStreak
            )

            HStack(spacing: 12) {
                iPadBookListCard

                iPadTimerAndCanonCard
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .top)
    }

    private var iPadBookListCard: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Arrange the Books", systemImage: "list.number")
                    .font(.headline.weight(.bold))
                Text("Drag the tiles into canonical order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            List {
                ForEach(vm.currentItems, id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Text(item)
                            .font(.body.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 46)
                    .glassEffect(answerGlass(for: item), in: .rect(cornerRadius: 12))
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: vm.move)
            }
            .environment(\.editMode, .constant(EditMode.active))
            .scrollContentBackground(.hidden)

            HStack(spacing: 12) {
                Button(action: checkOrder) {
                    Label("Check", systemImage: "checkmark.circle.fill")
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                .disabled(vm.showResult)

                if vm.showResult {
                    Button(action: advanceToNextRound) {
                        Label("Next", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                }
            }
            .controlSize(.regular)

            if vm.showResult {
                Label(
                    vm.wasCorrect ? "Correct!" : "Not quite.",
                    systemImage: vm.wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(vm.wasCorrect ? Color.green : Color.red)
            }

            if debugAutoWinEnabled, !vm.showResult, !vm.correctOrder.isEmpty {
                Button("WIN") {
                    vm.currentItems = vm.correctOrder
                    checkOrder()
                }
                .buttonStyle(ModernPillButtonStyle(tint: .red))
                .accessibilityLabel("Win this round")
            }
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .heroCardSurface()
    }

    private var iPadTimerAndCanonCard: some View {
        VStack(spacing: 16) {
            if vm.showResult {
                HStack {
                    Label("Books of the Bible", systemImage: "books.vertical.fill")
                        .font(.headline.weight(.bold))

                    Spacer()

                    Label(formattedElapsedTime, systemImage: "stopwatch.fill")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(canonicalBooks.enumerated()), id: \.element) { index, book in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, alignment: .trailing)

                                Text(book)
                                    .font(.body.weight(.medium))

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 46)
                            .glassEffect(canonGlass(for: book), in: .rect(cornerRadius: 12))
                        }
                    }
                    .padding(4)
                }
            } else {
                Spacer()

                VStack(spacing: 14) {
                    if isTimerHidden {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Timer Hidden")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "stopwatch.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(.tint)

                        Text(formattedElapsedTime)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .monospacedDigit()

                        Text("Time Elapsed")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isTimerHidden ? "Timer hidden" : "Time elapsed")
                .accessibilityValue(isTimerHidden ? "" : formattedElapsedTime)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isTimerHidden.toggle()
                    }
                } label: {
                    Label(isTimerHidden ? "Show Timer" : "Hide Timer", systemImage: isTimerHidden ? "eye" : "eye.slash")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.glass)
                .controlSize(.small)
            }
        }
        .padding(AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .heroCardSurface()
    }

    private var formattedElapsedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var canonicalBooks: [String] {
        BibleCanon.canonicalOrder()
    }

    private func answerGlass(for book: String) -> Glass {
        guard vm.showResult,
              let submittedIndex = vm.currentItems.firstIndex(of: book),
              vm.correctOrder.indices.contains(submittedIndex) else {
            return .regular.interactive()
        }

        let tint: Color = vm.correctOrder[submittedIndex] == book
            ? .green.opacity(0.3)
            : .red.opacity(0.3)
        return .regular.tint(tint).interactive()
    }

    private func canonGlass(for book: String) -> Glass {
        guard vm.correctOrder.contains(book) else { return .regular }
        return .regular.tint(.green.opacity(0.3))
    }

    private func startGame() {
        elapsedSeconds = 0
        vm.startGame()
    }

    private func checkOrder() {
        vm.checkOrder()
    }

    private func advanceToNextRound() {
        elapsedSeconds = 0
        vm.showResult = false
        vm.showingCorrectOrder = false
        vm.nextRound()
    }
}

private struct BookOrderDashboardScoreboard: View {
    let score: Int
    let answered: Int
    let streak: Int
    let allTimeCorrect: Int
    let allTimeAnswered: Int
    let allTimeBestStreak: Int

    private var accuracy: Int {
        guard answered > 0 else { return 0 }
        return Int((Double(score) / Double(answered) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("This Game", systemImage: "chart.bar.fill")
                    .font(.headline.weight(.bold))

                Spacer()

                Text("All time: \(allTimeCorrect)/\(allTimeAnswered)  •  Best streak \(allTimeBestStreak)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                BookOrderScoreMetric(title: "Correct", value: "\(score)", systemImage: "checkmark.circle.fill", tint: .green)
                BookOrderScoreMetric(title: "Attempts", value: "\(answered)", systemImage: "scope", tint: .blue)
                BookOrderScoreMetric(title: "Accuracy", value: "\(accuracy)%", systemImage: "percent", tint: .purple)
                BookOrderScoreMetric(title: "Streak", value: "\(streak)", systemImage: "flame.fill", tint: .orange)
            }
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }
}

private struct BookOrderScoreMetric: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            Label(value, systemImage: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

#Preview {
    NavigationStack {
        BookOrderGameView()
    }
}
