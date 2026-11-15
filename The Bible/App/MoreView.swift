import SwiftUI

enum MoreDestination: Hashable {
    case favorites
    case stats
    case settings
}

struct MoreView: View {
    var body: some View {
        List {
            Section {
                NavigationLink(value: MoreDestination.favorites) {
                    Label("Saved Verses", systemImage: "heart")
                }

                NavigationLink(value: MoreDestination.stats) {
                    Label("Stats", systemImage: "chart.bar")
                }

                NavigationLink(value: MoreDestination.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .listRowBackground(HeroCardListRowBackground())
        }
        .scrollContentBackground(.hidden)
        // Pinned to the bottom; inside the tab bar clearance, so on iPhone it sits just
        // above the floating tab bar.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ShareAppFooterCard()
                .padding(.horizontal)
                .padding(.vertical, 12)
        }
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("More")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: MoreDestination.self) { destination in
            switch destination {
            case .favorites:
                FavoritesView()
            case .stats:
                StatsView()
            case .settings:
                SettingsView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        MoreView()
    }
}
