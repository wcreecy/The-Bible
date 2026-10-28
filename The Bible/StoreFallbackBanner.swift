import SwiftUI

/// Warns on every screen when the app launched without its iCloud-backed library, so notes,
/// favorites, and bookmarks aren't saved somewhere the person doesn't expect.
/// The same explanation also appears in Settings under iCloud.
struct StoreFallbackBanner: View {
    let mode: PersistenceStoreMode
    @State private var isDismissed = false

    private var message: LocalizedStringResource? {
        switch mode {
        case .cloudKit:
            nil
        case .localOnly:
            "Not syncing: notes, favorites, and bookmarks are saved on this device only. Quit and reopen the app to try again."
        case .inMemory:
            "Changes won't be saved: your library couldn't be opened. Quit and reopen the app."
        }
    }

    private var tint: Color {
        mode == .inMemory ? .red : .orange
    }

    var body: some View {
        if let message, !isDismissed {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    isDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                }
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) { tint.frame(height: 2) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("storeFallbackBanner")
        }
    }
}
