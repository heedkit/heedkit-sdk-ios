import Foundation
#if canImport(Security)
import Security
#endif

/// Persists a stable per-device id in the Keychain so anonymous end-users
/// (no externalId passed to `initialize`) keep the same EndUser across
/// launches — including app reinstalls on iOS, since Keychain items survive
/// uninstall by default. Falls back to UserDefaults if Keychain is unavailable.
enum DeviceId {
    private static let service = "dev.featurekit.sdk"
    private static let account = "device_id"

    static func get() -> String {
        if let existing = readKeychain() ?? UserDefaults.standard.string(forKey: account) {
            return existing
        }
        let fresh = "dev_" + UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        if !writeKeychain(fresh) {
            UserDefaults.standard.set(fresh, forKey: account)
        }
        return fresh
    }

    private static func readKeychain() -> String? {
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
    private static func writeKeychain(_ value: String) -> Bool {
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


public enum FeatureKitError: Error {
    case notInitialized
    case http(Int, String)
    case decoding(Error)
}

public final class FeatureKit {
    public static let shared = FeatureKit()
    private init() {}

    private var apiUrl: URL = URL(string: "https://api.featurekit.dev")!
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
                           apiUrl: String = "https://api.featurekit.dev",
                           user: EndUser = EndUser()) async throws -> Theme {
        self.projectKey = projectKey
        if let u = URL(string: apiUrl) { self.apiUrl = u }
        // Fall back to the Keychain-persisted device id when no externalId was
        // passed — keeps the same EndUser across app launches for anonymous users.
        let effectiveExternalId: Any = user.externalId ?? DeviceId.get()
        let res: InitResult = try await request(
            path: "/sdk/init", method: "POST",
            body: [
                "external_id": effectiveExternalId,
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
        guard let eu = endUserId else { throw FeatureKitError.notInitialized }
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
        guard let eu = endUserId else { throw FeatureKitError.notInitialized }
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
        guard let eu = endUserId else { throw FeatureKitError.notInitialized }
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
        guard let eu = endUserId else { throw FeatureKitError.notInitialized }
        return try await request(
            path: "/sdk/features/\(featureId)/comments", method: "POST",
            body: ["end_user_id": eu, "body": body]
        )
    }

    // MARK: - HTTP

    private func request<T: Decodable>(path: String, method: String,
                                       body: [String: Any]? = nil) async throws -> T {
        guard let projectKey = projectKey else { throw FeatureKitError.notInitialized }
        guard let url = URL(string: apiUrl.absoluteString + path) else {
            throw FeatureKitError.http(0, "bad url")
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
            throw FeatureKitError.http(code, msg)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw FeatureKitError.decoding(error)
        }
    }
}

