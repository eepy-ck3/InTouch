import Foundation
import Observation
import Supabase
import UIKit

@Observable
final class OnboardingViewModel {
    var fullName = ""
    var username = ""
    var locationName = ""
    var locationLat: Double?
    var locationLng: Double?

    var step: Step = .name
    var isLoading = false
    var errorMessage: String?
    var usernameAvailable: Bool? = nil
    var isCheckingUsername = false
    var avatarImage: UIImage? = nil
    var avatarUrl: String? = nil
    var isUploadingAvatar = false
    var avatarUploadFailed = false

    private var usernameCheckTask: Task<Void, Never>?

    enum Step {
        case name, avatar, username, location
    }

    var canAdvanceFromName: Bool {
        fullName.trimmingCharacters(in: .whitespaces).count >= 2
    }

    var canAdvanceFromUsername: Bool {
        usernameAvailable == true && isValidUsername
    }

    var isValidUsername: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 && trimmed.count <= 30 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Debounced username check (called on every keystroke)
    func onUsernameChanged() {
        usernameAvailable = nil
        usernameCheckTask?.cancel()
        guard isValidUsername else { return }
        usernameCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await checkUsername()
        }
    }

    // MARK: - Check username availability
    func checkUsername() async {
        let trimmed = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard isValidUsername else {
            usernameAvailable = false
            return
        }
        isCheckingUsername = true
        defer { isCheckingUsername = false }
        do {
            let results: [AppUser] = try await supabase
                .from("users")
                .select("id")
                .eq("username", value: trimmed)
                .execute()
                .value
            usernameAvailable = results.isEmpty
        } catch {
            usernameAvailable = nil
        }
    }

    // MARK: - Upload avatar (called immediately on photo selection)
    func uploadAvatar(userId: UUID) async {
        guard let image = avatarImage,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        let path = "\(userId.uuidString.lowercased()).jpg"
        avatarUploadFailed = false
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        do {
            _ = try await supabase.storage
                .from("avatars")
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
            let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path)
            avatarUrl = publicURL.absoluteString
        } catch {
            avatarUploadFailed = true
            avatarUrl = nil
            errorMessage = error.localizedDescription
        }
    }

    func removeAvatar() {
        avatarImage = nil
        avatarUrl = nil
        avatarUploadFailed = false
        errorMessage = nil
    }

    // MARK: - Complete onboarding
    func completeOnboarding(userId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces).lowercased()

        do {
            struct UserUpdate: Encodable {
                let full_name: String
                let username: String
                let avatar_url: String?
                let primary_location_name: String?
                let primary_location_lat: Double?
                let primary_location_lng: Double?
            }
            let update = UserUpdate(
                full_name: trimmedName,
                username: trimmedUsername,
                avatar_url: avatarUrl,
                primary_location_name: locationName.isEmpty ? nil : locationName,
                primary_location_lat: locationLat,
                primary_location_lng: locationLng
            )
            try await supabase
                .from("users")
                .update(update)
                .eq("id", value: userId)
                .execute()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
