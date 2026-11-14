import SwiftUI

/// Every reading plan: the ones in progress, the reader's own, and the catalog by category.
struct ReadingPlansView: View {
    @State private var store = ReadingPlanStore.shared

    var body: some View {
        List {
            if !store.activePlans.isEmpty {
                Section("In Progress") {
                    ForEach(store.activePlans, id: \.plan.id) { item in
                        NavigationLink(value: Route.readingPlan(id: item.plan.id)) {
                            ActivePlanRow(plan: item.plan, store: store)
                        }
                    }
                }
                .listRowBackground(HeroCardListRowBackground())

                Section {
                    ReadingPlanReminderRows()
                } footer: {
                    Text("A daily reminder with your next reading. It's skipped on days you've already read.")
                }
                .listRowBackground(HeroCardListRowBackground())
            }

            Section {
                NavigationLink(value: Route.customReadingPlanBuilder) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Create Your Own Plan")
                                .font(.headline)
                            Text("Choose a book, how many days, and how to read it.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }

                ForEach(inactiveCustomPlans) { plan in
                    NavigationLink(value: Route.readingPlan(id: plan.id)) {
                        PlanCatalogRow(plan: plan, isFinished: isFinished(plan))
                    }
                }
            } header: {
                Text(ReadingPlan.customCategory)
            }
            .listRowBackground(HeroCardListRowBackground())

            ForEach(store.categories, id: \.self) { category in
                Section(category) {
                    ForEach(store.catalog.filter { $0.category == category }) { plan in
                        NavigationLink(value: Route.readingPlan(id: plan.id)) {
                            PlanCatalogRow(plan: plan, isFinished: isFinished(plan))
                        }
                    }
                }
                .listRowBackground(HeroCardListRowBackground())
            }
        }
        .scrollContentBackground(.hidden)
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Reading Plans")
        .navigationBarTitleDisplayMode(.large)
    }

    /// Custom plans not already listed under In Progress.
    private var inactiveCustomPlans: [ReadingPlan] {
        let active = Set(store.activePlans.map(\.plan.id))
        return store.customPlans.filter { !active.contains($0.id) }
    }

    private func isFinished(_ plan: ReadingPlan) -> Bool {
        store.enrollment(for: plan.id)?.finishedAt != nil
    }
}

/// A plan in progress: where the reader is and how far along.
private struct ActivePlanRow: View {
    let plan: ReadingPlan
    let store: ReadingPlanStore

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(progress: store.progress(of: plan), lineWidth: 5, size: 44) {
                Text("\(Int((store.progress(of: plan) * 100).rounded()))%")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.headline)
                if let day = store.currentDay(of: plan) {
                    Text("Day \(day.day) of \(plan.days.count) · \(day.title)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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

/// A plan to browse: what it is and how long it takes.
struct PlanCatalogRow: View {
    let plan: ReadingPlan
    var isFinished = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(plan.title)
                    .font(.headline)
                if isFinished {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Finished")
                }
            }
            Text(plan.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(plan.metadataText)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.accentColor)
        }
        .padding(.vertical, 4)
    }
}

extension ReadingPlan {
    /// "7 days · Beginner".
    var metadataText: String {
        [durationText, difficulty.map { $0.capitalized }].compactMap { $0 }.joined(separator: " · ")
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
