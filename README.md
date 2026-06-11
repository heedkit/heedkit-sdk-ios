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
            try? await HeedKit.shared.initialize(
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
            .sheet(isPresented: $open) { HeedKitView() }
    }
}
```

## Programmatic

```swift
let features = try await HeedKit.shared.list()
let (voted, count) = try await HeedKit.shared.vote(featureId: id)
```
