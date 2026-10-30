import SwiftUI
import SwiftData

struct VerseMatchGameView: View {
    @Query private var favorites: [Favorite]
    @State private var vm: VerseMatchGameViewModel

    init(reviewQuestionIDs: Set<String> = []) {
        _vm = State(initialValue: VerseMatchGameViewModel(reviewQuestionIDs: reviewQuestionIDs))
    }

    // Global Auto‑Win debug toggle
    private var debugAutoWinEnabled: Bool { DebugOptions.autoWinEnabled }

    // Layout-only state
    @State private var referenceOnLeading = true
    @State private var verseToast = VerseActionToastState()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Favorites come from SwiftData, which only a view can query, so they're handed to the view model.
    private var favoriteVerses: [VerseMatchVerse] {
        favorites.map {
            VerseMatchVerse(bookName: $0.bookName, chapterNumber: $0.chapterNumber,
                            verseNumber: $0.verseNumber, verseText: $0.verseText)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch vm.phase {
                case .setup:
                    setupContent
                case .playing:
                    gameContent
                case .results:
                    Spacer(minLength: 32)
                    VerseMatchResultsCard(
                        score: vm.session.score,
                        total: vm.totalQuestions,
                        bestStreak: vm.session.sessionBestStreak,
                        bestGameScore: vm.session.bestGameScore,
                        isNewBest: vm.session.isNewBestGame,
                        onPlayAgain: vm.startGame,
                        onChangeSettings: vm.resetToSetup
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .tabBarContentClearance()
        .verseActionToast($verseToast)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.phase != .setup {
                    GameNavigationTitle(title: "Verses", systemImage: "text.quote", tint: .orange)
                }
            }
        }
        .onChange(of: favoriteVerses, initial: true) { _, verses in
            vm.favoriteVerses = verses
        }
        .onAppear {
            vm.onAppear()
        }
        // Sort out list and repeated verses while the start screen is showing.
        .task {
            await vm.prepareFilter()
        }
        .onDisappear {
            vm.onDisappear()
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupContent: some View {
        Spacer(minLength: 32)
        Text("Choose the verse text that matches the reference.")
            .gameStartDescriptionStyle(title: "Verses", systemImage: "text.quote", tint: .orange)

        GameSplashLaunchLayout(
            tint: .orange,
            experienceLevel: $vm.experienceLevel,
            experienceDetails: GameExperienceDetails(
                learn: "A gentle way to practice matching verses.",
                standard: "A balanced verse-matching challenge.",
                challenge: "A more demanding verse-matching challenge."
            ),
            experienceTitle: vm.reviewQuestionIDs.isEmpty ? "How you’ll play" : "Timer",
            isConfigurationEnabled: vm.reviewQuestionIDs.isEmpty,
            isStartEnabled: vm.canStart,
            startAction: vm.startGame
        ) {
            GameLobbyPreview(kind: .verseMatch)
        } configuration: {
            VStack(alignment: .leading, spacing: 8) {
                GameSettingsGroup {
                    VerseMatchSetupControls(
                        pool: $vm.pool,
                        isFavoritesAvailable: vm.isFavoritesAvailable
                    )

                    QuizCategoryQuickPicks(tint: .orange, selection: $vm.selectedSections)

                    GameStartMultiPickerCard(
                        title: "Fine-tune Categories",
                        tint: .orange,
                        selection: $vm.selectedSections,
                        options: QuizVerseSection.allCases
                    ) { section in
                        Text(section.title)
                    }
                }

                if !vm.isFilterReady {
                    Label {
                        Text("Preparing verses…")
                    } icon: {
                        ProgressView()
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }
            }
        } facts: {
            GameSplashFacts(
                first: ("number", "\(VerseMatchGameViewModel.questionsPerGame) questions", String(localized: "This session")),
                second: ("text.quote", String(localized: vm.pool.title), String(localized: "Verses")),
                third: ("square.stack.3d.up", "4", String(localized: "Choices"))
            )
        }
        Spacer(minLength: 32)
    }

    // MARK: - Gameplay

    @ViewBuilder
    private var gameContent: some View {
        if let current = vm.current {
            GameScoreboardCard(
                currentCorrect: vm.session.score,
                currentAnswered: vm.session.answered,
                currentStreak: vm.session.streak,
                game: .versematch,
                style: horizontalSizeClass == .regular ? .dashboard : .compact
            )

            VerseMatchBoard(
                reference: current.verse.reference,
                progressText: vm.progressText,
                options: current.options,
                selectedIndex: current.selectedIndex,
                correctIndex: current.correctIndex,
                isLocked: vm.isAnswered || vm.isViewingPrevious,
                usesSideBySideLayout: horizontalSizeClass == .regular,
                referenceOnLeading: $referenceOnLeading,
                onSelect: vm.select
            )

            if vm.isAnswered {
                VerseMatchNavigationButtons(
                    canGoPrevious: vm.canGoPrevious,
                    isLastQuestion: vm.isOnLastQuestion,
                    onPrevious: vm.showPrevious,
                    onNext: vm.showNext
                )
            }

            // DEBUG: WIN button
            if debugAutoWinEnabled, !vm.isAnswered, !vm.isViewingPrevious {
                Button("WIN") {
                    vm.select(current.correctIndex)
                }
                .buttonStyle(ModernPillButtonStyle(tint: .red))
                .controlSize(.large)
                .padding(.top, 6)
                .accessibilityLabel("Win this round")
            }
        }
    }
}
