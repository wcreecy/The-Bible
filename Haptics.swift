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

    static func impact(_ style: UIImpactFeedbackGenerator.Style) {
        guard supportsHaptics else { return }
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard supportsHaptics else { return }
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }

    static func selection() {
        guard supportsHaptics else { return }
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }
}
