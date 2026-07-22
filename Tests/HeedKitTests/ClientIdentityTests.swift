import XCTest
@testable import HeedKit

/// Intercepts URLSession.shared traffic so the client's wire behavior (bodies,
/// headers) can be asserted without a network.
final class StubURLProtocol: URLProtocol {
    struct Captured {
        let url: URL
        let method: String
        let headers: [String: String]
        let body: [String: Any]
    }

    nonisolated(unsafe) static var captured: [Captured] = []
    nonisolated(unsafe) static var responseBody: String = "{}"

    static func reset(responseBody: String) {
        captured = []
        self.responseBody = responseBody
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let bodyData = request.httpBody ?? request.httpBodyStream.map { stream -> Data in
            stream.open()
            defer { stream.close() }
            var data = Data()
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            return data
        } ?? Data()
        let json = (try? JSONSerialization.jsonObject(with: bodyData)) as? [String: Any] ?? [:]
        Self.captured.append(Captured(
            url: request.url!,
            method: request.httpMethod ?? "",
            headers: request.allHTTPHeaderFields ?? [:],
            body: json
        ))
        let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(Self.responseBody.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class InMemoryIdentityStore: IdentityTokenStoring {
    var tokens: [String: String] = [:]
    func read(workspaceKey: String) -> String? { tokens[workspaceKey] }
    func write(_ token: String, workspaceKey: String) { tokens[workspaceKey] = token }
    func clear(workspaceKey: String) { tokens.removeValue(forKey: workspaceKey) }
}

final class ClientIdentityTests: XCTestCase {
    static let initJSON = """
    { "end_user_id": 7, "identity": "idtok-1",
      "workspace": { "name": "T", "theme": {}, "enabled_kinds": ["feature_request"],
                   "kind_visibility": {}, "kind_interactions": {} } }
    """

    var store = InMemoryIdentityStore()

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(StubURLProtocol.self)
        StubURLProtocol.reset(responseBody: Self.initJSON)
        store = InMemoryIdentityStore()
        HeedKit.shared.identityStore = store
    }

    override func tearDown() {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        HeedKit.shared.identityStore = KeychainIdentityTokenStore()
        super.tearDown()
    }

    func testIdentifiedInitSendsExternalIdAndUserHash() async throws {
        _ = try await HeedKit.shared.initialize(
            workspaceKey: "fk_t", apiUrl: "https://stub.test",
            user: EndUser(externalId: "u-1", email: "a@b.c", userHash: "abc123")
        )
        let call = StubURLProtocol.captured[0]
        XCTAssertEqual(call.body["external_id"] as? String, "u-1")
        XCTAssertEqual(call.body["user_hash"] as? String, "abc123")
        XCTAssertEqual(call.headers["X-Workspace-Key"], "fk_t")
        XCTAssertNil(call.headers["X-HeedKit-Identity"], "no stale token on an identified init")
    }

    func testAnonymousInitOmitsExternalIdAndPersistsToken() async throws {
        _ = try await HeedKit.shared.initialize(workspaceKey: "fk_t", apiUrl: "https://stub.test")
        let call = StubURLProtocol.captured[0]
        XCTAssertNil(call.body["external_id"], "unsigned external ids are rejected by the API")
        XCTAssertNil(call.body["user_hash"])
        XCTAssertEqual(store.tokens["fk_t"], "idtok-1", "anonymous token persisted for the next launch")
    }

    func testAnonymousReinitReplaysPersistedToken() async throws {
        store.tokens["fk_t"] = "idtok-old"
        _ = try await HeedKit.shared.initialize(workspaceKey: "fk_t", apiUrl: "https://stub.test")
        let call = StubURLProtocol.captured[0]
        XCTAssertEqual(call.headers["X-HeedKit-Identity"], "idtok-old")
        XCTAssertEqual(store.tokens["fk_t"], "idtok-1", "refreshed token replaces the old one")
    }

    func testIdentifiedInitClearsPersistedAnonymousToken() async throws {
        store.tokens["fk_t"] = "idtok-old"
        _ = try await HeedKit.shared.initialize(
            workspaceKey: "fk_t", apiUrl: "https://stub.test",
            user: EndUser(externalId: "u-1", userHash: "abc123")
        )
        XCTAssertNil(store.tokens["fk_t"], "a named identity supersedes the anonymous one")
    }

    func testLaterCallsReplayIdentityAndDropLegacyEndUserId() async throws {
        _ = try await HeedKit.shared.initialize(workspaceKey: "fk_t", apiUrl: "https://stub.test")
        StubURLProtocol.reset(responseBody: #"{ "voted": true, "vote_count": 1 }"#)

        _ = try await HeedKit.shared.vote(featureId: "42")
        let call = StubURLProtocol.captured[0]
        XCTAssertEqual(call.headers["X-HeedKit-Identity"], "idtok-1")
        XCTAssertNil(call.body["end_user_id"], "legacy param removed — the header identifies the caller")
        XCTAssertFalse(call.url.query?.contains("end_user_id") ?? false)
    }
}
