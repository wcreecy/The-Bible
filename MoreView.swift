import SwiftUI

enum MoreDestination: Hashable {
    case stats
    case settings
}

struct MoreView: View {
    var body: some View {
        List {
            Section {
                NavigationLink(value: MoreDestination.stats) {
                    Label("Stats", systemImage: "chart.bar")
                }

                NavigationLink(value: MoreDestination.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
        }
        .navigationTitle("More")
        .navigationDestination(for: MoreDestination.self) { destination in
            switch destination {
            case .stats:
                StatsView()
            case .settings:
                SettingsView()
                    .environment(\.font, nil)
                    .fontDesign(.default)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MoreView()
    }
}
