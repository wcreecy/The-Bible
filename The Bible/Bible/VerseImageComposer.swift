import Photos
import PhotosUI
import SwiftUI
import UIKit

struct VerseImageComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: VerseImageComposerModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var shareImage: ShareableVerseImage?
    @State private var saveMessage: String?
    @State private var isExporting = false
    @State private var previewLayout = WallpaperPreviewLayout()
    @State private var showsFullScreenPreview = false
    @State private var showsWallpaperSavedSheet = false

    init(verse: VerseActionReference) {
        _model = State(initialValue: VerseImageComposerModel(verse: verse))
    }

    var body: some View {
        NavigationStack {
            // The preview stays above the controls so it can be dragged without fighting the
            // scroll view, and stays visible while a slider moves.
            VStack(spacing: 0) {
                VerseImagePreview(model: model, previewLayout: previewLayout)
                    .frame(maxHeight: 320)
                    .padding([.horizontal, .top])
                    .padding(.bottom, 12)

                if model.isMarkingUp {
                    // Drawing tools replace the style controls so the preview has the room.
                    VerseImageMarkupControls(model: model)
                        .padding()
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            VerseImageCanvasControls(model: model, selectedPhoto: $selectedPhoto)
                            if model.format == .wallpaper {
                                VerseWallpaperControls(
                                    model: model,
                                    layout: $previewLayout,
                                    onPreviewFullScreen: { showsFullScreenPreview = true }
                                )
                            }
                            VerseImageTextControls(model: model)
                            exportButtons
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .onDisappear {
                model.savePreferences()
                model.clearUndoHistory()
            }
            .onChange(of: model.photoScale) { model.clampPhotoOffset() }
            .onChange(of: model.format) { model.formatDidChange() }
            .navigationTitle(model.format == .wallpaper ? Text("Create Wallpaper") : Text("Share as Image"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            // A downward stroke would otherwise pull the sheet away.
            .interactiveDismissDisabled(model.isMarkingUp)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(
                        "Markup",
                        systemImage: model.isMarkingUp ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle"
                    ) {
                        model.isMarkingUp.toggle()
                    }
                    .accessibilityAddTraits(model.isMarkingUp ? .isSelected : [])
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Undo", systemImage: "arrow.uturn.backward", action: model.undo)
                        .disabled(!model.canUndo)
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
                VerseImageShareSheet(image: item.image, includesAppLink: item.includesAppLink)
            }
            .sheet(isPresented: $showsWallpaperSavedSheet) {
                WallpaperSavedSheet(isPad: model.format.contentFraction < 1)
            }
            .fullScreenCover(isPresented: $showsFullScreenPreview) {
                VerseLockScreenFullPreview(model: model, layout: previewLayout)
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

            Button(action: {
                Task { await saveToPhotos() }
            }) {
                Label {
                    if model.format == .wallpaper {
                        Text("Save Wallpaper")
                    } else {
                        Text("Save Image")
                    }
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                }
            }

            .buttonStyle(.glass)
            .tint(.orange)
        }
        .font(.headline)
        // The link is sent as text beside the image; this leaves it off.
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if model.format != .wallpaper {
                IncludeAppLinkToggle()
                    .font(.subheadline)
                    .tint(.orange)
                    .fixedSize()
            }
        }
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
        shareImage = ShareableVerseImage(
            image: image,
            includesAppLink: model.format != .wallpaper && AppShare.includesLink
        )
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
            if model.format == .wallpaper {
                showsWallpaperSavedSheet = true
            } else {
                saveMessage = String(localized: "Saved to Photos.")
            }
        } catch {
            saveMessage = String(localized: "The image could not be saved.")
        }
    }
}

private struct VerseImagePreview: View {
    let model: VerseImageComposerModel
    let previewLayout: WallpaperPreviewLayout
    @GestureState private var photoDrag = CGSize.zero
    @GestureState private var textDrag = CGSize.zero
    @State private var liveStroke: InkStroke?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let layoutSize = model.format.layoutSize
            // Drags are measured in preview points; the artwork is laid out at the export size.
            let toLayout = size.width > 0 ? layoutSize.width / size.width : 1
            let photoTranslation = model.background == .photo
                ? CGSize(width: photoDrag.width * toLayout, height: photoDrag.height * toLayout)
                : .zero

            ZStack {
                ExportSizedLayout(layoutSize: layoutSize) {
                    ZStack {
                        VerseShareArtwork(
                            model: model,
                            photoTranslation: photoTranslation,
                            textTranslation: CGSize(width: textDrag.width * toLayout, height: textDrag.height * toLayout),
                            liveStroke: liveStroke
                        )

                        // Preview chrome never enters VerseShareArtwork or the exported image.
                        if model.format == .wallpaper && previewLayout.showsLockScreen {
                            VerseLockScreenOverlay(
                                model: model,
                                layout: previewLayout,
                                photoTranslation: photoTranslation
                            )
                        }
                    }
                }

                if model.isMarkingUp {
                    InkCaptureView(
                        allowsFinger: model.drawsWithFinger,
                        onChange: { points in
                            liveStroke = points.isEmpty
                                ? nil
                                : InkStroke(points: points, color: model.inkColor, width: model.inkWidth)
                        },
                        onEnd: { points in
                            model.addInkStroke(points)
                            liveStroke = nil
                        }
                    )
                } else {
                    moveLayers(size: size)
                }
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

    /// The drag areas that reposition the photo and the text, off while drawing.
    @ViewBuilder
    private func moveLayers(size: CGSize) -> some View {
        ZStack {
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
    }
}

private struct VerseImageCanvasControls: View {
    let model: VerseImageComposerModel
    @Binding var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Canvas").font(.headline)
                Spacer()
                Picker("Format", selection: Bindable(model).format) {
                    ForEach(VerseImageFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Picker("Background", selection: Bindable(model).background) {
                ForEach(VerseImageBackground.allCases) { background in
                    Text(background.title).tag(background)
                }
            }
            .pickerStyle(.segmented)

            switch model.background {
            case .gradient:
                HStack {
                    Text("Gradient Style").font(.headline)
                    Spacer()
                    Picker("Gradient Style", selection: Bindable(model).gradient) {
                        ForEach(VerseImageGradient.allCases) { gradient in
                            Text(gradient.title).tag(gradient)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
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

                VStack(alignment: .leading, spacing: 4) {
                    // Shown off while unavailable, so a disabled switch never looks on.
                    Toggle("Verse Behind Subject", isOn: Binding(
                        get: { model.verseBehindSubject && model.hasPhotoSubject },
                        set: { model.verseBehindSubject = $0 }
                    ))
                    .disabled(!model.hasPhotoSubject)
                    Group {
                        if model.isFindingSubject {
                            Label("Finding the photo’s subject…", systemImage: "person.crop.rectangle")
                        } else if model.isSubjectDetectionUnavailable {
                            Text("Finding subjects isn’t available on this device.")
                        } else if model.photo != nil && model.photoSubject == nil {
                            Text("No clear subject was found in this photo.")
                        } else {
                            Text("Tucks the verse behind the people or things in your photo.")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

private struct VerseImageMarkupControls: View {
    let model: VerseImageComposerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Markup").font(.headline)
                Spacer()
                Button("Done") { model.isMarkingUp = false }
                    .fontWeight(.semibold)
            }

            HStack(spacing: 12) {
                ForEach(VerseImageInk.palette, id: \.self) { ink in
                    Button {
                        model.inkColor = ink
                    } label: {
                        Circle()
                            .fill(ink)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(.secondary.opacity(0.5), lineWidth: 1))
                            .overlay {
                                if model.inkColor == ink {
                                    Circle().stroke(.primary, lineWidth: 2.5).padding(-4)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(ink.description))
                    .accessibilityAddTraits(model.inkColor == ink ? .isSelected : [])
                }
            }

            LabeledContent("Pen Size") {
                Slider(value: Bindable(model).inkWidth, in: VerseImageInk.widthRange)
            }

            Toggle("Draw with Finger", isOn: Bindable(model).drawsWithFinger)
                .tint(.orange)

            HStack {
                Text("Draw on the preview above. Undo removes the last stroke.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear Drawing", role: .destructive, action: model.clearInk)
                    .font(.footnote.weight(.semibold))
                    .buttonStyle(.borderless)
                    .disabled(model.inkStrokes.isEmpty)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

private struct VerseImageTextControls: View {
    let model: VerseImageComposerModel
    @FocusState private var isEditingText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Verse Text").font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("Verse Text", text: Bindable(model).editedText, axis: .vertical)
                    .lineLimit(3...8)
                    .focused($isEditingText)
                    .padding(10)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 10))
                    .accessibilityHint("Edit to show only part of the verse on the image.")

                HStack {
                    Text("Delete words to show only part of the verse.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if model.isTextEdited {
                        Button("Use Full Verse") {
                            isEditingText = false
                            model.restoreFullVerse()
                        }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
            }
            .onChange(of: isEditingText) { _, isEditing in
                if isEditing { model.beginEditingText() }
            }
            .toolbar {
                // Return adds a line break in a multi-line field, so the keyboard needs its own way out.
                ToolbarItem(placement: .keyboard) {
                    Button("Done") { isEditingText = false }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            Picker("Font", selection: Bindable(model).fontStyle) {
                ForEach(VerseImageFontStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }

            LabeledContent("Text Size") {
                Slider(value: Bindable(model).textScale, in: VerseImageComposerModel.textScaleRange)
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
            if model.format != .wallpaper {
                Toggle("Show App Branding", isOn: Bindable(model).showsBranding)
            }
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
    let includesAppLink: Bool
}

private struct VerseImageShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    let includesAppLink: Bool

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Leave breathing room between the image and its optional tappable App Store link.
        let items: [Any] = includesAppLink ? [image, "\n\n", AppLinkActivityItem()] : [image]
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
