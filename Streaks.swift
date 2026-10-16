import SwiftUI

struct StreaksCard: View {
    /// Opens Reading Stats when the card is tapped.
    var onOpenStats: () -> Void = {}
    /// Opens the reader at the bookmarked verse.
    var onReadNow: () -> Void = {}

    @State private var vm = StreaksViewModel()
    @State private var isDailyGoalEditorPresented = false
    @State private var celebratingMilestone: Int?
    /// The highest milestone already celebrated for the current streak.
    @AppStorage("streakCelebratedMilestone") private var celebratedMilestone = 0

    var body: some View {
        // Reading this redraws the card when reading stats change.
        let _ = vm.revision
        // One pass over reading history per render; everything below reads from it.
        let summary = StreakTracker.summary()
        let weekDates = vm.currentWeekDates()

        HeroCard(
            title: "Reading Streak",
            subtitle: nil,
            icon: "flame.fill",
            tint: .orange
        ) {
            VStack(alignment: .leading, spacing: 14) {
                StreakHeadline(
                    current: summary.current,
                    best: summary.best,
                    milestone: StreakMilestone.reached(by: summary.current)
                )

                if let celebratingMilestone {
                    MilestoneBanner(milestone: celebratingMilestone) {
                        withAnimation(.snappy) { self.celebratingMilestone = nil }
                    }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else if summary.current > 0 {
                    NextMilestoneLabel(current: summary.current)
                }

                TodayProgressSection(
                    summary: summary,
                    dates: weekDates,
                    statusForDate: { vm.weekStatus(for: $0, summary: summary) },
                    onEditGoal: { isDailyGoalEditorPresented = true }
                )

                if !summary.todayGoalMet {
                    Button(action: onReadNow) {
                        Label("Read Now", systemImage: "book.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GameProminentButtonStyle(tint: .orange))
                    .accessibilityHint("Opens the reader at your bookmark")
                    .accessibilityIdentifier("homeStreakReadNowButton")
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenStats)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Open Reading Stats", onOpenStats)
        .onChange(of: summary.current, initial: true) { _, current in
            updateMilestone(for: current)
        }
        .sensoryFeedback(.success, trigger: celebratingMilestone) { _, newValue in
            newValue != nil
        }
        .sheet(isPresented: $isDailyGoalEditorPresented) {
            DailyGoalEditorView()
        }
    }

    /// Celebrates the first time the current streak reaches a milestone. When a streak
    /// ends, the saved milestone drops back so the next streak celebrates again.
    private func updateMilestone(for current: Int) {
        let reached = StreakMilestone.reached(by: current)
        if reached < celebratedMilestone {
            celebratedMilestone = reached
        } else if reached > celebratedMilestone {
            celebratedMilestone = reached
            withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
                celebratingMilestone = reached
            }
        }
    }
}

/// "1 day" / "12 days".
private func dayCount(_ days: Int) -> String {
    days == 1 ? "1 day" : "\(days) days"
}

/// Goal progress color: orange while reading, warming toward green, then green once met.
private func goalProgressTint(progress: Double, goalMet: Bool) -> Color {
    guard !goalMet else { return .green }
    let clamped = min(max(progress, 0), 1)
    return Color(hue: 0.08 + (0.14 * clamped), saturation: 0.85, brightness: 0.95)
}

// MARK: - Headline

private struct StreakHeadline: View {
    let current: Int
    let best: Int
    let milestone: Int

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(current, format: .number)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(current)))
                        .foregroundStyle(current > 0 ? Color.orange : Color.secondary)
                    Text(current == 1 ? "day" : "days")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(current > 0 ? "Current streak" : "Meet today's goal to start a streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                Label {
                    Text("Best \(dayCount(best))")
                } icon: {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                }
                .font(.subheadline.weight(.semibold))

                if milestone > 0 {
                    Label(StreakMilestone.title(for: milestone), systemImage: "medal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = ["Current streak, \(dayCount(current))", "Best streak, \(dayCount(best))"]
        if milestone > 0 { parts.append("Milestone reached, \(StreakMilestone.title(for: milestone))") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Milestones

private struct NextMilestoneLabel: View {
    let current: Int

    var body: some View {
        let next = StreakMilestone.next(after: current)
        let remaining = next - current

        Label(
            "\(remaining == 1 ? "1 more day" : "\(remaining) more days") to your \(StreakMilestone.title(for: next))",
            systemImage: "flag.checkered"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

private struct MilestoneBanner: View {
    let milestone: Int
    let onDismiss: () -> Void

    @State private var bounce = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "medal.fill")
                .font(.title)
                .foregroundStyle(.orange, .yellow)
                .symbolEffect(.bounce, options: .repeat(2), value: bounce)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(StreakMilestone.title(for: milestone))!")
                    .font(.headline)
                Text("Well done. Every day in the Word counts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss celebration")
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.25), Color.yellow.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .accessibilityElement(children: .combine)
        .onAppear { bounce.toggle() }
    }
}

// MARK: - This week and today's goal

private struct TodayProgressSection: View {
    let summary: StreakSummary
    let dates: [Date]
    let statusForDate: (Date) -> ReadingWeekStatus
    let onEditGoal: () -> Void

    private let weekdaySymbols = ["S", "M", "T", "W", "Th", "F", "Sa"]

    private var progress: Double {
        min(1.0, Double(summary.todaySeconds) / Double(max(1, summary.todayGoalSeconds)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This Week")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button(action: onEditGoal) {
                    Label("Edit Goal", systemImage: "pencil")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("homeDailyGoalEditButton")
            }

            HStack(spacing: 4) {
                ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                    ReadingWeekDay(
                        weekdaySymbol: weekdaySymbols[index],
                        date: date,
                        status: statusForDate(date),
                        todayProgress: progress,
                        todayTint: goalProgressTint(progress: progress, goalMet: summary.todayGoalMet)
                    )
                }
            }
            .animation(.easeInOut, value: progress)

            Divider()

            GoalStatusLine(summary: summary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        }
    }
}

private struct GoalStatusLine: View {
    let summary: StreakSummary

    private var readMinutes: Int { summary.todaySeconds / 60 }
    private var goalMinutes: Int { summary.todayGoalSeconds / 60 }
    /// Rounded up so the label never claims less time than is actually left.
    private var minutesLeft: Int {
        max(1, Int((Double(summary.todayRemainingSeconds) / 60).rounded(.up)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if summary.todayGoalMet {
                Label("Goal complete · \(readMinutes) min today", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Label {
                    Text(summary.current > 0
                         ? "Read \(minutesLeft) min to keep your \(summary.current)-day streak"
                         : "Read \(minutesLeft) min to start a new streak")
                } icon: {
                    Image(systemName: summary.current > 0 ? "flame.fill" : "book.fill")
                        .foregroundStyle(.orange)
                }
                .font(.footnote.weight(.semibold))

                Text("\(readMinutes) of \(goalMinutes) min today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ReadingWeekDay: View {
    let weekdaySymbol: String
    let date: Date
    let status: ReadingWeekStatus
    let todayProgress: Double
    let todayTint: Color

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Text(weekdaySymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(status == .future ? .tertiary : .secondary)

                if status == .completed {
                    HanddrawnCheckMark()
                        .frame(width: weekdaySymbol.count == 1 ? 24 : 32, height: 22)
                }
            }
            .frame(height: 22)
            .accessibilityHidden(true)

            ZStack {
                dayBackground

                Text(date, format: .dateTime.day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(numberStyle)
                    .monospacedDigit()
            }
            .frame(maxWidth: 32)
            .aspectRatio(1, contentMode: .fit)

            // A quiet dot marks a missed day instead of a red ✗.
            Circle()
                .fill(Color.secondary.opacity(status == .missed ? 0.5 : 0))
                .frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var dayBackground: some View {
        switch status {
        case .completed:
            Circle().fill(Color.green.opacity(0.18))
        case .today:
            // Today's ring fills as you read toward the goal.
            Circle()
                .stroke(todayTint.opacity(0.2), lineWidth: 3)
            Circle()
                .trim(from: 0, to: todayProgress)
                .stroke(todayTint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        case .missed, .future:
            EmptyView()
        }
    }

    private var numberStyle: AnyShapeStyle {
        switch status {
        case .future:
            AnyShapeStyle(.tertiary)
        case .missed:
            AnyShapeStyle(.secondary)
        default:
            AnyShapeStyle(.primary)
        }
    }

    private var accessibilityLabel: String {
        let dateLabel = date.formatted(.dateTime.weekday(.wide).month(.wide).day())

        switch status {
        case .completed:
            return "\(dateLabel), daily goal completed"
        case .missed:
            return "\(dateLabel), daily goal missed"
        case .today:
            return "\(dateLabel), today, \(Int(todayProgress * 100)) percent of daily goal"
        case .future:
            return "\(dateLabel), upcoming day"
        }
    }
}

private struct HanddrawnCheckMark: View {
    var body: some View {
        Canvas { context, size in
            let stroke = StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)

            func drawLine(_ points: [CGPoint], opacity: Double, offset: CGSize = .zero) {
                var path = Path()
                guard let first = points.first else { return }

                path.move(to: CGPoint(x: first.x + offset.width, y: first.y + offset.height))
                for point in points.dropFirst() {
                    path.addLine(to: CGPoint(x: point.x + offset.width, y: point.y + offset.height))
                }

                context.stroke(path, with: .color(Color.green.opacity(opacity)), style: stroke)
            }

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
        }
        .allowsHitTesting(false)
    }
}
