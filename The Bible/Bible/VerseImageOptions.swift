import SwiftUI
import UIKit

enum VerseImageFormat: String, CaseIterable, Identifiable {
    case square
    case portrait
    case story
    case wallpaper

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .square: "Square"
        case .portrait: "Portrait"
        case .story: "Story"
        case .wallpaper: "Wallpaper"
        }
    }

    var pixelSize: CGSize {
        switch self {
        case .square: CGSize(width: 1080, height: 1080)
        case .portrait: CGSize(width: 1080, height: 1350)
        case .story: CGSize(width: 1080, height: 1920)
        case .wallpaper: WallpaperCanvas.current.pixelSize
        }
    }

    var aspectRatio: CGFloat { pixelSize.width / pixelSize.height }

    /// Images are laid out at a third of their pixel size and rendered at 3x, which for a
    /// wallpaper is the screen's own point size, like the Lock Screen it will sit behind.
    static let renderScale: CGFloat = 3

    /// The size the artwork is laid out at, for both the export and every preview. Text doesn't
    /// scale evenly with point size, so laying out the preview any smaller would wrap differently.
    var layoutSize: CGSize {
        CGSize(width: pixelSize.width / Self.renderScale, height: pixelSize.height / Self.renderScale)
    }

    /// The share of each side the verse should stay inside so it's never cropped.
    /// An iPad wallpaper is square and the Lock Screen rotates, so only the center square
    /// the width of the screen's short side shows in every orientation.
    var contentFraction: CGFloat {
        self == .wallpaper ? WallpaperCanvas.current.contentFraction : 1
    }

    /// The longest side any format renders at, so a picked photo is decoded large enough for all of them.
    static var largestPixelSide: CGFloat {
        allCases.map { max($0.pixelSize.width, $0.pixelSize.height) }.max() ?? 2160
    }
}

/// Rough Lock Screen geometry, as fractions of a portrait iPhone screen's height.
enum LockScreenLayout {
    /// The date, clock, and widget row cover about this much from the top.
    static let topZone: CGFloat = 0.30
    /// Notifications and the flashlight and camera buttons cover about this much from the bottom.
    static let bottomZone: CGFloat = 0.20
    /// Moves a centered verse into the open band between the two.
    static var verseCenterOffset: CGFloat { (topZone + (1 - bottomZone)) / 2 - 0.5 }
}

/// A wallpaper canvas that matches this device's screen pixel for pixel, so iOS shows it
/// without cropping or zooming.
struct WallpaperCanvas: Equatable {
    /// The screen in pixels, portrait.
    let screenPixels: CGSize
    let isSquare: Bool

    var pixelSize: CGSize {
        guard isSquare else { return screenPixels }
        let side = max(screenPixels.width, screenPixels.height)
        return CGSize(width: side, height: side)
    }

    var contentFraction: CGFloat {
        guard isSquare else { return 1 }
        return min(screenPixels.width, screenPixels.height) / max(screenPixels.width, screenPixels.height)
    }

    private static let lastScreenKey = "verseWallpaperScreenPixels"
    /// Found once and reused: the screen doesn't change while the app runs, and the size is
    /// read several times a frame while the verse or photo is dragged.
    private static var cached: WallpaperCanvas?

    /// The device's screen. Shortcuts can run the wallpaper intent with no window open, so the last
    /// screen seen is remembered and used then.
    static var current: WallpaperCanvas {
        if let cached { return cached }
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        if let pixels = deviceScreenPixels(isPad: isPad) {
            let remembered = [Double(pixels.width), Double(pixels.height)]
            if UserDefaults.standard.array(forKey: lastScreenKey) as? [Double] != remembered {
                UserDefaults.standard.set(remembered, forKey: lastScreenKey)
            }
            let canvas = WallpaperCanvas(screenPixels: pixels, isSquare: isPad)
            cached = canvas
            return canvas
        }
        // Not cached, so a later call can still find the real screen once a window exists.
        if let saved = UserDefaults.standard.array(forKey: lastScreenKey) as? [Double], saved.count == 2 {
            return WallpaperCanvas(screenPixels: CGSize(width: saved[0], height: saved[1]), isSquare: isPad)
        }
        let fallback = isPad ? CGSize(width: 2064, height: 2752) : CGSize(width: 1290, height: 2796)
        return WallpaperCanvas(screenPixels: fallback, isSquare: isPad)
    }

    /// The device's own screen in portrait pixels, from the app's windows.
    private static func deviceScreenPixels(isPad: Bool) -> CGSize? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.session.role == .windowApplication }
            .map { portraitPixels($0.screen.nativeBounds.size) }
            .first { isDeviceScreen($0, isPad: isPad) }
    }

    /// `nativeBounds` is portrait-up on the device's screen, but not necessarily on others.
    static func portraitPixels(_ size: CGSize) -> CGSize {
        CGSize(width: min(size.width, size.height), height: max(size.width, size.height))
    }

    /// UIKit can't say which screen is built in. On iPad an app window can sit on an external
    /// display, but those are 16:9 (1.78:1) or wider, while iPad screens run from 4:3 up to
    /// about 1.52:1 on iPad mini, so anything wider than 1.6:1 is skipped. iPhone only mirrors
    /// to other displays, so its windows are always on its own screen.
    static func isDeviceScreen(_ portraitPixels: CGSize, isPad: Bool) -> Bool {
        guard portraitPixels.width > 0, portraitPixels.height > 0 else { return false }
        return !isPad || portraitPixels.height / portraitPixels.width <= 1.6
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
