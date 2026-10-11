import SwiftUI

extension View {
    /// Runs `action` each time `name` is posted while this view is on screen.
    ///
    /// The async replacement for `onReceive(NotificationCenter.default.publisher(for:))`.
    /// It stops listening when the view disappears (for example in a hidden tab), so
    /// views should also refresh in `onAppear` if they can miss changes while hidden.
    func onNotification(
        _ name: Notification.Name,
        object: AnyObject? = nil,
        perform action: @escaping @MainActor () -> Void
    ) -> some View {
        task(id: name) {
            for await _ in NotificationCenter.default.notifications(named: name, object: object) {
                action()
            }
        }
    }
}

extension NotificationCenter {
    /// Calls `action` on the main actor for each `name` notification, until the returned
    /// task is cancelled. For classes that listen for their whole lifetime.
    @MainActor
    static func observe(
        _ name: Notification.Name,
        perform action: @escaping @MainActor () -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(named: name) {
                action()
            }
        }
    }
}
