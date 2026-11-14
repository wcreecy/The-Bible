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
                ForEach(plan.days) { day in
                    DayRow(
                        plan: plan,
                        day: day,
                        isCurrent: enrollment?.isActive == true && store.currentDay(of: plan)?.day == day.day,
                        canCheck: enrollment != nil,
                        store: store
                    )
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

    @ViewBuilder
    private func header(_ plan: ReadingPlan, enrollment: PlanEnrollment?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.category.uppercased())
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
            Button("Read It Again") { store.restart(plan.id) }
                .buttonStyle(.bordered)
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
