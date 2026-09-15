# heedkit-sdk-ios — Guide for Claude Code

iOS **and macOS** SwiftUI SDK for the HeedKit feedback widget (one package: iOS 16+,
macOS 13+). SwiftPM library product `HeedKit`, **v0.4.0**. Standalone native
implementation (does **not** depend on `heedkit-sdk-kmp`).

- **Toolchain:** Swift Package Manager. Manifest `Package.swift`.
- **Source (`Sources/HeedKit/`):** `HeedKit.swift` (client — HeedKit `/sdk/*` API + HMAC
  identity, the entry point), `HeedKitView.swift` (SwiftUI widget), `Models.swift`. Tests in
  `Tests/HeedKitTests/`.
- **Build / test:** `swift build` · `swift test` (both build for the Mac host, so they
  verify the macOS side). Verify iOS with
  `xcodebuild -scheme HeedKit -destination 'generic/platform=iOS Simulator' build`.
  Platform differences are the few `#if os(macOS)` blocks in `HeedKitView.swift`
  (sheet sizing, grouped form) — keep them minimal.
- **Example app (`Example/`):** XcodeGen project with two targets sharing one source
  set: `HeedKitDemo` (iOS) and `HeedKitDemoMac` (sandboxed macOS, needs
  `com.apple.security.network.client`).
- **Publish (manual — no CI):** SwiftPM consumes git tags — cut a release by tagging the
  version (e.g. `git tag 0.1.0 && git push --tags`). Keep the tag in step with any version
  string in the source.

**Contract:** the backend `/sdk/*` JSON API (init → HMAC identity → replay token in
`X-HeedKit-Identity`), mirrored across all SDKs — keep in sync with `heedkit-rails` (§7 of
its CLAUDE.md). See `../CLAUDE.md` for the monorepo map.
