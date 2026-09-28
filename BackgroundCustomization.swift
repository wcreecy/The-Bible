import SwiftUI
import PhotosUI
import UIKit

enum AppBackgroundMode: String, CaseIterable, Identifiable {
    case defaultStyle
    case builtIn
    case photo
    case color

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .defaultStyle: "Default"
        case .builtIn: "Built-In"
        case .photo: "Photo"
        case .color: "Color"
        }
    }
}

private enum BuiltInBackground: String, CaseIterable, Identifiable {
    case river = "river-bg"
    case blackLeather = "blackleather"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .river: "River"
        case .blackLeather: "Black Leather"
        }
    }
}

extension AppTab: Identifiable {
    var id: Int { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .home: "Home"
        case .bible: "Bible"
        case .favorites: "Favorites"
        case .games: "Games"
        case .more: "More"
        }
    }
}

enum AppBackgroundStorage {
    static func modeKey(for tab: AppTab) -> String {
        "background.mode.\(tab.name)"
    }

    static func colorKey(for tab: AppTab) -> String {
        "background.color.\(tab.name)"
    }

    static func photoKey(for tab: AppTab) -> String {
        "background.photo.\(tab.name)"
    }

    static func builtInKey(for tab: AppTab) -> String {
        "background.builtIn.\(tab.name)"
    }

    static func savePhotoData(_ data: Data) throws -> String {
        let directory = try backgroundsDirectory()
        let fileName = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return fileName
    }

    static func image(named fileName: String) -> UIImage? {
        guard !fileName.isEmpty,
              let directory = try? backgroundsDirectory() else {
            return nil
        }
        return UIImage(contentsOfFile: directory.appendingPathComponent(fileName).path)
    }

    private static func backgroundsDirectory() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent("TabBackgrounds", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}

struct AppBackgroundView: View {
    let tab: AppTab
    let defaultImageName: String?

    @AppStorage private var modeRaw: String
    @AppStorage private var colorHex: String
    @AppStorage private var photoFileName: String
    @AppStorage private var builtInAssetName: String

    init(tab: AppTab, defaultImageName: String? = nil) {
        self.tab = tab
        self.defaultImageName = defaultImageName
        _modeRaw = AppStorage(
            wrappedValue: AppBackgroundMode.defaultStyle.rawValue,
            AppBackgroundStorage.modeKey(for: tab)
        )
        _colorHex = AppStorage(
            wrappedValue: "#F2F2F7",
            AppBackgroundStorage.colorKey(for: tab)
        )
        _photoFileName = AppStorage(
            wrappedValue: "",
            AppBackgroundStorage.photoKey(for: tab)
        )
        _builtInAssetName = AppStorage(
            wrappedValue: BuiltInBackground.river.rawValue,
            AppBackgroundStorage.builtInKey(for: tab)
        )
    }

