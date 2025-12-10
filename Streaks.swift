import SwiftUI

struct StreaksCard: View {
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30

    @StateObject private var vm = StreaksViewModel()

    private var goalSeconds: Int { max(1, dailyGoalMinutes) * 60 }

    private var todayTotal: Int {
        BibleStatsStore.shared.todayTotalSeconds()
    }

    private var progress: Double {
        min(1.0, Double(todayTotal) / Double(goalSeconds))
    }

    private var goalMet: Bool {
        BibleStatsStore.shared.isDailyGoalMet(goalSeconds: goalSeconds)
    }

    private func goalMinutesString(_ minutes: Int) -> String {
        let mins = max(0, minutes)
        let hrs = mins / 60
        let rem = mins % 60
        if hrs == 0 { return "\(rem) min" }
        if rem == 0 { return "\(hrs) hr" }
        return "\(hrs) hr \(rem) min"
    }

    private func friendlyDate(_ date: Date) -> String {
        vm.friendlyDate(date)
    }

    var body: some View {
        let current = StreakTracker.currentStreak
        let best = StreakTracker.bestStreak
        let last = StreakTracker.lastVisitDate

        HeroCard(
            title: "Daily Bible Streak",
            subtitle: nil,
            icon: "flame.fill",
            tint: current > 0 ? .orange : .secondary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // Header row: current streak and best
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(current)")
                        .font(.system(size: UIDevice.current.userInterfaceIdiom == .pad ? 48 : 40, weight: .black, design: .rounded))
                        .foregroundStyle(current > 0 ? .orange : .secondary)
                        .accessibilityLabel("Current streak \(current) days")
                    Text(current == 1 ? "day" : "days")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if best > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                            Text("Best \(best)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Best streak \(best) days")
                    }
                }

                // Last read / encouragement
                if let last {
                    Text("Last completed: \(friendlyDate(last))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Start your first day today.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Today's progress toward goal
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Goal: \(goalMinutesString(dailyGoalMinutes))")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: progress)
                        .tint(goalMet ? .green : .blue)
                    HStack {
                        if goalMet {
                            Label("Great job! You reached your goal today.", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .font(.footnote.weight(.semibold))
                        } else {
                            let remaining = max(0, goalSeconds - todayTotal)
                            let m = remaining / 60
                            let s = remaining % 60
                            Label("\(m)m \(s)s left", systemImage: "clock")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                        }
                        Spacer()
                    }
                }
                .padding(.top, 4)

                // Expandable calendar
                DisclosureGroup(isExpanded: $vm.isExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        calendarMonthView(anchor: vm.monthAnchor)
                    }
                    .padding(.top, 4)
                } label: {
                    HStack {
                        Text("Calendar")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(vm.friendlyMonthYear)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.9), value: vm.isExpanded)
            }
        }
        .accessibilityElement(children: .contain)
        .onReceive(NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)) { _ in
            // No-op; vm listens and nudges objectWillChange
        }
    }

    // MARK: - Calendar pieces (delegating to VM)

    private struct DayCell: View {
        let dayNumber: Int
        let met: Bool
        let future: Bool

        var body: some View {
            VStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(.caption)
                    .foregroundStyle(future ? .tertiary : .secondary)
                Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(future ? AnyShapeStyle(.tertiary) : AnyShapeStyle(met ? Color.green : Color.red))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private struct WeekRow: View {
        let dates: [Date?]
        let met: (Date) -> Bool
        let future: (Date) -> Bool

        var body: some View {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { c in
                    if let day = dates[c] {
                        let dayNum = Calendar.current.component(.day, from: day)
                        DayCell(dayNumber: dayNum, met: met(day), future: future(day))
                    } else {
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func calendarMonthView(anchor: Date) -> some View {
        let grid = vm.daysGrid(for: anchor)
        let weekdays = vm.weekdayShortSymbols

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    vm.goToPreviousMonth()
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    vm.goToNextMonth()
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.blue)

            HStack {
                ForEach(weekdays, id: \.self) { w in
                    Text(w.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 6) {
                ForEach(0..<grid.count, id: \.self) { r in
                    WeekRow(
                        dates: grid[r],
                        met: { vm.goalMet(for: $0) },
                        future: { vm.isFuture($0) }
                    )
                }
            }
        }
    }
}
