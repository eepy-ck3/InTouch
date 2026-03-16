import SwiftUI

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            PersonalFeedView()
                .tabItem { Label("Feed", systemImage: "list.bullet") }
                .tag(0)

            DiscoveryFeedView()
                .tabItem { Label("Discover", systemImage: "location.circle") }
                .tag(1)

            CreateActivityView()
                .tabItem { Label("New Activity", systemImage: "plus.circle.fill") }
                .tag(2)

            NotificationsView()
                .tabItem { Label("Alerts", systemImage: "bell") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.circle") }
                .tag(4)
        }
    }
}
