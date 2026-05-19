import Foundation

public struct EndUser: Codable {
    public var externalId: String?
    public var email: String?
    public var name: String?
    public var avatarUrl: String?
    public var platform: String?

    public init(externalId: String? = nil, email: String? = nil, name: String? = nil,
                avatarUrl: String? = nil, platform: String? = "ios") {
        self.externalId = externalId
        self.email = email
        self.name = name
        self.avatarUrl = avatarUrl
        self.platform = platform
    }
}

public struct Theme: Codable {
    public var primary: String?
    public var radius: Int?
    public var mode: String?
}

public struct Feature: Codable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let status: String
    public let tag: String?
    public var vote_count: Int
    public var voted: Bool
    public let platform: String?
    public let author_name: String?
    public let created_at: String
}

public struct Comment: Codable, Identifiable {
    public let id: String
    public let body: String
    public let author_name: String?
    public let is_internal: Bool
    public let created_at: String
}

struct InitResult: Codable {
    let project_id: String
    let project_name: String
    let theme: Theme
    let end_user_id: String
}

struct VoteResult: Codable {
    let voted: Bool
    let vote_count: Int
}
