import SwiftUI
import HeedKit

// MARK: - CONFIG (edit me)
//
// Point the demo at your local Rails backend and a project key.
//
//   1. Run the backend:   cd heedkit-rails && bin/dev   (serves :3000)
//   2. Grab a project key from the console Install page (or db/seeds —
//      the seeded "heedkit"/"demo" workspace). Never commit a real key.
//   3. Paste it into `projectKey` below, OR pass it at launch with the
//      HEEDKIT_PROJECT_KEY / HEEDKIT_API_URL environment variables
//      (Xcode → Scheme → Run → Arguments → Environment Variables).
//
enum Config {
    /// Public project key (safe to ship in client code). Placeholder by default —
    /// the app shows a setup banner until you replace it or set the env var.
    static let projectKey = env("HEEDKIT_PROJECT_KEY") ?? "pk_REPLACE_ME"

    /// Rails `/sdk` backend host. Defaults to the iOS-simulator-reachable host.
    ///
    /// Host cheatsheet (the apex route matches any Host, so no subdomain needed):
    ///   - iOS simulator   -> http://localhost:3000          (this default)
    ///   - Physical device -> http://<your-mac-LAN-ip>:3000  (e.g. 192.168.1.42)
    ///   - Android emulator (other SDK) -> http://10.0.2.2:3000
    static let apiUrl = env("HEEDKIT_API_URL") ?? "http://localhost:3000"

    /// True until a real key is supplied — drives the in-app setup banner.
    static var keyIsPlaceholder: Bool { projectKey == "pk_REPLACE_ME" }

    private static func env(_ name: String) -> String? {
        guard let v = ProcessInfo.processInfo.environment[name],
              !v.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return v
    }
}

@main
struct HeedKitDemoApp: App {
    @StateObject private var session = DemoSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .task { await session.start() }
        }
    }
}
