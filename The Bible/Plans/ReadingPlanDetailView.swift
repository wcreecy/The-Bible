import SwiftUI

/// One plan: what it covers, where the reader is, and every day with its checkmark.
struct ReadingPlanDetailView: View {
    let planID: String

    @Environment(NavigationCoordinator.self) private var coordinator
    @State private var store = ReadingPlanStore.shared
    @State private var confirmsRestart = false
    @State private var confirmsStop = false
    @State private var confirmsDelete = false
    @State private var celebration: ReadingPlanStore.Completion?
    @State private var showsReadDays = false

    /// Fewer finished days than this stay listed; more fold into one row so the next day
    /// is near the top.
    private static let foldThreshold = 3

    var body: some View {
        Group {
            if let plan = store.plan(id: planID) {
                content(plan)
            } else {
                ContentUnavailableView(
                    "Plan Not Found",
                    systemImage: "book.closed",
                    description: Text("This plan was deleted.")
                )
            }
        }
        .scrollContentBackground(.hidden)
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: store.latestCompletion) { _, completion in
            if let completion, completion.planID == planID, completion.finishedPlan {
                celebration = completion
            }
        }
        .sheet(item: $celebration) { _ in
            if let plan = store.plan(id: planID) {
                PlanFinishedView(plan: plan)
                    .presentationDetents([.medium])
            }
        }
    }

    private func content(_ plan: ReadingPlan) -> some View {
        let enrollment = store.enrollment(for: plan.id)
        return List {
            Section {
                header(plan, enrollment: enrollment)
            }
            .listRowBackground(HeroCardListRowBackground())

            Section("Days") {
                let current = enrollment?.isActive == true ? store.currentDay(of: plan)?.day : nil
                // Every day before the next one is read; fold them once there are a few.
                let readDays = current.map { next in plan.days.filter { $0.day < next } } ?? []
                let foldsReadDays = readDays.count >= Self.foldThreshold

                if foldsReadDays {
                    DisclosureGroup(isExpanded: $showsReadDays) {
                        ForEach(readDays) { day in
                            dayRow(day, plan: plan, current: current, enrollment: enrollment)
                        }
                    } label: {
                        Label(
                            readDays.count == 1 ? "Day 1 read" : "Days 1–\(readDays.count) read",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.secondary)
                    }
                }

                ForEach(foldsReadDays ? plan.days.filter { $0.day >= current ?? 0 } : plan.days) { day in
                    dayRow(day, plan: plan, current: current, enrollment: enrollment)
                }
            }
            .listRowBackground(HeroCardListRowBackground())
        }
        .navigationTitle(plan.title)
        .toolbar {
            if enrollment != nil || plan.isCustom {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if enrollment != nil {
                            Button("Start Over", systemImage: "arrow.counterclockwise") { confirmsRestart = true }
                            Button("Stop Plan", systemImage: "stop.circle", role: .destructive) { confirmsStop = true }
                        }
                        if plan.isCustom {
                            Button("Delete Plan", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Plan options")
                }
            }
        }
        .confirmationDialog("Start this plan over from day 1?", isPresented: $confirmsRestart, titleVisibility: .visible) {
            Button("Start Over", role: .destructive) { store.restart(plan.id) }
        } message: {
            Text("Your checkmarks for this plan will be cleared.")
        }
        .confirmationDialog("Stop this plan?", isPresented: $confirmsStop, titleVisibility: .visible) {
            Button("Stop Plan", role: .destructive) { store.stop(plan.id) }
        } message: {
            Text("It's removed from your plans in progress. You can start it again any time.")
        }
        .confirmationDialog("Delete this plan?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete Plan", role: .destructive) {
                store.deleteCustomPlan(plan.id)
                if coordinator.path.last == .readingPlan(id: plan.id) {
                    coordinator.path.removeLast()
                }
            }
        }
    }

    private func dayRow(_ day: PlanDay, plan: ReadingPlan, current: Int?, enrollment: PlanEnrollment?) -> some View {
        DayRow(
            plan: plan,
            day: day,
            isCurrent: current == day.day,
            canCheck: enrollment != nil,
            store: store
        )
    }

    /// "FRUIT OF THE SPIRIT · PART 3 OF 9" for a plan in a series, otherwise its category.
    private func eyebrow(for plan: ReadingPlan) -> String {
        if let series = plan.series, let position = store.seriesPosition(of: plan) {
            return "\(series) · Part \(position.position) of \(position.count)".uppercased()
        }
        return plan.category.uppercased()
    }

    /// "Last read today", "Last read yesterday", "Last read 3 days ago".
    private func lastReadText(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ...0: return "Last read today"
        case 1: return "Last read yesterday"
        default: return "Last read \(days) days ago"
        }
    }

    @ViewBuilder
    private func header(_ plan: ReadingPlan, enrollment: PlanEnrollment?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(eyebrow(for: plan))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(plan.title)
                        .font(.title2.weight(.bold))
                    Text(plan.metadataText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if enrollment != nil {
                    ProgressRing(progress: store.progress(of: plan), lineWidth: 6, size: 56) {
                        Text("\(enrollment?.completedDays.count ?? 0)/\(plan.days.count)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityLabel(ReadingPlanHomeCard.progressLabel(
                        read: enrollment?.completedDays.count ?? 0,
                        of: plan.days.count
                    ))
                }
            }

            Text(plan.description)
                .font(.body)
                .foregroundStyle(.secondary)

            if let pace = store.paceDescription(for: plan) {
                Label(pace, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Only once something has been read; a just-started plan has nothing to report.
            if let enrollment, enrollment.isActive, let lastRead = enrollment.lastDayCompletedAt {
                Label(lastReadText(lastRead), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            primaryAction(plan, enrollment: enrollment)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func primaryAction(_ plan: ReadingPlan, enrollment: PlanEnrollment?) -> some View {
        if let enrollment, enrollment.finishedAt != nil {
            Label("Plan complete", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
            if let next = store.nextInSeries(after: plan) {
                NavigationLink(value: Route.readingPlan(id: next.id)) {
                    Label("Next in Series: \(next.title)", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                }
            }
            Button("Read It Again") { store.restart(plan.id) }
                .buttonStyle(.bordered)
                .disabled(!store.canStart(plan.id))
            if !store.canStart(plan.id) {
                PlanLimitNote(message: store.limitMessage)
            }
        } else if enrollment != nil, let day = store.currentDay(of: plan) {
            Button {
                store.continuePlan(plan.id)
            } label: {
                // Text only: inside a list row, a filled button's icon takes the button's own color.
                Text("Read Day \(day.day): \(day.readingSummary)")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button {
                store.start(plan.id)
            } label: {
                Text("Start Plan")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!store.canStart(plan.id))
            if !store.canStart(plan.id) {
                PlanLimitNote(message: store.limitMessage)
            }
        }
    }
}

/// A day in the plan list. The circle checks the day off; the rest opens it.
private struct DayRow: View {
    let plan: ReadingPlan
    let day: PlanDay
    let isCurrent: Bool
    let canCheck: Bool
    let store: ReadingPlanStore

    private var isComplete: Bool { store.isDayComplete(day.day, planID: plan.id) }

    var body: some View {
        HStack(spacing: 12) {
            if canCheck {
                Button {
                    withAnimation(.snappy) {
                        store.setDay(day.day, of: plan.id, complete: !isComplete)
                    }
                } label: {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isComplete ? Color.green : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isComplete ? "Day \(day.day) read" : "Mark day \(day.day) read")
            }

            NavigationLink(value: Route.readingPlanDay(planID: plan.id, day: day.day)) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Day \(day.day)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                        if isCurrent {
                            Text("NEXT")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    Text(day.title)
                        .font(.body.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(isComplete ? .secondary : .primary)
                    if day.title != day.readingSummary {
                        Text(day.readingSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Shown when the last day of a plan is checked off.
struct PlanFinishedView: View {
    let plan: ReadingPlan

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating)
            Text("Plan Complete!")
                .font(.title.weight(.bold))
            Text("You finished \(plan.title): \(plan.durationText) in God's Word.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(28)
        .onAppear { Haptics.success() }
    }
}

/// Why a plan can't be started right now.
struct PlanLimitNote: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
