import SwiftUI
import UIKit

/// Local preview settings never participate in image rendering or export.
struct WallpaperPreviewLayout {
    var showsLockScreen = true
    /// iOS lets people stretch the clock taller; it has no width setting.
    var clockHeight = 1.0
    var showsDate = true
    var showsWidgets = true
    /// iPad has no flashlight and camera buttons on its Lock Screen.
    var showsBottomControls = UIDevice.current.userInterfaceIdiom != .pad
    var showsSafeZones = true
    var previewsDepth = true
}

/// The Lock Screen chrome drawn over the small preview in the composer. On an iPad's square
/// canvas, the chrome sits in the portrait crop and a dashed square marks what every orientation shows.
struct VerseLockScreenOverlay: View {
    let model: VerseImageComposerModel
    let layout: WallpaperPreviewLayout
    var photoTranslation = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let fraction = model.format.contentFraction
            ZStack {
                VerseLockScreenChrome(layout: layout)
                    .frame(width: size.width * fraction, height: size.height)
                    .frame(width: size.width, height: size.height)
                    .behindPhotoSubject(enabled: layout.previewsDepth) {
                        VersePhotoSubjectLayer(model: model, photoTranslation: photoTranslation)
                    }

                if layout.showsSafeZones && fraction < 1 {
                    Rectangle()
                        .strokeBorder(.white.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: size.width * fraction, height: size.height * fraction)
                }
            }
            .frame(width: size.width, height: size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// An approximation of the Lock Screen's date, clock, widget row, and bottom buttons, sized
/// for whatever frame it's given.
struct VerseLockScreenChrome: View {
    let layout: WallpaperPreviewLayout
    /// Where the clock and widgets end, measured so the safe-zone shading follows the clock height.
    @State private var topChromeBottom: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // The Lock Screen is laid out for a phone-shaped screen; on a wider iPad screen the
            // clock stays about the same size instead of growing with the width.
            let unit = min(size.width, size.height * 0.462)
            let clockBaseHeight = unit * 0.28

            ZStack(alignment: .top) {
                if layout.showsSafeZones {
                    safeZones(size: size, unit: unit)
                }

                VStack(spacing: unit * 0.015) {
                    VStack(spacing: unit * 0.015) {
                        if layout.showsDate {
                            TimelineView(.everyMinute) { context in
                                Text(context.date, format: .dateTime.weekday(.wide).month(.wide).day())
                                    .font(.system(size: unit * 0.045, weight: .medium))
                            }
                        }
                        TimelineView(.everyMinute) { context in
                            Text(context.date, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
                                .font(.system(size: unit * 0.23, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .fixedSize()
                                .frame(height: clockBaseHeight)
                                .scaleEffect(x: 1, y: layout.clockHeight, anchor: .top)
                                // Scaling doesn't change layout; reserve the stretched height explicitly.
                                .frame(height: clockBaseHeight * layout.clockHeight, alignment: .top)
                        }
                        if layout.showsWidgets {
                            widgetRow(unit: unit)
                                .padding(.top, unit * 0.02)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("lockScreen")).maxY } action: {
                        topChromeBottom = $0
                    }

                    Spacer(minLength: 0)

                    if layout.showsBottomControls {
                        HStack {
                            bottomButton("flashlight.off.fill", unit: unit)
                            Spacer()
                            bottomButton("camera.fill", unit: unit)
                        }
                        .padding(.horizontal, unit * 0.11)
                        .padding(.bottom, size.height * 0.045)
                    }
                }
                .padding(.top, size.height * 0.075)
            }
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: size.width, height: size.height)
            .coordinateSpace(.named("lockScreen"))
        }
    }

    private func widgetRow(unit: CGFloat) -> some View {
        HStack(spacing: unit * 0.04) {
            RoundedRectangle(cornerRadius: unit * 0.04)
                .frame(width: unit * 0.34, height: unit * 0.15)
            Circle()
                .frame(width: unit * 0.15, height: unit * 0.15)
            Circle()
                .frame(width: unit * 0.15, height: unit * 0.15)
        }
        .foregroundStyle(.white.opacity(0.22))
    }

    private func bottomButton(_ systemImage: String, unit: CGFloat) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: unit * 0.05))
            .frame(width: unit * 0.14, height: unit * 0.14)
            .background(.black.opacity(0.25), in: .circle)
    }

    /// Shades where the clock and widgets sit, and where notifications stack up from the bottom.
    private func safeZones(size: CGSize, unit: CGFloat) -> some View {
        let bottomZoneHeight = size.height * LockScreenLayout.bottomZone
        return ZStack(alignment: .top) {
            // The band reaches past the widgets far enough to fit its label below them.
            zone(height: max(topChromeBottom + unit * 0.08, 0), label: "Clock & Widgets", edge: .bottom, unit: unit)
            zone(height: bottomZoneHeight, label: "Notifications", edge: .top, unit: unit)
                .offset(y: size.height - bottomZoneHeight)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    /// `edge` is the side facing the open middle, where the label and a dashed line sit so the
    /// zone stays visible on busy or darkened photos.
    private func zone(height: CGFloat, label: LocalizedStringResource, edge: VerticalEdge, unit: CGFloat) -> some View {
        let alignment: Alignment = edge == .top ? .top : .bottom
        return Rectangle()
            .fill(.black.opacity(0.3))
            .overlay(alignment: alignment) {
                Rectangle()
                    .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .frame(height: 1)
            }
            .overlay(alignment: alignment) {
                Text(label)
                    .font(.system(size: max(unit * 0.03, 7), weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(unit * 0.015)
            }
            .frame(height: height)
    }
}

/// The wallpaper at full screen size with the Lock Screen over it, so people can judge the
/// verse as it will really look. Dragging moves the verse and pinching resizes it, so it can be
/// fitted around the real-size clock and notifications.
struct VerseLockScreenFullPreview: View {
    let model: VerseImageComposerModel
    let layout: WallpaperPreviewLayout
    @Environment(\.dismiss) private var dismiss
    @GestureState private var textDrag = CGSize.zero
    @GestureState private var pinch: CGFloat = 1

    private var isEditing: Bool { textDrag != .zero || pinch != 1 }

    var body: some View {
        GeometryReader { proxy in
            let screen = proxy.size
            let canvas = model.format.pixelSize
            // Fill the screen the way iOS does; on iPad this crops the square canvas to the orientation.
            let scale = max(screen.width / canvas.width, screen.height / canvas.height)
            let display = CGSize(width: canvas.width * scale, height: canvas.height * scale)
            let layoutSize = model.format.layoutSize
            // Drags are in screen points; the artwork is laid out at the export size.
            let toLayout = display.width > 0 ? layoutSize.width / display.width : 1

            ZStack {
                ExportSizedLayout(layoutSize: layoutSize) {
                    VerseShareArtwork(
                        model: model,
                        textTranslation: CGSize(width: textDrag.width * toLayout, height: textDrag.height * toLayout),
                        textScaleMultiplier: pinch
                    )
                }
                .frame(width: display.width, height: display.height)

                VerseLockScreenChrome(layout: layout)
                    .frame(width: screen.width, height: screen.height)
                    .behindPhotoSubject(enabled: layout.previewsDepth) {
                        ExportSizedLayout(layoutSize: layoutSize) {
                            VersePhotoSubjectLayer(model: model)
                        }
                        .frame(width: display.width, height: display.height)
                    }
                    .allowsHitTesting(false)
            }
            .frame(width: screen.width, height: screen.height)
            .clipped()
            .contentShape(.rect)
            .gesture(editGesture(display: display))
            .accessibilityElement()
            .accessibilityLabel("Lock Screen preview")
            .accessibilityValue(Text(model.textScale, format: .percent.precision(.fractionLength(0))))
            .accessibilityHint("Swipe up or down to change the text size.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: model.textScale = (model.textScale + 0.05).clamped(to: VerseImageComposerModel.textScaleRange)
                case .decrement: model.textScale = (model.textScale - 0.05).clamped(to: VerseImageComposerModel.textScaleRange)
                @unknown default: break
                }
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            // Sits between the flashlight and camera buttons, where the Lock Screen has nothing.
            VStack(spacing: 8) {
                Text("Drag to move · Pinch to resize")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.4), radius: 2)
                    // Out of the way while editing, so it never covers a verse being placed low.
                    .opacity(isEditing ? 0 : 1)
                    .animation(.easeOut(duration: 0.2), value: isEditing)
                Button("Done", action: dismiss.callAsFunction)
                    .buttonStyle(.glassProminent)
                    .tint(.orange)
            }
            .padding(.bottom, 24)
        }
        .statusBarHidden()
        .accessibilityAction(.escape, dismiss.callAsFunction)
    }

    /// One finger moves the verse and two fingers resize it, at the same time if both are used.
    /// Each finished gesture is a single undo step.
    private func editGesture(display: CGSize) -> some Gesture {
        let drag = DragGesture()
            .updating($textDrag) { value, state, _ in state = value.translation }
            .onEnded { value in
                guard display.width > 0, display.height > 0 else { return }
                model.moveText(by: CGSize(
                    width: value.translation.width / display.width,
                    height: value.translation.height / display.height
                ))
            }
        let magnify = MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                model.textScale = (model.textScale * value.magnification)
                    .clamped(to: VerseImageComposerModel.textScaleRange)
            }
        return drag.simultaneously(with: magnify)
    }
}

