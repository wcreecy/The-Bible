import Foundation
import UserNotifications
import WidgetKit

/// A daily reminder for the most recent reading plan, naming the day's reading.
///
/// Like the streak reminder, a notification is scheduled for each of the next few days, and
/// today's is left out once a plan day has been read. The app calls `refresh()` when it
/// becomes active or moves to the background, and whenever plan progress changes.
@MainActor
enum ReadingPlanReminderScheduler {
    static let enabledKey = "readingPlanReminderEnabled"
    static let hourKey = "readingPlanReminderHour"
    static let minuteKey = "readingPlanReminderMinute"
    static let defaultHour = 7
    /// `userInfo["destination"]` value, so tapping the reminder opens the plan.
    static let destination = "readingPlan"

    private static let identifierPrefix = "reading-plan-reminder-"
    private static let daysAhead = 7

    static func refresh(now: Date = Date()) async {
        await cancel()

        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: enabledKey) else { return }

        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return
        }

        let store = ReadingPlanStore.shared
        let plans = store.activePlans.compactMap { item in
            store.currentDay(of: item.plan).map { (plan: item.plan, day: $0) }
        }
        guard !plans.isEmpty else { return }

        let hour = defaults.object(forKey: hourKey) as? Int ?? defaultHour
        let minute = defaults.object(forKey: minuteKey) as? Int ?? 0
        let calendar = Calendar.autoupdatingCurrent
        let startOfToday = calendar.startOfDay(for: now)
        // Today's reminder names only the plans not read yet today, and is skipped once all are.
        let unreadToday = plans.filter { !store.completedADay(of: $0.plan.id, on: now, calendar: calendar) }

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fireDate > now else { continue }
            let due = offset == 0 ? unreadToday : plans
            guard !due.isEmpty else { continue }

            let content = UNMutableNotificationContent()
            if due.count == 1, let only = due.first {
                content.title = only.plan.title
                content.body = offset <= 1
                    ? String(localized: "Day \(only.day.day): \(only.day.readingSummary)")
                    : String(localized: "Your next reading is ready.")
            } else {
                content.title = String(localized: "Today's Readings")
                content.body = due.map { "\($0.plan.title) · Day \($0.day.day)" }.joined(separator: "\n")
            }
            content.sound = .default
            // One plan opens directly; several open the list of plans.
            content.userInfo = due.count == 1
                ? ["destination": destination, "planID": due[0].plan.id]
                : ["destination": destination]

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = identifierPrefix + BibleStatsStore.isoDateString(day)
            try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
        }
    }

    static func cancel() async {
        let center = UNUserNotificationCenter.current()
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

/// Copies the current plan reading into the app group for the Reading Plan widget, which
/// can't read the app's data. The widget only draws what's written here.
@MainActor
enum ReadingPlanWidgetMirror {
    static let key = "readingPlanWidget"
    static let widgetKind = "ReadingPlanWidget"

    /// What the widget reads. Keep in step with `ReadingPlanWidgetSnapshot` in the widget.
    struct Snapshot: Codable, Equatable {
        let planID: String
        let planTitle: String
        let dayNumber: Int
        let dayCount: Int
        let dayTitle: String
        let readings: [String]
        let completedDays: Int
        let isFinished: Bool
        let bookName: String
        let chapter: Int
        let verse: Int
        /// The other plans in progress, such as "Growing in Peace · Day 2".
        var others: [String]? = nil
    }

    static func update(from store: ReadingPlanStore) {
        guard let shared = UserDefaults(suiteName: "group.bible.app") else { return }
        let snapshot = makeSnapshot(from: store)
        let data = snapshot.flatMap { try? JSONEncoder().encode($0) }
        guard data != shared.data(forKey: key) else { return }

        if let data {
            shared.set(data, forKey: key)
        } else {
            shared.removeObject(forKey: key)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    private static func makeSnapshot(from store: ReadingPlanStore) -> Snapshot? {
        if let (plan, enrollment) = store.activePlans.first, let day = store.currentDay(of: plan),
           let reading = store.todaysReading()?.reading {
            return Snapshot(
                planID: plan.id,
                planTitle: plan.title,
                dayNumber: day.day,
                dayCount: plan.days.count,
                dayTitle: day.title,
                readings: day.readings.map(\.title),
                completedDays: enrollment.completedDays.count,
                isFinished: false,
                bookName: reading.book,
                chapter: reading.chapter,
                verse: reading.firstVerse,
                others: store.activePlans.dropFirst().compactMap { other in
                    store.currentDay(of: other.plan).map { "\(other.plan.title) · Day \($0.day)" }
                }
            )
        }
        // A plan just finished: show it until another is started.
        if let (plan, enrollment) = store.finishedPlans.first, store.activePlans.isEmpty {
            return Snapshot(
                planID: plan.id,
                planTitle: plan.title,
                dayNumber: plan.days.count,
                dayCount: plan.days.count,
                dayTitle: "",
                readings: [],
                completedDays: enrollment.completedDays.count,
                isFinished: true,
                bookName: "",
                chapter: 0,
                verse: 0
            )
        }
        return nil
    }
}
