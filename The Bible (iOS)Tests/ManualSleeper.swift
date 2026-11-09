import Foundation

/// A clock that only moves when a test advances it, so timer-driven code can be tested without
/// real waits. Pass `sleep` to the code under test; sleepers wake when `advance(by:)` passes
/// their deadline, and a cancelled sleeper throws `CancellationError` like `Task.sleep`.
@MainActor
final class ManualSleeper {
    private struct Sleeper {
        let id: UUID
        let deadline: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }

    private var now: UInt64 = 0
    private var sleepers: [Sleeper] = []

    /// The clock's time as a date, for code that measures elapsed time rather than sleeping.
    /// It starts at a fixed date and moves only with `advance(by:)`.
    var date: Date { Date(timeIntervalSinceReferenceDate: Double(now) / 1_000_000_000) }

    func sleep(_ nanoseconds: UInt64) async throws {
        try Task.checkCancellation()
        let id = UUID()
        let deadline = now + nanoseconds
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                sleepers.append(Sleeper(id: id, deadline: deadline, continuation: continuation))
            }
        } onCancel: {
            Task { @MainActor in self.cancel(id) }
        }
    }

    /// The same wait, for code that sleeps by `Duration`.
    func sleep(for duration: Duration) async throws {
        let (seconds, attoseconds) = duration.components
        try await sleep(UInt64(seconds) * 1_000_000_000 + UInt64(attoseconds / 1_000_000_000))
    }

    /// Moves time forward, wakes every sleeper whose deadline has passed, and lets the woken
    /// work run, including any sleeps it starts that are also due.
    func advance(by seconds: TimeInterval) async {
        // Tasks started since the last step must reach their sleep before time moves.
        await settle()
        now += UInt64(seconds * 1_000_000_000)
        repeat {
            let due = sleepers.filter { $0.deadline <= now }
            sleepers.removeAll { $0.deadline <= now }
            due.forEach { $0.continuation.resume() }
            await settle()
        } while sleepers.contains { $0.deadline <= now }
    }

    /// Lets tasks on the main actor that are ready to run finish their current step.
    func settle() async {
        for _ in 0..<20 { await Task.yield() }
    }

    private func cancel(_ id: UUID) {
        guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return }
        sleepers.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
