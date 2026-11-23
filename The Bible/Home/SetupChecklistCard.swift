import SwiftData
import SwiftUI

/// A short first-use checklist that walks someone through the few actions that make the app
/// useful: reading, saving a verse, setting a goal, trying a game, and arranging Home.
struct SetupChecklistCard: View {
    let onEditHome: () -> Void
    let onDismiss: () -> Void

    fileprivate enum Step: String, CaseIterable, Identifiable {
        case readVerse
        case saveVerse
        case dailyGoal
        case playGame
        case customizeHome

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .readVerse: "Read today’s verse"
            case .saveVerse: "Save or highlight a verse"
            case .dailyGoal: "Set a daily reading goal"
            case .playGame: "Play a Bible game"
            case .customizeHome: "Make Home yours"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .readVerse: "Open the Verse of the Day in the reader"
            case .saveVerse: "Tap a verse to select it, then tap it again to highlight or favorite it"
            case .dailyGoal: "Choose your daily minutes, then tap Confirm Goal"
            case .playGame: "Answer a quick quiz question"
            case .customizeHome: "Rearrange the cards on this page"
            }
        }

        var systemImage: String {
            switch self {
            case .readVerse: "book.pages"
            case .saveVerse: "highlighter"
            case .dailyGoal: "target"
            case .playGame: "gamecontroller"
            case .customizeHome: "rectangle.grid.1x2"
            }
        }

        var canSkip: Bool {
            switch self {
            case .readVerse, .saveVerse: false
            case .dailyGoal, .playGame, .customizeHome: true
            }
        }
    }

    private static let skippedStepsKey = "homeOnboardingSkippedStepsV2"
    private static let readStartedKey = "homeOnboardingReadStartedV2"
    private static let dailyGoalReviewedKey = "homeOnboardingDailyGoalReviewedV3"
    private static let savedVerseBaselineKey = "homeOnboardingSavedVerseBaselineV2"
    private static let highlightBaselineKey = "homeOnboardingHighlightBaselineV2"
    private static let gameBaselineKey = "homeOnboardingGameBaselineV2"
    private static let homeOrderBaselineKey = "homeOnboardingHomeOrderBaselineV2"
    private static let completionBaselineCapturedKey = "homeOnboardingCompletionBaselineCapturedV1"
    private static let completedDayKey = "homeOnboardingCompletedDayV1"
    private static let didAutoHideKey = "homeOnboardingDidAutoHideV1"

    @Query private var favorites: [Favorite]
    @Query private var verseNotes: [VerseNote]

    @AppStorage(Self.skippedStepsKey) private var skippedStepsRaw = ""
    @AppStorage(Self.readStartedKey) private var readStarted = false
    @AppStorage(Self.dailyGoalReviewedKey) private var dailyGoalReviewed = false
    @AppStorage(AppStorageKey.homeCardOrder) private var homeCardOrderRaw = ""
    @AppStorage(AppStorageKey.verseOfDayBook) private var verseOfDayBook = ""
    @AppStorage(AppStorageKey.verseOfDayChapter) private var verseOfDayChapter = 0
    @AppStorage(AppStorageKey.verseOfDayNumber) private var verseOfDayNumber = 0
    @AppStorage(Self.savedVerseBaselineKey) private var savedVerseBaseline = 0
    @AppStorage(Self.highlightBaselineKey) private var highlightBaseline = 0
    @AppStorage(Self.gameBaselineKey) private var gameBaseline = 0
    @AppStorage(Self.homeOrderBaselineKey) private var homeOrderBaseline = ""
    @AppStorage(Self.completionBaselineCapturedKey) private var completionBaselineCaptured = false
    /// The day every step was first done (`yyyy-MM-dd`), or empty while steps remain.
    @AppStorage(Self.completedDayKey) private var completedDay = ""
    /// Set once the finished card has left Home on its own, so it only ever does that once.
    @AppStorage(Self.didAutoHideKey) private var didAutoHide = false

    @State private var isShowingDailyGoal = false
    @State private var isShowingResetConfirmation = false

    private let steps = Step.allCases

    private var skippedSteps: Set<Step> {
        Set(skippedStepsRaw.split(separator: ",").compactMap { Step(rawValue: String($0)) })
    }

    private var savedVerseCount: Int {
        favorites.count + verseNotes.filter { !$0.title.isEmpty || !$0.content.isEmpty }.count
    }

    private var highlightCount: Int {
        verseNotes.filter { !$0.highlightColor.isEmpty }.count
    }

    private var gamesAnswered: Int {
        let _ = GameStats.shared.version
        return GameStats.shared.snapshot().totalAnswered
    }

    private var verseOfDayReference: String? {
        guard !verseOfDayBook.isEmpty, verseOfDayChapter > 0, verseOfDayNumber > 0 else {
            return nil
        }
        return "\(verseOfDayBook) \(verseOfDayChapter):\(verseOfDayNumber)"
    }

    private var completedStepCount: Int {
        steps.filter(isComplete).count
    }

    private var isAllComplete: Bool {
        completedStepCount == steps.count
    }

    private var hasExistingCompletionBaseline: Bool {
        [
            Self.savedVerseBaselineKey,
            Self.highlightBaselineKey,
            Self.gameBaselineKey,
            Self.homeOrderBaselineKey
        ].contains { UserDefaults.standard.object(forKey: $0) != nil }
    }

    var body: some View {
        HeroCard(
            title: String(localized: "Welcome to The Bible"),
            subtitle: subtitle,
            icon: HomeCardID.setup.systemImage,
            tint: .orange,
            trailingAccessory: {
                if completedStepCount > 0 {
                    Menu {
                        Button("Reset Checklist", systemImage: "arrow.counterclockwise", role: .destructive) {
                            isShowingResetConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("More options")
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ProgressView(value: Double(completedStepCount), total: Double(steps.count))
                    .tint(isAllComplete ? .green : .orange)
                    .accessibilityHidden(true)

                VStack(spacing: 4) {
                    ForEach(steps) { step in
                        OnboardingStepRow(
                            step: step,
                            isComplete: isComplete(step),
                            title: step == .playGame ? TodayChallengeStore.gameChallengeTitle(for: selectedGameName) : nil,
                            detail: step == .readVerse
                                ? verseOfDayReference.map { String(localized: "Start with \($0)") }
                                : step == .playGame
                                    ? String(localized: "Answer one question to complete this.")
                                : nil,
                            action: { open(step) },
                            skipAction: step.canSkip ? { skip(step) } : nil
                        )
                    }
                }

                if isAllComplete {
                    OnboardingCompletionMessage()
                }

                footer
            }
        }
        .onAppear {
            establishCompletionBaselineIfNeeded()
        }
        .onChange(of: isAllComplete, initial: true) { _, isComplete in
            updateAutomaticDismissal(isComplete: isComplete)
        }
        .sheet(isPresented: $isShowingDailyGoal) {
            NavigationStack {
                SettingsDailyGoalDetailView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Confirm Goal", systemImage: "checkmark", role: .confirm) {
                                dailyGoalReviewed = true
                                isShowingDailyGoal = false
                            }
                        }
                    }
            }
        }
        .confirmationDialog(
            "Reset this checklist?",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Checklist", role: .destructive, action: resetChecklist)
        } message: {
            Text("This leaves your notes, favorites, game progress, and settings unchanged.")
        }
    }

    private var subtitle: String {
        if isAllComplete {
            String(localized: "You’re all set")
        } else {
            String(localized: "\(completedStepCount) of \(steps.count) steps done")
        }
    }

    private let selectedGameName = "Quiz"

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(leavesHomeTomorrow
                 ? "This card leaves Home tomorrow. You can show it again in Customize Home."
                 : "You can show this card again in Customize Home.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button(isAllComplete ? "Done" : "Hide", action: onDismiss)
                .font(.subheadline.weight(.semibold))
                .tint(isAllComplete ? .green : .orange)
                .accessibilityHint("Removes the Welcome card from Home")
        }
    }

    /// Whether the finished card will leave Home on its own the next day.
    private var leavesHomeTomorrow: Bool {
        isAllComplete && !didAutoHide
    }

    /// A finished card shows its completion message for the rest of the day, then leaves Home
    /// the next time it appears. It does this once: a card shown again from Customize Home
    /// stays until it's dismissed.
    private func updateAutomaticDismissal(isComplete: Bool, now: Date = Date()) {
        guard !didAutoHide else { return }
        guard isComplete else {
            completedDay = ""
            return
        }
        let today = BibleStatsStore.isoDateString(now)
        if completedDay.isEmpty {
            completedDay = today
        } else if completedDay < today {
            didAutoHide = true
            onDismiss()
        }
    }

    private func isComplete(_ step: Step) -> Bool {
        if skippedSteps.contains(step) { return true }

        switch step {
        case .readVerse:
            return readStarted
        case .saveVerse:
            // Highlighting counts too, since the step invites either.
            return savedVerseCount > savedVerseBaseline || highlightCount > highlightBaseline
        case .dailyGoal:
            return dailyGoalReviewed
        case .playGame:
            return gamesAnswered > gameBaseline
        case .customizeHome:
            return homeCardOrderRaw != homeOrderBaseline
        }
    }

    private func resetChecklist() {
        captureCompletionBaseline()
        completionBaselineCaptured = true
        withAnimation(.snappy) {
            skippedStepsRaw = ""
            readStarted = false
            dailyGoalReviewed = false
        }
        Haptics.selection()
    }

    /// Records current counts once so only actions taken after the card first appears check off steps.
    private func establishCompletionBaselineIfNeeded() {
        guard !completionBaselineCaptured else { return }

        guard !hasExistingCompletionBaseline else {
            completionBaselineCaptured = true
            return
        }

        captureCompletionBaseline()
        completionBaselineCaptured = true
    }

    private func captureCompletionBaseline() {
        savedVerseBaseline = savedVerseCount
        highlightBaseline = highlightCount
        gameBaseline = gamesAnswered
        homeOrderBaseline = homeCardOrderRaw
    }

    private func skip(_ step: Step) {
        var skipped = skippedSteps
        guard skipped.insert(step).inserted else { return }
        withAnimation(.snappy) {
            skippedStepsRaw = steps.filter(skipped.contains).map(\.rawValue).joined(separator: ",")
        }
    }

    private func open(_ step: Step) {
        Haptics.selection()

        switch step {
        case .readVerse:
            readStarted = true
            if verseOfDayReference != nil {
                AppRouter.shared.openBibleReference(
                    book: verseOfDayBook,
                    chapter: verseOfDayChapter,
                    verse: verseOfDayNumber
                )
            } else {
                AppRouter.shared.open(.verseOfDayNotification)
            }
        case .saveVerse:
            AppRouter.shared.openBibleReference(book: "John", chapter: 3, verse: 16)
        case .dailyGoal:
            isShowingDailyGoal = true
        case .playGame:
            GameLaunchRequest.open(gameName: selectedGameName)
        case .customizeHome:
            onEditHome()
        }
    }
}

