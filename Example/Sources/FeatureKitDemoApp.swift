import SwiftUI
import FeatureKit

@main
struct FeatureKitDemoApp: App {
    init() {
        Task {
            do {
                try await FeatureKit.shared.initialize(
                    projectKey: Config.projectKey,
                    apiUrl: Config.apiUrl,
                    user: .init(
                        externalId: "demo-user-\(UUID().uuidString.prefix(6))",
                        name: "Demo User",
                        platform: "ios"
                    )
                )
                print("✅ FeatureKit initialized for project: \(FeatureKit.shared.projectName)")
            } catch {
                print("⚠️ FeatureKit init failed: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

enum Config {
    /// Public project key (Integrations tab in the console). Safe to ship in
    /// client code. This is the local Rails demo seed's key — swap in your own.
    static let projectKey = "fk_UegAN0zxw4UqGrLO3uCF9sq-zPF-09Z2"

    /// Rails backend. The simulator can reach localhost; physical devices need
    /// your Mac's LAN address (e.g. "http://192.168.1.42:3000"). The /sdk
    /// endpoints are key-resolved, so the apex host works (no subdomain needed).
    static let apiUrl = "http://localhost:3000"
}
