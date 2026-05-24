# FeatureKit (iOS / Swift Package)

Native iOS SDK for Feature Kit.

## Install

`Package.swift`:
```swift
.package(url: "https://github.com/yourorg/featurekit-sdk-ios.git", from: "0.1.0")
```

## Quickstart

```swift
import FeatureKit
import SwiftUI

@main
struct MyApp: App {
    init() {
        Task {
            try? await FeatureKit.shared.initialize(
                projectKey: "fh_xxx",
                user: .init(externalId: "user-123", email: "you@app.com")
            )
        }
    }
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @State private var open = false
    var body: some View {
        Button("Send feedback") { open = true }
            .sheet(isPresented: $open) { FeatureKitView() }
    }
}
```

## Programmatic

```swift
let features = try await FeatureKit.shared.list()
let (voted, count) = try await FeatureKit.shared.vote(featureId: id)
```
