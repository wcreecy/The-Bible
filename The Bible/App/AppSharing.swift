import CoreImage.CIFilterBuiltins
import SwiftUI

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

    /// The line added to shared text: "Shared from The Bible app: <link>".
    static var attributionLine: String {
        "Shared from The Bible app: \(url.absoluteString)"
    }

    /// `text` with the app's link on its own line, when that's turned on.
    static func withAttribution(_ text: String) -> String {
        includesLink ? "\(text)\n\n\(attributionLine)" : text
    }

    /// A QR code for the App Store link, sharp at any size.
    static func qrCode() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Scan to download The Bible")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                if let image {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        // Always on white, so the code scans in dark mode too.
                        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .frame(maxWidth: 280)
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

/// The setting for adding the app's link to shared verses and results.
struct ShareAttributionToggle: View {
    @AppStorage(AppShare.includesLinkKey) private var includesLink = true

    var body: some View {
        Toggle(isOn: $includesLink) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Include App Link When Sharing")
                Text("Adds the App Store link to verses and results you share")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("shareAttributionToggle")
    }
}
