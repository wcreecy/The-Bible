import ImageIO
import Photos
import PhotosUI
import SwiftUI
import UIKit

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

@MainActor
@Observable
final class VerseImageComposerModel {
    let verse: VerseActionReference

    var format: VerseImageFormat = .portrait
    var background: VerseImageBackground = .gradient
    var gradient: VerseImageGradient = .sunrise
    var solidColor = Color.indigo
    var photo: UIImage?
    var photoScale: CGFloat = 1
    var photoOffset = CGSize.zero
    var photoDimming: Double = 0.28
    var photoBlur: Double = 0
    /// Average brightness of the chosen photo, used to warn about unreadable text.
    private var photoLuminance = 0.5

    var fontStyle: VerseImageFontStyle = .serif
    var textScale: CGFloat = 1
    var textOffset = CGSize.zero
    var textColor = Color.white
    var textAlignment: VerseImageTextAlignment = .center
    var showsReference = true
    var showsBranding = true

    init(verse: VerseActionReference) {
        self.verse = verse
        loadPreferences()
    }

    /// Restores the look; the chosen canvas format stays.
    func reset() {
        background = .gradient
        gradient = .sunrise
        solidColor = .indigo
        photo = nil
        photoScale = 1
        photoOffset = .zero
        photoDimming = 0.28
        photoBlur = 0
        fontStyle = .serif
        textScale = 1
        textOffset = .zero
        textColor = .white
        textAlignment = .center
        showsReference = true
        showsBranding = true
    }

    /// Loads the picked photo at a size that suits the canvas. Returns false if it can't be read.
    @discardableResult
    func loadPhoto(from item: PhotosPickerItem?) async -> Bool {
        guard let item else { return true }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let decoded = await Task.detached(priority: .userInitiated, operation: {
                  VerseImageComposerModel.decodePhoto(data)
              }).value else { return false }
        photo = decoded.image
        photoLuminance = decoded.luminance
        background = .photo
        photoScale = 1
        photoOffset = .zero
        return true
    }

    /// Photos are decoded at no more than the largest canvas side so a 48MP photo doesn't fill memory.
    nonisolated private static func decodePhoto(_ data: Data) -> (image: UIImage, luminance: Double)? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 2160
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

    // MARK: Placement

