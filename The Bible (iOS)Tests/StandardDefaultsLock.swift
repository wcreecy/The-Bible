import Foundation

/// Lets tests that write to `UserDefaults.standard` take turns.
///
/// `@Suite(.serialized)` only orders the tests inside one suite; different suites still run
/// together. Many game tests snapshot the standard defaults and put them back when they finish,
/// so while one test is suspended at an `await`, another suite's restore can erase or overwrite
/// the keys it just wrote. Holding this lock for the whole test keeps those tests apart.
///
/// Take it first and release it last, so the restore runs while the lock is still held:
///
///     await StandardDefaultsLock.lock()
///     defer { StandardDefaultsLock.unlock() }
@MainActor
enum StandardDefaultsLock {
    private static var isHeld = false
    private static var waiters: [CheckedContinuation<Void, Never>] = []

    static func lock() async {
        if isHeld {
            // `unlock()` hands the lock straight to the next waiter, so `isHeld` stays true.
            await withCheckedContinuation { waiters.append($0) }
        } else {
            isHeld = true
        }
    }

    static func unlock() {
        if waiters.isEmpty {
            isHeld = false
        } else {
            waiters.removeFirst().resume()
        }
    }
}
