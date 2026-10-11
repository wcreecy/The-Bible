import Foundation

/// Support for UI tests. When launched with `-UITesting`, the settings the tests depend
/// on are overridden for this launch only, so every run starts from the same Home and a
/// test run never changes the person's saved settings.
enum UITestSupport {
    static let launchArgument = "-UITesting"

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// Call before any view reads settings.
    static func configureIfNeeded() {
        guard isActive else { return }

        // The argument domain is volatile and searched first, so these values win over
        // saved ones and disappear when the app quits.
        let defaults = UserDefaults.standard
        var overrides = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        overrides.merge([
            // Open on Home.
            LaunchTabPreference.defaultsKey: LaunchTabPreference.home.rawValue,
            // Every Home card visible.
            "homeCardHidden": "[]",
            "homeTodayVisibilityMigratedV1": true,
            // No tips or permission prompts in the way.
            "contextualTipsEnabled": false,
            "didRequestNotifications": true,
            // The reader opens normally rather than in Focus Mode.
            "focusReadingEnabled": false
        ]) { _, test in test }
        defaults.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
    }
}
