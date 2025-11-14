import Foundation
import WidgetKit

final class WidgetReloadManager {
    static let shared = WidgetReloadManager()

    private var pendingAll = false
    private var pendingKinds: Set<String> = []
    private var lastReload: Date = .distantPast
    private let minInterval: TimeInterval = 3 // seconds

    private var enabled: Bool = false
    private var enableWorkItem: DispatchWorkItem? = nil

    private let queue = DispatchQueue(label: "WidgetReloadManagerQueue")

    private init() {
        // Default: enable after 3 seconds to avoid launch-time churn
        enableAfter(seconds: 3)
    }

    func enableAfter(seconds: TimeInterval) {
        queue.async { [weak self] in
            guard let self else { return }
            self.enableWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.enabled = true }
            self.enableWorkItem = work
            self.enabled = false
            self.queue.asyncAfter(deadline: .now() + seconds, execute: work)
        }
    }

    func requestReloadAll() {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.enabled else { return }
            self._requestReloadAll()
        }
    }

    func requestReload(kind: String) {
        queue.async { [weak self] in
            guard let self else { return }
            guard self.enabled else { return }
            self._requestReload(kind: kind)
        }
    }

    private func _requestReloadAll() {
        // If an all reload is pending or recently fired, coalesce
        pendingAll = true
        scheduleIfNeeded()
    }

    private func _requestReload(kind: String) {
        // If an all reload is pending, no need to track kinds
        if !pendingAll { pendingKinds.insert(kind) }
        scheduleIfNeeded()
    }

    private func scheduleIfNeeded() {
        let now = Date()
        let since = now.timeIntervalSince(lastReload)
        if since >= minInterval {
            fireReload()
        } else {
            // Coalesce within the window; schedule one fire after the window elapses
            let delay = minInterval - since
            queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.fireReload()
            }
        }
    }

    private func fireReload() {
        // Snapshot state
        let fireAll = pendingAll
        let kinds = pendingKinds
        // Reset
        pendingAll = false
        pendingKinds.removeAll()
        lastReload = Date()
        // Call WidgetCenter on main
        DispatchQueue.main.async {
            if fireAll {
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                for k in kinds { WidgetCenter.shared.reloadTimelines(ofKind: k) }
            }
        }
    }
}
