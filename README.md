# OpenTaskbar

A macOS menubar utility that replaces the Dock with a customizable, Windows-style taskbar. It shows all running apps with active-state indicators, window badges, hover window previews (thumbnails or a window list), a Spotlight-triggering Start button, drag-to-reorder, per-app window cycling, and per-app context menus with pin/unpin and quit actions.

> **Status:** This project is in active development. It works, but there is no stable release or automated test suite yet — see [Contributing](#contributing).

## Screenshots

Screenshots are coming soon. They will live in [`docs/screenshots/`](docs/screenshots/) — contributions of real taskbar captures (taskbar, hover thumbnails, context menu, settings window) are welcome. See [`docs/screenshots/README.md`](docs/screenshots/README.md) for the exact captures needed.

## Features

- **Windows-style taskbar** — running apps with an active-window indicator bar, window-count badges, and optional app names
- **Hover previews** — hover an app to see live window thumbnails (via ScreenCaptureKit) or a clickable window list
- **Start button** — a Spotlight button at the left edge of the bar; clicking it opens Spotlight
- **Drag-to-reorder** — drag apps to rearrange them; pinned apps keep their own order
- **Pin/unpin** — pinned apps stay on the taskbar even when not running
- **Per-app window cycling** — click an app with multiple windows to raise/cycle its windows; click again to bring the next window forward
- **Rich context menus** — per-window activate/close, Close All, Quit / Force Quit / Quit Apps to the Right, "Don't Quit When Closed" protection, and Finder extras (New Window, Open folder, Empty Trash)
- **Fullscreen handling** — the taskbar hides automatically while a fullscreen or player window is active (configurable)
- **Multi-screen support** — one taskbar per display (configurable)
- **Two styles** — a full-width *Taskbar* or a floating *Dock*-style pill
- **Themes** — system / dark / light / glassmorphism / custom background color, with a translucent-bar option
- **Zoomed-window handling** — optionally keep zoomed (green-button) windows above the taskbar
- **Launch animation** — apps animate in when they launch; minimize/restore bounce animations
- **Crash safety** — the Dock is saved before it's hidden and restored on unexpected exits
- **Zero dependencies** — pure AppKit + Apple SDKs, Swift Package Manager only

## Requirements

- **macOS 14.0 (Sonoma) or later** — Intel or Apple Silicon
- **Accessibility permission (required)** — needed to switch, focus, minimize, and close windows. OpenTaskbar cannot function without it.
- **Screen Recording permission (optional)** — only needed for live hover thumbnails. Without it, hover shows the window list instead.

## Installation

### From a release

Prebuilt releases are not published yet. Until then, build from source (below) or watch the [Releases](https://github.com/opentaskbar/opentaskbar/releases) page.

### Build from source

Requires Xcode Command Line Tools (`xcode-select --install`) or a full Xcode installation — `swift` must be available on your `PATH`.

```bash
git clone https://github.com/opentaskbar/opentaskbar.git
cd opentaskbar

# Build, package into OpenTaskbar.app, and launch it
./Scripts/run.sh

# Or just build the .app bundle without launching
./Scripts/build.sh
# Output: build/OpenTaskbar.app
```

Debug / release builds without the app bundle:

```bash
swift build                 # debug binary
swift build -c release      # release binary
```

> **Note:** `Scripts/build.sh` code-signs the bundle. It uses your identity if the `OPENTASKBAR_SIGN_IDENTITY` environment variable is set (or a local `OpenTaskbarDev` identity), and falls back to ad-hoc signing otherwise. Ad-hoc-signed builds run fine locally.

### First launch & permissions

1. Launch OpenTaskbar. A system dialog asks for **Accessibility** access.
2. Open **System Settings → Privacy & Security → Accessibility** and make sure OpenTaskbar is enabled. The app waits and starts automatically once granted.
3. (Optional) For hover thumbnails, grant **Screen Recording** in **System Settings → Privacy & Security → Screen & System Audio Recording**.
4. The Dock is hidden automatically (it is restored when you quit OpenTaskbar via the menu bar, or automatically if the app crashes).

## Usage

### Mouse interactions

| Action | Result |
|---|---|
| **Click** an app | Activate the app; if it has multiple windows, cycle/raise its windows |
| **Hover** an app | Live thumbnail previews (if Screen Recording is granted) or a window list |
| **Hover** a preview thumbnail | Shows a close button on that window's card; click the card to activate that window |
| **Right-click** an app | Context menu: per-window actions, pin/unpin, quit options, Finder shortcuts |
| **Drag** an app | Reorder it on the taskbar |
| **Click the Start button** | Opens Spotlight |

### Context menu

Right-click any app button for:

- A list of the app's windows (with keyboard shortcuts `⌘1`, `⌘2`, …), each clickable to focus, plus **Close All Windows**
- **Pin to taskbar** / **Unpin from taskbar** — pinned apps remain on the bar when not running
- **Don't Quit When Closed** / **Allow Quit When Closed** — prevents the app from being quit when its last window closes
- **Quit** submenu: **Quit** (⌘Q), **Quit Apps to the Right**, **Force Quit**
- Finder-specific items: **New Finder Window**, **Open** (recent folders), **Empty Trash…**

### Menu bar icon

The menubar icon gives you **About OpenTaskbar**, **Preferences…** (⌘,), and **Restore Dock & Quit** (⌘Q) — the reliable way to get your Dock back.

## Settings

Open **Preferences…** from the menu bar (⌘,). Changes apply immediately.

| Section | Setting | Default | Description |
|---|---|---|---|
| General | Style | Taskbar | `Taskbar` (full-width bar) or `Dock` (floating pill) |
| General | Bar Alignment | Center | Left / center / right placement of the bar on screen |
| General | Show on All Screens | On | One taskbar per display vs. primary display only |
| Appearance | Background Theme | System | System / Dark / Light / Glassmorphism / Custom |
| Appearance | Custom Color | — | Background color (shown when theme is Custom) |
| Appearance | Translucent Bar | On | Translucent (vibrancy) bar effect; requires "Reduce Transparency" to be off |
| Appearance | App Icon Size | 32 pt | Icon size, 16–64 pt |
| Appearance | Bar Spacing | 4 px | Spacing between app buttons, 0–16 px |
| Display Options | Launch at Login | On | Start automatically at login |
| Display Options | Enable Animations | On | Launch / minimize / restore animations |
| Display Options | Show Window Thumbnails on Hover | Off | Live thumbnails vs. window list; requires Screen Recording |
| Display Options | Show App Names | Off | App name text next to icons |
| Display Options | Show Spotlight Button | On | Show/hide the Start (Spotlight) button |
| Display Options | Hide Taskbar on Fullscreen | On | Auto-hide when a fullscreen window is active |
| Display Options | Quit Apps When All Windows Close | Off | Quit an app when its last window closes |
| Display Options | Keep Zoomed Windows Above Taskbar | Off | Prevent zoomed windows from overlapping the bar |
| — | Reset to Defaults | — | Restore all defaults |

## How it works

- **Window tracking** — a 1-second poll of the window list plus `NSWorkspace` notifications (launch/terminate/activate) and per-app `AXObserver` callbacks (open/close/minimize/focus) keep the taskbar in sync without continuous AX traffic.
- **Window management** — all focus, minimize, close, and fullscreen operations go through the Accessibility (AX) API.
- **Thumbnails** — live previews are captured asynchronously with ScreenCaptureKit (`SCScreenshotManager`) on macOS 14+, with a `CGWindowList` fallback.
- **Hiding the Dock** — the Dock's autohide state is saved to `~/.config/opentaskbar/dock-state.plist` before hiding and restored on quit or crash.
- **Spotlight button** — simulates `Cmd+Space` via `CGEvent` to open Spotlight. This depends on the standard Spotlight shortcut not being remapped.
- **Permissions** — Accessibility is polled every 2 seconds until granted, then the app starts.

## Troubleshooting

| Problem | Fix |
|---|---|
| Taskbar never appears | Grant **Accessibility** permission; quit and relaunch. The app cannot run without it |
| Thumbnails don't show; window list shows instead | Grant **Screen Recording** permission in System Settings, then relaunch |
| Thumbnails are black/empty | Screen Recording was granted after launch — relaunch OpenTaskbar |
| Spotlight button does nothing | The shortcut was remapped or Spotlight is disabled; OpenTaskbar simulates `Cmd+Space` |
| Taskbar hidden | A fullscreen window is active (disable "Hide Taskbar on Fullscreen"), or check "Show on All Screens" |
| Dock is gone and OpenTaskbar is not running | Launch OpenTaskbar again — it restores the Dock — or run `defaults write com.apple.dock autohide -bool false && killall Dock` |
| Build fails with codesign error | Ensure a signing identity exists (`OPENTASKBAR_SIGN_IDENTITY`), or edit `Scripts/build.sh` to use ad-hoc signing (`--sign -`) |

## Privacy

- **No telemetry, no analytics, no network calls.** OpenTaskbar never contacts a server.
- **Local logs only** — a debug log is written to `/tmp/opentaskbar.log`; crash state to `/tmp/opentaskbar.crash`. Nothing leaves your machine.
- **Permissions are scoped** — Accessibility is used solely to control windows; Screen Recording is used solely to render your own thumbnails on hover.
- **Private API** — window identification uses the private `_AXUIElementGetWindow` symbol, loaded at runtime via `dlsym`. This is why OpenTaskbar cannot be distributed through the Mac App Store; it is distributed as source and (in the future) signed releases.

## FAQ

**Does it replace the Dock?** It hides the Dock while running; the Dock is restored on quit (or automatically after a crash). You can keep both by using OpenTaskbar in *Dock* style mode.

**Will it break my setup?** It changes only the Dock autohide preference and backs it up first. All settings live in `UserDefaults`; uninstalling is just deleting the app.

**Why does it need Accessibility?** The same reason Dock-alternative and window-management apps do — controlling other apps' windows requires the Accessibility API. Without it, the taskbar is display-only.

**Can I contribute?** Yes — see [Contributing](#contributing).

## Contributing

Contributions are welcome! Please read **[AGENTS.md](AGENTS.md)** first — it documents the architecture, coding conventions (pure AppKit, programmatic Auto Layout, no third-party dependencies), and known pain points.

- Open an issue for bugs (include macOS version and permission state) or feature requests
- Keep pull requests focused; verify `swift build` succeeds before submitting
- There is no test suite yet — adding tests is a great first contribution

## License

[GNU Affero General Public License v3.0](LICENSE) — see [LICENSE](LICENSE) for the full text.

OpenTaskbar is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. This program is distributed in the hope that it will be useful, but **without any warranty**; without even the implied warranty of merchantability or fitness for a particular purpose.
