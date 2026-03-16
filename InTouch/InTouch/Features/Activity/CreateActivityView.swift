import SwiftUI

struct CreateActivityView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(AppRouter.self) private var router
    @State private var vm = CreateActivityViewModel()

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Title & Description
                Section {
                    TextField("What are you up to?", text: $vm.title, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Add more details (optional)", text: $vm.description, axis: .vertical)
                        .lineLimit(2...6)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Activity")
                }

                // MARK: Category
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(CreateActivityViewModel.Category.allCases) { cat in
                                CategoryChip(
                                    category: cat,
                                    isSelected: vm.category == cat
                                ) {
                                    vm.category = vm.category == cat ? nil : cat
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Category")
                }

                // MARK: Timeframe
                Section {
                    Picker("Timeframe", selection: $vm.timeframe) {
                        ForEach(Activity.Timeframe.allCases, id: \.self) { t in
                            Text(t.displayName).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("When")
                } footer: {
                    Text(timeframeFooter).font(.caption)
                }

                // MARK: Date & Time picker (hidden for Immediate)
                if vm.timeframe != .immediate {
                    Section {
                        DatePicker(
                            "Date & Time",
                            selection: $vm.startsAt,
                            in: Date.now...,
                            displayedComponents: vm.timeframe == .planned
                                ? [.date, .hourAndMinute]
                                : [.date]
                        )
                    } header: {
                        Text(vm.timeframe == .planned ? "Scheduled for" : "Starting around")
                    }
                }

                // MARK: Visibility
                Section {
                    Picker("Who can see this?", selection: $vm.visibility) {
                        ForEach(vm.availableVisibilityOptions, id: \.self) { v in
                            Label(v.displayName, systemImage: visibilityIcon(v)).tag(v)
                        }
                    }
                } header: {
                    Text("Visibility")
                }

                // MARK: Location
                Section {
                    HStack {
                        Image(systemName: "location")
                            .foregroundStyle(.secondary)
                        TextField("Add a location (optional)", text: $vm.locationName)
                    }
                } header: {
                    Text("Location")
                }


            }
            .navigationTitle("New Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        guard let userId = auth.currentUser?.id else { return }
                        Task { @MainActor in
                            await vm.submit(creatorId: userId)
                            if vm.createdActivityId != nil {
                                router.selectedTab = 0
                                vm = CreateActivityViewModel()
                                await vm.fetchUserGroups(userId: userId)
                            }
                        }
                    }
                    .disabled(!vm.canSubmit || vm.isLoading)
                    .overlay {
                        if vm.isLoading { ProgressView().scaleEffect(0.8) }
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .task {
                if let userId = auth.currentUser?.id {
                    await vm.fetchUserGroups(userId: userId)
                }
            }
            // Reset groups visibility if user selects .groups then loses eligibility
            .onChange(of: vm.availableVisibilityOptions) {
                if !vm.availableVisibilityOptions.contains(vm.visibility) {
                    vm.visibility = .friends
                }
            }
        }
    }

    private var timeframeFooter: String {
        switch vm.timeframe {
        case .immediate: return "Happening now — start time set automatically."
        case .planned:   return "Scheduled for a specific date and time."
        case .longterm:  return "An ongoing or open-ended plan."
        }
    }

    private func visibilityIcon(_ v: Activity.Visibility) -> String {
        switch v {
        case .private: return "lock"
        case .friends: return "person.2"
        case .groups:  return "person.3"
        case .public:  return "globe"
        }
    }
}

// MARK: - Category Chip
private struct CategoryChip: View {
    let category: CreateActivityViewModel.Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                Text(category.displayName)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
