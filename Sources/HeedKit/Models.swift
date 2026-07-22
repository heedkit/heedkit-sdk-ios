import Foundation

public struct EndUser: Codable {
    public var externalId: String?
    public var email: String?
    public var name: String?
    public var avatarUrl: String?
    public var platform: String?
    /// HMAC_SHA256(serverSecret, externalId) as lowercase hex, computed on YOUR
    /// backend. Required whenever `externalId` is set — the API rejects unsigned ids
    /// with 401 invalid_user_signature. Never compute this in the app; the workspace
    /// secret must not ship in a binary.
    public var userHash: String?

    public init(externalId: String? = nil, email: String? = nil, name: String? = nil,
                avatarUrl: String? = nil, platform: String? = "ios",
                userHash: String? = nil) {
        self.externalId = externalId
        self.email = email
        self.name = name
        self.avatarUrl = avatarUrl
        self.platform = platform
        self.userHash = userHash
    }
}

/// Whether items are visible beyond the submitter + the workspace team.
public enum Visibility: String, Codable, CaseIterable {
    case publicVisibility  = "public"
    case privateVisibility = "private"
}

/// End-user interaction the SDK may render on an item. Admins enable/disable
/// these per kind in the console; widgets should only render enabled ones.
public enum Interaction: String, Codable, CaseIterable {
    case upvote
    case downvote
    case plusOne = "plus_one"
    case like
}

/// Tabs vs single mixed feed for the widget layout.
public enum GroupMode: String, Codable {
    case tabs
    case list
}

public struct Theme: Decodable {
    public var primary: String?
    public var radius: Int?
    /// `light`, `dark`, or `system` (follow OS preference at render time).
    public var mode: String?
    public var font_family: String?
    /// `"sm"`, `"md"`, or `"lg"`.
    public var font_size: String?
    public var group_mode: String?
    /// Per-kind toggle: when false, render the action icon without a count.
    public var show_counts: [String: Bool]?

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case primary, radius, mode, font_family, fontFamily, font_size, group_mode, show_counts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        primary = try? c.decode(String.self, forKey: .primary)
        mode = try? c.decode(String.self, forKey: .mode)
        // The backend may send `fontFamily` (camelCase) instead of `font_family`.
        font_family = (try? c.decode(String.self, forKey: .font_family)) ?? (try? c.decode(String.self, forKey: .fontFamily))
        font_size = try? c.decode(String.self, forKey: .font_size)
        group_mode = try? c.decode(String.self, forKey: .group_mode)
        show_counts = try? c.decode([String: Bool].self, forKey: .show_counts)
        // `radius` may be an Int (px) or a CSS string like "12px" / "0.75rem".
        if let i = try? c.decode(Int.self, forKey: .radius) {
            radius = i
        } else if let s = try? c.decode(String.self, forKey: .radius) {
            radius = Double(s.prefix { $0.isNumber || $0 == "." }).map { Int($0.rounded()) }
        } else {
            radius = nil
        }
    }

    public var groupMode: GroupMode {
        GroupMode(rawValue: group_mode ?? "tabs") ?? .tabs
    }

    /// Whether to display the vote/like/+1 count for a given kind.
    /// Defaults to true when unset — admin opts out of counts per kind.
    public func showCount(for kind: FeatureKind) -> Bool {
        show_counts?[kind.rawValue] ?? true
    }
}

/// What a submission is about. Defaults to `.featureRequest` when omitted.
public enum FeatureKind: String, Codable, CaseIterable {
    case featureRequest = "feature_request"
    case bugReport      = "bug_report"
    case improvement
    case appreciation
    case other

    /// User-facing label for picker UIs.
    public var label: String {
        switch self {
        case .featureRequest: return "Feature Request"
        case .bugReport:      return "Bug Report"
        case .improvement:    return "Improvement"
        case .appreciation:   return "Appreciation"
        case .other:          return "Other"
        }
    }

    /// Placeholder copy that fits the kind in a submit form.
    public var titlePlaceholder: String {
        switch self {
        case .featureRequest: return "What should we build?"
        case .bugReport:      return "What's broken?"
        case .improvement:    return "What could be better?"
        case .appreciation:   return "What did you love?"
        case .other:          return "Tell us anything"
        }
    }
}

/// Decode an `id` that may arrive as a JSON string (legacy) or number (Rails
/// integer primary key) — always normalized to a String.
func decodeFlexibleId<K: CodingKey>(_ c: KeyedDecodingContainer<K>, forKey key: K) -> String {
    if let s = try? c.decode(String.self, forKey: key) { return s }
    if let i = try? c.decode(Int64.self, forKey: key) { return String(i) }
    return ""
}