extension View {
    /// Cuts the photo's subject out of this view, so the subject seems to stand in front of it.
    /// This is how the depth effect is previewed: only the Lock Screen chrome goes behind the
    /// subject, while the verse, which is part of the wallpaper itself, stays where it was drawn.
    func behindPhotoSubject(enabled: Bool, @ViewBuilder subject: () -> some View) -> some View {
        mask {
            ZStack {
                Rectangle()
                if enabled {
                    subject().blendMode(.destinationOut)
                }
            }
            .compositingGroup()
        }
    }
}

struct VerseWallpaperControls: View {
    let model: VerseImageComposerModel
    @Binding var layout: WallpaperPreviewLayout
    let onPreviewFullScreen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Preview on Lock Screen", systemImage: "iphone", action: onPreviewFullScreen)
                .buttonStyle(.glass)
                .tint(.orange)
                .frame(maxWidth: .infinity)

            Toggle("Show Lock Screen", isOn: $layout.showsLockScreen)
            if layout.showsLockScreen {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Clock Height") {
                        Text(layout.clockHeight, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                    }
                    Slider(value: $layout.clockHeight, in: 1...3.5, step: 0.05) {
                        Text("Clock Height")
                    }
                    .accessibilityValue(Text(layout.clockHeight, format: .percent.precision(.fractionLength(0))))
                }
                Toggle("Show Date", isOn: $layout.showsDate)
                Toggle("Show Widgets", isOn: $layout.showsWidgets)
                Toggle("Show Bottom Buttons", isOn: $layout.showsBottomControls)
                Toggle("Show Safe Zones", isOn: $layout.showsSafeZones)
                // Shown off while unavailable, so a disabled switch never looks on.
                Toggle("Preview Depth Effect", isOn: Binding(
                    get: { layout.previewsDepth && model.hasPhotoSubject },
                    set: { layout.previewsDepth = $0 }
                ))
                .disabled(!model.hasPhotoSubject)
                Button("Reset Lock Screen Preview") {
                    layout = WallpaperPreviewLayout()
                }
            }

            Text(footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Get a new verse every day: in Shortcuts, make an automation that runs Create Verse Wallpaper, then Set Wallpaper Photo. Keep Show Preview on so you can pinch to fit before it’s set.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 18))
    }

    private var footnote: LocalizedStringResource {
        if model.format.contentFraction < 1 {
            "Keep the verse inside the dashed square so it shows in both portrait and landscape. The Lock Screen preview isn’t saved in your wallpaper."
        } else if model.hasPhotoSubject {
            "Keep the verse out of the shaded areas. Depth Effect is an approximation; iOS decides whether to use it. The Lock Screen preview isn’t saved in your wallpaper."
        } else {
            "Keep the verse out of the shaded areas so the clock and notifications don’t cover it. The Lock Screen preview isn’t saved in your wallpaper."
        }
    }
}

