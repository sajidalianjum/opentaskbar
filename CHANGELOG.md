# Changelog

All notable changes to OpenTaskbar are documented here.

## [0.1.1] - 2026-09-28

Fixes a silent startup failure when Accessibility permission is missing or stale, and makes release signing stable so the permission survives updates.

### Fixed

- **No more silent hang** — while waiting for Accessibility, OpenTaskbar now shows a menu-bar item ("Accessibility Permission Required", with Open System Settings and Restore Dock & Quit) and logs to `/tmp/opentaskbar.log`, instead of launching invisibly with no feedback.
- **Stale Accessibility grant after updates** — `Scripts/install.sh` clears the old TCC entry when an ad-hoc build changes, so users get a clean permission prompt instead of an app that waits forever.

### Changed

- **Stable code signing** — `Scripts/build.sh` auto-detects a signing identity (`Developer ID Application` → `Apple Development` → self-signed `OpenTaskbarDev`) and only falls back to ad-hoc when none exists. New `Scripts/setup-signing.sh` creates a local identity.
- **Optional signed releases** — the Release workflow can import a signing identity from the `OPENTASKBAR_SIGNING_P12` / `OPENTASKBAR_SIGNING_PASSWORD` repository secrets and sign releases, keeping the Accessibility grant valid across updates. It stays secretless and ad-hoc when those secrets are unset.

### Added

- `permission.accessibilityRequired` string, translated in all 12 bundled locales.

## [0.1.0] - 2026-08-19

First public release.

### Added

- **Windows-style taskbar** — running apps with active-window indicator bars, window-count badges, and optional app names
- **Hover previews** — live ScreenCaptureKit thumbnails or a clickable window list popover
- **Start button** — opens Spotlight (Cmd+Space simulation)
- **Drag-to-reorder** apps; pin/unpin with separate pinned ordering
- **Per-app window cycling** and rich context menus (per-window activate/close, Close All, Quit / Force Quit / Quit Apps to the Right, Finder extras)
- **Fullscreen handling** — auto-hide while fullscreen/player windows are active
- **Multi-screen support**, **Taskbar / Dock (pill)** styles, **themes** (system/dark/light/custom)
- **Settings window**, menu bar icon, About panel
- **CrashGuard** — Dock autohide state saved and restored on quit or unexpected exit
- **Single-instance lock**
- **Test suite** — 110+ unit tests covering window grouping, models, settings, DockManager, and utilities
- **CI** — build + tests + coverage threshold on every push/PR
- **Universal binary** release packaging with ad-hoc signing (`Scripts/release.sh`)

### Security / distribution notes

- Prebuilt releases are **ad-hoc signed** (no Apple Developer ID) — see README for the one-time Gatekeeper override
- No telemetry, no analytics, no network calls; local logs only
- Uses the private `_AXUIElementGetWindow` symbol via `dlsym` — cannot be distributed through the Mac App Store