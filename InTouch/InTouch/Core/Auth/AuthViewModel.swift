import Foundation
import Observation
import Supabase

@Observable
final class AuthViewModel {
    var currentUser: AppUser?
    var isLoading = false
    var errorMessage: String?

    var isSignedIn: Bool { currentUser != nil }
    var needsEmailConfirmation = false

    // Onboarding is needed if full_name is still empty (set by trigger default)
    var needsOnboarding: Bool {
        guard let user = currentUser else { return false }
        return user.fullName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Session restore
    func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            await fetchCurrentUser(id: session.user.id)
        } catch {
            // No active session — user needs to sign in
        }
    }

    // MARK: - Sign Up
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            if response.session != nil {
                await fetchCurrentUser(id: response.user.id)
            } else {
                // Email confirmation required
                needsEmailConfirmation = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            await fetchCurrentUser(id: session.user.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Refresh current user profile
    func refreshCurrentUser() async {
        guard let id = currentUser?.id else { return }
        await fetchCurrentUser(id: id)
    }

    // MARK: - Fetch profile
    private func fetchCurrentUser(id: UUID) async {
        do {
            let users: [AppUser] = try await supabase
                .from("users")
                .select()
                .eq("id", value: id)
                .execute()
                .value
            currentUser = users.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
