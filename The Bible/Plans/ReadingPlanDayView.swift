import SwiftUI

/// One day of a plan: its introduction, readings to open, questions to reflect on, and a
/// takeaway, with a way to mark it read.
struct ReadingPlanDayView: View {
    let planID: String
    let dayNumber: Int

    @State private var store = ReadingPlanStore.shared

    var body: some View {
        Group {
            if let plan = store.plan(id: planID), let day = plan.day(dayNumber) {
                content(plan: plan, day: day)
            } else {
                ContentUnavailableView("Day Not Found", systemImage: "book.closed")
            }
        }
        .scrollContentBackground(.hidden)
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(plan: ReadingPlan, day: PlanDay) -> some View {
        let isEnrolled = store.enrollment(for: plan.id) != nil
        let isComplete = store.isDayComplete(day.day, planID: plan.id)

        return List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DAY \(day.day) OF \(plan.days.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(day.title)
                        .font(.title2.weight(.bold))
                    if let introduction = day.introduction {
                        Text(introduction)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(HeroCardListRowBackground())

            Section {
                ForEach(Array(day.readings.enumerated()), id: \.offset) { index, reading in
                    ReadingRow(
                        reading: reading,
                        isComplete: store.isReadingComplete(index, day: day.day, planID: plan.id),
                        canCheck: isEnrolled,
                        onToggle: { complete in
                            withAnimation(.snappy) {
                                store.setReading(index, day: day.day, of: plan.id, complete: complete)
                            }
                        },
                        onRead: { store.openReading(index, day: day.day, of: plan.id) }
                    )
                }
            } header: {
                Text(day.readings.count == 1 ? "Reading" : "Readings")
            } footer: {
                if isEnrolled {
                    Text("Readings are checked off as you read them, or tap the circle.")
                }
            }
            .listRowBackground(HeroCardListRowBackground())

            if let questions = day.reflectionQuestions, !questions.isEmpty {
                Section("Reflect") {
                    ForEach(questions, id: \.self) { question in
                        Label(question, systemImage: "bubble.left.and.text.bubble.right")
                            .font(.body)
                    }
                }
                .listRowBackground(HeroCardListRowBackground())
            }

            if let takeaway = day.takeaway {
                Section("Takeaway") {
                    Label(takeaway, systemImage: "lightbulb")
                        .font(.body.weight(.medium))
                }
                .listRowBackground(HeroCardListRowBackground())
            }

            Section {
                if isEnrolled {
                    Button {
                        withAnimation(.snappy) {
                            store.setDay(day.day, of: plan.id, complete: !isComplete)
                        }
                        if !isComplete { Haptics.success() }
                    } label: {
                        // Text only: inside a list row, a filled button's icon takes the button's own color.
                        Text(isComplete ? "Day Complete ✓" : "Mark Day Complete")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isComplete ? .green : .accentColor)
                    .controlSize(.large)
                } else {
                    if !store.canStart(plan.id) {
                        PlanLimitNote(message: store.limitMessage)
                    }
                    Button {
                        store.start(plan.id)
                    } label: {
                        Text("Start This Plan")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!store.canStart(plan.id))
                }

                if let next = plan.day(day.day + 1) {
                    NavigationLink(value: Route.readingPlanDay(planID: plan.id, day: next.day)) {
                        Text("Next: Day \(next.day) · \(next.title)")
                            .lineLimit(1)
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Day \(day.day)")
    }
}

/// A reading with its checkmark and a Read button.
private struct ReadingRow: View {
    let reading: PlanReading
    let isComplete: Bool
    let canCheck: Bool
    let onToggle: (Bool) -> Void
    let onRead: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if canCheck {
                Button {
                    onToggle(!isComplete)
                } label: {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isComplete ? Color.green : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isComplete ? "\(reading.title) read" : "Mark \(reading.title) read")
            }

            Text(reading.title)
                .font(.headline)
                .foregroundStyle(isComplete ? .secondary : .primary)

            Spacer(minLength: 8)

            Button(action: onRead) {
                Label("Read", systemImage: "book.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .accessibilityHint("Opens \(reading.title) in the reader")
        }
        .padding(.vertical, 2)
    }
}
