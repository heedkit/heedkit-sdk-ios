# HeedKit iOS & macOS — Example app

A SwiftUI app (two targets, `HeedKitDemo` for iOS and `HeedKitDemoMac` for macOS,
sharing one source set) that drives the **local `HeedKit` Swift package** (path
dependency, not a published release) against the **Rails `/sdk` backend**. It
walks the full SDK flow end to end:

1. **Configure** the SDK with a workspace key + the Rails endpoint (`Config` at the
   top of `Sources/HeedKitDemoApp.swift`; override with env vars).
2. **Init / identify** an end-user — `HeedKit.shared.initialize(...)` → `POST /sdk/init`.
3. **Fetch & display** features — `list(sort:)` → `GET /sdk/features` (Top / New).
4. **Submit** a new feature — `submit(title:description:kind:)` → `POST /sdk/features`.
5. **Upvote (toggle)** — `vote(featureId:)` → `POST /sdk/features/:id/vote`.
6. **Comment** — `listComments` / `comment` → `GET` + `POST /sdk/features/:id/comments`.

The `+` toolbar button submits, each row has an upvote button and a Comments
sheet, and "Open HeedKitView" presents the SDK's bundled widget (browse +
suggest + vote + comment, themed by the workspace's `/sdk/init` response).

> All of step 2–6 go through real SDK methods — the example never builds a
> `URLRequest` by hand. The `X-Workspace-Key` header and `end_user_id` plumbing
> live inside the SDK.

## Prerequisites

- **Xcode 15+** (deployment targets iOS 16 / macOS 13, for `NavigationStack`).
- **The Rails backend running locally:**
  ```bash
  cd heedkit-rails
  bin/dev            # serves http://localhost:3000
  ```
- **A workspace key.** Grab one from the console **Install** page, or from
  `db/seeds` (the seeded `heedkit` / `demo` workspace). It's a public key
  (`pk_…`), safe to ship in client code — but **never commit a real one**.

## Configure

Open `Sources/HeedKitDemoApp.swift` and edit `Config`:

```swift
enum Config {
    static let workspaceKey = env("HEEDKIT_WORKSPACE_KEY") ?? "pk_REPLACE_ME"
    static let apiUrl     = env("HEEDKIT_API_URL")     ?? "http://localhost:3000"
}
```

Either paste your key into `workspaceKey`, or set it without touching code via
**Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Environment
Variables**:

| Variable                  | Example value             |
| ------------------------- | ------------------------- |
| `HEEDKIT_WORKSPACE_KEY`  | `pk_your_real_key`        |
| `HEEDKIT_API_URL`      | `http://localhost:3000`   |

Until a real key is set, the app shows a setup banner instead of calling the API.

### Endpoint / host notes

The Rails apex route matches any `Host`, so no subdomain is needed.

| Where the app runs            | `apiUrl`                       |
| ----------------------------- | ------------------------------ |
| **iOS simulator / Mac app** (default) | `http://localhost:3000` |
| iOS simulator (alt)           | `http://127.0.0.1:3000`        |
| **Physical iPhone**           | `http://<your-mac-LAN-ip>:3000` (e.g. `http://192.168.1.42:3000`) |
| Android emulator (other SDK)  | `http://10.0.2.2:3000`         |

`Info.plist` already whitelists `localhost` and `127.0.0.1` for cleartext HTTP.
For a physical device on your LAN IP, add that IP under
`NSAppTransportSecurity → NSExceptionDomains` too.

## Run it

### Path A — XcodeGen (fastest)

```bash
brew install xcodegen      # one-time
cd Example
xcodegen                   # regenerates HeedKitDemo.xcodeproj from project.yml
open HeedKitDemo.xcodeproj
```

Pick the `HeedKitDemo` scheme and an iPhone simulator, or the `HeedKitDemoMac`
scheme and **My Mac**, then press ⌘R.

The Mac target is sandboxed like a Mac App Store app; its generated
`HeedKitDemoMac.entitlements` grants `com.apple.security.network.client`, the one
entitlement the SDK needs.

### Path B — open the checked-in project

```bash
cd Example
open HeedKitDemo.xcodeproj
```

The project already references the local SDK (`XCLocalSwiftPackageReference`
pointing at the repo root) and lists all three sources. Pick a simulator, ⌘R.

> The SDK is a **local path dependency** (`packages.HeedKit.path: ../` in
> `project.yml`). Edits to `Sources/HeedKit/*` are picked up on the next build.

## What to verify

1. Launch → "Connecting to http://localhost:3000…" then the **Session** section
   fills in Workspace name + a monospaced End-user id (proves `/sdk/init` worked).
2. **Roadmap (headless)** lists seeded features with kind chips; toggle **Top /
   New** to re-query; tap the up-chevron to upvote (count + fill toggle).
3. **+** → pick a kind, type a title, **Submit** → the row appears in the list.
4. **Comments** on a row → existing comments load; send one → it appears, and is
   visible to the bundled widget and the web console too.
5. **Open HeedKitView** → the SDK's full Browse / Suggest widget, themed by
   the workspace config.

## Files

| File                              | Role                                                       |
| --------------------------------- | ---------------------------------------------------------- |
| `Sources/HeedKitDemoApp.swift` | `@main` entry + `Config` (key/endpoint, env-var override). |
| `Sources/DemoSession.swift`       | `ObservableObject` owning the whole `/sdk` flow.           |
| `Sources/ContentView.swift`       | Thin SwiftUI UI: roadmap, submit sheet, comment sheet.     |
| `project.yml` / `Info.plist`      | XcodeGen spec (iOS + macOS targets) + ATS cleartext exceptions. |
