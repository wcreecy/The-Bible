import SwiftUI

struct ContextualTipView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String
    let actionTitle: LocalizedStringResource?
    let action: (() -> Void)?

    @AppStorage(AppStorageKey.contextualTipsEnabled) private var contextualTipsEnabled = false
    @AppStorage(AppStorageKey.contextualTipsResetGeneration) private var resetGeneration = 0
    @AppStorage private var dismissedGeneration: Int

    init(
        id: String,
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        systemImage: String,
        actionTitle: LocalizedStringResource? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
        _dismissedGeneration = AppStorage(
            wrappedValue: -1,
            Self.dismissedGenerationKey(for: id)
        )
    }

    static func dismissedGenerationKey(for id: String) -> String {
        "contextualTipDismissedGeneration.\(id)"
    }

    /// Learning a feature retires its tip just like dismissal. Reset Tips allows it again.
    static func complete(_ id: String, defaults: UserDefaults = .standard) {
        let generation = defaults.integer(forKey: AppStorageKey.contextualTipsResetGeneration)
        defaults.set(generation, forKey: dismissedGenerationKey(for: id))
    }

    var body: some View {
        if contextualTipsEnabled && dismissedGeneration != resetGeneration {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.subheadline.weight(.semibold))
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: systemImage)
                            .foregroundStyle(.tint)
                            .font(.title3)
                    }
                    .accessibilityElement(children: .combine)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        dismissedGeneration = resetGeneration
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss tip")
                    .accessibilityIdentifier("dismissContextualTip")
                }

                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(12)
            .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
