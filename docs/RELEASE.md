# Release Process

How to cut and publish an OpenTaskbar release.

## Prerequisites

- Xcode Command Line Tools (`xcode-select --install`) — `swift` and `codesign` on `PATH`.
- A GitHub account with write access. The [GitHub CLI](https://cli.github.com/) (`gh`) makes publishing one command.
- **No Apple Developer ID required.** Releases are ad-hoc signed and distributed with a documented one-time Gatekeeper override.

## Steps

### 1. Bump the version

Edit `Resources/Info.plist` — set both `CFBundleShortVersionString` and `CFBundleVersion` to the new version (e.g. `0.1.1`), and update the top entry of `CHANGELOG.md`. Commit the change.

### 2. Build the release artifact

```bash
./Scripts/release.sh
```

This builds a **universal** (Intel + Apple Silicon) release binary, assembles `build/OpenTaskbar.app`, embeds `Resources/OpenTaskbar.entitlements`, code-signs it, and zips it to `build/OpenTaskbar-<version>.zip`.

Signing:

- If `OPENTASKBAR_SIGN_IDENTITY` names an installed identity (or a local `OpenTaskbarDev` identity exists), the bundle is signed with it.
- Otherwise it falls back to **ad-hoc signing** (`codesign --sign - --options runtime`).

### 3. Verify the artifact

```bash
# Sanity check the signature
codesign --verify --deep --strict --verbose=2 build/OpenTaskbar.app

# Confirm entitlements embedded
codesign -d --entitlements - build/OpenTaskbar.app

# Confirm universal binary
file build/OpenTaskbar.app/Contents/MacOS/OpenTaskbar
# Look for: "Mach-O universal binary with 2 architectures"
```

### 4. Publish

```bash
gh release create v<version> "build/OpenTaskbar-<version>.zip" \
  --title "OpenTaskbar <version>" \
  --notes "…"
```

Or set `OPENTASKBAR_PUBLISH=1 ./Scripts/release.sh` to have the script build and publish in one go.

> Keep the release notes honest about signing: ad-hoc signed, one-time Gatekeeper override (right-click → Open), and re-granting Accessibility/Screen Recording after updates. `Scripts/release.sh` generates a starter notes file.

## What users experience

- **Double-click launch is blocked once** → right-click → Open, or `xattr -dr com.apple.quarantine /Applications/OpenTaskbar.app`.
- **Permissions re-grant on update** — release signatures change between versions, so TCC (Accessibility/Screen Recording) grants may need to be re-applied once. Settings in `UserDefaults` are unaffected.

## Future: Developer ID + notarization

Once a paid Apple Developer Program membership and a **Developer ID Application** certificate exist, the same artifact can be notarized so users get a clean double-click install:

1. Sign with the Developer ID identity (already supported via `OPENTASKBAR_SIGN_IDENTITY`).
2. `xcrun notarytool submit build/OpenTaskbar-<version>.zip --keychain-profile "opentaskbar-notary" --wait`
3. `xcrun stapler staple build/OpenTaskbar.app`
4. Re-zip and publish.

No code changes are required for this switch.

## Also see

- `Scripts/build.sh` — the bundle/zip stage used by `release.sh`
- `README.md` — user-facing install instructions
- `.github/workflows/ci.yml` — automated build + test + coverage gate