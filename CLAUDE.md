# heedkit-sdk-ios — Guide for Claude Code

iOS/SwiftUI SDK for the HeedKit feedback widget. SwiftPM library product `HeedKit`,
**v0.3.0**. Standalone native implementation (does **not** depend on `heedkit-sdk-kmp`).

- **Toolchain:** Swift Package Manager. Manifest `Package.swift`.
- **Source (`Sources/HeedKit/`):** `HeedKit.swift` (client — HeedKit `/sdk/*` API + HMAC
  identity, the entry point), `HeedKitView.swift` (SwiftUI widget), `Models.swift`. Tests in
  `Tests/HeedKitTests/`.
- **Build / test:** `swift build` · `swift test`.
- **Publish (manual — no CI):** SwiftPM consumes git tags — cut a release by tagging the
  version (e.g. `git tag 0.1.0 && git push --tags`). Keep the tag in step with any version
  string in the source.

**Contract:** the backend `/sdk/*` JSON API (init → HMAC identity → replay token in
`X-HeedKit-Identity`), mirrored across all SDKs — keep in sync with `heedkit-rails` (§7 of
its CLAUDE.md). See `../CLAUDE.md` for the monorepo map.
