import Foundation

// TEMPORARY: launch timing diagnostics. Remove after measuring.
enum LaunchTiming {
    nonisolated static func sinceProcessStart() -> Double {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        sysctl(&mib, 4, &info, &size, nil, 0)
        let start = info.kp_proc.p_un.__p_starttime
        return Date().timeIntervalSince1970 - (Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000)
    }

    nonisolated static func mark(_ label: String) {
        print(String(format: "⏱LAUNCH %.3fs %@%@", sinceProcessStart(), label, Thread.isMainThread ? " [main]" : ""))
    }

    @discardableResult
    nonisolated static func measure<T>(_ label: String, _ work: () throws -> T) rethrows -> T {
        let start = Date()
        defer { print(String(format: "⏱LAUNCH %.3fs %@ took %.3fs%@", sinceProcessStart(), label, Date().timeIntervalSince(start), Thread.isMainThread ? " [main]" : "")) }
        return try work()
    }
}
