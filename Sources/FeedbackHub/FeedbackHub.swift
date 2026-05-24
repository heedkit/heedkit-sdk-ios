import Foundation

public enum FeedbackHubError: Error {
    case notInitialized
    case http(Int, String)
    case decoding(Error)
}

public final class FeedbackHub {
    public static let shared = FeedbackHub()
    private init() {}

    private var apiUrl: URL = URL(string: "https://api.feedbackhub.dev")!
    private var projectKey: String?
    private(set) public var endUserId: String?
    private(set) public var theme: Theme = Theme()
    private(set) public var projectName: String = ""
    private(set) public var enabledKinds: [FeatureKind] = []
    private(set) public var kindVisibility: [FeatureKind: Visibility] = [:]
    private(set) public var kindInteractions: [FeatureKind: [Interaction]] = [:]

    /// Interactions enabled by the admin for a given kind, in stable display order.
    public func interactions(for kind: FeatureKind) -> [Interaction] {
        kindInteractions[kind] ?? []
    }

    @discardableResult
    public func initialize(projectKey: String,
                           apiUrl: String = "https://api.feedbackhub.dev",
                           user: EndUser = EndUser()) async throws -> Theme {
        self.projectKey = projectKey
        if let u = URL(string: apiUrl) { self.apiUrl = u }
        let res: InitResult = try await request(
            path: "/sdk/init", method: "POST",
            body: [
                "external_id": user.externalId ?? NSNull(),
                "email": user.email ?? NSNull(),
                "name": user.name ?? NSNull(),
                "avatar_url": user.avatarUrl ?? NSNull(),
                "platform": user.platform ?? "ios",
            ]
        )
        self.endUserId = res.end_user_id
        self.theme = res.theme
        self.projectName = res.project_name
        self.enabledKinds = res.enabled_kinds.compactMap(FeatureKind.init(rawValue:))

        var vMap: [FeatureKind: Visibility] = [:]
        for (k, v) in res.kind_visibility ?? [:] {
            if let kind = FeatureKind(rawValue: k), let vis = Visibility(rawValue: v) {
                vMap[kind] = vis
            }
        }
        self.kindVisibility = vMap

        var iMap: [FeatureKind: [Interaction]] = [:]
        for kind in FeatureKind.allCases {
            iMap[kind] = res.interactions(for: kind)
        }
        self.kindInteractions = iMap

        return res.theme
    }

    public func list(
        status: String? = nil,
        kind: FeatureKind? = nil,
        sort: String = "top"
    ) async throws -> [Feature] {
        guard let eu = endUserId else { throw FeedbackHubError.notInitialized }
        var q = "?end_user_id=\(eu)&sort=\(sort)"
        if let s = status { q += "&status=\(s)" }
        if let k = kind { q += "&kind=\(k.rawValue)" }
        return try await request(path: "/sdk/features\(q)", method: "GET")
    }

    public func submit(
        title: String,
        description: String = "",
        tag: String? = nil,
        kind: FeatureKind = .featureRequest
    ) async throws -> Feature {
        guard let eu = endUserId else { throw FeedbackHubError.notInitialized }
        return try await request(
            path: "/sdk/features", method: "POST",
            body: [
                "end_user_id": eu,
                "title": title,
                "description": description,
                "tag": tag ?? NSNull(),
                "kind": kind.rawValue,
            ]
        )
    }

    public func vote(featureId: String) async throws -> (voted: Bool, count: Int) {
        guard let eu = endUserId else { throw FeedbackHubError.notInitialized }
        let r: VoteResult = try await request(
            path: "/sdk/features/\(featureId)/vote", method: "POST",
            body: ["end_user_id": eu]
        )
        return (r.voted, r.vote_count)
    }

    public func listComments(featureId: String) async throws -> [Comment] {
        return try await request(path: "/sdk/features/\(featureId)/comments", method: "GET")
    }

    public func comment(featureId: String, body: String) async throws -> Comment {
        guard let eu = endUserId else { throw FeedbackHubError.notInitialized }
        return try await request(
            path: "/sdk/features/\(featureId)/comments", method: "POST",
            body: ["end_user_id": eu, "body": body]
        )
    }

    // MARK: - HTTP

    private func request<T: Decodable>(path: String, method: String,
                                       body: [String: Any]? = nil) async throws -> T {
        guard let projectKey = projectKey else { throw FeedbackHubError.notInitialized }
        guard let url = URL(string: apiUrl.absoluteString + path) else {
            throw FeedbackHubError.http(0, "bad url")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(projectKey, forHTTPHeaderField: "X-Project-Key")
        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw FeedbackHubError.http(code, msg)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw FeedbackHubError.decoding(error)
        }
    }
}

