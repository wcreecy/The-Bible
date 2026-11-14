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
        guard let (plan, _) = store.activePlans.first, let today = store.currentDay(of: plan) else { return }

        let hour = defaults.object(forKey: hourKey) as? Int ?? defaultHour
        let minute = defaults.object(forKey: minuteKey) as? Int ?? 0
        let calendar = Calendar.autoupdatingCurrent
        let startOfToday = calendar.startOfDay(for: now)
        let readToday = store.completedADay(of: plan.id, on: now, calendar: calendar)

        for offset in 0..<daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                  let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fireDate > now else { continue }
            if offset == 0 && readToday { continue }

            let content = UNMutableNotificationContent()
            content.title = plan.title
            if offset == 0 || (offset == 1 && readToday) {
                // The next day's reading is known for the next reminder.
                content.body = String(localized: "Day \(today.day): \(today.readingSummary)")
            } else {
                content.body = String(localized: "Your next reading is ready.")
            }
            content.sound = .default
            content.userInfo = ["destination": destination, "planID": plan.id]

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
                verse: reading.firstVerse
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
