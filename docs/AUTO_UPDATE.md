# Auto Update

How OpenTaskbar updates itself, and what it takes to keep that safe.

## Overview

OpenTaskbar is a menu-bar (accessory) app with no installer daemon, so the
update path has to work with three constraints:

1. **An app cannot replace its own bundle while running.** The swap is handed to
   a short-lived shell helper that waits for the process to exit.
2. **macOS keys the Accessibility grant to the app's code requirement.** For an
   ad-hoc signed build that requirement is the `cdhash`, which changes on every
   update. The helper reconciles the grant exactly like `Scripts/install.sh`.
3. **The GitHub API is rate limited** (60 requests/hour/IP unauthenticated), so
   checks are throttled to once a day and replay the server's `ETag` — a routine
   "nothing new" check costs no rate-limit budget (the API answers `304`).

There are no third-party dependencies: the updater is ~700 lines of Foundation
plus an `NSAlert`.

## Files

| File | Role |
|---|---|
| `Services/Update/AppVersion.swift` | Semantic-version parsing and ordering (pure, unit-tested) |
| `Services/Update/UpdateRelease.swift` | `Codable` model of a GitHub release + asset selection |
| `Services/Update/UpdateFeedClient.swift` | `releases/latest` fetch with `ETag` replay; HTTP → error mapping |
| `Services/Update/UpdateHistoryStore.swift` | Updater memory: last check, skipped version, last installed |
| `Services/Update/UpdateInstaller.swift` | Download → checksum → unpack → validate → stage → swap helper |
| `Services/Update/UpdateManager.swift` | State machine and orchestration; publishes `Status` |
| `Services/Update/UpdateError.swift` | Failure taxonomy with localized messages |
| `Views/UpdatePresenter.swift` | The "an update is available" and failure alerts |
| `Tests/OpenTaskbarTests/UpdateTests.swift` | 66 tests over all of the above |

## Flow

```
launch (+8s, or "Check for Updates…")
      │
      ▼
UpdateManager.checkForUpdates(userInitiated:)
      │  ETag replay · throttled to 24h unless manual
      ▼
UpdateFeedClient ──▶ GitHub /releases/latest
      │  304 → up to date      403/429 → rate-limited      200 → release
      ▼
UpdateManager.evaluate(release, against: currentVersion)
      │  newer? not skipped? has a .zip asset? prerelease allowed?
      ▼
Status.updateAvailable ──▶ UpdatePresenter ──▶ NSAlert (one line: "An update to
      │                    %@ is available." + Install / Later / Skip + Release Notes)
      ▼
UpdateInstaller.download   (progress 0.0–0.7)
      ▼
UpdateInstaller.sha256     (0.7)   ← GitHub asset `digest`, else `<zip>.sha256`
      ▼
UpdateInstaller.unpack     (0.8–0.9)   ditto -x -k
      ▼
UpdateInstaller.validate   (0.9)   bundle id + version + executable + codesign
      ▼
UpdateInstaller.stage      new bundle under ~/Library/Caches/com.opentaskbar.app
      ▼
UpdateInstaller.scheduleReplacement  → detached /bin/sh helper
      ▼
AppDelegate.onReadyToRelaunch: dockManager.restoreDock(); NSApp.terminate(nil)
      ▼
helper: wait for pid → move old aside → ditto new in → strip quarantine →
        tccutil reset Accessibility (ad-hoc cdhash changed) → relaunch
```

## Settings

| Setting | Key | Default | Meaning |
|---|---|---|---|
| Automatically Check for Updates | `autoCheckForUpdates` | `true` | Check once a day, starting 8 s after launch |
| Download and Install Updates Automatically | `installUpdatesAutomatically` | `false` | Install without asking (still prompts on nothing) |
| Include Pre-release Versions | `includePrereleaseUpdates` | `false` | Accept GitHub releases marked as pre-release |

Updater bookkeeping is separate, in `UserDefaults` under `opentaskbar.update.*`
(`lastCheck`, `skippedVersion`, `lastInstalledVersion`, `etag`) so a "Reset to
Defaults" in Preferences does not silently re-enable nagging for a version the
user skipped. Nothing here is synced; the app has no iCloud/entitlements.

## Safety properties

