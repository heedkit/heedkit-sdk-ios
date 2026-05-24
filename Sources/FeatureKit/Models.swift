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

/// Whether items are visible beyond the submitter + the project team.
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

public struct Theme: Codable {
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

public struct Feature: Codable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let status: String
    /// Raw string for forward compatibility with future server-added kinds.
    /// Use `featureKind` for the typed enum (falls back to `.other` if unknown).
    public let kind: String
    /// `"public"` or `"private"`. Use `visibility` for the typed enum.
    public let visibility: String?
    public let on_roadmap: Bool?
    public let tag: String?
    public var vote_count: Int
    public var voted: Bool
    public let platform: String?
    public let author_name: String?
    public let created_at: String

    public var featureKind: FeatureKind {
        FeatureKind(rawValue: kind) ?? .other
    }

    public var visibilityEnum: Visibility {
        Visibility(rawValue: visibility ?? "public") ?? .publicVisibility
    }

    public var onRoadmap: Bool { on_roadmap ?? false }
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
    let enabled_kinds: [String]
    /// Default visibility per kind for new submissions: `{ "feature_request": "public", ... }`.
    let kind_visibility: [String: String]?
    /// Enabled interactions per kind: `{ "feature_request": { "upvote": true, "downvote": false }, ... }`.
    let kind_interactions: [String: [String: Bool]]?
    let end_user_id: String

    /// Which interactions the admin has enabled for a given kind, in stable order.
    func interactions(for kind: FeatureKind) -> [Interaction] {
        let row = kind_interactions?[kind.rawValue] ?? [:]
        return [.upvote, .downvote, .plusOne, .like].filter { row[$0.rawValue] == true }
    }
}

struct VoteResult: Codable {
    let voted: Bool
    let vote_count: Int
}
