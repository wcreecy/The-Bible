import CoreImage.CIFilterBuiltins
import LinkPresentation
import SwiftUI
import UIKit

/// Sharing the app itself: its App Store link, a QR code for sharing in person, and the
/// optional link added to shared verses.
enum AppShare {
    static let appStoreID = "6756133350"
    static let url = URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
    static let message = "I've been reading the Bible with this app. Take a look:"

    /// Whether verses and results shared from the app end with the app's link.
    static let includesLinkKey = "shareIncludesAppLink"

    static var includesLink: Bool {
        UserDefaults.standard.object(forKey: includesLinkKey) as? Bool ?? true
    }

    /// The link without "https://", as people see it in the line below.
    static var displayLink: String {
        (url.host() ?? "apps.apple.com") + url.path()
    }

    /// The standalone App Store URL added to shared text. Receiving apps can present it as a
    /// tappable link and may generate their own rich App Store preview.
    static var attributionLine: String {
        url.absoluteString
    }

    /// `text` with the app's link on its own line, when that's turned on.
    static func withAttribution(_ text: String) -> String {
        withAttribution(text, includingLink: includesLink)
    }

    static func withAttribution(_ text: String, includingLink: Bool) -> String {
        includingLink ? "\(text)\n\n\(attributionLine)" : text
    }

    /// A QR code for the App Store link, sharp at any size.
    static func qrCode() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        // High correction keeps the code reliable with the centered app icon.
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// The primary icon embedded in the app bundle.
    static func appIcon() -> UIImage? {
        let iconDictionaries = ["CFBundleIcons", "CFBundleIcons~ipad"]

        for dictionaryKey in iconDictionaries {
            guard
                let icons = Bundle.main.object(forInfoDictionaryKey: dictionaryKey) as? [String: Any],
                let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
                let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
                let iconName = iconFiles.last,
                let icon = UIImage(named: iconName)
            else { continue }

            return icon
        }

        return UIImage(named: "AppIcon")
    }
}

/// The App Store link as a share sheet item. Left alone, Messages fetches the App Store page
/// and previews the link with an App Store screenshot; supplying the preview here keeps it
/// to the app's name and icon, with no picture.
final class AppLinkActivityItem: NSObject, UIActivityItemSource {
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        AppShare.url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        AppShare.url
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = AppShare.url
        metadata.url = AppShare.url
        metadata.title = "The Bible"
        if let icon = AppShare.appIcon() {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}

/// The complete text-share payload. Keeping the text and link choice together ensures the
/// share sheet always receives the selection that opened it.
struct AppLinkShareRequest: Identifiable {
    let id = UUID()
    let text: String
    let includesAppLink: Bool

    var activityItems: [Any] {
        if includesAppLink {
            return [text + "\n\n", AppLinkActivityItem()]
        }

        return [text]
    }
}

/// The system share sheet for a list of items.
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// "Share The Bible": the share sheet with the App Store link, and a QR code to scan in person.
struct ShareAppRows: View {
    @State private var showsQRCode = false

    var body: some View {
        ShareLink(
            item: AppShare.url,
            subject: Text("The Bible"),
            message: Text(AppShare.message),
            preview: SharePreview("The Bible", image: Image(systemName: "book.closed.fill"))
        ) {
            row(
                title: "Share The Bible",
                subtitle: "Send the App Store link to a friend",
                systemImage: "square.and.arrow.up"
            )
        }
        .accessibilityIdentifier("shareAppLink")

        Button {
            showsQRCode = true
        } label: {
            row(
                title: "Show QR Code",
                subtitle: "Let someone scan it to download the app",
                systemImage: "qrcode"
            )
        }
        .accessibilityIdentifier("shareAppQRCode")
        .sheet(isPresented: $showsQRCode) {
            AppQRCodeView()
                .presentationDetents([.medium, .large])
        }
    }