    var body: some View {
        ZStack {
            switch AppBackgroundMode(rawValue: modeRaw) ?? .defaultStyle {
            case .defaultStyle:
                if let defaultImageName {
                    Image(defaultImageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemGroupedBackground)
                }
            case .builtIn:
                Image(builtInAssetName)
                    .resizable()
                    .scaledToFill()
            case .photo:
                if let image = AppBackgroundStorage.image(named: photoFileName) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let defaultImageName {
                    Image(defaultImageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemGroupedBackground)
                }
            case .color:
                Color(hex: colorHex)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private struct AdaptiveBackgroundForegroundModifier: ViewModifier {
    let defaultImageName: String?

    @Environment(\.colorScheme) private var inheritedColorScheme
    @AppStorage private var modeRaw: String
    @AppStorage private var colorHex: String
    @AppStorage private var photoFileName: String
    @AppStorage private var builtInAssetName: String

    init(tab: AppTab, defaultImageName: String?) {
        self.defaultImageName = defaultImageName
        _modeRaw = AppStorage(
            wrappedValue: AppBackgroundMode.defaultStyle.rawValue,
            AppBackgroundStorage.modeKey(for: tab)
        )
        _colorHex = AppStorage(
            wrappedValue: "#F2F2F7",
            AppBackgroundStorage.colorKey(for: tab)
        )
        _photoFileName = AppStorage(
            wrappedValue: "",
            AppBackgroundStorage.photoKey(for: tab)
        )
        _builtInAssetName = AppStorage(
            wrappedValue: BuiltInBackground.river.rawValue,
            AppBackgroundStorage.builtInKey(for: tab)
        )
    }

    func body(content: Content) -> some View {
        content.environment(\.colorScheme, foregroundColorScheme)
    }

    private var foregroundColorScheme: ColorScheme {
        let mode = AppBackgroundMode(rawValue: modeRaw) ?? .defaultStyle

        if mode == .builtIn && builtInAssetName == BuiltInBackground.blackLeather.rawValue {
            return .dark
        }

        let luminance: CGFloat?
        switch mode {
        case .color:
            luminance = Self.relativeLuminance(hex: colorHex)
        case .builtIn:
            luminance = UIImage(named: builtInAssetName)?.averageRelativeLuminance
        case .photo:
            luminance = AppBackgroundStorage.image(named: photoFileName)?.averageRelativeLuminance
                ?? defaultImageName.flatMap { UIImage(named: $0)?.averageRelativeLuminance }
        case .defaultStyle:
            luminance = defaultImageName.flatMap { UIImage(named: $0)?.averageRelativeLuminance }
        }

        guard let luminance else { return inheritedColorScheme }
        return luminance > 0.179 ? .light : .dark
    }

    private static func relativeLuminance(hex: String) -> CGFloat? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }

        let channels = [
            CGFloat((value >> 16) & 0xFF) / 255,
            CGFloat((value >> 8) & 0xFF) / 255,
            CGFloat(value & 0xFF) / 255
        ].map { channel in
            channel <= 0.04045
                ? channel / 12.92
                : pow((channel + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}

extension View {
    func adaptiveBackgroundForeground(tab: AppTab, defaultImageName: String? = nil) -> some View {
        modifier(AdaptiveBackgroundForegroundModifier(tab: tab, defaultImageName: defaultImageName))
    }
}

private extension UIImage {
    var averageRelativeLuminance: CGFloat? {
        guard let cgImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        let channels = pixel.prefix(3).map { value -> CGFloat in
            let channel = CGFloat(value) / 255
            return channel <= 0.04045
                ? channel / 12.92
                : pow((channel + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}

struct SettingsBackgroundSection: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        Section {
            Picker("Page", selection: $selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }

            BackgroundEditor(tab: selectedTab)
                .id(selectedTab)

            Button("Apply This Background to All Tabs") {
                applyToAllTabs()
            }
            .accessibilityHint("Uses the selected page's background on every tab.")
        } header: {
            Text("Tab Backgrounds")
                .foregroundStyle(.primary)
        } footer: {
            Text("Choose a photo or solid color for each tab. Default restores the app's original background.")
        }
        .headerProminence(.increased)
    }

    private func applyToAllTabs() {
        let defaults = UserDefaults.standard
        let sourceMode = defaults.string(forKey: AppBackgroundStorage.modeKey(for: selectedTab))
            ?? AppBackgroundMode.defaultStyle.rawValue
        let sourceColor = defaults.string(forKey: AppBackgroundStorage.colorKey(for: selectedTab))
            ?? "#F2F2F7"
        let sourcePhoto = defaults.string(forKey: AppBackgroundStorage.photoKey(for: selectedTab))
            ?? ""
        let sourceBuiltIn = defaults.string(forKey: AppBackgroundStorage.builtInKey(for: selectedTab))
            ?? BuiltInBackground.river.rawValue

        for tab in AppTab.allCases {
            defaults.set(sourceMode, forKey: AppBackgroundStorage.modeKey(for: tab))
            defaults.set(sourceColor, forKey: AppBackgroundStorage.colorKey(for: tab))
            defaults.set(sourcePhoto, forKey: AppBackgroundStorage.photoKey(for: tab))
            defaults.set(sourceBuiltIn, forKey: AppBackgroundStorage.builtInKey(for: tab))
        }
    }
}

private struct BackgroundEditor: View {
    let tab: AppTab

    @AppStorage private var modeRaw: String
    @AppStorage private var colorHex: String
    @AppStorage private var photoFileName: String
    @AppStorage private var builtInAssetName: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var errorMessage: String?

    init(tab: AppTab) {
        self.tab = tab
        _modeRaw = AppStorage(
            wrappedValue: AppBackgroundMode.defaultStyle.rawValue,
            AppBackgroundStorage.modeKey(for: tab)
        )
        _colorHex = AppStorage(
            wrappedValue: "#F2F2F7",
            AppBackgroundStorage.colorKey(for: tab)
        )
        _photoFileName = AppStorage(
            wrappedValue: "",
            AppBackgroundStorage.photoKey(for: tab)
        )
        _builtInAssetName = AppStorage(
            wrappedValue: BuiltInBackground.river.rawValue,
            AppBackgroundStorage.builtInKey(for: tab)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Background Type", selection: $modeRaw) {
                ForEach(AppBackgroundMode.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)

            if modeRaw == AppBackgroundMode.builtIn.rawValue {
                BuiltInBackgroundPicker(
                    selection: $builtInAssetName,
                    onSelect: {
                        modeRaw = AppBackgroundMode.builtIn.rawValue
                    }
                )
            }

            if modeRaw == AppBackgroundMode.color.rawValue {
                ColorPicker("Background Color", selection: colorBinding, supportsOpacity: false)
            }

            if modeRaw == AppBackgroundMode.photo.rawValue {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(
                        photoFileName.isEmpty ? "Choose Photo" : "Replace Photo",
                        systemImage: "photo.on.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingPhoto)

                if isLoadingPhoto {
                    ProgressView("Importing photo…")
                }
            }

            BackgroundPreview(
                tab: tab,
                defaultImageName: defaultImageName(for: tab)
            )
        }
        .onChange(of: selectedPhoto) { _, newValue in
            guard let newValue else { return }
            Task {
                await importPhoto(from: newValue)
            }
        }
        .alert(
            "Photo Could Not Be Imported",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: colorHex) },
            set: { colorHex = $0.hexString }
        )
    }

    private func importPhoto(from item: PhotosPickerItem) async {
        isLoadingPhoto = true
        defer {
            isLoadingPhoto = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let jpegData = image.jpegData(compressionQuality: 0.88) else {
                throw BackgroundImportError.invalidImage
            }
            photoFileName = try AppBackgroundStorage.savePhotoData(jpegData)
            modeRaw = AppBackgroundMode.photo.rawValue
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func defaultImageName(for tab: AppTab) -> String? {
        switch tab {
        case .home, .more:
            "river-bg"
        case .bible, .favorites, .games:
            nil
        }
    }
}

private struct BuiltInBackgroundPicker: View {
    @Binding var selection: String
    let onSelect: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(BuiltInBackground.allCases) { background in
                Button {
                    selection = background.rawValue
                    onSelect()
                } label: {
                    VStack(spacing: 6) {
                        Image(background.rawValue)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 76)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .allowsHitTesting(false)

                        Text(background.title)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(4)
                    .contentShape(Rectangle())
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                selection == background.rawValue ? Color.accentColor : Color.clear,
                                lineWidth: 3
                            )
                            .allowsHitTesting(false)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(
                    selection == background.rawValue ? .isSelected : []
                )
            }
        }
    }
}

private struct BackgroundPreview: View {
    let tab: AppTab
    let defaultImageName: String?

    var body: some View {
        AppBackgroundView(tab: tab, defaultImageName: defaultImageName)
            .frame(height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.separator)
            }
    }
}

private enum BackgroundImportError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        "The selected item could not be converted to an image."
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0xF2F2F7
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    var hexString: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#F2F2F7"
        }
        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
