# FeedbackHub (iOS / Swift Package)

Native iOS SDK for Feedback Hub.

## Install

`Package.swift`:
```swift
.package(url: "https://github.com/yourorg/feedback-hub-sdk-ios.git", from: "0.1.0")
```

## Quickstart

```swift
import FeedbackHub
import SwiftUI

@main
struct MyApp: App {
    init() {
        Task {
            try? await FeedbackHub.shared.initialize(
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
            .sheet(isPresented: $open) { FeedbackHubView() }
    }
}
```

## Programmatic

```swift
let features = try await FeedbackHub.shared.list()
let (voted, count) = try await FeedbackHub.shared.vote(featureId: id)
```
