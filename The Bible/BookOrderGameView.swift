import SwiftUI

struct BookOrderGameView: View {
    @State private var vm = BookOrderGameViewModel()
    @State private var elapsedSeconds: Int = 0
    @State private var isTimerHidden: Bool = false

    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    var body: some View {
        GeometryReader { geometry in
        VStack {
            if !vm.started {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Rearrange the books in the correct order.")
                            .gameStartDescriptionStyle(title: "Book Order", systemImage: "list.number", tint: .purple)

                        GameSplashLaunchLayout(tint: .purple, startAction: startGame) {
                            GameLobbyPreview(kind: .bookOrder, bookOrderBooks: vm.source.previewBookNames)
                        } configuration: {
                            BookOrderSetupControls(
                                source: $vm.source,
                                difficulty: $vm.difficulty,
                                roundBookCount: vm.roundBookCount
                            )
                        } facts: {
                            GameSplashFacts(
                                first: ("books.vertical", "\(vm.roundBookCount)", String(localized: "Books")),
                                second: (
                                    "stopwatch",
                                    vm.savedBestTime.map(Self.formatted) ?? "—",
                                    String(localized: "Best time")
                                ),
                                third: ("flame.fill", "\(vm.persistentBestStreak)", String(localized: "Best streak"))
                            )
                        }
                    }
                    .padding()
                }
            } else if geometry.size.width >= 700 {
                iPadGameBoard(availableHeight: geometry.size.height)
            } else {
                compactGameBoard
            }
        }
        }
        .tabBarContentClearance()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.started {
                    GameNavigationTitle(title: "Book Order", systemImage: "list.number", tint: .purple)
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

    // MARK: - iPhone

    private var compactGameBoard: some View {
        VStack(spacing: 12) {
            GameScoreboardCard(
                currentCorrect: vm.score,
                currentAnswered: vm.answered,
                currentStreak: vm.sessionStreak,
                game: .bookorder
            )

            HStack(alignment: .firstTextBaseline) {
                Text(prompt)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                timerToggle
            }

            List {
                ForEach(Array(vm.currentItems.enumerated()), id: \.element) { index, item in
                    BookOrderRow(
                        position: index + 1,
                        book: item,
                        correctBook: vm.showResult ? vm.correctBook(at: index) : nil
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(rowBackground(for: item, at: index))
                    .moveDisabled(vm.showResult)
                }
                .onMove(perform: vm.move)
            }
            .environment(\.editMode, .constant(EditMode.active))
            .listStyle(.plain)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))

            if vm.showResult {
                resultSummary
            }

            actionButtons
        }
        .padding()
    }

    // MARK: - iPad

    private func iPadGameBoard(availableHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            GameScoreboardCard(
                currentCorrect: vm.score,
                currentAnswered: vm.answered,
                currentStreak: vm.sessionStreak,
                game: .bookorder,
                style: .dashboard
            )
            .heroCardSurface()

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
                Text(prompt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            List {
                ForEach(Array(vm.currentItems.enumerated()), id: \.element) { index, item in
                    HStack(spacing: 10) {
                        Image(systemName: vm.showResult ? resultIcon(for: item, at: index) : "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Text(item)
                            .font(.body.weight(.medium))
                        Spacer()
                        if vm.showResult, let correct = vm.correctBook(at: index), correct != item {
                            Text("Should be \(correct)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 46)
                    .glassEffect(answerGlass(for: item, at: index), in: .rect(cornerRadius: 12))
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .moveDisabled(vm.showResult)
                }
                .onMove(perform: vm.move)
            }
            .environment(\.editMode, .constant(EditMode.active))
            .scrollContentBackground(.hidden)

            if vm.showResult {
                resultSummary
            }

            actionButtons
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
                            .font(.largeTitle.weight(.bold))
                            .fontDesign(.rounded)
                            .monospacedDigit()

                        Text("Time Elapsed")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }

                    if let best = vm.savedBestTime {
                        Label("Best \(Self.formatted(best))", systemImage: "trophy.fill")
                            .font(.subheadline.weight(.semibold))
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

    // MARK: - Shared pieces

    private var prompt: String {
        let count = vm.correctOrder.count
        return switch vm.source {
        case .both: String(localized: "Put these \(count) books in Bible order.")
        case .ot: String(localized: "Put these \(count) Old Testament books in Bible order.")
        case .nt: String(localized: "Put these \(count) New Testament books in Bible order.")
        default: String(localized: "Put these \(count) \(String(localized: vm.source.title)) books in Bible order.")
        }
    }

    /// Elapsed time on iPhone, with a tap to hide it.
    private var timerToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isTimerHidden.toggle()
            }
        } label: {
            if isTimerHidden {
                Label("Show Timer", systemImage: "eye.slash")
                    .labelStyle(.iconOnly)
            } else {
                Label(formattedElapsedTime, systemImage: "stopwatch")
                    .monospacedDigit()
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
        .accessibilityLabel(isTimerHidden ? "Show timer" : "Time elapsed \(formattedElapsedTime). Hide timer")
    }

    private var resultSummary: some View {
        BookOrderResultSummary(
            wasCorrect: vm.wasCorrect,
            booksInPlace: vm.booksInPlace,
            total: vm.correctOrder.count,
            time: Self.formatted(vm.lastTimeSeconds),
            bestTime: vm.bestTimeSeconds.map(Self.formatted),
            isNewBestTime: vm.isNewBestTime
        )
    }

    @ViewBuilder
    private var actionButtons: some View {
        if vm.showResult {
            HStack(spacing: 12) {
                Button("Change Settings", systemImage: "slider.horizontal.3", action: endGame)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))

                Button("Next Puzzle", systemImage: "arrow.right.circle.fill", action: advanceToNextRound)
                    .buttonStyle(GameProminentButtonStyle(tint: .purple))
            }
        } else {
            VStack(spacing: 10) {
                Button("Check", systemImage: "checkmark.circle.fill", action: checkOrder)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))

                // DEBUG: WIN button
                if debugAutoWinEnabled, !vm.correctOrder.isEmpty {
                    Button("WIN") {
                        vm.currentItems = vm.correctOrder
                        checkOrder()
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .red))
                    .accessibilityLabel("Win this round")
                }
            }
        }
    }

    private var formattedElapsedTime: String {
        Self.formatted(elapsedSeconds)
    }

    nonisolated private static func formatted(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private var canonicalBooks: [String] {
        BibleCanon.canonicalOrder()
    }

    private func isInPlace(_ book: String, at index: Int) -> Bool {
        vm.correctBook(at: index) == book
    }

    private func rowBackground(for book: String, at index: Int) -> Color? {
        guard vm.showResult else { return nil }
        return isInPlace(book, at: index) ? Color.green.opacity(0.15) : Color.red.opacity(0.15)
    }

    private func resultIcon(for book: String, at index: Int) -> String {
        isInPlace(book, at: index) ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private func answerGlass(for book: String, at index: Int) -> Glass {
        guard vm.showResult else { return .regular.interactive() }
        let tint: Color = isInPlace(book, at: index) ? .green.opacity(0.3) : .red.opacity(0.3)
        return .regular.tint(tint)
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
        vm.checkOrder(elapsedSeconds: elapsedSeconds)
    }

    private func advanceToNextRound() {
        elapsedSeconds = 0
        vm.nextRound()
    }

    private func endGame() {
        elapsedSeconds = 0
        vm.endGame()
    }
}

private struct BookOrderRow: View {
    let position: Int
    let book: String
    /// The book that belongs here, once checked.
    let correctBook: String?

    private var isChecked: Bool { correctBook != nil }
    private var isInPlace: Bool { correctBook == book }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(position)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(book)
                    .font(.subheadline.weight(.medium))

                if let correctBook, !isInPlace {
                    Text("Should be \(correctBook)")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer(minLength: 8)

            if isChecked {
                Image(systemName: isInPlace ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isInPlace ? .green : .red)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BookOrderResultSummary: View {
    let wasCorrect: Bool
    let booksInPlace: Int
    let total: Int
    let time: String
    let bestTime: String?
    let isNewBestTime: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                wasCorrect ? "Correct!" : "Not quite",
                systemImage: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(wasCorrect ? Color.green : Color.red)

            Text(wasCorrect ? "All \(total) books are in order." : "\(booksInPlace) of \(total) books are in the right place.")
                .font(.subheadline)

            HStack(spacing: 16) {
                Label(time, systemImage: "stopwatch")
                    .monospacedDigit()

                if isNewBestTime {
                    Label("New best time!", systemImage: "trophy.fill")
                        .foregroundStyle(.orange)
                } else if let bestTime {
                    Label("Best \(bestTime)", systemImage: "trophy")
                        .monospacedDigit()
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            (wasCorrect ? Color.green : Color.red).opacity(0.1),
            in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct BookOrderSetupControls: View {
    @Binding var source: BookSourceScope
    @Binding var difficulty: BookOrderDifficulty
    let roundBookCount: Int

    private static let testamentOptions = BookSourceScope.allCases.filter { !$0.isCategory }
    private static let categoryOptions = BookSourceScope.allCases.filter(\.isCategory)

    private var partPhrase: String {
        switch source {
        case .both: String(localized: "the Bible")
        case .ot: String(localized: "the Old Testament")
        case .nt: String(localized: "the New Testament")
        default: String(localized: "the \(String(localized: source.title)) books")
        }
    }

    private var detail: String {
        let available = source.bookNames.count
        if difficulty.runLength == nil {
            return String(localized: "Every book in \(partPhrase): \(available) books.")
        }
        if roundBookCount < (difficulty.runLength ?? 0) {
            return String(localized: "\(String(localized: source.title)) has only \(available) books, so you’ll arrange all of them.")
        }
        return String(localized: "A run of \(roundBookCount) books in a row from \(partPhrase).")
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Part of the Bible")
                    .font(.headline)

                Spacer()

                Picker("Part of the Bible", selection: $source) {
                    ForEach(Self.testamentOptions) { option in
                        Text(option.title).tag(option)
                    }

                    Section("Book Groups") {
                        ForEach(Self.categoryOptions) { option in
                            Text(option.title).tag(option)
                        }
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty")
                    .font(.headline)

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(BookOrderDifficulty.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 620)
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        BookOrderGameView()
    }
}
