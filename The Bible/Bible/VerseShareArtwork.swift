import SwiftUI

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
                    Text(model.displayedText)
                        .font(model.fontStyle.font(size: verseFontSize(for: size)))
                        .fontWeight(.semibold)
                        .multilineTextAlignment(model.textAlignment.textAlignment)
                        .minimumScaleFactor(0.55)
                        .lineLimit(14)
                        .shadow(color: .black.opacity(0.45), radius: size.width * 0.008, y: size.width * 0.004)

                    if model.showsReference {
                        Text("\(model.verse.bookName) \(model.verse.chapterNumber):\(model.verse.verseNumber) \(model.verse.translation.abbreviation)")
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
        switch model.displayedText.count {
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
