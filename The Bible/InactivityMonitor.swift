import Foundation

final class InactivityMonitor {
    private var task: Task<Void, Never>?
    private var timeout: TimeInterval
    private var onInactive: @MainActor () -> Void

    init(timeout: TimeInterval, onInactive: @escaping @MainActor () -> Void) {
        self.timeout = timeout
        self.onInactive = onInactive
    }

    @MainActor
    func configure(timeout: TimeInterval? = nil, onInactive: (@MainActor () -> Void)? = nil) {
        if let t = timeout { self.timeout = t }
        if let cb = onInactive { self.onInactive = cb }
    }

    @MainActor
    func markActivity() {
        cancel()
        let deadline = Date().addingTimeInterval(timeout)
        task = Task { [deadline, onInactive] in
            let now = Date()
            let delay = max(0, deadline.timeIntervalSince(now))
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            if Task.isCancelled { return }
            onInactive()
        }
    }

    @MainActor
    func cancel() {
        task?.cancel()
        task = nil
    }
}
