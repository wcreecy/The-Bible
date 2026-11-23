import Foundation
import Testing
@testable import Bible

@MainActor
struct ContextualTipTests {
    @Test
    func learningOneFeatureDoesNotDismissOtherTipsOrDisableTips() throws {
        let suite = "ContextualTipTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: AppStorageKey.contextualTipsEnabled)

        ContextualTipView.complete("reader.shortcuts", defaults: defaults)

        #expect(defaults.object(forKey: ContextualTipView.dismissedGenerationKey(for: "reader.shortcuts")) as? Int == 0)
        #expect(defaults.object(forKey: ContextualTipView.dismissedGenerationKey(for: "reader.translations")) == nil)
        #expect(defaults.bool(forKey: AppStorageKey.contextualTipsEnabled))
    }

    @Test
    func resetAllowsPreviouslyLearnedTipsAndLearningRetiresThemAgain() throws {
        let suite = "ContextualTipTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = ContextualTipView.dismissedGenerationKey(for: "home.customization")
        ContextualTipView.complete("home.customization", defaults: defaults)

        defaults.set(1, forKey: AppStorageKey.contextualTipsResetGeneration)
        #expect(defaults.integer(forKey: key) != defaults.integer(forKey: AppStorageKey.contextualTipsResetGeneration))

        ContextualTipView.complete("home.customization", defaults: defaults)
        #expect(defaults.integer(forKey: key) == 1)
        ContextualTipView.complete("home.customization", defaults: defaults)
        #expect(defaults.integer(forKey: key) == 1)
    }
}
