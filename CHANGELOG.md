# Changelog

All notable changes to OpenTaskbar are documented here.

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