    private func row(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

/// A large QR code for the App Store link, for sharing face to face.
struct AppQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var image = AppShare.qrCode()
    private let appIcon = AppShare.appIcon()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Scan to download The Bible")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                if let image {
                    ZStack {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()

                        if let appIcon {
                            Image(uiImage: appIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .padding(5)
                                .background(
                                    .white,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(16)
                    // Always on white, so the code scans in dark mode too.
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .frame(maxWidth: 280)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("QR code for The Bible on the App Store")
                }

                Text("Point the camera at the code to open the App Store.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                ShareLink(item: AppShare.url, message: Text(AppShare.message)) {
                    Label("Share Link Instead", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Opens a compact preparation sheet before the system share sheet so the app-link choice
/// is visible as a real switch at the moment of sharing.
struct AppLinkShareButton<Label: View>: View {
    let title: LocalizedStringResource
    let text: String
    @ViewBuilder let label: () -> Label

    @State private var showsShareOptions = false

    var body: some View {
        Button {
            showsShareOptions = true
        } label: {
            label()
        }
        .sheet(isPresented: $showsShareOptions) {
            AppLinkShareSheet(title: title, text: text)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

struct AppLinkShareSheet: View {
    let title: LocalizedStringResource
    let text: String

    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppShare.includesLinkKey) private var includesLink = true
    @State private var showsShareSheet = false

    private var preparedText: String {
        AppShare.withAttribution(text, includingLink: includesLink)
    }

    /// Keep the shared verse separate from the App Store link. Supplying the link through
    /// `AppLinkActivityItem` gives Messages controlled metadata, rather than letting it fetch
    /// an App Store screenshot for a URL embedded in the text.
    private var shareItems: [Any] {
        if includesLink {
            return [text + "\n\n", AppLinkActivityItem()]
        }

        return [text]
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Preview")
                    .font(.headline)
                    .foregroundStyle(.black)

                ScrollView {
                    Text(preparedText)
                        .font(.body)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("shareTextPreviewText")
                        .padding(16)
                }
                .frame(maxHeight: 180)
                .accessibilityIdentifier("shareTextPreview")
                .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Toggle(isOn: $includesLink) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Include App Link")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.black)
                        Text("Adds a link to The Bible on the App Store")
                            .font(.caption)
                            .foregroundStyle(.black)
                    }
                }
                .accessibilityIdentifier("includeAppLinkToggle")

                Button {
                    showsShareSheet = true
                } label: {
                    Label("Continue to Share", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("continueToShareButton")
            }
            .sheet(isPresented: $showsShareSheet) {
                ActivityShareSheet(items: shareItems)
            }
            .padding(24)
            .navigationTitle(Text(title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

/// A slim card pinned to the bottom of the More tab: Share and a QR code, side by side.
struct ShareAppFooterCard: View {
    @State private var showsQRCode = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Enjoying The Bible?")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text("Help others find it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            ShareLink(
                item: AppShare.url,
                subject: Text("The Bible"),
                message: Text(AppShare.message),
                preview: SharePreview("The Bible", image: Image(systemName: "book.closed.fill"))
            ) {
                // Icon and word when there's room, otherwise just the icon; never wrapped.
                ViewThatFits(in: .horizontal) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .lineLimit(1)
                        .fixedSize()
                    Image(systemName: "square.and.arrow.up")
                }
                .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .accessibilityLabel("Share The Bible")
            .accessibilityIdentifier("shareAppLink")

            Button {
                showsQRCode = true
            } label: {
                Image(systemName: "qrcode")
                    .font(.subheadline.weight(.semibold))
            }
            // Filled like Share, so the two read as a matched pair.
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .accessibilityLabel("Show QR code")
            .accessibilityIdentifier("shareAppQRCode")
        }
        .padding(14)
        .frame(maxWidth: 600)
        .heroCardSurface()
        .sheet(isPresented: $showsQRCode) {
            AppQRCodeView()
                .presentationDetents([.medium, .large])
        }
    }
}

/// The contextual app-link switch shown before sharing an image.
struct IncludeAppLinkToggle: View {
    @AppStorage(AppShare.includesLinkKey) private var includesLink = true

    var body: some View {
        Toggle("Include App Link", systemImage: "link", isOn: $includesLink)
    }
}
