import XCTest
@testable import FeatureKit

final class ModelsTests: XCTestCase {

    // MARK: - FeatureKind raw values

    func testFeatureKindRawValues() {
        // These raw values are the public contract with the backend — they must
        // never drift. The model uses camelCase Swift names mapped to snake_case
        // server values.
        XCTAssertEqual(FeatureKind.featureRequest.rawValue, "feature_request")
        XCTAssertEqual(FeatureKind.bugReport.rawValue,      "bug_report")
        XCTAssertEqual(FeatureKind.improvement.rawValue,    "improvement")
        XCTAssertEqual(FeatureKind.appreciation.rawValue,   "appreciation")
        XCTAssertEqual(FeatureKind.other.rawValue,          "other")
        XCTAssertEqual(FeatureKind.allCases.count, 5)
    }

    func testInteractionRawValues() {
        XCTAssertEqual(Interaction.upvote.rawValue,   "upvote")
        XCTAssertEqual(Interaction.downvote.rawValue, "downvote")
        XCTAssertEqual(Interaction.plusOne.rawValue,  "plus_one")
        XCTAssertEqual(Interaction.like.rawValue,     "like")
    }

    func testVisibilityRawValues() {
        XCTAssertEqual(Visibility.publicVisibility.rawValue,  "public")
        XCTAssertEqual(Visibility.privateVisibility.rawValue, "private")
    }

    // MARK: - Codable round-trip

    func testFeatureDecodesNewFields() throws {
        let json = """
        {
          "id": "f-1",
          "title": "Dark mode polish",
          "description": "",
          "status": "planned",
          "kind": "feature_request",
          "visibility": "public",
          "on_roadmap": true,
          "tag": null,
          "vote_count": 12,
          "voted": false,
          "platform": "ios",
          "author_name": "Alice",
          "created_at": "2026-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let f = try JSONDecoder().decode(Feature.self, from: json)
        XCTAssertEqual(f.id, "f-1")
        XCTAssertEqual(f.featureKind, .featureRequest)
        XCTAssertEqual(f.visibilityEnum, .publicVisibility)
        XCTAssertTrue(f.onRoadmap)
        XCTAssertEqual(f.vote_count, 12)
    }

    func testFeatureToleratesMissingNewFields() throws {
        // Backcompat: old servers may not send visibility / on_roadmap.
        let json = """
        {
          "id": "f-2",
          "title": "Old feature",
          "description": "",
          "status": "open",
          "kind": "other",
          "tag": null,
          "vote_count": 0,
          "voted": false,
          "platform": null,
          "author_name": null,
          "created_at": "2025-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let f = try JSONDecoder().decode(Feature.self, from: json)
        XCTAssertEqual(f.featureKind, .other)
        XCTAssertEqual(f.visibilityEnum, .publicVisibility, "missing visibility should default to public")
        XCTAssertFalse(f.onRoadmap)
    }

    func testFeatureUnknownKindFallsBackToOther() throws {
        let json = """
        {
          "id": "f-3",
          "title": "From the future",
          "description": "",
          "status": "open",
          "kind": "future_kind_not_yet_defined",
          "tag": null,
          "vote_count": 0,
          "voted": false,
          "platform": null,
          "author_name": null,
          "created_at": "2025-01-01T00:00:00Z"
        }
        """.data(using: .utf8)!

        let f = try JSONDecoder().decode(Feature.self, from: json)
        XCTAssertEqual(f.featureKind, .other)
    }

    // MARK: - InitResult — the SDK handshake payload

    func testInitResultDecodesFullPayload() throws {
        let json = """
        {
          "project_id": "p-1",
          "project_name": "Acme",
          "theme": {
            "primary": "#000000",
            "mode": "system",
            "font_family": "inter",
            "font_size": "lg",
            "group_mode": "tabs",
            "show_counts": { "feature_request": true, "bug_report": false }
          },
          "enabled_kinds": ["feature_request", "bug_report"],
          "kind_visibility": {
            "feature_request": "public",
            "bug_report":      "private"
          },
          "kind_interactions": {
            "feature_request": { "upvote": true,  "downvote": false },
            "bug_report":      { "plus_one": true }
          },
          "end_user_id": "eu-alice"
        }
        """.data(using: .utf8)!

        let r = try JSONDecoder().decode(InitResult.self, from: json)
        XCTAssertEqual(r.project_id, "p-1")
        XCTAssertEqual(r.end_user_id, "eu-alice")
        XCTAssertEqual(r.theme.font_family, "inter")
        XCTAssertEqual(r.theme.group_mode, "tabs")
        XCTAssertEqual(r.theme.show_counts?["bug_report"], false)
        XCTAssertEqual(r.kind_visibility?["bug_report"], "private")
        XCTAssertEqual(r.kind_interactions?["feature_request"]?["upvote"], true)
        XCTAssertEqual(r.kind_interactions?["feature_request"]?["downvote"], false)
    }

    func testInitResultInteractionsForReturnsCanonicalOrder() throws {
        let json = """
        {
          "project_id": "p", "project_name": "n", "theme": {},
          "enabled_kinds": [],
          "kind_visibility": null,
          "kind_interactions": {
            "feature_request": { "downvote": true, "upvote": true }
          },
          "end_user_id": "eu"
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(InitResult.self, from: json)
        // Stable order: upvote, downvote, plus_one, like — regardless of JSON key order.
        XCTAssertEqual(r.interactions(for: .featureRequest), [.upvote, .downvote])
    }

    func testInitResultInteractionsForUnknownKindIsEmpty() throws {
        let json = """
        {
          "project_id": "p", "project_name": "n", "theme": {},
          "enabled_kinds": [],
          "kind_visibility": null, "kind_interactions": null,
          "end_user_id": "eu"
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(InitResult.self, from: json)
        XCTAssertEqual(r.interactions(for: .bugReport), [])
    }

    func testThemeAllFieldsOptional() throws {
        // Decoding an empty theme dict must succeed — every Theme field is optional.
        let json = "{}".data(using: .utf8)!
        let t = try JSONDecoder().decode(Theme.self, from: json)
        XCTAssertNil(t.primary)
        XCTAssertNil(t.mode)
        XCTAssertEqual(t.groupMode, .tabs, "groupMode should default to .tabs")
    }
}
