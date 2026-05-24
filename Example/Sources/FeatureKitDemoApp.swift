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
    /// Public project key from the demo account. Safe to ship in client code.
    static let projectKey = "fh_hpqXsmsukX2MzoH6ikBdvb8ar1FVCGGk"

    /// Local API URL. The simulator can reach localhost; physical devices need
    /// your Mac's LAN address (e.g. "http://192.168.1.42:8000").
    static let apiUrl = "http://localhost:8000"
}