/// Step-by-step instructions shown after a wallpaper is saved, since apps can't set the wallpaper
/// or open the wallpaper settings directly.
struct WallpaperSavedSheet: View {
    let isPad: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // iOS zooms in on every photo it's given, so the full verse only shows after a pinch.
                // Most people miss this, so it leads the sheet instead of sitting among the steps.
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pinch to zoom out")
                                .font(.headline)
                            Text(isPad
                                ? "iOS zooms in on new wallpapers. Pinch inward until the whole verse shows; the image is already sized for both orientations."
                                : "iOS zooms in on new wallpapers. Pinch inward until the whole verse shows; the image is already sized for this screen.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    step(1, "Touch and hold your Lock Screen, then tap Customize or the Add button.")
                    step(2, "Choose Photos, then pick the wallpaper you just saved.")
                    step(3, "Pinch to zoom out until the edges of the image line up with the screen.")
                    step(4, "If your photo has a clear subject, turn on Depth Effect from the More button.")
                    step(5, "Tap Add, then Set as Wallpaper Pair.")
                } footer: {
                    Text("You can also add it from Settings → Wallpaper → Add New Wallpaper.")
                }
            }
            .navigationTitle("Wallpaper Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
        .presentationDetents([.fraction(0.8), .large])
    }

    private func step(_ number: Int, _ text: LocalizedStringResource) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "\(number).circle.fill")
                .foregroundStyle(.orange)
        }
    }
}
