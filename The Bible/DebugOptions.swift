import Foundation

/// Shortcuts for testing games. They exist only in debug builds; release builds always
/// report them off, so no stored setting can switch them on.
enum DebugOptions {
    /// Shows the "win this round" shortcut in games. Set with the `debugAutoWinEnabled`
    /// default (for example the `-debugAutoWinEnabled YES` launch argument).
    static var autoWinEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: AppStorageKey.debugAutoWinEnabled)
        #else
        false
        #endif
    }
}
