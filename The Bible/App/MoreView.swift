import SwiftUI

enum MoreDestination: Hashable {
    case favorites
    case stats
    case settings
}

struct MoreView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

            // A tall footer must scroll with the destinations rather than consume
            // most of their viewport at accessibility text sizes.
            if dynamicTypeSize.isAccessibilitySize {
                ShareAppFooterCard()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        // At standard text sizes, keep the compact footer above the floating tab bar.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !dynamicTypeSize.isAccessibilitySize {
                ShareAppFooterCard()
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
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
