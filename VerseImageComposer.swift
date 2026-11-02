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

    var fontStyle: VerseImageFontStyle = .serif
    var textScale: CGFloat = 1
    var textOffset = CGSize.zero
    var textColor = Color.white
    var textAlignment: VerseImageTextAlignment = .center
    var showsReference = true
    var showsBranding = true

    init(verse: VerseActionReference) {
        self.verse = verse
    }

    func reset() {
        format = .portrait
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

    func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        photo = image
        background = .photo
        photoScale = 1
        photoOffset = .zero
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

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

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
                .offset(
                    x: model.textOffset.width * size.width,
                    y: model.textOffset.height * size.height
                )

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
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(model.photoScale)
                    .offset(
                        x: model.photoOffset.width * size.width,
                        y: model.photoOffset.height * size.height
                    )
                    .blur(radius: model.photoBlur * size.width / 360)
            } else {
                LinearGradient(colors: VerseImageGradient.sunrise.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
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

    init(verse: VerseActionReference) {
        _model = State(initialValue: VerseImageComposerModel(verse: verse))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VerseImagePreview(model: model)
                    VerseImageCanvasControls(model: model, selectedPhoto: $selectedPhoto)
                    VerseImageTextControls(model: model)
                    exportButtons
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
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
                Task { await model.loadPhoto(from: item) }
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
                if let image = model.render() {
                    shareImage = ShareableVerseImage(image: image)
                }
            }
            .buttonStyle(.glassProminent)
            .tint(.orange)

            Button("Save Image", systemImage: "square.and.arrow.down") {
                saveToPhotos()
            }
            .buttonStyle(.glass)
            .tint(.orange)
        }
        .font(.headline)
    }

    private func saveToPhotos() {
        guard let image = model.render() else {
            saveMessage = String(localized: "The image could not be created.")
            return
        }

        Task {
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
}

private struct VerseImagePreview: View {
    let model: VerseImageComposerModel
    @GestureState private var photoDrag = CGSize.zero
    @GestureState private var textDrag = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                VerseShareArtwork(model: model)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .updating($photoDrag) { value, state, _ in state = value.translation }
                            .onEnded { value in
                                guard model.background == .photo else { return }
                                model.photoOffset.width += value.translation.width / size.width
                                model.photoOffset.height += value.translation.height / size.height
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
                                model.textOffset.width = clamped(
                                    model.textOffset.width + value.translation.width / size.width,
                                    to: -0.35...0.35
                                )
                                model.textOffset.height = clamped(
                                    model.textOffset.height + value.translation.height / size.height,
                                    to: -0.35...0.35
                                )
                            }
                    )
            }
            .offset(x: model.background == .photo ? photoDrag.width : 0, y: model.background == .photo ? photoDrag.height : 0)
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
        .accessibilityHint("Drag the verse text to reposition it. Drag a selected photo to reposition the background.")
    }

    private func clamped(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
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
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(model.photo == nil ? "Choose Photo" : "Change Photo", systemImage: "photo.on.rectangle")
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

            ColorPicker("Text Color", selection: Bindable(model).textColor, supportsOpacity: false)
            Toggle("Show Reference", isOn: Bindable(model).showsReference)
            Toggle("Show App Branding", isOn: Bindable(model).showsBranding)
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
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
