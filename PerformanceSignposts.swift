import OSLog

/// Development-only intervals for measuring key user-facing work in Instruments.
enum AppPerformance {
    #if DEBUG
    private static let signposter = OSSignposter(
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
}
