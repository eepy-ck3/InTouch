import Foundation
import Observation
import Supabase

@Observable
final class CreateActivityViewModel {
    var title = ""
    var description = ""
    var category: Category? = nil
    var timeframe: Activity.Timeframe = .planned
    var visibility: Activity.Visibility = .friends
    var locationName = ""
    var startsAt: Date = .now

    var isLoading = false
    var errorMessage: String?
    var createdActivityId: UUID? = nil

    // Groups the user belongs to — determines if .groups visibility is available
    var userGroups: [UserGroup] = []

    var canSubmit: Bool {
        title.trimmingCharacters(in: .whitespaces).count >= 2
    }

    var availableVisibilityOptions: [Activity.Visibility] {
        Activity.Visibility.allCases.filter { v in
            if v == .groups { return !userGroups.isEmpty }
            return true
        }
    }

    enum Category: String, CaseIterable, Identifiable {
        case food, activity, hangout, travel, sports, gaming, other
        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .food:     return "fork.knife"
            case .activity: return "figure.run"
            case .hangout:  return "person.2"
            case .travel:   return "airplane"
            case .sports:   return "sportscourt"
            case .gaming:   return "gamecontroller"
            case .other:    return "ellipsis.circle"
            }
        }
    }

    struct UserGroup: Codable, Identifiable {
        let id: UUID
        let name: String
    }

    // MARK: - Fetch user's groups
    func fetchUserGroups(userId: UUID) async {
        do {
            struct GroupMemberRow: Codable {
                let group_id: UUID
                let groups: UserGroup
            }
            let rows: [GroupMemberRow] = try await supabase
                .from("group_members")
                .select("group_id, groups(id, name)")
                .eq("user_id", value: userId)
                .execute()
                .value
            userGroups = rows.map { $0.groups }
        } catch {
            // Non-fatal — groups visibility option just won't appear
        }
    }

    // MARK: - Submit
    func submit(creatorId: UUID) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Immediate activities always use current time
        let activityStartsAt = timeframe == .immediate ? Date.now : startsAt

        struct ActivityInsert: Encodable {
            let creator_id: UUID
            let title: String
            let description: String?
            let category: String?
            let timeframe: String
            let visibility: String
            let location_name: String?
            let starts_at: Date
        }

        let insert = ActivityInsert(
            creator_id: creatorId,
            title: title.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
            category: category?.rawValue,
            timeframe: timeframe.rawValue,
            visibility: visibility.rawValue,
            location_name: locationName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : locationName.trimmingCharacters(in: .whitespaces),
            starts_at: activityStartsAt
        )

        do {
            struct InsertedRow: Codable { let id: UUID }
            let rows: [InsertedRow] = try await supabase
                .from("activities")
                .insert(insert)
                .select("id")
                .execute()
                .value
            createdActivityId = rows.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
