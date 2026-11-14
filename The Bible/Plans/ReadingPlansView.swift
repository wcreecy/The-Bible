import SwiftUI

/// Every reading plan: the ones in progress, the reader's own, and the catalog as a row of
/// cards per category. A series (such as Fruit of the Spirit) shows as one card.
struct ReadingPlansView: View {
    @State private var store = ReadingPlanStore.shared

    /// A card in a category row: one plan, or a series of them.
    private enum Entry: Identifiable {
        case plan(ReadingPlan)
        case series(String, [ReadingPlan])

        var id: String {
            switch self {
            case .plan(let plan): plan.id
            case .series(let name, _): "series-" + name
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !store.activePlans.isEmpty {
                    inProgressSection
                }

                section(ReadingPlan.customCategory, detail: store.customPlans.isEmpty ? nil : "(\(store.customPlans.count))") {
                    cardRow {
                        NavigationLink(value: Route.customReadingPlanBuilder) {
                            CreatePlanCard()
                        }
                        .buttonStyle(.plain)

                        ForEach(store.customPlans) { plan in
                            NavigationLink(value: Route.readingPlan(id: plan.id)) {
                                PlanCard(plan: plan, status: status(of: plan))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                ForEach(store.categories, id: \.self) { category in
                    // Every plan counts, including each part of a series.
                    section(category, detail: "(\(store.catalog.filter { $0.category == category }.count))") {
                        cardRow {
                            ForEach(entries(in: category)) { entry in
                                switch entry {
                                case .plan(let plan):
                                    NavigationLink(value: Route.readingPlan(id: plan.id)) {
                                        PlanCard(plan: plan, status: status(of: plan))
                                    }
                                    .buttonStyle(.plain)
                                case let .series(name, plans):
                                    NavigationLink(value: Route.readingPlanSeries(name)) {
                                        SeriesCard(name: name, plans: plans, store: store)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Reading Plans")
        .navigationBarTitleDisplayMode(.large)
    }

    private var inProgressSection: some View {
        section("In Progress", detail: "\(store.activePlans.count) of \(ReadingPlanStore.maximumActivePlans)") {
            VStack(spacing: 10) {
                ForEach(store.activePlans, id: \.plan.id) { item in
                    NavigationLink(value: Route.readingPlan(id: item.plan.id)) {
                        HStack {
                            ActivePlanRow(plan: item.plan, store: store)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .heroCardSurface()
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ReadingPlanReminderRows()
                    Text("A daily reminder with your next readings. It's skipped once you've read today.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .heroCardSurface()
            }
            .padding(.horizontal)
        }
    }

    private func section<Content: View>(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.title3.weight(.bold))
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    /// A row of cards that scrolls sideways, settling on a card.
    private func cardRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 12) {
                content()
            }
            .padding(.horizontal)
            // Room for the cards' shadows, which the scroll view would otherwise clip.
            .padding(.vertical, 6)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
    }

    /// A category's plans in catalog order, with each series in place of its first plan.
    private func entries(in category: String) -> [Entry] {
        var seenSeries = Set<String>()
        return store.catalog.filter { $0.category == category }.compactMap { plan in
            guard let series = plan.series else { return .plan(plan) }
            guard seenSeries.insert(series).inserted else { return nil }
            return .series(series, store.plans(inSeries: series))
        }
    }

    private func status(of plan: ReadingPlan) -> PlanCard.Status {
        guard let enrollment = store.enrollment(for: plan.id) else { return .notStarted }
        return enrollment.finishedAt != nil ? .finished : .inProgress(store.progress(of: plan))
    }
}

/// A plan in the library's card rows.
struct PlanCard: View {
    enum Status: Equatable {
        case notStarted
        case inProgress(Double)
        case finished
    }

    let plan: ReadingPlan
    let status: Status

    static let size = CGSize(width: 250, height: 168)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(plan.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: 4)
                statusBadge
            }
            Text(plan.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 0)
            Text(plan.metadataText)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
        }
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .heroCardSurface()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .notStarted:
            EmptyView()
        case .inProgress(let progress):
            ProgressRing(progress: progress, lineWidth: 3, size: 24) { EmptyView() }
                .accessibilityLabel("In progress")
        case .finished:
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("Finished")
        }
    }
}

/// A series of plans as one card: how many parts and how many are finished.
private struct SeriesCard: View {
    let name: String
    let plans: [ReadingPlan]
    let store: ReadingPlanStore

    var body: some View {
        let finished = plans.filter { store.enrollment(for: $0.id)?.finishedAt != nil }.count
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(Color.accentColor)
                Text("SERIES")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Text(name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
            Text(plans.map(\.title).joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(finished > 0 ? "\(plans.count) plans · \(finished) finished" : "\(plans.count) plans")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
        }
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(width: PlanCard.size.width, height: PlanCard.size.height, alignment: .topLeading)
        .heroCardSurface()
        .accessibilityElement(children: .combine)
    }
}

/// The first card under My Plans.
private struct CreatePlanCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.title)
                .foregroundStyle(Color.accentColor)
            Text("Create Your Own")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Choose a book, how many days, and how to read it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .multilineTextAlignment(.leading)
        .padding(14)
        .frame(width: 180, height: PlanCard.size.height, alignment: .topLeading)
        .heroCardSurface()
    }
}

/// The plans of a series, in the order they're meant to be read.
struct ReadingPlanSeriesView: View {
    let series: String

    @State private var store = ReadingPlanStore.shared

    var body: some View {
        let plans = store.plans(inSeries: series)
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SERIES")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(series)
                        .font(.title2.weight(.bold))
                    Text("\(plans.count) plans, best read in order. Start the next when you finish one.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(HeroCardListRowBackground())

            Section("Plans") {
                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    NavigationLink(value: Route.readingPlan(id: plan.id)) {
                        HStack(spacing: 12) {
                            partBadge(index + 1, plan: plan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.title)
                                    .font(.headline)
                                Text(plan.metadataText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listRowBackground(HeroCardListRowBackground())
        }
        .scrollContentBackground(.hidden)
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle(series)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The part number, or a check once it's finished.
    @ViewBuilder
    private func partBadge(_ part: Int, plan: ReadingPlan) -> some View {
        let enrollment = store.enrollment(for: plan.id)
        ZStack {
            Circle()
                .fill(enrollment?.finishedAt != nil ? Color.green : Color.accentColor.opacity(enrollment != nil ? 1 : 0.15))
            if enrollment?.finishedAt != nil {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            } else {
                Text("\(part)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(enrollment != nil ? Color.white : Color.accentColor)
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityLabel(enrollment?.finishedAt != nil ? "Part \(part), finished" : "Part \(part)")
    }
}

/// A plan in progress: where the reader is and how far along.
private struct ActivePlanRow: View {
    let plan: ReadingPlan
    let store: ReadingPlanStore

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(progress: store.progress(of: plan), lineWidth: 5, size: 44) {
                Text("\(store.enrollment(for: plan.id)?.completedDays.count ?? 0)/\(plan.days.count)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
            .accessibilityLabel(ReadingPlanHomeCard.progressLabel(
                read: store.enrollment(for: plan.id)?.completedDays.count ?? 0,
                of: plan.days.count
            ))

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.headline)
                if let day = store.currentDay(of: plan) {
                    Text("Day \(day.day) of \(plan.days.count) · \(day.title)")
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
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

extension ReadingPlan {
    /// "21 days · About a chapter a day". The catalog's difficulty isn't shown: nearly every
    /// plan is marked beginner, and a level can put people off a plan that would suit them.
    var metadataText: String {
        [durationText, ReadingPlanLoad.dailyDescription(for: self)].compactMap { $0 }.joined(separator: " · ")
    }
}

/// How much a plan asks of each day, worked out from its readings.
@MainActor
enum ReadingPlanLoad {
    private static var cache: [String: String] = [:]

    /// "About 3 chapters a day", "About a chapter a day", "About 10 verses a day", or nil
    /// until the Bible text has loaded.
    static func dailyDescription(for plan: ReadingPlan) -> String? {
        if let cached = cache[plan.id] { return cached }
        guard !plan.days.isEmpty, !BibleData.books.isEmpty else { return nil }

        // A whole chapter counts as one, part of a chapter as the share read, so a plan of
        // one long chapter a day still reads "a chapter a day".
        var countsByBook: [String: [Int]] = [:]
        var totalVerses = 0
        var totalChapters = 0.0
        for day in plan.days {
            for reading in day.readings {
                let counts = countsByBook[reading.book] ?? ReadingPlanStore.verseCounts(forBook: reading.book)
                countsByBook[reading.book] = counts
                for (chapter, verses) in Dictionary(grouping: reading.verses(verseCounts: counts), by: \.chapter) {
                    totalVerses += verses.count
                    totalChapters += Double(verses.count) / Double(max(1, counts[safe: chapter - 1] ?? 1))
                }
            }
        }
        guard totalVerses > 0 else { return nil }

        let versesPerDay = Double(totalVerses) / Double(plan.days.count)
        let chaptersPerDay = totalChapters / Double(plan.days.count)
        let description: String
        if chaptersPerDay >= 1.5 {
            description = "About \(Int(chaptersPerDay.rounded())) chapters a day"
        } else if chaptersPerDay >= 0.75 {
            description = "About a chapter a day"
        } else {
            // Round to a friendly number: 5, 10, 15…
            let rounded = max(5, Int((versesPerDay / 5).rounded()) * 5)
            description = "About \(rounded) verses a day"
        }
        cache[plan.id] = description
        return description
    }
}

/// The reading plan reminder toggle and its time.
struct ReadingPlanReminderRows: View {
    @AppStorage(ReadingPlanReminderScheduler.enabledKey) private var reminderEnabled = false
    @AppStorage(ReadingPlanReminderScheduler.hourKey) private var reminderHour = ReadingPlanReminderScheduler.defaultHour
    @AppStorage(ReadingPlanReminderScheduler.minuteKey) private var reminderMinute = 0

    @State private var showsNotificationPermissionAlert = false

    var body: some View {
        Toggle(isOn: reminderBinding) {
            Label("Daily Reminder", systemImage: "bell.badge")
        }
        .alert("Notifications Are Off", isPresented: $showsNotificationPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow notifications for this app in Settings to get reading plan reminders.")
        }

        if reminderEnabled {
            DatePicker("Remind Me At", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
        }
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { reminderEnabled },
            set: { newValue in
                guard newValue else {
                    reminderEnabled = false
                    Task { await ReadingPlanReminderScheduler.cancel() }
                    return
                }
                Task {
                    let allowed = await VOTDNotificationScheduler.requestAuthorizationIfNeeded()
                    reminderEnabled = allowed
                    if allowed {
                        await ReadingPlanReminderScheduler.refresh()
                    } else {
                        showsNotificationPermissionAlert = true
                    }
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Date()) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = components.hour ?? ReadingPlanReminderScheduler.defaultHour
                reminderMinute = components.minute ?? 0
                Task { await ReadingPlanReminderScheduler.refresh() }
            }
        )
    }
}

#Preview {
    NavigationStack {
        ReadingPlansView()
    }
}
