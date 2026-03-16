import SwiftUI

@main
struct InTouchApp: App {
    @State private var authViewModel = AuthViewModel()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authViewModel)
                .environment(router)
                .task {
                    await authViewModel.restoreSession()
                }
        }
    }
}