public struct Feature: Decodable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let status: String
    /// Raw string for forward compatibility with future server-added kinds.
    /// Use `featureKind` for the typed enum (falls back to `.other` if unknown).
    public let kind: String
    /// `"public"` or `"private"`. Use `visibilityEnum` for the typed enum.
    public let visibility: String?
    public let on_roadmap: Bool?
    public let tag: String?
    public var vote_count: Int
    public var voted: Bool
    public let platform: String?
    public let author_name: String?
    public let created_at: String

    public var featureKind: FeatureKind { FeatureKind(rawValue: kind) ?? .other }
    public var visibilityEnum: Visibility { Visibility(rawValue: visibility ?? "public") ?? .publicVisibility }
    public var onRoadmap: Bool { on_roadmap ?? false }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, status, kind, visibility, on_roadmap, tag
        case vote_count, voted, platform, author, author_name, created_at
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // The Rails backend uses integer ids, exposes the author display name as
        // `author`, and omits null fields — so decode defensively.
        id = decodeFlexibleId(c, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        status = (try? c.decode(String.self, forKey: .status)) ?? "open"
        kind = (try? c.decode(String.self, forKey: .kind)) ?? "feature_request"
        visibility = try? c.decode(String.self, forKey: .visibility)
        on_roadmap = try? c.decode(Bool.self, forKey: .on_roadmap)
        tag = try? c.decode(String.self, forKey: .tag)
        vote_count = (try? c.decode(Int.self, forKey: .vote_count)) ?? 0
        voted = (try? c.decode(Bool.self, forKey: .voted)) ?? false
        platform = try? c.decode(String.self, forKey: .platform)
        author_name = (try? c.decode(String.self, forKey: .author_name)) ?? (try? c.decode(String.self, forKey: .author))
        created_at = (try? c.decode(String.self, forKey: .created_at)) ?? ""
    }
}

public struct Comment: Decodable, Identifiable {
    public let id: String
    public let body: String
    public let author_name: String?
    public let is_internal: Bool
    public let created_at: String

    private enum CodingKeys: String, CodingKey {
        case id, body, author, author_name, is_internal, created_at
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = decodeFlexibleId(c, forKey: .id)
        body = (try? c.decode(String.self, forKey: .body)) ?? ""
        author_name = (try? c.decode(String.self, forKey: .author_name)) ?? (try? c.decode(String.self, forKey: .author))
        // The SDK endpoint only ever returns public comments; the field may be absent.
        is_internal = (try? c.decode(Bool.self, forKey: .is_internal)) ?? false
        created_at = (try? c.decode(String.self, forKey: .created_at)) ?? ""
    }
}

/// Workspace configuration returned by /sdk/init (nested under `workspace`).
struct WorkspaceConfig: Decodable {
    let name: String?
    let theme: Theme
    let enabled_kinds: [String]
    let kind_visibility: [String: String]?
    let kind_interactions: [String: [String: Bool]]?
    let is_public_roadmap: Bool?
}

struct InitResult: Decodable {
    let end_user_id: String
    /// Signed replay token; sent as X-HeedKit-Identity on every later call.
    let identity: String?
    let workspace: WorkspaceConfig

    private enum CodingKeys: String, CodingKey { case end_user_id, identity, workspace }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Rails returns an integer end_user_id; normalize to String.
        end_user_id = decodeFlexibleId(c, forKey: .end_user_id)
        identity = try? c.decode(String.self, forKey: .identity)
        workspace = try c.decode(WorkspaceConfig.self, forKey: .workspace)
    }

    var theme: Theme { workspace.theme }
    var workspaceName: String { workspace.name ?? "" }
    var enabledKinds: [String] { workspace.enabled_kinds }
    var kindVisibility: [String: String]? { workspace.kind_visibility }

    /// Which interactions the admin has enabled for a given kind, in stable order.
    func interactions(for kind: FeatureKind) -> [Interaction] {
        let row = workspace.kind_interactions?[kind.rawValue] ?? [:]
        return [.upvote, .downvote, .plusOne, .like].filter { row[$0.rawValue] == true }
    }
}

/// GET /sdk/features → `{ features: [...], next_cursor }`.
struct FeaturesResult: Decodable {
    let features: [Feature]
    let next_cursor: String?
}

/// GET /sdk/features/:id/comments → `{ comments: [...] }`.
struct CommentsResult: Decodable {
    let comments: [Comment]
}

struct VoteResult: Codable {
    let voted: Bool
    let vote_count: Int
}