private struct OnboardingStepRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let step: SetupChecklistCard.Step
    let isComplete: Bool
    let title: String?
    let detail: String?
    let action: () -> Void
    let skipAction: (() -> Void)?

    /// Width of the checkmark and step icon columns. It grows with the text size so the
    /// body-sized symbols never overlap each other or the title at large sizes.
    @ScaledMetric(relativeTo: .body) private var iconColumnWidth: CGFloat = 22
    private static let columnSpacing: CGFloat = 10

    /// The checkmark and step icon columns plus their spacing, so Skip lines up with the text.
    private var textLeadingInset: CGFloat { (iconColumnWidth + Self.columnSpacing) * 2 }

    var body: some View {
        // Skip sits under the step's description rather than beside it, so the text keeps the
        // card's full width in narrow columns (such as iPad portrait).
        VStack(alignment: .leading, spacing: 6) {
            Button(action: action) {
                let rowLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Self.columnSpacing))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: Self.columnSpacing))
                rowLayout {
                    HStack(spacing: Self.columnSpacing) {
                        Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isComplete ? .green : .secondary)
                            .frame(width: iconColumnWidth)
                            .accessibilityHidden(true)

                        Image(systemName: step.systemImage)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(isComplete ? Color.secondary : Color.accentColor)
                            .frame(width: iconColumnWidth)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title ?? String(localized: step.title))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isComplete ? .secondary : .primary)
                            .strikethrough(isComplete)
                        Text(detail ?? String(localized: step.detail))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .strikethrough(isComplete)
                    }

                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isComplete)

            if !isComplete, let skipAction {
                Button("Skip", action: skipAction)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    // Matches the card's Hide button and progress bar.
                    .tint(.orange)
                    .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : textLeadingInset)
                    .accessibilityHint("Marks this optional step complete")
            }
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .contain)
    }
}

private struct OnboardingCompletionMessage: View {
    var body: some View {
        Label("Your Home page will keep helping you return to Scripture.", systemImage: "checkmark.seal.fill")
            .font(.subheadline)
            .foregroundStyle(.green)
    }
}