    private static let textOffsetLimit: CGFloat = 0.35
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
        let limit = Self.textOffsetLimit
        return CGSize(
            width: min(max(offset.width, -limit), limit),
            height: min(max(offset.height, -limit), limit)
        )
    }

    /// Zooming out or changing the format can leave the photo offset past its new limit.
    func clampPhotoOffset() {
        photoOffset = clampedPhotoOffset(photoOffset)
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
        textScale = CGFloat(min(max(preferences.textScale, 0.65), 1.6))
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
        let size = format.pixelSize
        let renderer = ImageRenderer(content: VerseShareArtwork(model: self).frame(width: size.width, height: size.height))
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

struct VerseShareArtwork: View {
    let model: VerseImageComposerModel
    var photoTranslation = CGSize.zero
    var textTranslation = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let textOffset = textOffset(in: size)

            ZStack {
                background(size: size)

                Color.black.opacity(model.background == .photo ? model.photoDimming : 0.12)

                VStack(alignment: model.textAlignment.horizontalAlignment, spacing: size.width * 0.035) {
                    Text(model.verse.verseText)
                        .font(model.fontStyle.font(size: verseFontSize(for: size)))
                        .fontWeight(.semibold)
                        .multilineTextAlignment(model.textAlignment.textAlignment)
                        .minimumScaleFactor(0.55)
                        .lineLimit(14)
                        .shadow(color: .black.opacity(0.45), radius: size.width * 0.008, y: size.width * 0.004)

                    if model.showsReference {
                        Text("\(model.verse.bookName) \(model.verse.chapterNumber):\(model.verse.verseNumber)")
                            .font(.system(size: size.width * 0.032, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(size.width * 0.002)
                    }
                }
                .foregroundStyle(model.textColor)
                .frame(width: size.width * 0.82, alignment: frameAlignment)
                .offset(x: textOffset.width * size.width, y: textOffset.height * size.height)

                if model.showsBranding {
                    VStack {
                        Spacer()
                        Text("THE BIBLE")
                            .font(.system(size: size.width * 0.021, weight: .bold, design: .rounded))
                            .tracking(size.width * 0.004)
                            .foregroundStyle(model.textColor.opacity(0.75))
                            .padding(.bottom, size.height * 0.035)
                    }
                }
            }
            .clipped()
        }
    }

    @ViewBuilder
    private func background(size: CGSize) -> some View {
        switch model.background {
        case .gradient:
            LinearGradient(colors: model.gradient.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        case .solid:
            model.solidColor
        case .photo:
            if let photo = model.photo {
                let photoOffset = photoOffset(in: size)
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(model.photoScale)
                    .offset(x: photoOffset.width * size.width, y: photoOffset.height * size.height)
                    .blur(radius: model.photoBlur * size.width / 360)
            } else {
                LinearGradient(colors: VerseImageGradient.sunrise.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    /// A drag distance in points, as a fraction of the canvas.
    private func fraction(of translation: CGSize, in size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return .zero }
        return CGSize(width: translation.width / size.width, height: translation.height / size.height)
    }

    /// The saved offset plus the drag in progress, held to the same limits as the final one
    /// so the preview doesn't jump when the drag ends.
    private func photoOffset(in size: CGSize) -> CGSize {
        let drag = fraction(of: photoTranslation, in: size)
        return model.clampedPhotoOffset(CGSize(
            width: model.photoOffset.width + drag.width,
            height: model.photoOffset.height + drag.height
        ))
    }

    private func textOffset(in size: CGSize) -> CGSize {
        let drag = fraction(of: textTranslation, in: size)
        return model.clampedTextOffset(CGSize(
            width: model.textOffset.width + drag.width,
            height: model.textOffset.height + drag.height
        ))
    }

    private func verseFontSize(for size: CGSize) -> CGFloat {
        let base: CGFloat
        switch model.verse.verseText.count {
        case ..<100: base = 0.064
        case ..<200: base = 0.052
        default: base = 0.042
        }
        return size.width * base * model.textScale
    }

    private var frameAlignment: Alignment {
        switch model.textAlignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

struct VerseImageComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: VerseImageComposerModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var shareImage: ShareableVerseImage?
    @State private var saveMessage: String?
    @State private var isExporting = false

    init(verse: VerseActionReference) {
        _model = State(initialValue: VerseImageComposerModel(verse: verse))
    }

    var body: some View {
        NavigationStack {
            // The preview stays above the controls so it can be dragged without fighting the
            // scroll view, and stays visible while a slider moves.
            VStack(spacing: 0) {
                VerseImagePreview(model: model)
                    .frame(maxHeight: 320)
                    .padding([.horizontal, .top])
                    .padding(.bottom, 12)

                ScrollView {
                    VStack(spacing: 20) {
                        VerseImageCanvasControls(model: model, selectedPhoto: $selectedPhoto)
                        VerseImageTextControls(model: model)
                        exportButtons
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .onDisappear { model.savePreferences() }
            .onChange(of: model.photoScale) { model.clampPhotoOffset() }
            .onChange(of: model.format) { model.clampPhotoOffset() }
            .navigationTitle("Share as Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset", systemImage: "arrow.counterclockwise", action: model.reset)
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if !(await model.loadPhoto(from: item)) {
                        saveMessage = String(localized: "That photo could not be loaded.")
                    }
                    // Clearing the pick lets the same photo be chosen again.
                    selectedPhoto = nil
                }
            }
            .sheet(item: $shareImage) { item in
                VerseImageShareSheet(image: item.image)
            }
            .alert("Image Export", isPresented: Binding(
                get: { saveMessage != nil },
                set: { if !$0 { saveMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveMessage ?? "")
            }
        }
    }

    private var exportButtons: some View {
        HStack(spacing: 12) {
            Button("Share", systemImage: "square.and.arrow.up") {
                Task { await share() }
            }
            .buttonStyle(.glassProminent)
            .tint(.orange)

            Button("Save Image", systemImage: "square.and.arrow.down") {
                Task { await saveToPhotos() }
            }
            .buttonStyle(.glass)
            .tint(.orange)
        }
        .font(.headline)
        .disabled(isExporting)
        .opacity(isExporting ? 0.4 : 1)
        .overlay {
            if isExporting {
                ProgressView()
            }
        }
    }

    /// Renders the full-size image. Rendering occupies the main thread, so the progress
    /// indicator gets a moment to appear first.
    private func renderImage() async -> UIImage? {
        isExporting = true
        defer { isExporting = false }
        try? await Task.sleep(for: .milliseconds(60))
        return model.render()
    }

    private func share() async {
        guard let image = await renderImage() else {
            saveMessage = String(localized: "The image could not be created.")
            return
        }
        shareImage = ShareableVerseImage(image: image)
    }

    private func saveToPhotos() async {
        guard let image = await renderImage() else {
            saveMessage = String(localized: "The image could not be created.")
            return
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveMessage = String(localized: "Allow photo access in Settings to save this image.")
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            Haptics.success()
            saveMessage = String(localized: "Saved to Photos.")
        } catch {
            saveMessage = String(localized: "The image could not be saved.")
        }
    }
}

private struct VerseImagePreview: View {
    let model: VerseImageComposerModel
    @GestureState private var photoDrag = CGSize.zero
    @GestureState private var textDrag = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                VerseShareArtwork(
                    model: model,
                    photoTranslation: model.background == .photo ? photoDrag : .zero,
                    textTranslation: textDrag
                )

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .updating($photoDrag) { value, state, _ in state = value.translation }
                            .onEnded { value in
                                guard model.background == .photo, size.width > 0, size.height > 0 else { return }
                                model.movePhoto(by: CGSize(
                                    width: value.translation.width / size.width,
                                    height: value.translation.height / size.height
                                ))
                            }
                    )

                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: size.width * 0.86, height: size.height * 0.46)
                    .offset(
                        x: model.textOffset.width * size.width,
                        y: model.textOffset.height * size.height
                    )
                    .gesture(
                        DragGesture()
                            .updating($textDrag) { value, state, _ in state = value.translation }
                            .onEnded { value in
                                guard size.width > 0, size.height > 0 else { return }
                                model.moveText(by: CGSize(
                                    width: value.translation.width / size.width,
                                    height: value.translation.height / size.height
                                ))
                            }
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        }
        .aspectRatio(model.format.aspectRatio, contentMode: .fit)
        .animation(.snappy, value: model.format)
        .accessibilityLabel("Verse image preview")
        .accessibilityHint("Drag the verse text to reposition it. Drag a selected photo to reposition the background. The position buttons below do the same.")
    }
}

private struct VerseImageCanvasControls: View {
    let model: VerseImageComposerModel
    @Binding var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Canvas").font(.headline)

            Picker("Format", selection: Bindable(model).format) {
                ForEach(VerseImageFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }
            .pickerStyle(.segmented)

            Picker("Background", selection: Bindable(model).background) {
                ForEach(VerseImageBackground.allCases) { background in
                    Text(background.title).tag(background)
                }
            }
            .pickerStyle(.segmented)

            switch model.background {
            case .gradient:
                Picker("Gradient", selection: Bindable(model).gradient) {
                    ForEach(VerseImageGradient.allCases) { gradient in
                        Text(gradient.title).tag(gradient)
                    }
                }
            case .solid:
                ColorPicker("Background Color", selection: Bindable(model).solidColor, supportsOpacity: false)
            case .photo:
                let photoButtonTitle: LocalizedStringResource = model.photo == nil ? "Choose Photo" : "Change Photo"
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(photoButtonTitle, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.glass)
                .tint(.orange)

                LabeledContent("Photo Zoom") {
                    Slider(value: Bindable(model).photoScale, in: 1...2.5)
                }
                LabeledContent("Darken") {
                    Slider(value: Bindable(model).photoDimming, in: 0...0.75)
                }
                LabeledContent("Blur") {
                    Slider(value: Bindable(model).photoBlur, in: 0...16)
                }
                VerseImageNudgeRow(
                    title: "Photo Position",
                    onNudge: model.nudgePhoto,
                    onCenter: { model.photoOffset = .zero }
                )
                .disabled(model.photo == nil)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

private struct VerseImageTextControls: View {
    let model: VerseImageComposerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Verse Text").font(.headline)

            Picker("Font", selection: Bindable(model).fontStyle) {
                ForEach(VerseImageFontStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }

            LabeledContent("Text Size") {
                Slider(value: Bindable(model).textScale, in: 0.65...1.6)
            }

            Picker("Alignment", selection: Bindable(model).textAlignment) {
                ForEach(VerseImageTextAlignment.allCases) { alignment in
                    Text(alignment.title).tag(alignment)
                }
            }
            .pickerStyle(.segmented)

            VerseImageNudgeRow(
                title: "Text Position",
                onNudge: model.nudgeText,
                onCenter: { model.textOffset = .zero }
            )

            ColorPicker("Text Color", selection: Bindable(model).textColor, supportsOpacity: false)

            if model.hasLowContrast {
                Label("This text color may be hard to read on this background.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Toggle("Show Reference", isOn: Bindable(model).showsReference)
            Toggle("Show App Branding", isOn: Bindable(model).showsBranding)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

/// Moves the text or photo a step at a time, for people who can't drag the preview.
private struct VerseImageNudgeRow: View {
    let title: LocalizedStringKey
    let onNudge: (CGFloat, CGFloat) -> Void
    let onCenter: () -> Void

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 16) {
                Button("Move Left", systemImage: "arrow.left") { onNudge(-1, 0) }
                Button("Move Right", systemImage: "arrow.right") { onNudge(1, 0) }
                Button("Move Up", systemImage: "arrow.up") { onNudge(0, -1) }
                Button("Move Down", systemImage: "arrow.down") { onNudge(0, 1) }
                Button("Center", systemImage: "scope", action: onCenter)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
    }
}

private struct ShareableVerseImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct VerseImageShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
