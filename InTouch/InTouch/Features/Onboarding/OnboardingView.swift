import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var vm = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * progressFraction)
                    }
                    .frame(height: 3)
                    .animation(.easeInOut, value: vm.step)
                }
                .frame(height: 3)

                switch vm.step {
                case .name:     NameStepView(vm: vm)
                case .avatar:   AvatarStepView(vm: vm, userId: auth.currentUser?.id)
                case .username: UsernameStepView(vm: vm)
                case .location: LocationStepView(vm: vm, onComplete: finish)
                }
            }
            .navigationBarBackButtonHidden()
        }
    }

    private var progressFraction: Double {
        switch vm.step {
        case .name:     return 0.25
        case .avatar:   return 0.50
        case .username: return 0.75
        case .location: return 1.0
        }
    }

    private func finish() {
        guard let user = auth.currentUser else { return }
        Task {
            let success = await vm.completeOnboarding(userId: user.id)
            if success {
                // Refresh user profile so ContentView re-evaluates needsOnboarding
                await auth.refreshCurrentUser()
            }
        }
    }
}

// MARK: - Step 1: Name
private struct NameStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("What's your name?")
                    .font(.largeTitle.bold())
                Text("This is how you'll appear to others.")
                    .foregroundStyle(.secondary)
            }

            TextField("Full name", text: $vm.fullName)
                .textContentType(.name)
                .font(.title3)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let error = vm.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            Spacer()

            Button {
                vm.step = .avatar
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(vm.canAdvanceFromName ? Color.accentColor : Color.secondary.opacity(0.3))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!vm.canAdvanceFromName)
        }
        .padding(24)
    }
}

// MARK: - Step 2: Avatar
private struct AvatarStepView: View {
    @Bindable var vm: OnboardingViewModel
    let userId: UUID?
    @State private var photoItem: PhotosPickerItem?

    // Continue is blocked only if a photo was selected but upload failed
    private var canContinue: Bool {
        if vm.isUploadingAvatar { return false }
        if vm.avatarUploadFailed { return false }
        return true
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Text("Add a profile photo")
                    .font(.largeTitle.bold())
                Text("Help friends recognize you.")
                    .foregroundStyle(.secondary)
            }

            ZStack {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack {
                        if let image = vm.avatarImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .opacity(vm.isUploadingAvatar ? 0.5 : 1)
                        } else {
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 120, height: 120)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                        }

                        if vm.isUploadingAvatar {
                            ProgressView()
                        }

                        if !vm.isUploadingAvatar {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.white)
                                )
                                .offset(x: 40, y: 40)
                        }
                    }
                }
                .onChange(of: photoItem) {
                    Task {
                        if let data = try? await photoItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            vm.avatarImage = uiImage
                            if let userId {
                                await vm.uploadAvatar(userId: userId)
                            }
                        }
                    }
                }
            }

            // Error state
            if vm.avatarUploadFailed, let error = vm.errorMessage {
                VStack(spacing: 8) {
                    Text("Upload failed: \(error)")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Remove photo") {
                        vm.removeAvatar()
                        photoItem = nil
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else if vm.avatarUrl != nil {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Photo uploaded").font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    vm.step = .username
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canContinue ? Color.accentColor : Color.secondary.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canContinue)

                if !vm.avatarUploadFailed {
                    Button("Skip for now") {
                        vm.step = .username
                    }
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                }
            }
        }
        .padding(24)
    }
}

// MARK: - Step 3: Username
private struct UsernameStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Pick a username")
                    .font(.largeTitle.bold())
                Text("3–30 characters, letters, numbers, and underscores only.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("@").foregroundStyle(.secondary)
                    TextField("username", text: $vm.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: vm.username) {
                            vm.onUsernameChanged()
                        }
                }
                .font(.title3)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Availability indicator
                if vm.isCheckingUsername {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Checking...").font(.caption).foregroundStyle(.secondary)
                    }
                } else if let available = vm.usernameAvailable {
                    HStack(spacing: 6) {
                        Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text(available ? "Available" : "Already taken")
                    }
                    .font(.caption)
                    .foregroundStyle(available ? .green : .red)
                } else if !vm.username.isEmpty && !vm.isValidUsername {
                    Text("Username must be 3–30 characters, letters/numbers/underscores only.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    vm.step = .location
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(vm.canAdvanceFromUsername ? Color.accentColor : Color.secondary.opacity(0.3))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!vm.canAdvanceFromUsername)
            }
        }
        .padding(24)
    }
}

// MARK: - Step 3: Location
private struct LocationStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Where are you based?")
                    .font(.largeTitle.bold())
                Text("Used to show nearby activities in the Discovery feed. You can change this later.")
                    .foregroundStyle(.secondary)
            }

            TextField("City or neighborhood (optional)", text: $vm.locationName)
                .font(.title3)
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let error = vm.errorMessage {
                Text(error).foregroundStyle(.red).font(.caption)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onComplete) {
                    Group {
                        if vm.isLoading {
                            ProgressView()
                        } else {
                            Text("Finish setup")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(vm.isLoading)

                Button("Skip for now", action: onComplete)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(24)
    }
}
