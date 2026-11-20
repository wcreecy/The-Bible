import SwiftUI

/// A month of Daily WORD results: solved days in green (orange in color-blind mode) with the
/// guess count, missed days in gray, and today outlined. Earlier months are a swipe or tap away.
struct WordDailyCalendarView: View {
    let results: [String: WordleDailyResult]
    let todayKey: String
    @Environment(\.wordColorBlindMode) private var colorBlind
    @State private var monthOffset = 0

    private var calendar: Calendar { .autoupdatingCurrent }

    private var displayedMonth: Date {
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return calendar.date(byAdding: .month, value: monthOffset, to: startOfMonth) ?? startOfMonth
    }

    /// Days of the displayed month, with blanks before the first so it starts on the right weekday.
    private var days: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let dates = range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: displayedMonth)
        }
        return Array(repeating: nil, count: leading) + dates
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    private var monthResults: (solved: Int, played: Int) {
        let keys = days.compactMap { $0.map { GameStats.localDayKey(for: $0, calendar: calendar) } }
        let played = keys.compactMap { results[$0] }
        return (played.count { $0.won }, played.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button("Previous month", systemImage: "chevron.left") { monthOffset -= 1 }
                    .labelStyle(.iconOnly)
                Spacer()
                VStack(spacing: 2) {
                    Text(displayedMonth, format: .dateTime.month(.wide).year())
                        .font(.headline)
                    let tally = monthResults
                    Text("\(tally.solved) of \(tally.played) solved")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Next month", systemImage: "chevron.right") { monthOffset += 1 }
                    .labelStyle(.iconOnly)
                    .disabled(monthOffset >= 0)
            }
            .buttonStyle(.borderless)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
        .padding(12)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .gesture(
            DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width > 40 { monthOffset -= 1 }
                if value.translation.width < -40, monthOffset < 0 { monthOffset += 1 }
            }
        )
        .animation(.snappy, value: monthOffset)
    }

    private func dayCell(_ date: Date) -> some View {
        let key = GameStats.localDayKey(for: date, calendar: calendar)
        let result = results[key]
        let isToday = key == todayKey
        let solvedFill = WordleKeyState.correct.fill(colorBlind: colorBlind)
        let fill: Color = switch result?.won {
        case true?: solvedFill
        case false?: Color.secondary.opacity(0.35)
        case nil: .clear
        }

        return VStack(spacing: 0) {
            Text(date, format: .dateTime.day())
                .font(.caption.weight(.semibold))
            if let result, result.won {
                Text("\(result.guesses)")
                    .font(.caption2.monospacedDigit())
            }
        }
        .foregroundStyle(result?.won == true ? WordleKeyState.correct.foreground(colorBlind: colorBlind) : .primary)
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.mint, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(date, format: .dateTime.month(.wide).day()))
        .accessibilityValue(accessibilityValue(result, isToday: isToday))
    }

    private func accessibilityValue(_ result: WordleDailyResult?, isToday: Bool) -> String {
        let status: String = switch result?.won {
        case true?: result?.guesses == 1
            ? String(localized: "Solved in 1 guess")
            : String(localized: "Solved in \(result?.guesses ?? 0) guesses")
        case false?: String(localized: "Missed")
        case nil: String(localized: "Not played")
        }
        return isToday ? String(localized: "Today, \(status)") : status
    }
}