- **HTTPS only.** Both the feed and the download URL come from GitHub
  (`OpenTaskbarReleaseAPIBase`, `OpenTaskbarReleasesPageURL` in `Info.plist`) and
  assets are always `https://github.com/...` download URLs from the API.
- **Integrity.** The download is checked against the GitHub asset `digest`
  (`sha256:…`) when present, otherwise the `OpenTaskbar-<version>.zip.sha256`
  sidecar that `Scripts/build.sh` publishes. A mismatch aborts the install.
- **Authenticity.** After unpacking, the bundle must have the same
  `CFBundleIdentifier`, the expected `CFBundleShortVersionString`, an executable
  binary, and a bundle that passes `codesign --verify --deep --strict`.
- **Blast radius.** The helper only ever `mv`s the staged bundle over
  `Bundle.main.bundleURL` and relaunches it. It never runs code from the archive
  and never touches anything else on disk. If `ditto` fails, the previous bundle
  is restored from the backup.
- **Fail-safe.** Before downloading anything, `UpdateInstaller.canSelfUpdate(at:)`
  runs a real write-then-rename probe in the folder containing the running
  bundle. If it fails, the install is refused with an explanation and the failure
  dialog offers the release page instead — no 800 KB download, no restart, no
  half-applied update.
- **Where the app lives matters.** The probe exists because Unix permissions are
  not the whole story on macOS. An app running out of `~/Documents`,
  `~/Desktop` or `~/Downloads` is inside a TCC-protected folder, so renaming its
  own bundle comes back `EPERM` ("Operation not permitted") even though the mode
  bits say the directory is writable — and no amount of Full Disk Access or
  Files-and-Folders consent is the right answer, because the fix is to run the
  app from a normal install location. `/Applications` and `~/Applications`
  (where `Scripts/install.sh` puts it) are both fine. A development build run
  from a checkout inside `~/Documents/...` **cannot** self-update; use
  `Scripts/run.sh` for that, or copy the bundle somewhere neutral to test the
  updater end to end.
- **No forced relaunch.** Nothing is installed without an explicit user action,
  unless *Download and Install Updates Automatically* is on.

## Operational notes

- **The Dock is restored before the app exits** (`onReadyToRelaunch`), so the
  replacement launch re-saves and re-hides it exactly as a normal launch does.
- **The helper waits up to 10 s** for the old process to exit before proceeding,
  so a slow termination does not corrupt the swap. Logs land in
  `~/Library/Caches/com.opentaskbar.app/updates/apply/apply-update.log`.
- **Ad-hoc signing caveat.** Every ad-hoc update changes the `cdhash`, so the
  Accessibility grant has to be re-approved. The helper clears the stale TCC
  entry so the user gets a clean prompt instead of an app that waits forever.
  Signing releases with a stable identity (see `docs/RELEASE.md`) removes this
  entirely.
- **Mixed signing and the TCC marker.** The helper clears the stale grant by
  comparing the new bundle's `cdhash` against
  `~/.config/opentaskbar/installed-cdhash`, the value the last successful
  install recorded. That file is global to the machine, so a machine that
  alternates between ad-hoc releases and a locally signed dev build can end up
  with a grant that needs re-approval without the helper noticing. Re-approving
  once is harmless, and consistent signing (the normal release case) never hits
  it.
- **Manual installs still work.** `Scripts/install.sh` now verifies the same
  `.sha256` sidecar, so the two paths agree on what a valid artifact is.

## For maintainers

Releases need no extra configuration — the release workflow publishes the
versioned zip, the version-less alias, the `.sha256` sidecar, and `install.sh`.
The updater picks the versioned asset by name and falls back to the alias, so
older releases that predate the sidecar still work (they simply have no
checksum to compare, and the signature check still applies).

If the repository is forked, set the owner once in two places:
`Info.plist` → `OpenTaskbarReleaseAPIBase` / `OpenTaskbarReleasesPageURL`, and
the defaults in `UpdateFeedClient.defaultOwner` / `.defaultRepository`.

Testing the updater without waiting for a release: point
`OpenTaskbarReleaseAPIBase` at a fixture, or drive `UpdateManager.evaluate(_:against:userInitiated:)`
directly — it is a pure function of the release, the current version, and the
history store, which is why most updater tests need no network.