import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        Group {
            if auth.isSignedIn {
                if auth.needsOnboarding {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            } else {
                SignInView()
            }
        }
    }
}
