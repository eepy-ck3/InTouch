import Foundation

// MARK: - User
struct AppUser: Codable, Identifiable {
    let id: UUID
    var username: String
    var fullName: String
    var avatarUrl: String?
    var primaryLocationLat: Double?
    var primaryLocationLng: Double?
    var primaryLocationName: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case primaryLocationLat = "primary_location_lat"
        case primaryLocationLng = "primary_location_lng"
        case primaryLocationName = "primary_location_name"
        case createdAt = "created_at"
    }
}

// MARK: - Activity
struct Activity: Codable, Identifiable {
    let id: UUID
    let creatorId: UUID
    var title: String
    var description: String?
    var category: String?
    var timeframe: Timeframe
    var visibility: Visibility
    var locationLat: Double?
    var locationLng: Double?
    var locationName: String?
    var status: Status
    var startsAt: Date?
    var expiresAt: Date?
    let createdAt: Date

    // Joined relation (optional, populated via select)
    var creator: AppUser?

    enum Timeframe: String, Codable, CaseIterable {
        case immediate, planned, longterm
        var displayName: String {
            switch self {
            case .immediate: return "Immediate"
            case .planned:   return "Planned"
            case .longterm:  return "Long-term"
            }
        }
    }

    enum Visibility: String, Codable, CaseIterable {
        case `private`, friends, groups, `public`
        var displayName: String {
            switch self {
            case .private: return "Private"
            case .friends: return "Friends"
            case .groups:  return "Groups"
            case .public:  return "Public"
            }
        }
    }

    enum Status: String, Codable {
        case active, expired
    }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case title
        case description
        case category
        case timeframe
        case visibility
        case locationLat = "location_lat"
        case locationLng = "location_lng"
        case locationName = "location_name"
        case status
        case startsAt = "starts_at"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case creator
    }
}

// MARK: - Activity Join
struct ActivityJoin: Codable, Identifiable {
    let id: UUID
    let activityId: UUID
    let userId: UUID
    let joinedAt: Date
    var user: AppUser?

    enum CodingKeys: String, CodingKey {
        case id
        case activityId = "activity_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case user
    }
}

// MARK: - Activity Comment
struct ActivityComment: Codable, Identifiable {
    let id: UUID
    let activityId: UUID
    let userId: UUID
    var messageType: MessageType
    var body: String?
    var mediaUrl: String?
    var metadata: [String: AnyCodable]?
    let createdAt: Date
    var user: AppUser?

    enum MessageType: String, Codable {
        case text, image, video, location, link, reaction
    }

    enum CodingKeys: String, CodingKey {
        case id
        case activityId = "activity_id"
        case userId = "user_id"
        case messageType = "message_type"
        case body
        case mediaUrl = "media_url"
        case metadata
        case createdAt = "created_at"
        case user
    }
}

// MARK: - Notification
struct AppNotification: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let type: String
    let payload: [String: AnyCodable]?
    let activityId: UUID?
    var readAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case payload
        case activityId = "activity_id"
        case readAt = "read_at"
        case createdAt = "created_at"
    }
}

// MARK: - Friendship
struct Friendship: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let friendId: UUID
    var status: FriendshipStatus
    let createdAt: Date

    enum FriendshipStatus: String, Codable {
        case pending, accepted
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case friendId = "friend_id"
        case status
        case createdAt = "created_at"
    }
}

// MARK: - AnyCodable (for jsonb fields like metadata/payload)
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let string = try? container.decode(String.self) { value = string }
        else if let array = try? container.decode([AnyCodable].self) { value = array.map { $0.value } }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict.mapValues { $0.value } }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int:       try container.encode(int)
        case let double as Double: try container.encode(double)
        case let bool as Bool:     try container.encode(bool)
        case let string as String: try container.encode(string)
        default:                   try container.encodeNil()
        }
    }
}
