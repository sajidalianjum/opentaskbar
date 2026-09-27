# Release Process

How to cut and publish an OpenTaskbar release.

## Prerequisites

- Xcode Command Line Tools (`xcode-select --install`) — `swift` and `codesign` on `PATH`.
- A GitHub account with write access. The [GitHub CLI](https://cli.github.com/) (`gh`) makes publishing one command.
- **No Apple Developer ID required.** Releases are ad-hoc signed. The recommended install path is `Scripts/install.sh` (attached to every release), which downloads with `curl` and so avoids the Gatekeeper prompt entirely.

## Steps

### 1. Bump the version

Edit `Resources/Info.plist` — set both `CFBundleShortVersionString` and `CFBundleVersion` to the new version (e.g. `0.1.1`), and update the top entry of `CHANGELOG.md`. Commit the change.

### 2. Build the release artifact

```bash
./Scripts/release.sh
```

This builds a **universal** (Intel + Apple Silicon) release binary, assembles `build/OpenTaskbar.app`, embeds `Resources/OpenTaskbar.entitlements`, code-signs it, and zips it to `build/OpenTaskbar-<version>.zip`. It also writes a version-less `build/OpenTaskbar.zip` alias used by the installer.

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
gh release create v<version> \
  "build/OpenTaskbar-<version>.zip" \
  "build/OpenTaskbar.zip" \
  Scripts/install.sh \
  --title "OpenTaskbar <version>" \
  --notes "…"
```

Both the `OpenTaskbar.zip` alias and `Scripts/install.sh` must be attached — the
README one-liner and the installer's download URL depend on them.

Or set `OPENTASKBAR_PUBLISH=1 ./Scripts/release.sh` to have the script build and publish (including all three assets) in one go.

> Keep the release notes honest about signing: ad-hoc signed, and re-granting Accessibility/Screen Recording after updates. `Scripts/release.sh` generates a starter notes file.

## The installer

`Scripts/install.sh` is attached to every release and is what the README one-liner
runs. It downloads the release with `curl` (which, unlike browser downloads, never
sets the macOS quarantine attribute), installs `OpenTaskbar.app` to `/Applications`
(or `~/Applications` when `/Applications` is not writable), and strips quarantine
defensively. For an ad-hoc-signed build this is the only install path that avoids
the Gatekeeper prompt.

Two assets must be present on the release for the documented URLs to resolve:

- `OpenTaskbar.zip` — version-less alias (`build.sh` emits it)
- `install.sh` — the installer itself

Environment overrides:

| Variable | Purpose |
|---|---|
| `OPENTASKBAR_INSTALL_DIR` | Install location (default `/Applications`, then `~/Applications`) |
| `OPENTASKBAR_VERSION` | Pin a release, e.g. `0.1.0` |
| `OPENTASKBAR_SHA256` | Verify the downloaded zip against a known checksum |
| `OPENTASKBAR_URL` | Force a download URL (mirrors, local testing) |
| `OPENTASKBAR_OWNER` | GitHub owner (default `sajidalianjum`) |

## What users experience

- **Recommended:** `curl … | bash` installs with no Gatekeeper prompt.
- **Manual browser download:** the launch is blocked once — allow it in **System Settings → Privacy & Security → Open Anyway** (macOS 15+), **right-click → Open** (macOS 14), or `xattr -dr com.apple.quarantine /Applications/OpenTaskbar.app`.
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
- `Scripts/install.sh` — the user-facing installer attached to each release
- `README.md` — user-facing install instructions
- `.github/workflows/ci.yml` — automated build + test + coverage gate