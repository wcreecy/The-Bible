import SwiftUI

/// Home's reading plan card: today's reading in the current plan, or plans to start.
struct ReadingPlanHomeCard: View {
    let usesCompactLayout: Bool
    let onOpenLibrary: () -> Void
    let onOpenPlan: (String) -> Void
    let onCreatePlan: () -> Void

    @State private var store = ReadingPlanStore.shared

    var body: some View {
        HeroCard(title: "", subtitle: nil, icon: nil, tint: .blue) {
            if let (plan, enrollment) = store.activePlans.first, let day = store.currentDay(of: plan) {
                activeContent(plan: plan, enrollment: enrollment, day: day)
            } else {
                browseContent
            }
        }
    }

    // MARK: - A plan in progress

    private func activeContent(plan: ReadingPlan, enrollment: PlanEnrollment, day: PlanDay) -> some View {
        VStack(alignment: .leading, spacing: usesCompactLayout ? 10 : 12) {
            // The plans list sits up here, so the action buttons below keep their room.
            HStack {
                Text("READING PLAN")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("All Plans", action: onOpenLibrary)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            }

            Button {
                onOpenPlan(plan.id)
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            PlanArtworkTile(plan: plan, size: 26)
                            Text(plan.title)
                                .font(.headline)
                                .bold()
                                .lineLimit(1)
                        }
                        Text("Day \(day.day) of \(plan.days.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(day.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if day.title != day.readingSummary {
                            Text(day.readingSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        if let pace = store.paceDescription(for: plan) {
                            Text(pace)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)

                    ProgressRing(progress: store.progress(of: plan), lineWidth: 5, size: 46) {
                        Text("\(enrollment.completedDays.count)/\(plan.days.count)")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                    }
                    .accessibilityLabel(Self.progressLabel(read: enrollment.completedDays.count, of: plan.days.count))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    store.continuePlan(plan.id)
                } label: {
                    Label("Start Reading", systemImage: "book.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)

                Button {
                    withAnimation(.snappy) {
                        store.setDay(day.day, of: plan.id, complete: true)
                    }
                    Haptics.success()
                } label: {
                    Label {
                        Text("Mark Read")
                    } icon: {
                        // The checkmark symbol reads as "Selected" to VoiceOver; the text says it.
                        Image(systemName: "checkmark").accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                }
                .accessibilityLabel("Mark day \(day.day) read")
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)

                Spacer(minLength: 0)
            }

            // The other plans in progress, each a tap from its next reading.
            let others = Array(store.activePlans.dropFirst())
            if !others.isEmpty {
                Divider()
                ForEach(others, id: \.plan.id) { other in
                    otherPlanRow(other.plan, enrollment: other.enrollment)
                }
            }
        }
    }

    private func otherPlanRow(_ plan: ReadingPlan, enrollment: PlanEnrollment) -> some View {
        HStack(spacing: 12) {
            Button {
                onOpenPlan(plan.id)
            } label: {
                HStack(spacing: 10) {
                    PlanArtworkTile(plan: plan, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let day = store.currentDay(of: plan) {
                            Text("Day \(day.day) of \(plan.days.count) · \(day.readingSummary)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Self.progressLabel(read: enrollment.completedDays.count, of: plan.days.count))

            Button("Read") {
                store.continuePlan(plan.id)
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .accessibilityLabel("Read \(plan.title)")
        }
    }

    /// "3 of 21 days read", "0 of 1 day read".
    static func progressLabel(read: Int, of total: Int) -> String {
        total == 1 ? "\(read) of 1 day read" : "\(read) of \(total) days read"
    }

    // MARK: - No plan in progress

    private var browseContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpenLibrary) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    Text("Reading Plans")
                        .font(.headline)
                        .bold()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let (plan, _) = store.finishedPlans.first {
                Label("You finished \(plan.title)!", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Text("Read through the Bible a day at a time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(suggestedPlans) { plan in
                Button {
                    onOpenPlan(plan.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(plan.metadataText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button("Create Your Own", systemImage: "plus", action: onCreatePlan)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        }
    }

    /// Two short plans not finished yet, starting with the getting-started ones.
    private var suggestedPlans: [ReadingPlan] {
        let finished = Set(store.finishedPlans.map(\.plan.id))
        return Array(store.catalog.filter { !finished.contains($0.id) && $0.durationDays <= 14 }.prefix(2))
    }
}

/// A one-time note on Home introducing reading plans, until the reader dismisses it or
/// starts a plan.
struct ReadingPlansNewTip: View {
    let onBrowse: () -> Void

    @AppStorage("readingPlansNewTipDismissed") private var isDismissed = false
    @State private var store = ReadingPlanStore.shared

    var body: some View {
        if !isDismissed && store.document.enrollments.isEmpty {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 6) {
                    Text("New: Reading Plans")
                        .font(.headline)
                    Text("Read through a book or a topic a day at a time, or build your own plan.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Browse Plans", action: onBrowse)
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation { isDismissed = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface()
        }
    }
}
