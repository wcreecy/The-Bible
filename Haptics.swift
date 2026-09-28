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

    @available(iOS 10.0, *)
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard supportsHaptics else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }

    @available(iOS 10.0, *)
    static func selection() {
        guard supportsHaptics else { return }
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }
}
