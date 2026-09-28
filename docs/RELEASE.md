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

- `Scripts/build.sh` automatically uses the first stable identity it finds: `Developer ID Application`, then `Apple Development`, then a self-signed `OpenTaskbarDev` identity (create one once with `Scripts/setup-signing.sh`). An explicit `OPENTASKBAR_SIGN_IDENTITY` overrides the automatic choice.
- If no identity exists it falls back to **ad-hoc signing** (`codesign --sign - --options runtime`). This is what the GitHub release workflow produces, since CI runners carry no identity.

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

## Optional: sign releases with a stable identity

By default the CI release is **ad-hoc signed** on a clean runner, so macOS
invalidates the Accessibility grant on every update and users must re-grant it.
`Scripts/install.sh` clears the stale grant so this is a clean prompt rather
than a silent failure, but you can remove the chore entirely by signing every
release with the **same** certificate.

macOS stores the Accessibility grant against the app's *designated
requirement*. For an ad-hoc build that requirement is the binary's `cdhash`,
which changes on every build. For a certificate-signed build it is
`identifier + certificate leaf`, which is stable as long as the certificate is:

```text
ad-hoc   designated => cdhash H"…"                                # new every build → grant lost
signed   designated => identifier "com.opentaskbar.app" and certificate leaf = H"…"   # stable
```

You can use any long-lived certificate (a paid **Developer ID Application** is
best). The steps below use a free self-signed one, which is enough for TCC. The
certificate must be the *same* one every release — recreating it regenerates the
leaf hash and breaks the grant.

### 1. Create the certificate (once)

```bash
./Scripts/setup-signing.sh
```

This creates an `OpenTaskbarDev` code-signing identity in your login keychain.
It is deliberately not marked trusted (codesign does not need it) and the script
never uploads anything.

### 2. Export it as a .p12

Keychain Access → **login** → **My Certificates** → right-click
`OpenTaskbarDev` → **Export…** → save as `OpenTaskbarDev.p12`, set a password.

### 3. Add two repository secrets

Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Value |
|---|---|
| `OPENTASKBAR_SIGNING_P12` | `base64 -i OpenTaskbarDev.p12` (paste the result) |
| `OPENTASKBAR_SIGNING_PASSWORD` | the password you set in step 2 |

That is the only GitHub configuration required. Without these secrets the
workflow stays secretless and produces an ad-hoc build exactly as before.

### 4. Release as usual

The **Release** workflow detects the secret, imports the identity into a
throwaway keychain on the runner, and `Scripts/build.sh` signs with it. The
grant then survives updates and `Scripts/install.sh` no longer resets it
(it only resets ad-hoc builds).

> Security: the `.p12` is a private key. Anyone who has it can sign a binary that
> TCC will treat as OpenTaskbar on machines that already granted it. Keep it out
> of the repository, rotate it if leaked — and remember that rotating it
> invalidates existing grants anyway.

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
- **Permissions re-grant on update** — for **ad-hoc** release builds, signatures change between versions, so TCC (Accessibility/Screen Recording) grants may need to be re-applied once. Signing releases with a stable identity (see above) removes this. Settings in `UserDefaults` are unaffected.

## Future: Developer ID + notarization

Once a paid Apple Developer Program membership and a **Developer ID Application** certificate exist, the same artifact can be notarized so users get a clean double-click install:

1. Sign with the Developer ID identity (build.sh picks it up automatically; `OPENTASKBAR_SIGN_IDENTITY` is only needed to force a specific one).
2. `xcrun notarytool submit build/OpenTaskbar-<version>.zip --keychain-profile "opentaskbar-notary" --wait`
3. `xcrun stapler staple build/OpenTaskbar.app`
4. Re-zip and publish.

No code changes are required for this switch.

## Also see

- `Scripts/build.sh` — the bundle/zip stage used by `release.sh`
- `Scripts/install.sh` — the user-facing installer attached to each release
- `README.md` — user-facing install instructions
- `.github/workflows/ci.yml` — automated build + test + coverage gate