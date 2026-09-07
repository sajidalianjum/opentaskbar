# OpenTaskbar

A lightweight, macOS menubar utility that replaces the Dock with a customizable, Windows-style taskbar. It shows all running apps with active-state indicators, window badges, hover window previews (thumbnails or a window list), a Spotlight-triggering Start button, drag-to-reorder, per-app window cycling, and per-app context menus with pin/unpin and quit actions.

> **Status:** OpenTaskbar ships as a prebuilt release and is tested in CI (110+ tests). The prebuilt app is **ad-hoc signed** (no Apple Developer ID), so first launch needs a one-time Gatekeeper override — see [From a release](#from-a-release).

[![CI](https://github.com/sajidalianjum/opentaskbar/actions/workflows/ci.yml/badge.svg)](https://github.com/sajidalianjum/opentaskbar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/sajidalianjum/opentaskbar)](https://github.com/sajidalianjum/opentaskbar/releases)
[![License: AGPL-3.0](https://img.shields.io/badge/License-AGPL--3.0-blue.svg)](LICENSE)

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
- **Themes** — system / dark / light / custom background color, with automatic translucency (vibrancy)
- **Zoomed-window handling** — optionally keep zoomed (green-button) windows above the taskbar
- **Launch animation** — apps animate in when they launch; minimize/restore bounce animations
- **Crash safety** — the Dock is saved before it's hidden and restored on unexpected exits
- **Zero dependencies** — pure AppKit + Apple SDKs, Swift Package Manager only

## Requirements

- **macOS 14.0 (Sonoma) or later** — Intel or Apple Silicon
- **Accessibility permission (required)** — needed to switch, focus, minimize, and close windows. OpenTaskbar cannot function without it.
- **Screen Recording permission (optional)** — only needed for live hover thumbnails. Without it, hover shows the window list instead.

## Localization

OpenTaskbar uses the native macOS bundle localization system. All static UI text goes through `L10n`, and macOS chooses the best matching locale from the user's preferred languages (including a per-app language override) when the app launches. English is the development-language fallback. Bundled locales currently include English, Spanish, French, German, Italian, Brazilian Portuguese, Simplified Chinese, Japanese, Korean, Hindi, Arabic, and Urdu.

To add a translation, create `Resources/<locale>.lproj/` and add:

- `Localizable.strings` with the keys from `Resources/en.lproj/Localizable.strings`
- `Localizable.stringsdict` for pluralized strings, using the English file as the structural template
- `InfoPlist.strings` for localized Accessibility, Screen Recording, and Automation permission prompts

`Scripts/build.sh` copies every `*.lproj` directory into `OpenTaskbar.app/Contents/Resources`, which is required because the app bundle is assembled manually. A language change normally takes effect after relaunching OpenTaskbar. macOS cannot translate arbitrary languages automatically; each supported language needs its own reviewed translation file. App names and window titles supplied by macOS remain untouched.

## Installation

### From a release

Download the latest `OpenTaskbar-*.zip` from the [Releases](https://github.com/sajidalianjum/opentaskbar/releases) page.

1. Unzip and drag `OpenTaskbar.app` into your **Applications** folder.
2. **First launch:** prebuilt releases are ad-hoc signed (no Apple Developer ID), so Gatekeeper blocks the first double-click. Do one of these **once**:
   - **Right-click** `OpenTaskbar.app` → **Open** → **Open**, or
   - run `xattr -dr com.apple.quarantine /Applications/OpenTaskbar.app` in Terminal
3. Grant **Accessibility** permission when prompted (required), and optionally **Screen Recording** for hover thumbnails.

> **Updating:** because release builds are ad-hoc signed, the app's signature changes between versions, so you may need to re-grant Accessibility / Screen Recording after updating. Your settings are unaffected.

### Build from source

Requires Xcode Command Line Tools (`xcode-select --install`) or a full Xcode installation — `swift` must be available on your `PATH`.

```bash
git clone https://github.com/sajidalianjum/opentaskbar.git
cd opentaskbar

# Build, package into OpenTaskbar.app, and launch it
./Scripts/run.sh

# Or just build the .app bundle (+ distributable zip) without launching
./Scripts/build.sh
# Output: build/OpenTaskbar.app, build/OpenTaskbar-<version>.zip
```

Debug / release builds without the app bundle:

```bash
swift build                 # debug binary
swift build -c release      # release binary
```

> **Note:** `Scripts/build.sh` builds a **universal** (Intel + Apple Silicon) release binary, assembles `OpenTaskbar.app`, embeds the accessibility entitlement, code-signs it, and packages a distributable `build/OpenTaskbar-<version>.zip`. It signs with your identity if `OPENTASKBAR_SIGN_IDENTITY` is set (or a local `OpenTaskbarDev` identity), and falls back to ad-hoc signing otherwise. For a one-command release artifact, use `./Scripts/release.sh`.

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
| Appearance | Background Theme | System | System / Dark / Light / Custom |
| Appearance | Custom Color | — | Background color (shown when theme is Custom) |
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

- **Window tracking** — a 0.5-second poll of the window list plus `NSWorkspace` notifications (launch/terminate/activate) and per-app `AXObserver` callbacks (open/close/minimize/focus) keep the taskbar in sync without continuous AX traffic.
- **Window management** — all focus, minimize, close, and fullscreen operations go through the Accessibility (AX) API.
- **Thumbnails** — live previews are captured asynchronously with ScreenCaptureKit (`SCScreenshotManager`) on macOS 14+, with a `CGWindowList` fallback.
- **Hiding the Dock** — the Dock's autohide state is saved to `~/.config/opentaskbar/dock-state.plist` before hiding and restored on quit or crash.
- **Translucency** — the bar is translucent (vibrancy) automatically; enabling **Reduce Transparency** in System Settings forces an opaque bar.
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
| Gatekeeper blocks the app ("Apple cannot check it…" / "unidentified developer") | Expected for ad-hoc-signed releases. Right-click `OpenTaskbar.app` → **Open** → **Open** once, or run `xattr -dr com.apple.quarantine /Applications/OpenTaskbar.app` |
| Access granted but permissions reset after an update | Release builds change signature between versions; re-grant Accessibility / Screen Recording once after updating |
| Build fails with codesign error | Ensure a signing identity exists (`OPENTASKBAR_SIGN_IDENTITY`), or let `Scripts/build.sh` fall back to ad-hoc signing (`--sign -`) |

## Privacy

- **No telemetry, no analytics, no network calls.** OpenTaskbar never contacts a server.
- **Local logs only** — a debug log is written to `/tmp/opentaskbar.log`; crash state to `/tmp/opentaskbar.crash`. Nothing leaves your machine.
- **Permissions are scoped** — Accessibility is used solely to control windows; Screen Recording is used solely to render your own thumbnails on hover.
- **Private API** — window identification uses the private `_AXUIElementGetWindow` symbol, loaded at runtime via `dlsym`. This is why OpenTaskbar cannot be distributed through the Mac App Store. The prebuilt release is ad-hoc signed — verify the build from source if you'd prefer.

## FAQ

**Does it replace the Dock?** It hides the Dock while running; the Dock is restored on quit (or automatically after a crash). You can keep both by using OpenTaskbar in *Dock* style mode.

**Will it break my setup?** It changes only the Dock autohide preference and backs it up first. All settings live in `UserDefaults`; uninstalling is just deleting the app.

**Why does it need Accessibility?** The same reason Dock-alternative and window-management apps do — controlling other apps' windows requires the Accessibility API. Without it, the taskbar is display-only.

**Why does macOS warn "Apple cannot check it for malicious software"?** The prebuilt release is ad-hoc signed because the project has no Apple Developer ID (required for notarization). This is how many open-source Mac utilities (e.g. yabai, SketchyBar) ship — the app is distributed with its source code and the AGPL license notice so you can verify and build it yourself if you wish. The one-time override is **right-click → Open**, or `xattr -dr com.apple.quarantine /Applications/OpenTaskbar.app`.

**Can I contribute?** Yes — see [Contributing](#contributing).

## Contributing

Contributions are welcome! Please read **[AGENTS.md](AGENTS.md)** first — it documents the architecture, coding conventions (pure AppKit, programmatic Auto Layout, no third-party dependencies), and known pain points.

- Open an issue for bugs (include macOS version and permission state) or feature requests
- Keep pull requests focused; verify `swift build` and `swift test` succeed before submitting
- Tests live in `Tests/OpenTaskbarTests/` — improving coverage of the AppKit/AX-driven flows is a great first contribution

## License

[GNU Affero General Public License v3.0](LICENSE) — see [LICENSE](LICENSE) for the full text.

OpenTaskbar is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, version 3. This program is distributed in the hope that it will be useful, but **without any warranty**; without even the implied warranty of merchantability or fitness for a particular purpose.
