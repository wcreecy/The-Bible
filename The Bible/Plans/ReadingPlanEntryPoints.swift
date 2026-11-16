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
        if compact {
            compactRow
        } else {
            // The current plan's art, or the plans' own when none is running.
            let active = store.activePlans.first?.plan
            FeatureTile(
                style: active.map { PlanArtworkStyle.forPlan($0) } ?? .readingPlans,
                title: "Reading Plans",
                subtitle: subtitle,
                progress: active.map { store.progress(of: $0) }
            )
        }
    }

    private var compactRow: some View {
        let active = store.activePlans.first?.plan
        return SidebarFeatureCard(
            style: active.map { PlanArtworkStyle.forPlan($0) } ?? .readingPlans,
            title: "Reading Plans",
            subtitle: subtitle,
            progress: active.map { store.progress(of: $0) }
        )
        .heroCardSurface()
        .contentShape(.rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// On a book's Study page: plans that read through the book, and a way to build one.
struct BookPlansSection: View {
    let bookName: String

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

    // Opens in the Bible tab: on iPhone in place of the Study pages (which are pushed as views,
    // not routes), so Back returns to the book list; on iPad in the detail pane.
    private func open(_ plan: ReadingPlan) {
        AppRouter.shared.open(.readingPlanInBible(.readingPlan(id: plan.id)))
    }

    private func createPlan() {
        AppRouter.shared.open(.readingPlanInBible(.customReadingPlanBuilder(book: bookName)))
    }
}

/// How plan screens move between each other, in whichever navigation stack they're in: the
/// iPhone tabs' route stacks, or the iPad Bible tab's detail pane.
struct PlanNavigation {
    let push: @MainActor (Route) -> Void
    /// Replaces the top screen, such as the plan builder with the plan it made.
    let replaceLast: @MainActor (Route) -> Void
    let popLast: @MainActor () -> Void
}

extension PlanNavigation {
    init(_ coordinator: NavigationCoordinator) {
        self.init(
            push: { coordinator.push($0) },
            replaceLast: { route in
                if !coordinator.path.isEmpty { coordinator.path.removeLast() }
                coordinator.push(route)
            },
            popLast: {
                if !coordinator.path.isEmpty { coordinator.path.removeLast() }
            }
        )
    }
}

extension EnvironmentValues {
    @Entry var planNavigation: PlanNavigation? = nil
}

/// The screen for a reading plan route.
struct ReadingPlanDestination: View {
    let route: Route

    var body: some View {
        switch route {
        case .readingPlans:
            ReadingPlansView()
        case .readingPlan(let id):
            ReadingPlanDetailView(planID: id)
        case let .readingPlanDay(planID, day):
            ReadingPlanDayView(planID: planID, dayNumber: day)
        case .customReadingPlanBuilder(let book):
            CustomPlanBuilderView(initialBook: book)
        case .readingPlanSeries(let series):
            ReadingPlanSeriesView(series: series)
        default:
            EmptyView()
        }
    }
}
