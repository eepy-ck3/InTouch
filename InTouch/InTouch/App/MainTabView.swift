import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            PersonalFeedView()
                .tabItem {
                    Label("Feed", systemImage: "list.bullet")
                }

            DiscoveryFeedView()
                .tabItem {
                    Label("Discover", systemImage: "location.circle")
                }

            CreateIntentView()
                .tabItem {
                    Label("New Intent", systemImage: "plus.circle.fill")
                }

            NotificationsView()
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}
