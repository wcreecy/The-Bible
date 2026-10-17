import SwiftData
import SwiftUI

/// A progressive first-use guide that helps someone make an early, meaningful use of the app.
/// Shared reading steps remain the same on every device; the last step adapts to the device.
struct SetupChecklistCard: View {
    let onCustomizeHome: () -> Void
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
                [.firstReading, .saveVerse, deviceStep, .iCloud]
            case .study:
                [.firstStudy, .highlightVerse, .favoriteVerse, deviceStep, .iCloud]
            case .habit:
                [.dailyGoal, .playGame, deviceStep, .iCloud]
            case .settings:
                [.changeBackground, .updateLaunchPage, .setupWidget, .customizeHomeCards]
            }
        }
    }

    fileprivate enum Step: String, Identifiable {
        case firstReading
        case firstStudy
        case saveVerse
        case highlightVerse
        case favoriteVerse
        case dailyGoal
        case playGame
        case changeBackground
        case updateLaunchPage
        case setupWidget
        case customizeHomeCards
        case focusReading
        case studyDesk
        case iCloud

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .firstReading: "Read your first passage"
            case .firstStudy: "Explore a Bible study"
            case .saveVerse: "Save a verse that matters to you"
            case .highlightVerse: "Highlight a verse"
            case .favoriteVerse: "Favorite a verse"
            case .dailyGoal: "Set a daily reading goal"
            case .playGame: "Play any game"
            case .changeBackground: "Change background"
            case .updateLaunchPage: "Update launch page"
            case .setupWidget: "Set up a widget"
            case .customizeHomeCards: "Customize Home screen cards"
            case .focusReading: "Try Focus Reading"
            case .studyDesk: "Build your study desk"
            case .iCloud: "Protect your library with iCloud"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .firstReading: "Open Mark 1 and begin reading"
            case .firstStudy: "See themes, people, places, and connections"
            case .saveVerse: "Highlight, favorite, or add a note to a verse"
            case .highlightVerse: "Mark a passage you want to return to"
            case .favoriteVerse: "Add a verse to your Saved Verses"
            case .dailyGoal: "Choose a goal that fits your day"
            case .playGame: "Try a Bible game and answer a question"
            case .changeBackground: "Choose a color or photo for an app page"
            case .updateLaunchPage: "Choose the page the app opens to"
            case .setupWidget: "Choose backgrounds for your Home Screen widgets"
            case .customizeHomeCards: "Arrange the cards on your Home screen"
            case .focusReading: "Read one verse at a time on iPhone"
            case .studyDesk: "Arrange the iPad dashboard for your study"
            case .iCloud: "Keep notes, favorites, and bookmarks available everywhere"
            }
        }

        var systemImage: String {
            switch self {
            case .firstReading: "book.pages"
            case .firstStudy: "text.book.closed"
            case .saveVerse: "heart.text.clipboard"
            case .highlightVerse: "highlighter"
            case .favoriteVerse: "heart"
            case .dailyGoal: "target"
            case .playGame: "gamecontroller"
            case .changeBackground: "photo"
            case .updateLaunchPage: "rectangle.on.rectangle"
            case .setupWidget: "rectangle.3.group"
            case .customizeHomeCards: "rectangle.grid.1x2"
            case .focusReading: "arrow.up.left.and.arrow.down.right"
            case .studyDesk: "rectangle.3.group"
            case .iCloud: "icloud"
            }
        }

        var canSkip: Bool {
            switch self {
            case .firstReading, .firstStudy, .saveVerse, .highlightVerse, .favoriteVerse, .playGame, .changeBackground, .updateLaunchPage, .setupWidget, .customizeHomeCards: false
            case .dailyGoal, .focusReading, .studyDesk, .iCloud: true
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
    private static let widgetBaselineKey = "homeOnboardingWidgetBaselineV2"

    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(\.persistenceStoreMode) private var persistenceStoreMode
    @Query private var favorites: [Favorite]
    @Query private var verseNotes: [VerseNote]

    @AppStorage(Self.focusKey) private var focusRaw = ""
    @AppStorage(Self.skippedStepsKey) private var skippedStepsRaw = ""
    @AppStorage(Self.readStartedKey) private var readStarted = false
    @AppStorage(Self.studyOpenedKey) private var studyOpened = false
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes = 30
    @AppStorage("focusReadingEnabled") private var focusReadingEnabled = false
    @AppStorage("homeCardOrder") private var homeCardOrderRaw = ""
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
    @AppStorage(Self.widgetBaselineKey) private var widgetBaseline = ""

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

    private var widgetSnapshot: String {
        let defaults = UserDefaults(suiteName: "group.bible.app") ?? .standard
        return [
            defaults.string(forKey: "verseWidgetBackground") ?? "",
            defaults.string(forKey: "lastReadWidgetBackground") ?? "",
            defaults.string(forKey: "pinnedVerseWidgetBackground") ?? ""
        ]
        .joined(separator: "|")
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

    private var isAllComplete: Bool {
        focus != nil && incompleteSteps.isEmpty
    }

    var body: some View {
        HeroCard(
            title: focus == nil ? "Welcome to The Bible" : "Your next steps",
            subtitle: subtitle,
            icon: HomeCardID.setup.systemImage,
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let focus {
                    OnboardingFocusHeader(focus: focus, backAction: clearFocus)

                    ProgressView(value: Double(steps.count - incompleteSteps.count), total: Double(steps.count))
                        .tint(isAllComplete ? .green : .orange)
                        .accessibilityHidden(true)

                    VStack(spacing: 4) {
                        ForEach(incompleteSteps.prefix(3)) { step in
                            OnboardingStepRow(
                                step: step,
                                action: { open(step) },
                                skipAction: step.canSkip ? { skip(step) } : nil
                            )
                        }
                    }

                    if isAllComplete {
                        OnboardingCompletionMessage()
                    } else if incompleteSteps.count > 3 {
                        Text("Complete these first; the rest will appear next.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    OnboardingFocusPicker(select: select)
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

    private var subtitle: String {
        if focus == nil {
            String(localized: "Choose how you’d like to begin.")
        } else if isAllComplete {
            String(localized: "Your reading space is ready.")
        } else {
            String(localized: "A few small steps, tailored to your device.")
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("You can change these anytime in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Button(isAllComplete ? "Remove Card" : "Dismiss", action: onDismiss)
                    .font(.subheadline.weight(.semibold))
                    .tint(isAllComplete ? .green : .orange)
                    .accessibilityHint("Hides the Get Started card from Home")
            }

            if focus != nil {
                Button("Reset Checklist", role: .destructive) {
                    isShowingResetConfirmation = true
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    private func isComplete(_ step: Step) -> Bool {
        if skippedSteps.contains(step) { return true }

        switch step {
        case .firstReading:
            return readStarted
        case .firstStudy:
            return studyOpened
        case .saveVerse:
            return hasSavedVerse
        case .highlightVerse:
            return hasHighlightedVerse
        case .favoriteVerse:
            return favorites.count > favoriteBaseline
        case .dailyGoal:
            return dailyGoalMinutes != dailyGoalBaseline
        case .playGame:
            return hasPlayedGame
        case .changeBackground:
            return backgroundSnapshot != backgroundBaseline
        case .updateLaunchPage:
            return UserDefaults.standard.string(forKey: LaunchTabPreference.defaultsKey) != launchPageBaseline
        case .setupWidget:
            return widgetSnapshot != widgetBaseline
        case .customizeHomeCards:
            return homeCardOrderRaw != homeOrderBaseline
        case .focusReading:
            return focusReadingEnabled != focusReadingBaseline
        case .studyDesk:
            return homeCardOrderRaw != homeOrderBaseline
        case .iCloud:
            return isICloudSyncing != iCloudBaseline
        }
    }

    private func select(_ focus: Focus) {
        captureCompletionBaseline()
        withAnimation(.snappy) {
            focusRaw = focus.rawValue
            skippedStepsRaw = ""
            readStarted = false
            studyOpened = false
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
        withAnimation(.snappy) {
            skippedStepsRaw = ""
            readStarted = false
            studyOpened = false
        }
        Haptics.selection()
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
        widgetBaseline = widgetSnapshot
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
            AppRouter.shared.openBibleReference(book: "Mark", chapter: 1, verse: 1)
        case .firstStudy:
            studyOpened = true
            AppRouter.shared.open(.bibleStudy)
        case .saveVerse, .highlightVerse, .favoriteVerse:
            AppRouter.shared.openBibleReference(book: "John", chapter: 3, verse: 16)
        case .playGame:
            GameLaunchRequest.open(gameName: "Bible Quiz")
        case .changeBackground, .updateLaunchPage, .setupWidget:
            presentedStep = step
        case .studyDesk, .customizeHomeCards:
            onCustomizeHome()
        case .dailyGoal, .focusReading, .iCloud:
            presentedStep = step
        }
    }

    @ViewBuilder
    private func settingsPage(for step: Step) -> some View {
        switch step {
        case .dailyGoal:
            SettingsDailyGoalDetailView()
        case .focusReading:
            SettingsView()
        case .iCloud:
            SettingsiCloudDetailView()
        case .changeBackground:
            SettingsAppearanceDetailView()
        case .updateLaunchPage:
            SettingsLaunchTabSection()
        case .setupWidget:
            SettingsWidgetAppearanceDetailView()
        case .firstReading, .firstStudy, .saveVerse, .highlightVerse, .favoriteVerse, .playGame, .studyDesk, .customizeHomeCards:
            EmptyView()
        }
    }
}

private struct OnboardingFocusPicker: View {
    let select: (SetupChecklistCard.Focus) -> Void

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
                            Text(focus.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

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

private struct OnboardingFocusHeader: View {
    let focus: SetupChecklistCard.Focus
    let backAction: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button("All paths", systemImage: "chevron.left", action: backAction)
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityHint("Returns to the Get Started choices")

            Spacer(minLength: 8)

            Label(focus.title, systemImage: focus.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
        }
    }
}

private struct OnboardingStepRow: View {
    let step: SetupChecklistCard.Step
    let action: () -> Void
    let skipAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button(action: action) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: step.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(step.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let skipAction {
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
