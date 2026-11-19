import CoreImage
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import Vision

@MainActor
@Observable
final class VerseImageComposerModel {
    private struct Snapshot {
        let format: VerseImageFormat
        let background: VerseImageBackground
        let gradient: VerseImageGradient
        let solidColor: Color
        let photo: UIImage?
        let photoSubject: UIImage?
        let verseBehindSubject: Bool
        let photoScale: CGFloat
        let photoOffset: CGSize
        let photoDimming: Double
        let photoBlur: Double
        let photoLuminance: Double
        let editedText: String
        let fontStyle: VerseImageFontStyle
        let textScale: CGFloat
        let textOffset: CGSize
        let textColor: Color
        let textAlignment: VerseImageTextAlignment
        let showsReference: Bool
        let showsBranding: Bool
        let inkStrokes: [InkStroke]
    }

    let verse: VerseActionReference

    /// The verse as it appears on the image. People can trim it to show only part of the verse.
    /// Typing doesn't record undo steps; `beginEditingText()` records one per editing session.
    var editedText: String
    var isTextEdited: Bool { editedText != verse.verseText }
    /// Falls back to the whole verse so clearing the field never leaves a blank image.
    var displayedText: String {
        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? verse.verseText : trimmed
    }

    var format: VerseImageFormat = .portrait { willSet { recordUndoSnapshot() } }
    var background: VerseImageBackground = .gradient { willSet { recordUndoSnapshot() } }
    var gradient: VerseImageGradient = .sunrise { willSet { recordUndoSnapshot() } }
    var solidColor = Color.indigo { willSet { recordUndoSnapshot() } }
    var photo: UIImage? { willSet { recordUndoSnapshot() } }
    /// The photo's people, pets, or other main subjects with everything else transparent, the same
    /// size as `photo` so it lines up. Nil until Vision finishes, or when it finds no subject.
    private(set) var photoSubject: UIImage?
    private(set) var isFindingSubject = false
    /// Vision couldn't run, as opposed to running and finding no subject.
    private(set) var isSubjectDetectionUnavailable = false
    @ObservationIgnored private var subjectTask: Task<Void, Never>?
    /// Draws the photo's subject over the verse, so the verse looks tucked behind it.
    var verseBehindSubject = false { willSet { recordUndoSnapshot() } }
    var hasPhotoSubject: Bool { background == .photo && photoSubject != nil }
    var photoScale: CGFloat = 1 { willSet { recordUndoSnapshot() } }
    var photoOffset = CGSize.zero { willSet { recordUndoSnapshot() } }
    var photoDimming: Double = 0.28 { willSet { recordUndoSnapshot() } }
    var photoBlur: Double = 0 { willSet { recordUndoSnapshot() } }
    /// Average brightness of the chosen photo, used to warn about unreadable text.
    private var photoLuminance = 0.5 { willSet { recordUndoSnapshot() } }

    var fontStyle: VerseImageFontStyle = .serif { willSet { recordUndoSnapshot() } }
    var textScale: CGFloat = 1 { willSet { recordUndoSnapshot() } }
    static let textScaleRange: ClosedRange<CGFloat> = 0.65...1.6
    var textOffset = CGSize.zero { willSet { recordUndoSnapshot() } }
    var textColor = Color.white { willSet { recordUndoSnapshot() } }
    var textAlignment: VerseImageTextAlignment = .center { willSet { recordUndoSnapshot() } }
    var showsReference = true { willSet { recordUndoSnapshot() } }
    var showsBranding = true { willSet { recordUndoSnapshot() } }

    /// Pen strokes drawn over the finished image. Each stroke is one undo step.
    var inkStrokes: [InkStroke] = [] { willSet { recordUndoSnapshot() } }
    /// While on, dragging the preview draws instead of moving the text or photo.
    var isMarkingUp = false
    var inkColor = Color.yellow
    var inkWidth: CGFloat = 0.01
    /// Apple Pencil always draws; this lets a finger draw too.
    var drawsWithFinger = UserDefaults.standard.object(forKey: "verseImageInkWithFinger") as? Bool ?? true {
        didSet { UserDefaults.standard.set(drawsWithFinger, forKey: "verseImageInkWithFinger") }
    }

