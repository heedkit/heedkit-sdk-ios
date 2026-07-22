import Foundation
#if canImport(Security)
import Security
#endif

/// Persists the server-issued anonymous identity token so anonymous end-users keep
/// the same EndUser (and their votes) across launches — including reinstalls, since
/// Keychain items survive uninstall by default. Falls back to UserDefaults when the
/// Keychain is unavailable.
///
/// This replaces the old device-id scheme: the API rejects any `external_id` that
/// isn't HMAC-signed by the host backend, so anonymous continuity comes from
/// replaying the signed token /sdk/init issued — never from a client-invented id.
protocol IdentityTokenStoring {
    func read(workspaceKey: String) -> String?
    func write(_ token: String, workspaceKey: String)
    func clear(workspaceKey: String)
}

struct KeychainIdentityTokenStore: IdentityTokenStoring {
    private let service = "dev.heedkit.sdk"

    private func account(_ workspaceKey: String) -> String { "identity." + workspaceKey }

    func read(workspaceKey: String) -> String? {
        readKeychain(account: account(workspaceKey))
            ?? UserDefaults.standard.string(forKey: account(workspaceKey))
    }

    func write(_ token: String, workspaceKey: String) {
        if !writeKeychain(token, account: account(workspaceKey)) {
            UserDefaults.standard.set(token, forKey: account(workspaceKey))
        }
    }

    func clear(workspaceKey: String) {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(workspaceKey),
        ]
        SecItemDelete(query as CFDictionary)
        #endif
        UserDefaults.standard.removeObject(forKey: account(workspaceKey))
    }

    private func readKeychain(account: String) -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
        #else
        return nil
        #endif
    }

    @discardableResult
    private func writeKeychain(_ value: String, account: String) -> Bool {
        #if canImport(Security)
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
        #else
        return false
        #endif
    }
}


public enum HeedKitError: Error {
    case notInitialized
    case http(Int, String)
    case decoding(Error)
}

public final class HeedKit {
    public static let shared = HeedKit()
    private init() {}

    private var apiUrl: URL = URL(string: "https://api.heedkit.com")!
    private var workspaceKey: String?
    /// Signed replay token from /sdk/init; attached to every later call as
    /// X-HeedKit-Identity. Anonymous tokens are persisted via `identityStore`.
    private(set) public var identity: String?
    var identityStore: IdentityTokenStoring = KeychainIdentityTokenStore() // test seam
    private(set) public var endUserId: String?
    private(set) public var theme: Theme = Theme()
    private(set) public var workspaceName: String = ""
    private(set) public var enabledKinds: [FeatureKind] = []
    private(set) public var kindVisibility: [FeatureKind: Visibility] = [:]
    private(set) public var kindInteractions: [FeatureKind: [Interaction]] = [:]

    /// Interactions enabled by the admin for a given kind, in stable display order.
    public func interactions(for kind: FeatureKind) -> [Interaction] {
        kindInteractions[kind] ?? []
    }

    @discardableResult
    public func initialize(workspaceKey: String,
                           apiUrl: String = "https://api.heedkit.com",
                           user: EndUser = EndUser()) async throws -> Theme {
        self.workspaceKey = workspaceKey
        if let u = URL(string: apiUrl) { self.apiUrl = u }

        var body: [String: Any] = [
            "email": user.email ?? NSNull(),
            "name": user.name ?? NSNull(),
            "avatar_url": user.avatarUrl ?? NSNull(),
            "platform": user.platform ?? "ios",
        ]
        if let externalId = user.externalId {
            // A named identity must be vouched for by the host app's BACKEND: the API
            // rejects an external_id without its HMAC (401 invalid_user_signature).
            body["external_id"] = externalId
            body["user_hash"] = user.userHash ?? NSNull()
            // A named identity supersedes any persisted anonymous one.
            identityStore.clear(workspaceKey: workspaceKey)
            self.identity = nil
        } else {
            // Anonymous: replay the persisted token so the backend re-selects the same
            // end-user (votes survive relaunches) while still returning fresh config.
            // A stale token just yields a fresh anonymous end-user.
            self.identity = identityStore.read(workspaceKey: workspaceKey)
        }

        let res: InitResult = try await request(path: "/sdk/init", method: "POST", body: body)
        self.identity = res.identity
        if user.externalId == nil, let token = res.identity {
            identityStore.write(token, workspaceKey: workspaceKey)
        }
        self.endUserId = res.end_user_id
        self.theme = res.theme
        self.workspaceName = res.workspaceName
        self.enabledKinds = res.enabledKinds.compactMap(FeatureKind.init(rawValue:))

        var vMap: [FeatureKind: Visibility] = [:]
        for (k, v) in res.kindVisibility ?? [:] {
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
        guard endUserId != nil else { throw HeedKitError.notInitialized }
        // The caller is identified by the X-HeedKit-Identity header, not a param.
        var q = "?sort=\(sort)"
        if let s = status { q += "&status=\(s)" }
        if let k = kind { q += "&kind=\(k.rawValue)" }
        // Rails returns { features, next_cursor }.
        let result: FeaturesResult = try await request(path: "/sdk/features\(q)", method: "GET")
        return result.features
    }

    public func submit(
        title: String,
        description: String = "",
        tag: String? = nil,
        kind: FeatureKind = .featureRequest
    ) async throws -> Feature {
        guard endUserId != nil else { throw HeedKitError.notInitialized }
        return try await request(
            path: "/sdk/features", method: "POST",
            body: [
                "title": title,
                "description": description,
                "tag": tag ?? NSNull(),
                "kind": kind.rawValue,
            ]
        )
    }

    public func vote(featureId: String) async throws -> (voted: Bool, count: Int) {
        guard endUserId != nil else { throw HeedKitError.notInitialized }
        let r: VoteResult = try await request(
            path: "/sdk/features/\(featureId)/vote", method: "POST",
            body: [:]
        )
        return (r.voted, r.vote_count)
    }

    public func listComments(featureId: String) async throws -> [Comment] {
        // Rails returns { comments: [...] }.
        let result: CommentsResult = try await request(path: "/sdk/features/\(featureId)/comments", method: "GET")
        return result.comments
    }

    public func comment(featureId: String, body: String) async throws -> Comment {
        guard endUserId != nil else { throw HeedKitError.notInitialized }
        return try await request(
            path: "/sdk/features/\(featureId)/comments", method: "POST",
            body: ["body": body]
        )
    }

    // MARK: - HTTP

    private func request<T: Decodable>(path: String, method: String,
                                       body: [String: Any]? = nil) async throws -> T {
        guard let workspaceKey = workspaceKey else { throw HeedKitError.notInitialized }
        guard let url = URL(string: apiUrl.absoluteString + path) else {
            throw HeedKitError.http(0, "bad url")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(workspaceKey, forHTTPHeaderField: "X-Workspace-Key")
        if let identity = identity {
            req.setValue(identity, forHTTPHeaderField: "X-HeedKit-Identity")
        }
        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw HeedKitError.http(code, msg)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw HeedKitError.decoding(error)
        }
    }
}
