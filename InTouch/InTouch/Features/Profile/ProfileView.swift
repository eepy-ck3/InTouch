import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let user = auth.currentUser {
                    Text(user.fullName)
                        .font(.title2.bold())
                    Text("@\(user.username)")
                        .foregroundStyle(.secondary)
                }

                Button("Sign Out") {
                    Task { await auth.signOut() }
                }
                .foregroundStyle(.red)
            }
            .navigationTitle("Profile")
        }
    }
}
