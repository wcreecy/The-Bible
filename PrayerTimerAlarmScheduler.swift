import Foundation

#if canImport(AlarmKit)
import AlarmKit
import SwiftUI
#endif

enum PrayerTimerAlarmScheduler {
    enum AuthorizationStatus {
        case authorized
        case denied
        case notDetermined
        case unavailable
    }

    static func authorizationStatus() -> AuthorizationStatus {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            return map(AlarmManager.shared.authorizationState)
        }
        #endif
        return .unavailable
    }

    static func requestAuthorization() async -> AuthorizationStatus {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            do {
                return map(try await AlarmManager.shared.requestAuthorization())
            } catch {
                return authorizationStatus()
            }
        }
        #endif
        return .unavailable
    }

    static func schedule(at date: Date) async -> Bool {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            let alert = AlarmPresentation.Alert(title: "Prayer/Study Finished")
            let presentation = AlarmPresentation(alert: alert)
            let attributes = AlarmAttributes<PrayerTimerAlarmMetadata>(
                presentation: presentation,
                metadata: PrayerTimerAlarmMetadata(),
                tintColor: .accentColor
            )
            let configuration = AlarmManager.AlarmConfiguration.alarm(
                schedule: .fixed(date),
                attributes: attributes
            )

            do {
                try? AlarmManager.shared.cancel(id: alarmID)
                _ = try await AlarmManager.shared.schedule(
                    id: alarmID,
                    configuration: configuration
                )
                return true
            } catch {
                return false
            }
        }
        #endif
        return false
    }

    static func cancel() {
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            try? AlarmManager.shared.cancel(id: alarmID)
        }
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.0, *)
    private static let alarmID = UUID(uuidString: "77591560-42A2-4F2E-9C57-C779767E0A24")!

    @available(iOS 26.0, *)
    private static func map(_ state: AlarmManager.AuthorizationState) -> AuthorizationStatus {
        switch state {
        case .authorized:
            .authorized
        case .denied:
            .denied
        case .notDetermined:
            .notDetermined
        @unknown default:
            .unavailable
        }
    }
    #endif
}

#if canImport(AlarmKit)
@available(iOS 26.1, *)
private struct PrayerTimerAlarmMetadata: AlarmMetadata {}
#endif
