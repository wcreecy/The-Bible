import SwiftUI

struct ContextualTipView: View {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String

    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("contextualTipsResetGeneration") private var resetGeneration = 0
    @AppStorage private var dismissedGeneration: Int
    @State private var isShowingTipOptions = false

    init(
        id: String,
        title: LocalizedStringResource,
        message: LocalizedStringResource,
        systemImage: String
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        _dismissedGeneration = AppStorage(
            wrappedValue: -1,
            "contextualTipDismissedGeneration.\(id)"
        )
    }

    var body: some View {
        if dismissedGeneration != resetGeneration {
            Button {
                isShowingTipOptions = true
            } label: {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Shows options for contextual tips")
            .confirmationDialog(
                "Contextual Tips",
                isPresented: $isShowingTipOptions,
                titleVisibility: .visible
            ) {
                Button("Dismiss This Tip") {
                    dismissedGeneration = resetGeneration
                }
                Button("Dismiss All Tips", role: .destructive) {
                    contextualTipsEnabled = false
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Contextual tips can also be controlled from Settings.")
            }
        }
    }
}
