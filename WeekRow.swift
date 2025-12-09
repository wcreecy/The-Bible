import SwiftUI

struct WeekRow: View {
    let dates: [Date?]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { c in
                if let day = dates[c] {
                    let dayNum = Calendar.current.component(.day, from: day)
                    let met = StreakTracker.isGoalMet(on: day)
                    let future: Bool = {
                        let cal = Calendar.current
                        if cal.isDate(day, inSameDayAs: Date()) { return false }
                        return day > Date()
                    }()
                    DayCell(dayNumber: dayNum, met: met, future: future)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
        }
    }
}
