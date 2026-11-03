import OSLog

/// The user-facing response-time targets used during development and release checks.
enum PerformanceBudget {
    /// Cold launch through the first interactive Home screen on a representative device.
    static let interactiveLaunch: Duration = .milliseconds(1_500)
    /// A visible destination after a tap or an in-app routing request.
    static let navigation: Duration = .milliseconds(250)
    /// Search execution after the intentional typing debounce has elapsed.
    static let searchFirstResult: Duration = .milliseconds(300)
}

/// Development-only intervals for measuring key user-facing work in Instruments.
enum AppPerformance {
    #if DEBUG
    private static let signposter = OSSignposter(
        subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
        category: "Performance"
    )
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
        category: "Performance"
    )
    #endif

    static func measure<T>(_ name: StaticString, operation: () -> T) -> T {
        #if DEBUG
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        #endif
        return operation()
    }

    static func measure<T>(_ name: StaticString, operation: () async -> T) async -> T {
        #if DEBUG
        let state = signposter.beginInterval(name)
        defer { signposter.endInterval(name, state) }
        #endif
        return await operation()
    }

    /// Emits a development warning when a measured operation exceeds its agreed budget.
    static func measure<T>(
        _ name: StaticString,
        budget: Duration,
        operation: () async -> T
    ) async -> T {
        #if DEBUG
        let clock = ContinuousClock()
        let start = clock.now
        let state = signposter.beginInterval(name)
        defer {
            signposter.endInterval(name, state)
            if clock.now - start > budget {
                logger.warning("\(String(describing: name), privacy: .public) exceeded its performance budget.")
            }
        }
        #endif
        return await operation()
    }
}