    private var undoHistory: [Snapshot] = []
    private var isRestoringSnapshot = false

    var canUndo: Bool { !undoHistory.isEmpty }

    init(verse: VerseActionReference) {
        self.verse = verse
        self.editedText = verse.verseText
        loadPreferences()
        formatDidChange()
    }

    func undo() {
        guard let snapshot = undoHistory.popLast() else { return }
        isRestoringSnapshot = true
        defer { isRestoringSnapshot = false }

        format = snapshot.format
        background = snapshot.background
        gradient = snapshot.gradient
        solidColor = snapshot.solidColor
        photo = snapshot.photo
        photoSubject = snapshot.photoSubject
        verseBehindSubject = snapshot.verseBehindSubject
        photoScale = snapshot.photoScale
        photoOffset = snapshot.photoOffset
        photoDimming = snapshot.photoDimming
        photoBlur = snapshot.photoBlur
        photoLuminance = snapshot.photoLuminance
        editedText = snapshot.editedText
        fontStyle = snapshot.fontStyle
        textScale = snapshot.textScale
        textOffset = snapshot.textOffset
        textColor = snapshot.textColor
        textAlignment = snapshot.textAlignment
        showsReference = snapshot.showsReference
        showsBranding = snapshot.showsBranding
        inkStrokes = snapshot.inkStrokes

        // The snapshot may predate Vision finishing with this photo.
        if let photo, photoSubject == nil {
            findSubject(in: photo)
        }
    }

    func addInkStroke(_ points: [CGPoint]) {
        guard !points.isEmpty else { return }
        inkStrokes.append(InkStroke(points: points, color: inkColor, width: inkWidth))
    }

    func clearInk() {
        guard !inkStrokes.isEmpty else { return }
        inkStrokes = []
    }

    /// Records one undo step before the person starts typing in the verse field.
    func beginEditingText() {
        recordUndoSnapshot()
    }

    func restoreFullVerse() {
        guard isTextEdited else { return }
        recordUndoSnapshot()
        editedText = verse.verseText
    }

    func clearUndoHistory() {
        undoHistory.removeAll()
    }

    /// Loads the picked photo at a size that suits the canvas. Returns false if it can't be read.
    @discardableResult
    func loadPhoto(from item: PhotosPickerItem?) async -> Bool {
        guard let item else { return true }
        let maxPixelSize = VerseImageFormat.largestPixelSide
        guard let data = try? await item.loadTransferable(type: Data.self),
              let decoded = await Task.detached(priority: .userInitiated, operation: {
                  VerseImageComposerModel.decodePhoto(data, maxPixelSize: maxPixelSize)
              }).value else { return false }
        recordUndoSnapshot()
        isRestoringSnapshot = true
        defer { isRestoringSnapshot = false }
        photo = decoded.image
        photoSubject = nil
        photoLuminance = decoded.luminance
        background = .photo
        photoScale = 1
        photoOffset = .zero
        findSubject(in: decoded.image)
        return true
    }

    /// Finds the photo's subject in the background; the photo shows right away without it.
    private func findSubject(in image: UIImage) {
        subjectTask?.cancel()
        isFindingSubject = true
        subjectTask = Task {
            let detection = await Task.detached(priority: .utility) {
                VerseImageComposerModel.subjectCutout(of: image)
            }.value
            guard !Task.isCancelled else { return }
            isFindingSubject = false
            // The person may have picked another photo, or undone this one, meanwhile.
            guard photo === image else { return }
            switch detection {
            case .success(let subject):
                photoSubject = subject
                isSubjectDetectionUnavailable = false
            case .failure:
                photoSubject = nil
                isSubjectDetectionUnavailable = true
            }
        }
    }

    private func recordUndoSnapshot() {
        guard !isRestoringSnapshot else { return }
        undoHistory.append(
            Snapshot(
                format: format,
                background: background,
                gradient: gradient,
                solidColor: solidColor,
                photo: photo,
                photoSubject: photoSubject,
                verseBehindSubject: verseBehindSubject,
                photoScale: photoScale,
                photoOffset: photoOffset,
                photoDimming: photoDimming,
                photoBlur: photoBlur,
                photoLuminance: photoLuminance,
                editedText: editedText,
                fontStyle: fontStyle,
                textScale: textScale,
                textOffset: textOffset,
                textColor: textColor,
                textAlignment: textAlignment,
                showsReference: showsReference,
                showsBranding: showsBranding,
                inkStrokes: inkStrokes
            )
        )
    }

