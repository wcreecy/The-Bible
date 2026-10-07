import SwiftUI

struct StreaksCard: View {
    @StateObject private var vm = StreaksViewModel()
    @State private var isDailyGoalEditorPresented = false

    private var goalSeconds: Int {
        StreakTracker.dailyGoalSeconds(on: Date())
    }

    private var todayTotal: Int {
        let key = BibleStatsStore.isoDateString(Date(), calendar: .autoupdatingCurrent)
        let map = BibleStatsStore.shared.loadDailyTotals()
        return max(0, map[key, default: 0])
    }

    private var progress: Double {
        min(1.0, Double(todayTotal) / Double(max(1, goalSeconds)))
    }

    private var goalMet: Bool {
        todayTotal >= goalSeconds
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
        let weekDates = vm.currentWeekDates()

        HeroCard(
            title: "Reading Streak",
            subtitle: nil,
            icon: "flame.fill",
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    streakMetric(
                        title: "Current",
                        value: current,
                        systemImage: "flame.fill",
                        tint: current > 0 ? .orange : .secondary
                    )
                    streakMetric(
                        title: "Best",
                        value: best,
                        systemImage: "trophy.fill",
                        tint: .yellow
                    )
                }

                ReadingWeekView(
                    dates: weekDates,
                    statusForDate: { vm.weekStatus(for: $0) }
                )

                DailyGoalSection(
                    goalText: goalMinutesString(goalSeconds / 60),
                    progress: progress,
                    goalMet: goalMet,
                    remainingSeconds: max(0, goalSeconds - todayTotal),
                    onEditGoal: {
                        isDailyGoalEditorPresented = true
                    }
                )

                HStack(spacing: 6) {
                    Image(systemName: last == nil ? "sparkles" : "calendar.badge.checkmark")
                    if let last {
                        Text("Last completed \(friendlyDate(last))")
                    } else {
                        Text("Start your first day today")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $isDailyGoalEditorPresented) {
            DailyGoalEditorView()
        }
    }

    private func streakMetric(
        title: LocalizedStringResource,
        value: Int,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text("\(value) days")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title), \(value) days"))
    }
}

private struct ReadingWeekView: View {
    let dates: [Date]
    let statusForDate: (Date) -> ReadingWeekStatus

    private let weekdaySymbols = ["S", "M", "T", "W", "Th", "F", "Sa"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Week")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 4) {
                ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                    ReadingWeekDay(
                        weekdaySymbol: weekdaySymbols[index],
                        date: date,
                        status: statusForDate(date)
                    )
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        }
    }
}

private struct ReadingWeekDay: View {
    let weekdaySymbol: String
    let date: Date
    let status: ReadingWeekStatus

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Text(weekdaySymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status == .future ? .tertiary : .secondary)

                if let mark = status.mark {
                    HanddrawnStatusMark(mark: mark)
                        .frame(width: weekdaySymbol.count == 1 ? 24 : 32, height: 22)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: 22)

            Text(date, format: .dateTime.day())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(status == .future ? .tertiary : .primary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let dateLabel = date.formatted(.dateTime.weekday(.wide).month(.wide).day())

        switch status {
        case .completed:
            return "\(dateLabel), daily goal completed"
        case .missed:
            return "\(dateLabel), daily goal missed"
        case .today:
            return "\(dateLabel), today, daily goal still in progress"
        case .future:
            return "\(dateLabel), upcoming day"
        }
    }
}

private struct DailyGoalSection: View {
    let goalText: String
    let progress: Double
    let goalMet: Bool
    let remainingSeconds: Int
    let onEditGoal: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Goal")
                        .font(.subheadline.weight(.semibold))
                    Text(goalText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onEditGoal) {
                    Label("Edit Goal", systemImage: "pencil")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("homeDailyGoalEditButton")
            }

            ProgressView(value: progress)
                .tint(goalMet ? .green : .orange)

            if goalMet {
                Label("Goal complete for today", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.footnote.weight(.semibold))
            } else {
                let minutes = remainingSeconds / 60
                let seconds = remainingSeconds % 60

                Label("\(minutes)m \(seconds)s remaining", systemImage: "clock")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        }
    }
}

private struct HanddrawnStatusMark: View {
    let mark: ReadingWeekMark

    var body: some View {
        Canvas { context, size in
            let color: Color = mark == .check ? .green : .red
            let stroke = StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)

            func drawLine(_ points: [CGPoint], opacity: Double, offset: CGSize = .zero) {
                var path = Path()
                guard let first = points.first else { return }

                path.move(to: CGPoint(x: first.x + offset.width, y: first.y + offset.height))
                for point in points.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x + offset.width, y: point.y + offset.height))
                }

                context.stroke(path, with: .color(color.opacity(opacity)), style: stroke)
            }

            switch mark {
            case .check:
                drawLine(
                    [
                        CGPoint(x: size.width * 0.12, y: size.height * 0.55),
                        CGPoint(x: size.width * 0.39, y: size.height * 0.80),
                        CGPoint(x: size.width * 0.88, y: size.height * 0.18)
                    ],
                    opacity: 0.9
                )
                drawLine(
                    [
                        CGPoint(x: size.width * 0.14, y: size.height * 0.49),
                        CGPoint(x: size.width * 0.40, y: size.height * 0.74),
                        CGPoint(x: size.width * 0.86, y: size.height * 0.14)
                    ],
                    opacity: 0.42,
                    offset: CGSize(width: 0.6, height: 0.4)
                )
            case .x:
                drawLine(
                    [
                        CGPoint(x: size.width * 0.16, y: size.height * 0.16),
                        CGPoint(x: size.width * 0.84, y: size.height * 0.84)
                    ],
                    opacity: 0.9
                )
                drawLine(
                    [
                        CGPoint(x: size.width * 0.84, y: size.height * 0.16),
                        CGPoint(x: size.width * 0.16, y: size.height * 0.84)
                    ],
                    opacity: 0.9
                )
                drawLine(
                    [
                        CGPoint(x: size.width * 0.18, y: size.height * 0.12),
                        CGPoint(x: size.width * 0.82, y: size.height * 0.80)
                    ],
                    opacity: 0.34,
                    offset: CGSize(width: 0.5, height: 0.5)
                )
            }
        }
        .allowsHitTesting(false)
    }
}
