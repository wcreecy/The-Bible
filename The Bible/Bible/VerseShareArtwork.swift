import SwiftUI

struct VerseShareArtwork: View {
    let model: VerseImageComposerModel
    var photoTranslation = CGSize.zero
    var textTranslation = CGSize.zero
    /// The stroke being drawn, shown before it joins the model's strokes.
    var liveStroke: InkStroke?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let contentWidth = size.width
            let textOffset = textOffset(in: size)

            ZStack {
                background(size: size)

                Color.black.opacity(model.background == .photo ? model.photoDimming : 0.12)

                VStack(alignment: model.textAlignment.horizontalAlignment, spacing: contentWidth * 0.035) {
                    Text(model.displayedText)
                        .font(model.fontStyle.font(size: verseFontSize(for: contentWidth)))
                        .fontWeight(.semibold)
                        .multilineTextAlignment(model.textAlignment.textAlignment)
                        .minimumScaleFactor(0.55)
                        .lineLimit(14)
                        .shadow(color: .black.opacity(0.45), radius: contentWidth * 0.008, y: contentWidth * 0.004)

                    if model.showsReference {
                        Text("\(model.verse.bookName) \(model.verse.chapterNumber):\(model.verse.verseNumber) \(model.verse.translation.abbreviation)")
                            .font(.system(size: contentWidth * 0.032, weight: .bold, design: .rounded))
                            .textCase(.uppercase)
                            .tracking(contentWidth * 0.002)
                    }
                }
                .foregroundStyle(model.textColor)
                .frame(width: contentWidth * 0.82, alignment: frameAlignment)
                .offset(x: textOffset.width * size.width, y: textOffset.height * size.height)

                if model.verseBehindSubject {
                    VersePhotoSubjectLayer(model: model, photoTranslation: photoTranslation)
                }

                if model.showsBranding {
                    VStack {
                        Spacer()
                        Text("THE BIBLE")
                            .font(.system(size: contentWidth * 0.021, weight: .bold, design: .rounded))
                            .tracking(contentWidth * 0.004)
                            .foregroundStyle(model.textColor.opacity(0.75))
                            .padding(.bottom, size.height * 0.035)
                    }
                }

                VerseInkLayer(strokes: liveStroke.map { model.inkStrokes + [$0] } ?? model.inkStrokes)
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
                VersePhotoLayer(image: photo, model: model, translation: photoTranslation)
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
    private func textOffset(in size: CGSize) -> CGSize {
        let drag = fraction(of: textTranslation, in: size)
        return model.clampedTextOffset(CGSize(
            width: model.textOffset.width + drag.width,
            height: model.textOffset.height + drag.height
        ))
    }

    private func verseFontSize(for contentWidth: CGFloat) -> CGFloat {
        let base: CGFloat
        switch model.displayedText.count {
        case ..<100: base = 0.064
        case ..<200: base = 0.052
        default: base = 0.042
        }
        let scale = model.textScale.clamped(to: VerseImageComposerModel.textScaleRange)
        return contentWidth * base * scale
    }

    private var frameAlignment: Alignment {
        switch model.textAlignment {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
}

/// Lays content out at the export's size, then shrinks or grows it to fill the space it's given,
/// so a preview wraps text and places everything exactly as the saved image does.
struct ExportSizedLayout<Content: View>: View {
    let layoutSize: CGSize
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { proxy in
            let scale = layoutSize.width > 0 ? proxy.size.width / layoutSize.width : 1
            content
                .frame(width: layoutSize.width, height: layoutSize.height)
                .scaleEffect(scale, anchor: .topLeading)
                // Scaling doesn't change layout, so pin the full-size content to the corner it shrinks toward.
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
    }
}

/// The photo filling the canvas with the person's zoom, position, and blur. The photo and its
/// subject cut-out both draw through this so they always line up.
struct VersePhotoLayer: View {
    let image: UIImage
    let model: VerseImageComposerModel
    var translation = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let offset = photoOffset(in: size)
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .scaleEffect(model.photoScale)
                .offset(x: offset.width * size.width, y: offset.height * size.height)
                .blur(radius: model.photoBlur * size.width / 360)
        }
    }

    /// The saved offset plus the drag in progress, held to the same limits as the final one.
    private func photoOffset(in size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return model.photoOffset }
        return model.clampedPhotoOffset(CGSize(
            width: model.photoOffset.width + translation.width / size.width,
            height: model.photoOffset.height + translation.height / size.height
        ))
    }
}

/// The photo's subject, darkened like the photo beneath it. Drawn over the verse it tucks the verse
/// behind the subject.
struct VersePhotoSubjectLayer: View {
    let model: VerseImageComposerModel
    var photoTranslation = CGSize.zero

    var body: some View {
        if model.background == .photo, let subject = model.photoSubject {
            let layer = VersePhotoLayer(image: subject, model: model, translation: photoTranslation)
            layer
                .overlay { Color.black.opacity(model.photoDimming) }
                .mask { layer }
        }
    }
}
