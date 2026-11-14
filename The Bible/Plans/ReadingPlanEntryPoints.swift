import SwiftUI

/// The Bible tab's way into reading plans, beside Bible Study: today's place in the most
/// recent plan, or an invitation to start one.
struct ReadingPlansEntryCard: View {
    /// The smaller style used in the iPad Books sidebar.
    var compact = false

    @State private var store = ReadingPlanStore.shared

    private var subtitle: String {
        if let (plan, _) = store.activePlans.first, let day = store.currentDay(of: plan) {
            return "\(plan.title) · Day \(day.day) of \(plan.days.count)"
        }
        return compact ? "A day at a time" : "Read a book or topic a day at a time"
    }

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            if let plan = store.activePlans.first?.plan {
                PlanArtworkTile(plan: plan, size: compact ? 28 : 44)
            } else {
                Image(systemName: "calendar.badge.checkmark")
                    .font(compact ? .body : .title2)
                    .foregroundStyle(.tint)
                    .frame(width: compact ? 28 : 44, height: compact ? 28 : 44)
                    .background(Color.accentColor.opacity(0.12), in: Circle())
            }

            VStack(alignment: .leading, spacing: compact ? 2 : 3) {
                Text("Reading Plans")
                    .font(compact ? .subheadline.weight(.semibold) : .headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(compact ? 1 : 2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(compact ? 12 : AppDesignMetrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .heroCardSurface()
        .contentShape(.rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// On a book's Study page: plans that read through the book, and a way to build one.
struct BookPlansSection: View {
    let bookName: String

    /// Present in the iPhone Bible tab; the iPad Study pages have their own navigation, so
    /// plans open in Home there instead.
    @Environment(NavigationCoordinator.self) private var coordinator: NavigationCoordinator?
    @State private var store = ReadingPlanStore.shared

    var body: some View {
        let plans = store.plans(readingMostly: bookName)
        HeroCard(title: "Read This Book as a Plan", icon: "calendar.badge.checkmark") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(plans) { plan in
                    Button {
                        open(plan)
                    } label: {
                        HStack(spacing: 12) {
                            PlanArtworkTile(plan: plan, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(plan.metadataText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if !plans.isEmpty {
                    Divider()
                }

                Button {
                    createPlan()
                } label: {
                    Label("Create a \(bookName) Plan", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Text("Choose how many days and how to read it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func open(_ plan: ReadingPlan) {
        if let coordinator {
            coordinator.push(.readingPlan(id: plan.id))
        } else {
            AppRouter.shared.open(.readingPlan(plan.id))
        }
    }

    private func createPlan() {
        if let coordinator {
            coordinator.push(.customReadingPlanBuilder(book: bookName))
        } else {
            AppRouter.shared.open(.readingPlanBuilder(book: bookName))
        }
    }
}
