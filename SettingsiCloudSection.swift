import SwiftUI
import CloudKit
import UIKit

struct SettingsiCloudSection: View {
    @EnvironmentObject private var cloudKitManager: CloudKitManager
    @State private var isRefreshingCloudStatus: Bool = false

    private var iCloudStatusText: String {
        switch cloudKitManager.accountState {
        case .available: return "Available"
        case .noAccount: return "No Account"
        case .restricted: return "Restricted"
        case .couldNotDetermine: return "Unavailable"
        case .unknown: return "Unknown"
        }
    }

    private var iCloudStatusColor: Color {
        switch cloudKitManager.accountState {
        case .available: return .green
        case .noAccount, .restricted, .couldNotDetermine: return .orange
        case .unknown: return .secondary
        }
    }

    var body: some View {
        Section {
            HStack {
                Label("CloudKit", systemImage: "icloud")
                Spacer()
                Text(iCloudStatusText)
                    .foregroundStyle(iCloudStatusColor)
                    .accessibilityIdentifier("icloudStatusText")
            }
            if let id = cloudKitManager.userRecordID {
                HStack {
                    Text("User Record")
                    Spacer()
                    Text(id.recordName)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .accessibilityIdentifier("icloudUserRecord")
            }
            Button {
                let h = UIImpactFeedbackGenerator(style: .light)
                h.impactOccurred()

                isRefreshingCloudStatus = true
                Task {
                    await cloudKitManager.refresh()
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await MainActor.run { isRefreshingCloudStatus = false }
                }
            } label: {
                Label {
                    Text(isRefreshingCloudStatus ? "Refreshing…" : "Refresh Status")
                } icon: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(isRefreshingCloudStatus ? .degrees(360) : .degrees(0))
                        .animation(
                            isRefreshingCloudStatus
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                            value: isRefreshingCloudStatus
                        )
                }
            }
            .disabled(isRefreshingCloudStatus)
            .accessibilityIdentifier("icloudRefreshButton")
        } header: {
            Text("iCloud").foregroundStyle(.white)
        } footer: {
            Text("""
            iCloud keeps your data up to date across your devices using CloudKit.
            Status meanings:
            • Available: Signed in to iCloud and CloudKit is ready.
            • No Account: Not signed in to iCloud on this device.
            • Restricted: iCloud is restricted by system settings or parental controls.
            • Unavailable: The status couldn’t be determined right now.
            """)
            .font(.footnote)
            .foregroundStyle(Color.white.opacity(0.7))
        }
        .headerProminence(.increased)
    }
}
