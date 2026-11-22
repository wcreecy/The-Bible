import SwiftUI

enum VerseImageFormat: String, CaseIterable, Identifiable {
    case square
    case portrait
    case story

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .square: "Square"
        case .portrait: "Portrait"
        case .story: "Story"
        }
    }

    var pixelSize: CGSize {
        switch self {
        case .square: CGSize(width: 1080, height: 1080)
        case .portrait: CGSize(width: 1080, height: 1350)
        case .story: CGSize(width: 1080, height: 1920)
        }
    }

    var aspectRatio: CGFloat { pixelSize.width / pixelSize.height }

    /// Images are laid out at a third of their pixel size and rendered at 3x.
    static let renderScale: CGFloat = 3

    /// The size the artwork is laid out at, for both the export and every preview. Text doesn't
    /// scale evenly with point size, so laying out the preview any smaller would wrap differently.
    var layoutSize: CGSize {
        CGSize(width: pixelSize.width / Self.renderScale, height: pixelSize.height / Self.renderScale)
    }

    /// The longest side any format renders at, so a picked photo is decoded large enough for all of them.
    static var largestPixelSide: CGFloat {
        allCases.map { max($0.pixelSize.width, $0.pixelSize.height) }.max() ?? 2160
    }
}

enum VerseImageBackground: String, CaseIterable, Identifiable {
    case gradient
    case solid
    case photo

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .gradient: "Gradient"
        case .solid: "Solid"
        case .photo: "Photo"
        }
    }
}

enum VerseImageGradient: String, CaseIterable, Identifiable {
    case sunrise
    case ocean
    case forest
    case twilight

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .sunrise: "Sunrise"
        case .ocean: "Ocean"
        case .forest: "Forest"
        case .twilight: "Twilight"
        }
    }

    var colors: [Color] {
        switch self {
        case .sunrise: [.orange, .pink, .purple]
        case .ocean: [.indigo, .blue, .cyan]
        case .forest: [Color(red: 0.05, green: 0.20, blue: 0.16), .green]
        case .twilight: [Color(red: 0.08, green: 0.05, blue: 0.20), .purple, .orange]
        }
    }
}

enum VerseImageFontStyle: String, CaseIterable, Identifiable {
    case classic
    case serif
    case rounded
    case modern

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .classic: "Classic"
        case .serif: "Serif"
        case .rounded: "Rounded"
        case .modern: "Modern"
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .classic: .system(size: size, weight: .semibold, design: .default)
        case .serif: .system(size: size, weight: .semibold, design: .serif)
        case .rounded: .system(size: size, weight: .semibold, design: .rounded)
        case .modern: .system(size: size, weight: .medium, design: .monospaced)
        }
    }
}

enum VerseImageTextAlignment: String, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .leading: "Left"
        case .center: "Center"
        case .trailing: "Right"
        }
    }

    var textAlignment: TextAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    var horizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}
