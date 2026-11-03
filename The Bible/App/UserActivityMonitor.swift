import SwiftUI
import UIKit

/// Tracks when the person last touched the app, so time trackers stop counting while it sits
/// open and unattended. Study and game time count until five minutes after the last touch,
/// the same idle limit the reader uses.
@MainActor
final class UserActivityMonitor {
    static let shared = UserActivityMonitor()

    static let idleTimeout: TimeInterval = 300

    /// The most recent touch anywhere in the app.
    private(set) var lastInteraction = Date()
    /// The first touch after the latest idle stretch. Time before it, back to the end of the
    /// idle limit, was spent away from the app.
    private(set) var activeSince = Date.distantPast

    private init() {}

    func recordInteraction(at date: Date = .now) {
        if date.timeIntervalSince(lastInteraction) > Self.idleTimeout {
            activeSince = date
        }
        lastInteraction = date
    }

    /// The active part of the time since `checkpoint`. See `countedSpan(checkpoint:now:lastInteraction:activeSince:timeout:)`.
    func countedSpan(since checkpoint: Date, now: Date = .now) -> CountedSpan {
        Self.countedSpan(
            checkpoint: checkpoint,
            now: now,
            lastInteraction: lastInteraction,
            activeSince: activeSince,
            timeout: Self.idleTimeout
        )
    }

    struct CountedSpan: Equatable {
        /// Where the counted time begins.
        let start: Date
        /// Whole seconds to record, starting at `start`.
        let seconds: Int
        /// Where the next measurement should begin.
        let nextCheckpoint: Date
    }

    /// The time between `checkpoint` and `now` that counts as active: from the later of the
    /// checkpoint and the return from the last idle stretch, up to `timeout` after the last
    /// touch. Trackers measure at least every 15 seconds, so an idle stretch always contains a
    /// measurement and the time away is never counted.
    nonisolated static func countedSpan(
        checkpoint: Date,
        now: Date,
        lastInteraction: Date,
        activeSince: Date,
        timeout: TimeInterval
    ) -> CountedSpan {
        let start = max(checkpoint, activeSince)
        let activeUntil = lastInteraction.addingTimeInterval(timeout)
        let end = min(now, activeUntil)
        let seconds = max(0, Int(end.timeIntervalSince(start)))

        let nextCheckpoint: Date
        if activeUntil < now {
            // Idle now: nothing past the limit counts, so the next measurement starts fresh.
            nextCheckpoint = now
        } else {
            // Still active: keep the leftover fraction of a second for the next measurement.
            nextCheckpoint = start.addingTimeInterval(TimeInterval(seconds))
        }
        return CountedSpan(start: start, seconds: seconds, nextCheckpoint: nextCheckpoint)
    }
}

/// Reports every touch in its window to `UserActivityMonitor` without taking part in gestures.
struct UserActivityCaptureView: UIViewRepresentable {
    func makeUIView(context: Context) -> CaptureView {
        CaptureView()
    }

    func updateUIView(_ uiView: CaptureView, context: Context) {}

    final class CaptureView: UIView {
        private let recognizer = TouchObservingGestureRecognizer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            recognizer.view?.removeGestureRecognizer(recognizer)
            window?.addGestureRecognizer(recognizer)
        }
    }

    /// Notes a touch, then fails at once so every other gesture proceeds as if it weren't there.
    private final class TouchObservingGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
        init() {
            super.init(target: nil, action: nil)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
            delegate = self
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            UserActivityMonitor.shared.recordInteraction()
            state = .failed
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
