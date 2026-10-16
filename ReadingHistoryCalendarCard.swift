import SwiftUI

struct ReadingHistoryCalendarCard: View {
    @State private var monthAnchor = Date()

    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 1
        return calendar
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor)) ?? monthAnchor
    }

    private var daysGrid: [[Date?]] {
        guard let days = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        var weeks: [[Date?]] = []
        var week = Array<Date?>(repeating: nil, count: (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7)

        for day in days {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                week.append(date)
            }

            if week.count == 7 {
                weeks.append(week)
                week = []
            }
        }

        if !week.isEmpty {
            week.append(contentsOf: repeatElement(nil, count: 7 - week.count))
            weeks.append(week)
        }

        return weeks
    }

    var body: some View {
        // Loaded once per render so each day cell doesn't reload history.
        let summary = StreakTracker.summary()

        HeroCard(
            title: "Reading History",
            subtitle: nil,
            icon: "calendar",
            tint: .orange
        ) {
            VStack(spacing: 12) {
                HStack {
                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous month")

                    Spacer()

                    Text(monthAnchor, format: .dateTime.month(.wide).year())
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Next month")
                }
                .buttonStyle(.borderless)

                HStack(spacing: 4) {
                    ForEach(["S", "M", "T", "W", "Th", "F", "Sa"], id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                VStack(spacing: 6) {
                    ForEach(daysGrid.indices, id: \.self) { row in
                        HStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { column in
                                if let date = daysGrid[row][column] {
                                    ReadingHistoryDay(
                                        date: date,
                                        status: StreaksViewModel.status(for: date, summary: summary, calendar: calendar)
                                    )
                                } else {
                                    Color.clear
                                        .frame(maxWidth: .infinity, minHeight: 38)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func changeMonth(by value: Int) {
        monthAnchor = calendar.date(byAdding: .month, value: value, to: monthAnchor) ?? monthAnchor
    }
}

private struct ReadingHistoryDay: View {
    let date: Date
    let status: ReadingWeekStatus

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(backgroundColor)

            Text(date, format: .dateTime.day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(foregroundStyle)

            if status == .completed {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.green)
                    .offset(x: 8, y: -8)
            } else if status == .missed {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.red)
                    .offset(x: 8, y: -8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 38)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var backgroundColor: Color {
        switch status {
        case .completed:
            .green.opacity(0.12)
        case .missed:
            .red.opacity(0.09)
        case .today:
            .orange.opacity(0.12)
        case .future:
            Color.secondary.opacity(0.06)
        }
    }

    private var foregroundStyle: AnyShapeStyle {
        status == .future ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary)
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