    /// Photos are decoded at no more than the largest canvas side so a 48MP photo doesn't fill memory.
    nonisolated private static func decodePhoto(_ data: Data, maxPixelSize: CGFloat) -> (image: UIImage, luminance: Double)? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        // Drawing the photo into a single pixel gives its average color.
        var pixel = [UInt8](repeating: 0, count: 4)
        let luminance: Double = pixel.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return 0.5 }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return VerseImageComposerModel.luminance(
                red: Double(buffer[0]) / 255,
                green: Double(buffer[1]) / 255,
                blue: Double(buffer[2]) / 255
            )
        }
        return (UIImage(cgImage: cgImage), luminance)
    }

    /// The photo's main subjects on a transparent background, at the photo's full size.
    /// This is the same kind of subject lifting the Lock Screen uses for its depth effect.
    /// Succeeds with nil when the photo has no clear subject, and fails when Vision can't run,
    /// such as in some simulators.
    nonisolated private static func subjectCutout(of image: UIImage) -> Result<UIImage?, any Error> {
        guard let cgImage = image.cgImage else { return .success(nil) }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        return Result {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: false
            )
            let masked = CIImage(cvPixelBuffer: buffer)
            guard let cutout = CIContext().createCGImage(masked, from: masked.extent) else {
                throw CocoaError(.coderInvalidValue)
            }
            return UIImage(cgImage: cutout)
        }
    }

    // MARK: Placement

    /// On an iPad wallpaper the verse stays inside the square that shows in every orientation.
    private var textOffsetLimit: CGFloat { 0.35 * format.contentFraction }
    private static let nudgeStep: CGFloat = 0.03

    /// How far, as a fraction of the canvas, the photo can move before an edge would show.
    private var photoOffsetLimit: CGSize {
        guard let photo, photo.size.width > 0, photo.size.height > 0 else { return .zero }
        let canvas = format.pixelSize
        let fill = max(canvas.width / photo.size.width, canvas.height / photo.size.height) * photoScale
        return CGSize(
            width: max(0, photo.size.width * fill - canvas.width) / 2 / canvas.width,
            height: max(0, photo.size.height * fill - canvas.height) / 2 / canvas.height
        )
    }

    func clampedPhotoOffset(_ offset: CGSize) -> CGSize {
        let limit = photoOffsetLimit
        return CGSize(
            width: min(max(offset.width, -limit.width), limit.width),
            height: min(max(offset.height, -limit.height), limit.height)
        )
    }

    func clampedTextOffset(_ offset: CGSize) -> CGSize {
        let limit = textOffsetLimit
        return CGSize(
            width: min(max(offset.width, -limit), limit),
            height: min(max(offset.height, -limit), limit)
        )
    }

    /// Zooming out or changing the format can leave the photo offset past its new limit.
    func clampPhotoOffset() {
        let clampedOffset = clampedPhotoOffset(photoOffset)
        guard clampedOffset != photoOffset else { return }
        isRestoringSnapshot = true
        photoOffset = clampedOffset
        isRestoringSnapshot = false
    }

    /// Keeps both offsets in range for the new format, and moves a centered verse into the
    /// Lock Screen's open middle, between the clock and the notifications.
    func formatDidChange() {
        clampPhotoOffset()
        isRestoringSnapshot = true
        defer { isRestoringSnapshot = false }
        let clampedText = clampedTextOffset(textOffset)
        if clampedText != textOffset {
            textOffset = clampedText
        }
        if format == .wallpaper, format.contentFraction == 1, textOffset == .zero {
            textOffset = CGSize(width: 0, height: LockScreenLayout.verseCenterOffset)
        }
    }

    func movePhoto(by fraction: CGSize) {
        photoOffset = clampedPhotoOffset(CGSize(width: photoOffset.width + fraction.width, height: photoOffset.height + fraction.height))
    }

    func moveText(by fraction: CGSize) {
        textOffset = clampedTextOffset(CGSize(width: textOffset.width + fraction.width, height: textOffset.height + fraction.height))
    }

    /// Moves one step in a direction, for people who can't drag the preview.
    func nudgePhoto(dx: CGFloat, dy: CGFloat) {
        movePhoto(by: CGSize(width: dx * Self.nudgeStep, height: dy * Self.nudgeStep))
    }

    func nudgeText(dx: CGFloat, dy: CGFloat) {
        moveText(by: CGSize(width: dx * Self.nudgeStep, height: dy * Self.nudgeStep))
    }

    // MARK: Readability

    /// WCAG contrast of the text against what is behind it, after the darkening overlay.
    /// Gradients are averaged, so this is an estimate.
    private var contrastRatio: Double {
        let behind: Double
        switch background {
        case .gradient: behind = Self.gradientLuminance(gradient)
        case .solid: behind = Self.luminance(solidColor)
        case .photo: behind = photo == nil ? Self.gradientLuminance(.sunrise) : photoLuminance
        }
        let overlay = background == .photo ? photoDimming : 0.12
        let back = behind * (1 - overlay)
        let text = Self.luminance(textColor)
        return (max(back, text) + 0.05) / (min(back, text) + 0.05)
    }

    var hasLowContrast: Bool { contrastRatio < 3 }

    private static func gradientLuminance(_ gradient: VerseImageGradient) -> Double {
        let values = gradient.colors.map(luminance)
        return values.reduce(0, +) / Double(values.count)
    }

    private static func luminance(_ color: Color) -> Double {
        let rgb = components(of: color)
        return luminance(red: rgb[0], green: rgb[1], blue: rgb[2])
    }

    nonisolated private static func luminance(red: Double, green: Double, blue: Double) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private static func components(of color: Color) -> [Double] {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [Double(red), Double(green), Double(blue)]
    }

    // MARK: Remembered choices

    private static let preferencesKey = "verseImageComposerPreferences"

    /// The look is remembered between verses. A photo isn't, so it falls back to a gradient.
    private struct Preferences: Codable {
        var format: String
        var background: String
        var gradient: String
        var fontStyle: String
        var textAlignment: String
        var textScale: Double
        var showsReference: Bool
        var showsBranding: Bool
        var solidColor: [Double]
        var textColor: [Double]
    }

    func savePreferences() {
        let preferences = Preferences(
            format: format.rawValue,
            background: (background == .photo ? .gradient : background).rawValue,
            gradient: gradient.rawValue,
            fontStyle: fontStyle.rawValue,
            textAlignment: textAlignment.rawValue,
            textScale: Double(textScale),
            showsReference: showsReference,
            showsBranding: showsBranding,
            solidColor: Self.components(of: solidColor),
            textColor: Self.components(of: textColor)
        )
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        UserDefaults.standard.set(data, forKey: Self.preferencesKey)
    }

    private func loadPreferences() {
        guard let data = UserDefaults.standard.data(forKey: Self.preferencesKey),
              let preferences = try? JSONDecoder().decode(Preferences.self, from: data) else { return }
        format = VerseImageFormat(rawValue: preferences.format) ?? format
        background = VerseImageBackground(rawValue: preferences.background) ?? background
        gradient = VerseImageGradient(rawValue: preferences.gradient) ?? gradient
        fontStyle = VerseImageFontStyle(rawValue: preferences.fontStyle) ?? fontStyle
        textAlignment = VerseImageTextAlignment(rawValue: preferences.textAlignment) ?? textAlignment
        textScale = CGFloat(preferences.textScale).clamped(to: Self.textScaleRange)
        showsReference = preferences.showsReference
        showsBranding = preferences.showsBranding
        if let color = Self.color(from: preferences.solidColor) { solidColor = color }
        if let color = Self.color(from: preferences.textColor) { textColor = color }
    }

    private static func color(from components: [Double]) -> Color? {
        guard components.count == 3 else { return nil }
        return Color(red: components[0], green: components[1], blue: components[2])
    }

    func render() -> UIImage? {
        let size = format.layoutSize
        let renderer = ImageRenderer(content: VerseShareArtwork(model: self).frame(width: size.width, height: size.height))
        renderer.scale = VerseImageFormat.renderScale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}
