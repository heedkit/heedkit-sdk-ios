# FeatureKitDemo

A minimal SwiftUI iOS app that wires up the local `FeatureKit` Swift package.
Use it to dogfood the iOS SDK end-to-end against your running backend.

## What it does

- Initializes the SDK against the demo project on app launch (`@main` init in
  `FeatureKitDemoApp.swift`).
- A button presents the built-in `FeatureKitView` in a sheet — the full
  list/suggest UI from the SDK.
- A second section exercises the headless API directly: fetch top requests,
  tap to toggle a vote.
- Shows the resolved project name and end-user id so you can confirm `/sdk/init`
  succeeded.

## Run it

You need: Xcode 15+, the API running locally on `http://localhost:8000`, and
the demo project key wired up in the backend (it should be — the test account
seeded it).

### Path A — fastest (with XcodeGen)

```bash
brew install xcodegen           # one-time
cd Example
xcodegen                        # generates FeatureKitDemo.xcodeproj
open FeatureKitDemo.xcodeproj
```

In Xcode: select an iPhone 15 simulator, hit ⌘R.

### Path B — no extra tools

If you don't want to install XcodeGen:

1. **Xcode → File → New → Project → iOS → App.**
   - Product name: `FeatureKitDemo`
   - Interface: SwiftUI
   - Language: Swift
   - Save it inside this `Example/` directory.
2. **Delete the auto-generated `ContentView.swift` and `*App.swift`** files
   that Xcode created.
3. **Drag** the two files from `Example/Sources/` into the project navigator
   (check "Copy items if needed" off — we want references to these files).
4. **Add the local SDK as a package dependency:**
   - File → Add Package Dependencies… → Add Local…
   - Pick the parent directory (`featurekit-sdk-ios/`).
   - Add the `FeatureKit` product to the demo target.
5. **Allow http://localhost** in `Info.plist`:
   ```xml
   <key>NSAppTransportSecurity</key>
   <dict>
     <key>NSAllowsLocalNetworking</key><true/>
     <key>NSExceptionDomains</key>
     <dict>
       <key>localhost</key>
       <dict>
         <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
       </dict>
     </dict>
   </dict>
   ```
6. Set the deployment target to **iOS 16.0** (`NavigationStack` requirement).
7. ⌘R.

## Configure

`Sources/FeatureKitDemoApp.swift` has a `Config` enum at the bottom:

```swift
enum Config {
    static let projectKey = "fh_hpqXsmsukX2MzoH6ikBdvb8ar1FVCGGk"
    static let apiUrl = "http://localhost:8000"
}
```

- Replace `projectKey` with one of your own from `/integrations` if you want
  to test against a different project.
- If you run on a **physical device**, `localhost` won't reach your Mac —
  swap `apiUrl` for your Mac's LAN address (e.g. `http://192.168.1.42:8000`).

## What to verify

1. App launches → console prints `✅ FeatureKit initialized for project: Demo App`.
2. "Open feedback panel" → modal sheet shows the seeded "Dark mode polish",
   "iPad split-view support", … each row tagged with a kind chip (Idea / Bug /
   Feedback) next to the title.
3. Tap a vote button → number updates and persists (refresh, it stays).
4. Switch to "Suggest" → segmented control lets you pick **Idea / Bug /
   Feedback**. Title placeholder + submit-button label both change with the
   selection. Submit → close → reopen → your row appears with the right kind chip.
5. **Quick submit** section in the demo: each row fires off a one-tap submission
   for a specific kind without opening the SDK UI. Confirms `submit(kind:)`
   works via the headless API too.
6. "Fetch top requests" in the headless section pulls the same data with kind
   chips on each row.
7. Open `/dashboard` and `/features` in the web console — your submissions
   show up with the right kind chip. On `/features` you can filter the
   `Everything · Features · Bugs · Feedbacks` strip and only your bug rows
   appear under "Bugs".
