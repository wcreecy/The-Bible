import Foundation
import SwiftUI
import ActivityKit

#if canImport(AlarmKit)
import AlarmKit

@available(iOS 26.1, *)
private struct PrayerTimerAlarmMetadata: AlarmMetadata {}
#endif

enum PrayerTimerAlarmScheduler {
    enum AuthorizationStatus {
        case unavailable
        case notDetermined
        case denied
        case authorized
    }

    private static let alarmID = UUID(uuidString: "7E9B4495-35BE-4CB1-9EF4-AFC5A8A79F0F")!

    static func schedule(at date: Date) async -> Bool {
        guard #available(iOS 26.1, *) else { return false }

        #if canImport(AlarmKit)
        let manager = AlarmManager.shared

        do {
            let authorization = try await manager.requestAuthorization()
            guard authorization == .authorized else { return false }

            try? manager.cancel(id: alarmID)

            let alert = AlarmPresentation.Alert(title: "Prayer/Study Finished")
            let presentation = AlarmPresentation(alert: alert)
            let attributes = AlarmAttributes(
                presentation: presentation,
                metadata: PrayerTimerAlarmMetadata(),
                tintColor: .accentColor
            )
            let configuration = AlarmManager.AlarmConfiguration.alarm(
                schedule: .fixed(date),
                attributes: attributes,
                sound: .default
            )

            _ = try await manager.schedule(id: alarmID, configuration: configuration)
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    static func authorizationStatus() -> AuthorizationStatus {
        guard #available(iOS 26.1, *) else { return .unavailable }

        #if canImport(AlarmKit)
        return mapAuthorizationState(AlarmManager.shared.authorizationState)
        #else
        return .unavailable
        #endif
    }

    static func requestAuthorization() async -> AuthorizationStatus {
        guard #available(iOS 26.1, *) else { return .unavailable }

        #if canImport(AlarmKit)
        do {
            let state = try await AlarmManager.shared.requestAuthorization()
            return mapAuthorizationState(state)
        } catch {
            return authorizationStatus()
        }
        #else
        return .unavailable
        #endif
    }

    static func cancel() {
        guard #available(iOS 26.1, *) else { return }

        #if canImport(AlarmKit)
        try? AlarmManager.shared.cancel(id: alarmID)
        #endif
    }

    #if canImport(AlarmKit)
    @available(iOS 26.1, *)
    private static func mapAuthorizationState(
        _ state: AlarmManager.AuthorizationState
    ) -> AuthorizationStatus {
        switch state {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        @unknown default: .unavailable
        }
    }
    #endif
}
