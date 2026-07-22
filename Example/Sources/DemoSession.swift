import Foundation
import HeedKit

/// Owns the whole demo flow against the Rails `/sdk` backend so the views stay
/// thin. Every step here maps to one HeedKit call (which in turn hits one
/// `/sdk/*` endpoint):
///
///   start()            -> initialize()  -> POST /sdk/init
///   reload()           -> list()        -> GET  /sdk/features
///   submit(...)        -> submit()      -> POST /sdk/features
///   toggleVote(...)    -> vote()        -> POST /sdk/features/:id/vote
///   loadComments(...)  -> listComments()-> GET  /sdk/features/:id/comments
///   addComment(...)    -> comment()     -> POST /sdk/features/:id/comments
///
/// The `X-Workspace-Key` header and `end_user_id` plumbing are handled inside the
/// SDK — the example never has to build a URLRequest by hand.
@MainActor
final class DemoSession: ObservableObject {
    enum Phase: Equatable {
        case idle
        case initializing
        case ready
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var features: [Feature] = []
    @Published var loadingFeatures = false
    @Published var lastAction: String?
    @Published var errorMessage: String?

    private let hub = HeedKit.shared

    var workspaceName: String { hub.workspaceName }
    var endUserId: String? { hub.endUserId }
    var enabledKinds: [FeatureKind] {
        hub.enabledKinds.isEmpty ? FeatureKind.allCases : hub.enabledKinds
    }

    // MARK: 1) configure + 2) init / identify the end-user

    func start() async {
        guard phase == .idle else { return }
        guard !Config.keyIsPlaceholder else {
            phase = .failed("Set Config.workspaceKey (or HEEDKIT_WORKSPACE_KEY) to a real key.")
            return
        }
        phase = .initializing
        do {
            try await hub.initialize(
                workspaceKey: Config.workspaceKey,
                apiUrl: Config.apiUrl,
                // A stable externalId keeps this demo user across launches so
                // their votes/submissions persist. Drop it to go anonymous
                // (the SDK then uses a Keychain-backed device id).
                user: .init(
                    externalId: "ios-demo-user",
                    email: "demo@heedkit.com",
                    name: "iOS Demo User",
                    platform: "ios"
                )
            )
            phase = .ready
            await reload()
        } catch {
            phase = .failed(describe(error))
        }
    }

    // MARK: 3) fetch + display features

    func reload(kind: FeatureKind? = nil, sort: String = "top") async {
        guard phase == .ready else { return }
        loadingFeatures = true
        errorMessage = nil
        defer { loadingFeatures = false }
        do {
            features = try await hub.list(kind: kind, sort: sort)
        } catch {
            errorMessage = "Load failed: \(describe(error))"
        }
    }

    // MARK: 4) submit a new feature

    @discardableResult
    func submit(title: String, description: String, kind: FeatureKind) async -> Feature? {
        guard phase == .ready, !title.isEmpty else { return nil }
        do {
            let created = try await hub.submit(title: title, description: description, kind: kind)
            lastAction = "Submitted “\(created.title)”"
            await reload()
            return created
        } catch {
            errorMessage = "Submit failed: \(describe(error))"
            return nil
        }
    }

    // MARK: 5) upvote (toggle)

    func toggleVote(_ feature: Feature) async {
        guard phase == .ready else { return }
        do {
            let result = try await hub.vote(featureId: feature.id)
            if let i = features.firstIndex(where: { $0.id == feature.id }) {
                features[i].voted = result.voted
                features[i].vote_count = result.count
            }
            lastAction = result.voted ? "Upvoted “\(feature.title)”" : "Removed vote on “\(feature.title)”"
        } catch {
            errorMessage = "Vote failed: \(describe(error))"
        }
    }

    // MARK: 6) comments

    func loadComments(for feature: Feature) async -> [Comment] {
        do {
            return try await hub.listComments(featureId: feature.id)
        } catch {
            errorMessage = "Comments failed: \(describe(error))"
            return []
        }
    }

    @discardableResult
    func addComment(to feature: Feature, body: String) async -> Comment? {
        guard !body.isEmpty else { return nil }
        do {
            let c = try await hub.comment(featureId: feature.id, body: body)
            lastAction = "Commented on “\(feature.title)”"
            return c
        } catch {
            errorMessage = "Comment failed: \(describe(error))"
            return nil
        }
    }

    // MARK: - Errors

    /// Turn HeedKitError into something readable in the demo UI.
    private func describe(_ error: Error) -> String {
        switch error {
        case HeedKitError.notInitialized:
            return "SDK not initialized (check the workspace key)."
        case HeedKitError.http(let code, let msg):
            return "HTTP \(code): \(msg.isEmpty ? "request rejected" : msg)"
        case HeedKitError.decoding:
            return "Could not decode the response."
        default:
            return error.localizedDescription
        }
    }
}
