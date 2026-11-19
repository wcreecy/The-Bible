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

                if layout.previewsDepth {
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
            zone(height: max(topChromeBottom + unit * 0.03, 0), label: "Clock & Widgets", labelAlignment: .bottom, unit: unit)
            zone(height: bottomZoneHeight, label: "Notifications", labelAlignment: .top, unit: unit)
                .offset(y: size.height - bottomZoneHeight)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private func zone(height: CGFloat, label: LocalizedStringResource, labelAlignment: Alignment, unit: CGFloat) -> some View {
        Rectangle()
            .fill(.black.opacity(0.22))
            .overlay(alignment: labelAlignment) {
                Text(label)
                    .font(.system(size: max(unit * 0.03, 7), weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(unit * 0.015)
            }
            .frame(height: height)
    }
}

/// The wallpaper at full screen size with the Lock Screen over it, so people can judge the
/// verse as it will really look. Tap anywhere to close.
struct VerseLockScreenFullPreview: View {
    let model: VerseImageComposerModel
    let layout: WallpaperPreviewLayout
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { proxy in
            let screen = proxy.size
            let canvas = model.format.pixelSize
            // Fill the screen the way iOS does; on iPad this crops the square canvas to the orientation.
            let scale = max(screen.width / canvas.width, screen.height / canvas.height)
            let display = CGSize(width: canvas.width * scale, height: canvas.height * scale)

            ZStack {
                VerseShareArtwork(model: model)
                    .frame(width: display.width, height: display.height)
                VerseLockScreenChrome(layout: layout)
                    .frame(width: screen.width, height: screen.height)
                if layout.previewsDepth {
                    VersePhotoSubjectLayer(model: model)
                        .frame(width: display.width, height: display.height)
                }
            }
            .frame(width: screen.width, height: screen.height)
            .clipped()
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .contentShape(.rect)
        .onTapGesture(perform: dismiss.callAsFunction)
        .accessibilityElement()
        .accessibilityLabel("Lock Screen preview")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Closes the preview.")
        .accessibilityAction(.escape, dismiss.callAsFunction)
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
                Toggle("Preview Depth Effect", isOn: $layout.previewsDepth)
                    .disabled(!model.hasPhotoSubject)
                Button("Reset Lock Screen Preview") {
                    layout = WallpaperPreviewLayout()
                }
            }

            Text(footnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Get a new verse every day: in Shortcuts, make an automation that runs Create Verse Wallpaper, then Set Wallpaper Photo.")
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
                Section {
                    step(1, "Touch and hold your Lock Screen, then tap Customize or the Add button.")
                    step(2, "Choose Photos, then pick the wallpaper you just saved.")
                    step(3, isPad
                        ? "It’s sized to fit both orientations, so you don’t need to zoom it."
                        : "It’s already sized for this screen, so you don’t need to pinch or zoom it.")
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
        .presentationDetents([.medium, .large])
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
