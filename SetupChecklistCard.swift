import SwiftUI

/// A short list of settings worth visiting first. Each step opens its Settings page. A step
/// is checked once its setting has changed or the person has opened it from here. Dismiss
/// hides the card like any other Home card, so Customize Home can show it again.
struct SetupChecklistCard: View {
    let onCustomizeHome: () -> Void
    let onDismiss: () -> Void

    enum Step: String, CaseIterable, Identifiable {
        case dailyGoal, verseOfDay, appearance, iCloud, customizeHome

        var id: String { rawValue }

        var title: LocalizedStringResource {
            switch self {
            case .dailyGoal: "Set a daily reading goal"
            case .verseOfDay: "Set up Verse of the Day"
            case .appearance: "Choose an appearance"
            case .iCloud: "Check iCloud sync"
            case .customizeHome: "Customize your Home"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .dailyGoal: "Pick how many minutes to read each day"
            case .verseOfDay: "Choose where verses come from and get reminders"
            case .appearance: "Light or dark mode and backgrounds"
            case .iCloud: "Keep notes and stats on all your devices"
            case .customizeHome: "Choose and arrange your Home cards"
            }
        }

        var systemImage: String {
            switch self {
            case .dailyGoal: "target"
            case .verseOfDay: "book.pages"
            case .appearance: "paintbrush"
            case .iCloud: "icloud"
            case .customizeHome: "rectangle.grid.1x2"
            }
        }
    }

    /// Steps opened from this card, stored as comma-separated raw values.
    static let visitedStepsKey = "homeSetupVisitedSteps"

    @Environment(CloudKitManager.self) private var cloudKitManager
    @Environment(\.persistenceStoreMode) private var persistenceStoreMode
    @AppStorage(Self.visitedStepsKey) private var visitedRaw = ""
    // Same keys and defaults as the Settings pages, so a change there checks the step here.
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes = 30
    @AppStorage("votdRefreshNotificationsEnabled") private var verseOfDayNotificationsEnabled = false
    @AppStorage("colorSchemePreference") private var colorSchemePreferenceRaw = "system"
    // Written the first time the Home layout is saved.
    @AppStorage("homeCardOrder") private var homeCardOrderRaw = ""

    @State private var presentedStep: Step?

    private var visitedSteps: Set<Step> {
        Set(visitedRaw.split(separator: ",").compactMap { Step(rawValue: String($0)) })
    }

    private var isICloudSyncing: Bool {
        cloudKitManager.accountState == .available && persistenceStoreMode == .cloudKit
    }

    private func isComplete(_ step: Step) -> Bool {
        if visitedSteps.contains(step) { return true }
        switch step {
        case .dailyGoal: return dailyGoalMinutes != 30
        case .verseOfDay: return verseOfDayNotificationsEnabled
        case .appearance: return colorSchemePreferenceRaw != "system"
        case .iCloud: return isICloudSyncing
        case .customizeHome: return !homeCardOrderRaw.isEmpty
        }
    }

    private var completedCount: Int {
        Step.allCases.filter(isComplete).count
    }

    private var isAllComplete: Bool {
        completedCount == Step.allCases.count
    }

    var body: some View {
        HeroCard(
            title: "Get Started",
            subtitle: "\(completedCount) of \(Step.allCases.count) done",
            icon: HomeCardID.setup.systemImage,
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 12) {
                ProgressView(value: Double(completedCount), total: Double(Step.allCases.count))
                    .tint(isAllComplete ? .green : .orange)
                    .accessibilityHidden(true)

                VStack(spacing: 4) {
                    ForEach(Step.allCases) { step in
                        stepRow(step)
                    }
                }

                if isAllComplete {
                    Label("You're all set. You can change these anytime in Settings.", systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
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
    }

    private func stepRow(_ step: Step) -> some View {
        let done = isComplete(step)
        return Button {
            open(step)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(done ? Color.green : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(done ? .secondary : .primary)
                    Text(detail(for: step))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? Text("Done") : Text("Not done"))
        .accessibilityHint("Opens settings")
    }

    /// The iCloud step reports its state rather than asking, since sync can't be turned on here.
    private func detail(for step: Step) -> LocalizedStringResource {
        if step == .iCloud && isICloudSyncing {
            return "Syncing across your devices"
        }
        return step.detail
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Bring this card back anytime from Customize Home.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button(isAllComplete ? "Remove Card" : "Dismiss", action: onDismiss)
                .font(.subheadline.weight(.semibold))
                .tint(isAllComplete ? .green : .orange)
                .accessibilityHint("Hides the Get Started card from Home")
        }
    }

    private func open(_ step: Step) {
        markVisited(step)
        Haptics.selection()
        if step == .customizeHome {
            onCustomizeHome()
        } else {
            presentedStep = step
        }
    }

    private func markVisited(_ step: Step) {
        var visited = visitedSteps
        guard visited.insert(step).inserted else { return }
        withAnimation(.snappy) {
            visitedRaw = Step.allCases.filter(visited.contains).map(\.rawValue).joined(separator: ",")
        }
    }

    @ViewBuilder
    private func settingsPage(for step: Step) -> some View {
        switch step {
        case .dailyGoal: SettingsDailyGoalDetailView()
        case .verseOfDay: SettingsVerseOfTheDayDetailView()
        case .appearance: SettingsAppearanceDetailView()
        case .iCloud: SettingsiCloudDetailView()
        // Customize Home opens in Home's own navigation stack instead of a sheet.
        case .customizeHome: EmptyView()
        }
    }
}
