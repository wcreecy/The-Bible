import Foundation
import WidgetKit

final class DebouncedWidgetReloader {
    static let shared = DebouncedWidgetReloader()
    private init() {}

    private var workItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "DebouncedWidgetReloader")
    private var pendingKinds = Set<String>()
    private let lock = NSLock()

    func reloadAll() {
        schedule {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func reload(kind: String) {
        lock.lock()
        pendingKinds.insert(kind)
        lock.unlock()
        schedule { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let kinds = Array(self.pendingKinds)
            self.pendingKinds.removeAll()
            self.lock.unlock()
            if kinds.isEmpty {
                WidgetCenter.shared.reloadAllTimelines()
            } else {
                kinds.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0) }
            }
        }
    }

    private func schedule(_ action: @escaping () -> Void) {
        workItem?.cancel()
        let item = DispatchWorkItem { action() }
        workItem = item
        queue.asyncAfter(deadline: .now() + 0.6, execute: item)
    }
}
