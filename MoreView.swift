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
                    Label("Favorites", systemImage: "heart")
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
