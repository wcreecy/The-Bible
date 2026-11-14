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
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.title3)
                                .foregroundStyle(Color.accentColor)
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
