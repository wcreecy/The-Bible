import SwiftUI

// Generic HeroCard with optional trailing and title accessories
struct HeroCard<Content: View, TrailingAccessory: View, TitleAccessory: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let tint: Color
    let backgroundColor: Color?
    let strokeColor: Color?
    let trailingAccessory: (() -> TrailingAccessory)?
    let titleAccessory: (() -> TitleAccessory)?
    let titleFont: Font
    let titleFontWeight: Font.Weight
    let centerHeader: Bool
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var colorScheme

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        backgroundColor: Color? = nil,
        strokeColor: Color? = nil,
        titleFont: Font = .headline,
        titleFontWeight: Font.Weight = .bold,
        centerHeader: Bool = false,
        @ViewBuilder content: () -> Content
    ) where TrailingAccessory == EmptyView, TitleAccessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.trailingAccessory = nil
        self.titleAccessory = nil
        self.titleFont = titleFont
        self.titleFontWeight = titleFontWeight
        self.centerHeader = centerHeader
        self.content = content()
    }

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        backgroundColor: Color? = nil,
        strokeColor: Color? = nil,
        trailingAccessory: @escaping () -> TrailingAccessory,
        titleFont: Font = .headline,
        titleFontWeight: Font.Weight = .bold,
        centerHeader: Bool = false,
        @ViewBuilder content: () -> Content
    ) where TitleAccessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.trailingAccessory = trailingAccessory
        self.titleAccessory = nil
        self.titleFont = titleFont
        self.titleFontWeight = titleFontWeight
        self.centerHeader = centerHeader
        self.content = content()
    }

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        backgroundColor: Color? = nil,
        strokeColor: Color? = nil,
        titleFont: Font = .headline,
        titleFontWeight: Font.Weight = .bold,
        centerHeader: Bool = false,
        titleAccessory: @escaping () -> TitleAccessory,
        @ViewBuilder content: () -> Content
    ) where TrailingAccessory == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.trailingAccessory = nil
        self.titleAccessory = titleAccessory
        self.titleFont = titleFont
        self.titleFontWeight = titleFontWeight
        self.centerHeader = centerHeader
        self.content = content()
    }

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        backgroundColor: Color? = nil,
        strokeColor: Color? = nil,
        trailingAccessory: @escaping () -> TrailingAccessory,
        titleFont: Font = .headline,
        titleFontWeight: Font.Weight = .bold,
        centerHeader: Bool = false,
        titleAccessory: @escaping () -> TitleAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.trailingAccessory = trailingAccessory
        self.titleAccessory = titleAccessory
        self.titleFont = titleFont
        self.titleFontWeight = titleFontWeight
        self.centerHeader = centerHeader
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !(title.isEmpty && subtitle == nil && icon == nil) {
                if centerHeader {
                    VStack(alignment: .center, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if let icon {
                                Image(systemName: icon)
                                    .foregroundStyle(tint)
                                    .font(titleFont)
                            }
                            HStack(spacing: 6) {
                                Text(title)
                                    .font(titleFont)
                                    .fontWeight(titleFontWeight)
                                    .multilineTextAlignment(.center)
                                if let titleAccessory {
                                    titleAccessory()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)

                        if let subtitle {
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        if let icon {
                            Image(systemName: icon)
                                .foregroundStyle(tint)
                                .font(titleFont)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(titleFont)
                                .fontWeight(titleFontWeight)
                            if let subtitle {
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let trailingAccessory {
                            trailingAccessory()
                        }
                    }
                }
            }
            content
        }
        .padding(16)
        .background(
            Group {
                if let backgroundColor {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(backgroundColor)
                } else {
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(.secondarySystemBackground), Color(.systemBackground)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
        )
        .overlay(
            Group {
                if let strokeColor {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(strokeColor, lineWidth: 1)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder((colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.06)), lineWidth: 1)
                }
            }
        )
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}
