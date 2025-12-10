import Foundation

enum VOTDSchedule {
    // Build a Date for "today at hour:minute" in the user’s current calendar/time zone.
    static func dateForToday(hour: Int, minute: Int, from now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Date? {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let base = cal.dateComponents([.year, .month, .day], from: now)
        var comps = DateComponents()
        comps.year = base.year
        comps.month = base.month
        comps.day = base.day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return cal.date(from: comps)
    }

    // Given one or two (hour, minute) pairs, return the next scheduled refresh Date from "now".
    // If both times today have passed, returns tomorrow’s first time.
    static func nextAutoRefreshDate(
        first: (hour: Int, minute: Int),
        second: (hour: Int, minute: Int)? = nil,
        from now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent

        guard let firstToday = dateForToday(hour: first.hour, minute: first.minute, from: now, calendar: cal) else {
            return now
        }

        if let second {
            guard let secondToday = dateForToday(hour: second.hour, minute: second.minute, from: now, calendar: cal) else {
                return now
            }
            if now < firstToday { return firstToday }
            if now < secondToday { return secondToday }
            // Tomorrow at first time
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
            return dateForToday(hour: first.hour, minute: first.minute, from: tomorrow, calendar: cal) ?? now
        } else {
            if now < firstToday { return firstToday }
            let tomorrow = cal.date(byAdding: .day, value: 1, to: now) ?? now
            return dateForToday(hour: first.hour, minute: first.minute, from: tomorrow, calendar: cal) ?? now
        }
    }

    // Builds a user-facing description like:
    // "Next auto refresh: Today at 6:00 AM" or "Tomorrow at 6:00 PM" or "Mar 12 at 6:00 AM"
    static func nextAutoRefreshDescription(
        first: (hour: Int, minute: Int),
        second: (hour: Int, minute: Int)? = nil,
        from now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent

        let next = nextAutoRefreshDate(first: first, second: second, from: now, calendar: cal)
        let isToday = cal.isDate(now, inSameDayAs: next)
        let isTomorrow = cal.isDate(next, inSameDayAs: cal.date(byAdding: .day, value: 1, to: now) ?? next)

        let dayString: String = {
            if isToday { return "Today" }
            if isTomorrow { return "Tomorrow" }
            // Fallback to a short date for other days
            let df = DateFormatter()
            df.locale = locale
            df.calendar = cal
            df.timeZone = cal.timeZone
            df.setLocalizedDateFormatFromTemplate("MMM d") // e.g., "Mar 12"
            return df.string(from: next)
        }()

        let timeString: String = {
            let tf = DateFormatter()
            tf.locale = locale
            tf.calendar = cal
            tf.timeZone = cal.timeZone
            tf.timeStyle = .short
            tf.dateStyle = .none
            return tf.string(from: next)
        }()

        return "Next auto refresh: \(dayString) at \(timeString)"
    }
}
