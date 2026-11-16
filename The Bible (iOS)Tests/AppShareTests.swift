import CoreImage
import Foundation
import Testing
import UIKit
@testable import Bible

/// The app link added to shared verses, passages, and results.
@Suite(.serialized)
struct AppShareTests {
    private let verse = "For God so loved the world… — John 3:16"

    @Test
    func theLinkIsAddedOnlyWhenTurnedOn() {
        let shared = AppShare.withAttribution(verse, includingLink: true)
        #expect(shared.hasPrefix(verse))
        #expect(shared.contains(AppShare.displayLink))
        #expect(AppShare.withAttribution(verse, includingLink: false) == verse)
    }

    @Test
    func theLinkIsOnUntilTurnedOff() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: AppShare.includesLinkKey)
        defer { defaults.set(saved, forKey: AppShare.includesLinkKey) }

        defaults.removeObject(forKey: AppShare.includesLinkKey)
        #expect(AppShare.includesLink)
        defaults.set(false, forKey: AppShare.includesLinkKey)
        #expect(!AppShare.includesLink)
        #expect(AppShare.withAttribution(verse) == verse)
    }

    /// A standalone full URL is tappable and lets receiving apps offer a rich preview.
    @Test
    func sharedTextEndsWithTheFullAppStoreURL() {
        let shared = AppShare.withAttribution(verse, includingLink: true)
        #expect(shared.hasSuffix(AppShare.url.absoluteString))
        #expect(shared == "\(verse)\n\n\(AppShare.url.absoluteString)")
    }

    @Test
    func theShownLinkIsTheAppStoreLinkWithoutItsScheme() {
        #expect(AppShare.displayLink == "apps.apple.com/app/id\(AppShare.appStoreID)")
        #expect(AppShare.url.absoluteString == "https://" + AppShare.displayLink)
    }

    @Test
    func theQRCodeScansToTheAppStoreLink() throws {
        let image = try #require(AppShare.qrCode()?.cgImage)
        let detector = try #require(CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        ))
        let codes = detector.features(in: CIImage(cgImage: image)).compactMap { $0 as? CIQRCodeFeature }
        #expect(codes.first?.messageString == AppShare.url.absoluteString)
    }
}
