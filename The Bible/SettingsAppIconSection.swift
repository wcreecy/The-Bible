import SwiftUI
import UIKit

struct SettingsAppIconSection: View {
    @State private var selectedIcon = AppIconChoice.current
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 86), spacing: 12)
    ]

    var body: some View {
        Section {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(AppIconChoice.allCases) { icon in
                    AppIconChoiceButton(
                        icon: icon,
                        isSelected: icon == selectedIcon,
                        select: select
                    )
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("App Icon")
        } footer: {
            Text("Choose the icon that appears on your Home Screen. You can change it again at any time.")
        }
        .alert("Couldn’t Change App Icon", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func select(_ icon: AppIconChoice) {
        guard icon != selectedIcon else { return }

        guard UIApplication.shared.supportsAlternateIcons else {
            errorMessage = String(localized: "This device doesn’t support changing the app icon.")
            return
        }

        UIApplication.shared.setAlternateIconName(icon.alternateIconName) { error in
            Task { @MainActor in
                let currentIcon = AppIconChoice.current
                if currentIcon == icon {
                    selectedIcon = currentIcon
                } else if let error {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct AppIconChoiceButton: View {
    let icon: AppIconChoice
    let isSelected: Bool
    let select: (AppIconChoice) -> Void

    var body: some View {
        Button {
            select(icon)
        } label: {
            VStack(spacing: 6) {
                Image(icon.previewAssetName)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                                lineWidth: isSelected ? 3 : 1
                            )
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(3)
                        }
                    }
                    .accessibilityHidden(true)

                Text(icon.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon.title)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint("Sets the Home Screen app icon.")
    }
}
