import SwiftUI

extension View {
    /// Runs `action` each time `name` is posted while this view is on screen.
    ///
    /// The async replacement for `onReceive(NotificationCenter.default.publisher(for:))`.
    /// It stops listening when the view disappears (for example in a hidden tab), so
    /// views should also refresh in `onAppear` if they can miss changes while hidden.
    func onNotification(
        _ name: Notification.Name,
        perform action: @escaping @MainActor () -> Void
    ) -> some View {
        task(id: name) {
            for await _ in NotificationCenter.default.notifications(named: name) {
                action()
            }
        }
    }
}

extension View {
    /// Runs `action` once a second while this view is on screen. The async replacement
    /// for `onReceive(Timer.publish(every: 1, ...).autoconnect())`.
    func onEverySecond(perform action: @escaping @MainActor () -> Void) -> some View {
        task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                action()
            }
        }
    }
}

extension NotificationCenter {
    /// Calls `action` with `owner` on the main actor for each `name` notification, for as
    /// long as `owner` exists. For classes that listen for their whole lifetime; `owner`
    /// is held weakly, so the loop ends after it is released.
    @MainActor
    @discardableResult
    static func observe<Owner: AnyObject>(
        _ name: Notification.Name,
        for owner: Owner,
        perform action: @escaping @MainActor (Owner) -> Void
    ) -> Task<Void, Never> {
        Task { @MainActor [weak owner] in
            for await _ in NotificationCenter.default.notifications(named: name) {
                guard let owner else { return }
                action(owner)
            }
        }
    }
}
