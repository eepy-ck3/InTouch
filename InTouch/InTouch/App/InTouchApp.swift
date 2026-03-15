import SwiftUI

@main
struct InTouchApp: App {
    @State private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .task {
                    await authViewModel.restoreSession()
                }
        }
    }
}
