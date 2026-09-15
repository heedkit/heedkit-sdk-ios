# HeedKit (iOS & macOS / Swift Package)

Native Swift SDK for HeedKit — one package for **iOS 16+** and **macOS 13+**, with a
SwiftUI `HeedKitView` that adapts to each platform.

## Install

`Package.swift` (or Xcode → File → Add Package Dependencies):
```swift
.package(url: "https://github.com/heedkit/heedkit-sdk-ios.git", from: "0.4.0")
```

## Quickstart

```swift
import HeedKit
import SwiftUI

@main
struct MyApp: App {
    init() {
        Task {
            // Anonymous: the server-issued identity token is persisted (Keychain),
            // so the same visitor keeps their votes across launches.
            try? await HeedKit.shared.initialize(
                workspaceKey: "fk_xxx",
                apiUrl: "https://heedkit.com"
            )
        }
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

> **`apiUrl`:** pass your HeedKit **origin** only (no `/sdk` suffix) — the SDK appends
> `/sdk/...` itself, so `https://heedkit.com/sdk` double-stacks the path and 404s.
> The default (`https://api.heedkit.com`) doesn't currently serve the API, so always set it.

### Identifying your signed-in user

A named identity must be signed by **your backend** — the API rejects any
`externalId` without a valid `userHash` (`401 invalid_user_signature`). Expose an
authenticated endpoint that returns
`{ externalId, userHash, name, email }` where
`userHash = lowercase_hex(HMAC_SHA256(serverSecret, externalId))`, fetch it in the
app, then:

```swift
try await HeedKit.shared.initialize(
    workspaceKey: "fk_xxx",
    apiUrl: "https://heedkit.com",
    user: .init(externalId: me.externalId, email: me.email, userHash: me.userHash)
)
```

Never embed the workspace *secret* in the app — binaries are trivially unpacked.

### Show the widget

```swift
struct ContentView: View {
    @State private var open = false
    var body: some View {
        Button("Send feedback") { open = true }
            .sheet(isPresented: $open) { HeedKitView() }
    }
}
```

## macOS

Everything above works unchanged in a Mac app — same `initialize`, same `HeedKitView`.
Two Mac-specific notes:

- **App Sandbox:** a sandboxed app (required for the Mac App Store) needs the
  outgoing-connections entitlement, or every request fails as if offline. In
  *Signing & Capabilities → App Sandbox → Network*, tick **Outgoing Connections
  (Client)** — that's `com.apple.security.network.client = true` in your `.entitlements`.
- **Presentation:** present it as a `.sheet` like on iOS. The view sizes the sheet itself
  (min 480×560), the Suggest form uses the grouped Mac style, and **Esc** closes it.

```swift
struct ContentView: View {
    @State private var open = false
    var body: some View {
        Button("Send feedback") { open = true }
            .sheet(isPresented: $open) { HeedKitView() }
    }
}
```

The anonymous identity token is stored in the app's Keychain on macOS too, so
votes persist across launches.

## Programmatic

```swift
let features = try await HeedKit.shared.list()
let (voted, count) = try await HeedKit.shared.vote(featureId: id)
```
