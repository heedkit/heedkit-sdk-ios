# HeedKit (iOS / Swift Package)

Native iOS SDK for HeedKit.

## Install

`Package.swift`:
```swift
.package(url: "https://github.com/heedkit-dev/heedkit-sdk-ios.git", from: "0.1.0")
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
                projectKey: "fk_xxx",
                apiUrl: "https://heedkit.com/sdk"
            )
        }
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

### Identifying your signed-in user

A named identity must be signed by **your backend** — the API rejects any
`externalId` without a valid `userHash` (`401 invalid_user_signature`). Expose an
authenticated endpoint that returns
`{ externalId, userHash, name, email }` where
`userHash = lowercase_hex(HMAC_SHA256(projectSecret, externalId))`, fetch it in the
app, then:

```swift
try await HeedKit.shared.initialize(
    projectKey: "fk_xxx",
    apiUrl: "https://heedkit.com/sdk",
    user: .init(externalId: me.externalId, email: me.email, userHash: me.userHash)
)
```

Never embed the project *secret* in the app — binaries are trivially unpacked.

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

## Programmatic

```swift
let features = try await HeedKit.shared.list()
let (voted, count) = try await HeedKit.shared.vote(featureId: id)
```
