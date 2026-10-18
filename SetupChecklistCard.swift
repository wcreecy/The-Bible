import SwiftData
import SwiftUI

/// A progressive first-use guide that helps someone make an early, meaningful use of the app.
/// Shared reading steps remain the same on every device; the last step adapts to the device.
struct SetupChecklistCard: View {
    let onCustomizeHome: () -> Void
    let onEditHome: () -> Void
    let onDismiss: () -> Void

    fileprivate enum Focus: String, CaseIterable, Identifiable {
        case read
        case study
        case habit
        case settings

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .read: "Start reading"
            case .study: "Explore Scripture"
            case .habit: "Build a daily habit"
            case .settings: "Modify Settings"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .read: "Pick up a short reading path"
            case .study: "Discover passages and study tools"
            case .habit: "Set a rhythm that fits your day"
            case .settings: "Make the app feel like yours"
            }
        }

        var checklistSubtitle: LocalizedStringResource {
            switch self {
            case .read: "Begin your reading journey"
            case .study: "Discover something new"
            case .habit: "Make time for Scripture"
            case .settings: "Make The Bible yours"
            }
        }

        var systemImage: String {
            switch self {
            case .read: "book"
            case .study: "text.book.closed"
            case .habit: "target"
            case .settings: "gearshape"
            }
        }

        func steps(deviceStep: Step) -> [Step] {
            switch self {
            case .read:
                [.firstReading, .saveVerse, .highlightVerse, .focusReading]
            case .study:
                [.firstStudy, .studyChapter]
            case .habit:
                [.dailyGoal, .refreshVerseOfDay, .focusReading, .playGame, .viewReadingStats, .viewGameStats]
            case .settings:
                [.customizeHomeCards, .updateLaunchPage, .setupWidget, .verseOfDaySettings]
            }
        }
    }

    fileprivate enum Step: String, Identifiable {
        case firstReading
        case firstStudy
        case studyChapter
        case saveVerse
        case highlightVerse
        case favoriteVerse
        case dailyGoal
        case refreshVerseOfDay
        case playGame
        case viewReadingStats
        case viewGameStats
        case changeBackground
        case updateLaunchPage
        case setupWidget
        case customizeHomeCards
        case verseOfDaySettings
        case focusReading
        case studyDesk
        case iCloud

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .firstReading: "Read a verse"
            case .firstStudy: "Study about a book"
            case .studyChapter: "Learn about a specific chapter"
            case .saveVerse: "Save a verse that matters to you"
            case .highlightVerse: "Highlight a verse"
            case .favoriteVerse: "Favorite a verse"
            case .dailyGoal: "Reading Goal"
            case .refreshVerseOfDay: "Refresh Verse of the Day"
            case .playGame: "Play any game"
            case .viewReadingStats: "View Reading Stats"
            case .viewGameStats: "View Game Stats"
            case .changeBackground: "Change background"
            case .updateLaunchPage: "Update launch page"
            case .setupWidget: "Set up a widget"
            case .customizeHomeCards: "Customize Homepage cards"
            case .verseOfDaySettings: "Edit Verse of the Day settings"
            case .focusReading: "Focus Reading"
            case .studyDesk: "Build your study desk"
            case .iCloud: "Protect your library with iCloud"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .firstReading: "Start with today’s Verse of the Day"
            case .firstStudy: "Explore a book’s background and themes"
            case .studyChapter: "Explore a chapter’s themes and key passages"
            case .saveVerse: "Highlight, favorite, or add a note to a verse"
            case .highlightVerse: "Mark a passage you want to return to"
            case .favoriteVerse: "Add a verse to your Saved Verses"
            case .dailyGoal: "Set a daily reading goal target"
            case .refreshVerseOfDay: "Refresh the Verse of the Day to find inspiration"
            case .playGame: "Try a Bible game and answer a question"
            case .viewReadingStats: "See your reading progress and habits"
            case .viewGameStats: "See your game activity and progress"
            case .changeBackground: "Choose a color or photo for an app page"
            case .updateLaunchPage: "Choose the page the app opens to"
            case .setupWidget: "Learn how to customize a Home Screen widget"
            case .customizeHomeCards: "Arrange the cards on your Home screen"
            case .verseOfDaySettings: "Choose how your daily verse is selected"
            case .focusReading: "Read one verse at a time"
            case .studyDesk: "Arrange the iPad dashboard for your study"
            case .iCloud: "Keep notes, favorites, and your bookmark available everywhere"
            }
        }

        var systemImage: String {
            switch self {
            case .firstReading: "book.pages"
            case .firstStudy: "text.book.closed"
            case .studyChapter: "lightbulb.max.fill"
            case .saveVerse: "heart.text.clipboard"
            case .highlightVerse: "highlighter"
            case .favoriteVerse: "heart"
            case .dailyGoal: "target"
            case .refreshVerseOfDay: "arrow.clockwise"
            case .playGame: "gamecontroller"
            case .viewReadingStats: "chart.bar"
            case .viewGameStats: "chart.bar.xaxis"
            case .changeBackground: "photo"
            case .updateLaunchPage: "rectangle.on.rectangle"
            case .setupWidget: "rectangle.3.group"
            case .customizeHomeCards: "rectangle.grid.1x2"
            case .verseOfDaySettings: "sun.max"
            case .focusReading: "arrow.up.left.and.arrow.down.right"
            case .studyDesk: "rectangle.3.group"
            case .iCloud: "icloud"
            }
        }

        var canSkip: Bool {
            switch self {
            case .firstReading, .firstStudy, .studyChapter, .saveVerse, .highlightVerse, .favoriteVerse, .refreshVerseOfDay, .playGame, .viewReadingStats, .viewGameStats, .changeBackground, .updateLaunchPage, .customizeHomeCards, .verseOfDaySettings: false
            case .dailyGoal, .setupWidget, .focusReading, .studyDesk, .iCloud: true
            }
        }
    }

    private static let focusKey = "homeOnboardingFocusV2"
    private static let skippedStepsKey = "homeOnboardingSkippedStepsV2"
    private static let readStartedKey = "homeOnboardingReadStartedV2"
    private static let studyOpenedKey = "homeOnboardingStudyOpenedV2"
    private static let savedVerseBaselineKey = "homeOnboardingSavedVerseBaselineV2"
    private static let highlightBaselineKey = "homeOnboardingHighlightBaselineV2"
    private static let favoriteBaselineKey = "homeOnboardingFavoriteBaselineV2"
    private static let gameBaselineKey = "homeOnboardingGameBaselineV2"
    private static let dailyGoalBaselineKey = "homeOnboardingDailyGoalBaselineV2"
    private static let focusReadingBaselineKey = "homeOnboardingFocusReadingBaselineV2"
    private static let homeOrderBaselineKey = "homeOnboardingHomeOrderBaselineV2"
    private static let iCloudBaselineKey = "homeOnboardingICloudBaselineV2"
    private static let backgroundBaselineKey = "homeOnboardingBackgroundBaselineV2"
    private static let launchPageBaselineKey = "homeOnboardingLaunchPageBaselineV2"
    private static let completionBaselineCapturedKey = "homeOnboardingCompletionBaselineCapturedV1"

    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(\.persistenceStoreMode) private var persistenceStoreMode
    @Query private var favorites: [Favorite]
    @Query private var verseNotes: [VerseNote]

    @AppStorage(Self.focusKey) private var focusRaw = ""
    @AppStorage(Self.skippedStepsKey) private var skippedStepsRaw = ""
    @AppStorage(Self.readStartedKey) private var readStarted = false
    @AppStorage(Self.studyOpenedKey) private var studyOpened = false
    @AppStorage("homeOnboardingChapterStudyOpenedV2") private var chapterStudyOpened = false
    @AppStorage("homeOnboardingVODSettingsOpenedV2") private var verseOfDaySettingsOpened = false
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes = 30
    @AppStorage("focusReadingEnabled") private var focusReadingEnabled = false
    @AppStorage("homeOnboardingFocusReadingReadV2") private var focusReadingRead = false
    @AppStorage("homeOnboardingVerseOfDayRefreshedV2") private var verseOfDayRefreshed = false
    @AppStorage("homeOnboardingReadingStatsViewedV2") private var readingStatsViewed = false
    @AppStorage("homeOnboardingGameStatsViewedV2") private var gameStatsViewed = false
    @AppStorage("verseOfDayPaused") private var verseOfDayPaused = false
    @AppStorage("homeCardOrder") private var homeCardOrderRaw = ""
    @AppStorage("homeCardHidden") private var homeCardHiddenRaw = ""
    @AppStorage("verseOfDayBook") private var verseOfDayBook = ""
    @AppStorage("verseOfDayChapter") private var verseOfDayChapter = 0
    @AppStorage("verseOfDayNumber") private var verseOfDayNumber = 0
    @AppStorage(Self.savedVerseBaselineKey) private var savedVerseBaseline = 0
    @AppStorage(Self.highlightBaselineKey) private var highlightBaseline = 0
    @AppStorage(Self.favoriteBaselineKey) private var favoriteBaseline = 0
    @AppStorage(Self.gameBaselineKey) private var gameBaseline = 0
    @AppStorage(Self.dailyGoalBaselineKey) private var dailyGoalBaseline = 30
    @AppStorage(Self.focusReadingBaselineKey) private var focusReadingBaseline = false
    @AppStorage(Self.homeOrderBaselineKey) private var homeOrderBaseline = ""
    @AppStorage(Self.iCloudBaselineKey) private var iCloudBaseline = false
    @AppStorage(Self.backgroundBaselineKey) private var backgroundBaseline = ""
    @AppStorage(Self.launchPageBaselineKey) private var launchPageBaseline = LaunchTabPreference.home.rawValue
    @AppStorage(Self.completionBaselineCapturedKey) private var completionBaselineCaptured = false
    @AppStorage("homeOnboardingWidgetSetupInstructionsViewedV1") private var widgetSetupInstructionsViewed = false

    @State private var presentedStep: Step?
    @State private var isShowingResetConfirmation = false

    private var focus: Focus? {
        Focus(rawValue: focusRaw)
    }

    private var skippedSteps: Set<Step> {
        Set(skippedStepsRaw.split(separator: ",").compactMap { Step(rawValue: String($0)) })
    }

    private var isICloudSyncing: Bool {
        cloudKitManager.accountState == .available && persistenceStoreMode == .cloudKit
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

    private var hasSavedVerse: Bool {
        savedVerseCount > savedVerseBaseline
    }

    private var hasHighlightedVerse: Bool {
        highlightCount > highlightBaseline
    }

    private var hasPlayedGame: Bool {
        gamesAnswered > gameBaseline
    }

    private var backgroundSnapshot: String {
        let tabs: [AppTab] = [.home, .bible, .notes, .games, .more]
        return tabs.flatMap { tab in
            [
                UserDefaults.standard.string(forKey: AppBackgroundStorage.modeKey(for: tab)) ?? "",
                UserDefaults.standard.string(forKey: AppBackgroundStorage.colorKey(for: tab)) ?? "",
                UserDefaults.standard.string(forKey: AppBackgroundStorage.photoKey(for: tab)) ?? ""
            ]
        }
        .joined(separator: "|")
    }

    private var isVerseOfDayCardActive: Bool {
        guard let data = homeCardHiddenRaw.data(using: .utf8),
              let hiddenIDs = try? JSONDecoder().decode([String].self, from: data) else {
            return true
        }
        return !hiddenIDs.contains(HomeCardID.verseOfDay.rawValue)
    }

    private var verseOfDayReference: String? {
        guard !verseOfDayBook.isEmpty, verseOfDayChapter > 0, verseOfDayNumber > 0 else {
            return nil
        }
        return "\(verseOfDayBook) \(verseOfDayChapter):\(verseOfDayNumber)"
    }

    private var deviceStep: Step {
        UIDevice.current.userInterfaceIdiom == .pad ? .studyDesk : .focusReading
    }

    private var steps: [Step] {
        guard let focus else { return [] }
        return focus.steps(deviceStep: deviceStep)
    }

    private var incompleteSteps: [Step] {
        steps.filter { !isComplete($0) }
    }

    private func pathProgressText(_ path: Focus) -> String {
        let pathSteps = path.steps(deviceStep: deviceStep)
        let completedCount = pathSteps.filter(isComplete).count
        return "\(completedCount)/\(pathSteps.count)"
    }

    private var isAllComplete: Bool {
        focus != nil && incompleteSteps.isEmpty
    }

    private var hasExistingCompletionBaseline: Bool {
        [
            Self.savedVerseBaselineKey,
            Self.highlightBaselineKey,
            Self.favoriteBaselineKey,
            Self.gameBaselineKey,
            Self.dailyGoalBaselineKey,
            Self.focusReadingBaselineKey,
            Self.homeOrderBaselineKey,
            Self.iCloudBaselineKey,
            Self.backgroundBaselineKey,
            Self.launchPageBaselineKey
        ].contains { UserDefaults.standard.object(forKey: $0) != nil }
    }

    var body: some View {
        HeroCard(
            title: headerTitle,
            subtitle: subtitle,
            icon: focus?.systemImage ?? HomeCardID.setup.systemImage,
            tint: .orange,
            trailingAccessory: {
                if focus == nil {
                    Button("Reset Card", role: .destructive) {
                        isShowingResetConfirmation = true
                    }
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            },
            titleFont: focus == nil ? .headline : .subheadline
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if focus != nil {
                    ProgressView(value: Double(steps.count - incompleteSteps.count), total: Double(steps.count))
                        .tint(isAllComplete ? .green : .orange)
                        .accessibilityHidden(true)

                    ScrollView(.vertical, showsIndicators: steps.count > 3) {
                        VStack(spacing: 4) {
                            ForEach(steps) { step in
                                OnboardingStepRow(
                                    step: step,
                                    isComplete: isComplete(step),
                                    title: step == .focusReading && focusReadingEnabled
                                        ? "Focus Reading"
                                        : step == .refreshVerseOfDay && !isVerseOfDayCardActive
                                            ? "Show Verse of the Day on Home"
                                            : nil,
                                    detail: step == .firstReading
                                        ? verseOfDayReference.map { "Start with \($0)" }
                                        : step == .focusReading
                                            ? (focusReadingEnabled
                                                ? "Open a passage in Focus Reading"
                                                : "Turn on Focus Reading in Bible Reader settings")
                                            : step == .refreshVerseOfDay && !isVerseOfDayCardActive
                                                ? "Turn on the Verse of the Day card in Home Layout"
                                                : nil,
                                    action: { open(step) },
                                    skipAction: step.canSkip ? { skip(step) } : nil
                                )
                            }
                        }
                    }
                    .frame(maxHeight: steps.count > 3 ? 240 : nil)

                    if isAllComplete {
                        OnboardingCompletionMessage()
                    }
                } else {
                    OnboardingFocusPicker(
                        select: select,
                        progressText: pathProgressText
                    )
                }

                footer
            }
        }
        .sheet(item: $presentedStep) { step in
            NavigationStack {
                settingsPage(for: step)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done", systemImage: "checkmark", role: .confirm) {
                                presentedStep = nil
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

    private var headerTitle: String {
        guard let focus else { return String(localized: "Welcome to The Bible") }
        return String(localized: "Next steps") + " · " + String(localized: focus.title)
    }

    private var subtitle: String {
        if focus == nil {
            String(localized: "Choose your path")
        } else if isAllComplete {
            String(localized: "Your reading space is ready.")
        } else if let focus {
            String(localized: focus.checklistSubtitle)
        } else {
            String(localized: "Choose your path")
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            if focus != nil {
                Button("Choose a different path", systemImage: "chevron.left", action: clearFocus)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityHint("Returns to the Get Started choices")
            } else {
                Text("You can change these anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button(isAllComplete ? "Remove Card" : "Hide Card", action: onDismiss)
                .font(.subheadline.weight(.semibold))
                .tint(isAllComplete ? .green : .orange)
                .accessibilityHint("Hides the Get Started card from Home")
        }
    }

    private func isComplete(_ step: Step) -> Bool {
        if skippedSteps.contains(step) { return true }

        switch step {
        case .firstReading:
            return readStarted
        case .firstStudy:
            return studyOpened
        case .studyChapter:
            return chapterStudyOpened
        case .saveVerse:
            return hasSavedVerse
        case .highlightVerse:
            return hasHighlightedVerse
        case .favoriteVerse:
            return favorites.count > favoriteBaseline
        case .dailyGoal:
            return dailyGoalMinutes != dailyGoalBaseline
        case .refreshVerseOfDay:
            return verseOfDayRefreshed
        case .playGame:
            return hasPlayedGame
        case .viewReadingStats:
            return readingStatsViewed
        case .viewGameStats:
            return gameStatsViewed
        case .changeBackground:
            return backgroundSnapshot != backgroundBaseline
        case .updateLaunchPage:
            return UserDefaults.standard.string(forKey: LaunchTabPreference.defaultsKey) != launchPageBaseline
        case .setupWidget:
            return widgetSetupInstructionsViewed
        case .customizeHomeCards:
            return homeCardOrderRaw != homeOrderBaseline
        case .verseOfDaySettings:
            return verseOfDaySettingsOpened
        case .focusReading:
            return focusReadingRead
        case .studyDesk:
            return homeCardOrderRaw != homeOrderBaseline
        case .iCloud:
            return isICloudSyncing != iCloudBaseline
        }
    }

    private func select(_ focus: Focus) {
        establishCompletionBaselineIfNeeded()
        withAnimation(.snappy) {
            focusRaw = focus.rawValue
        }
        Haptics.selection()
    }

    private func clearFocus() {
        withAnimation(.snappy) {
            focusRaw = ""
        }
    }

    private func resetChecklist() {
        captureCompletionBaseline()
        completionBaselineCaptured = true
        withAnimation(.snappy) {
            focusRaw = ""
            skippedStepsRaw = ""
            readStarted = false
            studyOpened = false
            chapterStudyOpened = false
            verseOfDaySettingsOpened = false
            focusReadingRead = false
            verseOfDayRefreshed = false
            readingStatsViewed = false
            gameStatsViewed = false
            widgetSetupInstructionsViewed = false
        }
        Haptics.selection()
    }

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
        favoriteBaseline = favorites.count
        gameBaseline = gamesAnswered
        dailyGoalBaseline = dailyGoalMinutes
        focusReadingBaseline = focusReadingEnabled
        homeOrderBaseline = homeCardOrderRaw
        iCloudBaseline = isICloudSyncing
        backgroundBaseline = backgroundSnapshot
        launchPageBaseline = UserDefaults.standard.string(forKey: LaunchTabPreference.defaultsKey) ?? LaunchTabPreference.home.rawValue
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
        case .firstReading:
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
        case .firstStudy:
            studyOpened = true
            UserDefaults.standard.set(
                verseOfDayBook.isEmpty ? "Genesis" : verseOfDayBook,
                forKey: "lastStudiedBook"
            )
            UserDefaults.standard.set(true, forKey: "openLastStudiedBookOverview")
            AppRouter.shared.open(.bibleStudy)
        case .studyChapter:
            chapterStudyOpened = true
            let bookName = verseOfDayBook.isEmpty ? "Genesis" : verseOfDayBook
            let chapterNumber = verseOfDayChapter > 0 ? verseOfDayChapter : 1
            UserDefaults.standard.set(bookName, forKey: "lastStudiedBook")
            UserDefaults.standard.set(chapterNumber, forKey: "lastStudiedChapter")
            UserDefaults.standard.set(true, forKey: "openLastStudiedChapter")
            AppRouter.shared.open(.bibleStudy)
        case .saveVerse, .highlightVerse, .favoriteVerse:
            AppRouter.shared.openBibleReference(book: "John", chapter: 3, verse: 16)
        case .refreshVerseOfDay:
            guard isVerseOfDayCardActive else {
                onCustomizeHome()
                return
            }
            guard !verseOfDayPaused else {
                presentedStep = .verseOfDaySettings
                return
            }
            AppRouter.shared.open(.tab(.home))
        case .playGame:
            GameLaunchRequest.open(gameName: "Bible Quiz")
        case .viewReadingStats:
            readingStatsViewed = true
            AppRouter.shared.open(.stats(.reading))
        case .viewGameStats:
            gameStatsViewed = true
            AppRouter.shared.open(.stats(.games))
        case .changeBackground, .updateLaunchPage:
            presentedStep = step
        case .setupWidget:
            widgetSetupInstructionsViewed = true
            presentedStep = step
        case .verseOfDaySettings:
            verseOfDaySettingsOpened = true
            presentedStep = step
        case .studyDesk:
            onCustomizeHome()
        case .customizeHomeCards:
            onEditHome()
        case .dailyGoal, .iCloud:
            presentedStep = step
        case .focusReading:
            if focusReadingEnabled {
                focusReadingRead = true
                AppRouter.shared.openBibleReference(book: "John", chapter: 3, verse: 16)
            } else {
                presentedStep = step
            }
        }
    }

    @ViewBuilder
    private func settingsPage(for step: Step) -> some View {
        switch step {
        case .dailyGoal:
            SettingsDailyGoalDetailView()
        case .focusReading:
            SettingsBibleReaderDetailView(highlightFocusReading: true)
        case .iCloud:
            SettingsiCloudDetailView()
        case .changeBackground:
            SettingsAppearanceDetailView()
        case .updateLaunchPage:
            SettingsLaunchTabSection()
        case .setupWidget:
            WidgetCustomizationInstructionsView()
        case .verseOfDaySettings:
            SettingsVerseOfTheDayDetailView()
        case .firstReading, .firstStudy, .studyChapter, .saveVerse, .highlightVerse, .favoriteVerse, .refreshVerseOfDay, .playGame, .viewReadingStats, .viewGameStats, .studyDesk, .customizeHomeCards:
            EmptyView()
        }
    }
}

private struct WidgetCustomizationInstructionsView: View {
    var body: some View {
        ContentUnavailableView(
            "Customize Widgets",
            systemImage: "rectangle.3.group",
            description: Text("Touch and hold a widget on your Home Screen, then choose Edit Widget to select its background.")
        )
        .navigationTitle("Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OnboardingFocusPicker: View {
    let select: (SetupChecklistCard.Focus) -> Void
    let progressText: (SetupChecklistCard.Focus) -> String

    var body: some View {
        VStack(spacing: 8) {
            ForEach(SetupChecklistCard.Focus.allCases) { focus in
                Button {
                    select(focus)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: focus.systemImage)
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(focus.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                            Text(focus.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }

                        Spacer(minLength: 8)

                        Text(progressText(focus))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("\(progressText(focus)) tasks completed")

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct OnboardingStepRow: View {
    let step: SetupChecklistCard.Step
    let isComplete: Bool
    let title: String?
    let detail: String?
    let action: () -> Void
    let skipAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: action) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isComplete ? .green : .secondary)
                        .frame(width: 22)
                        .accessibilityHidden(true)

                    Image(systemName: step.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isComplete ? Color.secondary : Color.accentColor)
                        .frame(width: 22)

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

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isComplete)

            if !isComplete, let skipAction {
                Button("Not now", action: skipAction)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityHint("Marks this optional step complete")
            }
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .contain)
    }
}

private struct OnboardingCompletionMessage: View {
    var body: some View {
        Label("You’re all set. Your Home page will keep helping you return to Scripture.", systemImage: "checkmark.seal.fill")
            .font(.subheadline)
            .foregroundStyle(.green)
    }
}
