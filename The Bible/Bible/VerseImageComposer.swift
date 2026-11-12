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
            .onDisappear {
                model.savePreferences()
                model.clearUndoHistory()
            }
            .onChange(of: model.photoScale) { model.clampPhotoOffset() }
            .onChange(of: model.format) { model.clampPhotoOffset() }
            .navigationTitle("Share as Image")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss.callAsFunction)
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
