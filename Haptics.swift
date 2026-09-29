// Haptics.swift
import UIKit
import CoreHaptics

enum Haptics {
    static var supportsHaptics: Bool = {
        #if targetEnvironment(simulator)
        return false
        #else
        if #available(iOS 13.0, *) {
            return CHHapticEngine.capabilitiesForHardware().supportsHaptics
        } else {
            return false
        }
        #endif
    }()

    private static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard supportsHaptics else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }

    static func selection() {
        guard supportsHaptics else { return }
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        gen.impactOccurred()
    }

    /// Reserve this for completed actions that have a meaningful user-visible result.
    static func success() {
        notify(.success)
    }

    static func warning() {
        notify(.warning)
    }

    static func error() {
        notify(.error)
    }
}
