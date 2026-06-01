# AGENTS.md — OpenTaskbar

## Project Overview

OpenTaskbar is a macOS app (Swift 5.9, AppKit, macOS 14.0+) that replaces the native Dock with a customizable Windows-style taskbar. It shows running apps with active-state indicators, window badges, hover thumbnails (ScreenCaptureKit), right-click menus, and a "Show Desktop" button.

**Key constraint:** Requires Accessibility permissions. Screen Recording required for thumbnails.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| UI | AppKit (NSView, NSPanel, NSStackView, NSVisualEffectView) — **no SwiftUI** |
| Build | Swift Package Manager (no Xcode project, no CocoaPods/SPM deps) |
| Concurrency | Combine (@Published), async/await (thumbnails), GCD (DispatchQueue.main.async) |
| Dependencies | **Zero external.** Only Apple SDKs: AppKit, CoreGraphics, ApplicationServices, ScreenCaptureKit, Combine |
| macOS Target | 14.0+ |
| Accessibility | AXUIElement, AXObserver, AXIsProcessTrustedWithOptions, private API `_AXUIElementGetWindow` via `dlsym` |

---

## Directory Structure

```
OpenTaskbar/
├── Resources/
│   ├── Info.plist                  # Bundle metadata, LSUIElement=true, permissions prompts
│   └── OpenTaskbar.entitlements    # com.apple.security.automation.accessibility
├── Scripts/
│   └── build.sh                    # swift build -c release + codesign → .app bundle
├── Sources/OpenTaskbar/
│   ├── App/
│   │   ├── main.swift              # NSApplication, .accessory activation policy
│   │   ├── AppDelegate.swift       # Lifecycle, per-screen panels, menu bar item, permission polling
│   │   └── PermissionsManager.swift# AX + Screen Recording runtime checks
│   ├── Models/
│   │   ├── WindowInfo.swift        # CGWindowID, pid, title, frame, minimized, fullscreen (Hashable)
│   │   ├── AppGroup.swift          # Bundle grouping: windows[WindowInfo], icon, active state (Hashable)
│   │   └── TaskbarSettings.swift   # Singleton, @Published, UserDefaults persistence
│   ├── Services/
│   │   ├── WindowManager.swift     # Central orchestrator: app groups, polling, show/hide desktop
│   │   ├── AccessibilityService.swift# AX wrappers: raise/minimize/close/fullscreen windows
│   │   ├── AXObserverManager.swift # Per-PID AXObserver C callbacks for window events
│   │   ├── WorkspaceMonitor.swift  # NSWorkspace notifications (launch/terminate/activate/screens)
│   │   ├── DockManager.swift       # Save/restore Dock autohide via defaults + killall
│   │   └── ThumbnailService.swift  # Async SCScreenshotManager (macOS 14+) / CGWindowList fallback
│   ├── Utilities/
│   │   ├── SingleInstanceLock.swift# PID file at /tmp/com.opentaskbar.lock
│   │   ├── ScreenGeometry.swift    # Taskbar rect from NSScreen
│   │   ├── CGWindowExtensions.swift# CGWindowListCopyWindowInfo filtered wrapper
│   │   └── NSImageExtensions.swift # resized(to:), roundedCorners(radius:), systemIcon(for:size:)
│   └── Views/
│       ├── TaskbarPanel.swift      # NSPanel: borderless, statusBar level, click-through
│       ├── TaskbarContentView.swift# NSVisualEffectView + NSStackView + buttons
│       ├── AppButtonView.swift     # App icon, name, active indicator bar, badge, hover, right-click
│       ├── ShowDesktopButton.swift # SF Symbol "compress" button for minimize-all
│       ├── ThumbnailPopover.swift  # Floating NSWindow with thumbnail + title
│       └── SettingsWindowController.swift # 400×480 preferences window
├── Package.swift                   # Swift 5.9, macOS 14, single executable target
└── AGENTS.md                       # This file
```

---

## Architecture & Data Flow

### MVC-like pattern

- **Models:** `WindowInfo`, `AppGroup`, `TaskbarSettings` — value types with `Hashable`
- **Views:** AppKit `NSView` subclasses, programmatic Auto Layout, `NSTrackingArea`, target-action
- **Controllers/Services:** Managers orchestrate via closures and Combine

### Data Flow

```
NSWorkspace notifications → WorkspaceMonitor → WindowManager
AXObserver callbacks     → AXObserverManager → WindowManager
2s NSTimer poll          → WindowManager.pollWindows()
                                  ↓
                         WindowManager.refreshAppGroups()
                         (merges AX windows + CGWindowList)
                                  ↓
                         AppDelegate.onAppGroupsChanged
                                  ↓
                         TaskbarPanel → TaskbarContentView.reloadData()
                                  ↓
                         Creates/reuses AppButtonView in NSStackView
```

### Key Patterns

- **Singletons:** `TaskbarSettings.shared`, `PermissionsManager.shared`, `ThumbnailService.shared`, `SettingsWindowController.shared`
- **Closure callbacks:** Managers communicate state changes via `var onX: ((T) -> Void)?` closures
- **Combine:** `TaskbarSettings` uses `@Published` properties; views subscribe via `NotificationCenter`
- **C callbacks:** `AXObserverManager` bridges C callbacks → `[weak self]` → main thread
- **Private API:** `_AXUIElementGetWindow` loaded via `dlsym` at runtime

---

## Build & Run

```bash
# Build (debug)
swift build

# Build (release, universal binary)
swift build -c release --arch arm64 --arch x86_64

# Build & bundle into .app (run Scripts/build.sh)
./Scripts/build.sh
# Output: build/OpenTaskbar.app

# Run
.build/debug/OpenTaskbar
```

**No tests, no CI, no linter/formatter currently exist.**

---

## Coding Conventions

- **Indentation:** 4 spaces
- **Naming:** Classes/types `PascalCase`, properties/methods `camelCase`, file name matches type name
- **Classes:** `final class` everywhere (no inheritance)
- **Access control:** `private(set)` for exposed-but-readonly, `private` for helpers
- **`@objc`:** Used for selectors, NotificationCenter, menu actions
- **Memory:** `[weak self]` in closures, `Set<AnyCancellable>` for Combine, `deinit` cleanup
- **Error handling:** `try?` + `guard`; minimal `do/catch` (only in ThumbnailService)
- **No storyboards/xibs:** All views programmatic with `NSLayoutConstraint.activate()`
- **No SwiftUI:** Pure AppKit
- **No doc comments:** No `///` inline docs
- **No third-party dependencies**

---

## Known Pain Points & Refactor Targets

1. **`AppButtonView.reloadData()`** rebuilds all buttons on every change — no diffing
2. **No window drag-to-reorder** on the taskbar
3. **SettingsWindowController** uses manual frame layout, not Auto Layout
4. **2s poll timer** compares full window sets each cycle; could optimize
5. **`MenuItemActions`** is a global with its own `AccessibilityService` instance rather than sharing
6. **Show Desktop** tracked minimized set can race with user minimize/unminimize
7. **No tests** — no test target in Package.swift, no test files
8. **No CI** — no GitHub Actions or similar
9. **No localization** — all strings hardcoded in English
10. **No SwiftUI `@main`** — uses classic `NSApplicationMain` pattern

---

## State Persistence

| Data | Location |
|---|---|
| Settings | `UserDefaults` (standard) |
| Dock state backup | `~/.config/opentaskbar/dock-state.plist` |
| Single-instance lock | `/tmp/com.opentaskbar.lock` |

---

## Important APIs & Gotchas

- **Accessibility permission required.** `AppDelegate` polls every 2s until granted. Will not function without it.
- **Screen Recording permission** required for thumbnails (macOS 14+ `CGRequestScreenCaptureAccess()`).
- **`LSUIElement=true`** in Info.plist — app runs as menu bar app (no Dock icon, no menu bar).
- **`NSApplication.activationPolicy = .accessory`** set in `main.swift`.
- **ClickThroughView** allows mouse events to pass through the panel to windows except on interactive subviews.
- **`_AXUIElementGetWindow`** is a private API — loaded via `dlsym` with `RTLD_DEFAULT`.
- **`killall Dock`** is used to apply Dock autohide changes — brief visual disruption.
- **Per-screen panels:** `AppDelegate` creates a `TaskbarPanel` per `NSScreen`, updates on screen changes.

---

## Guidelines for AI Agents

### When adding features:
- Match existing patterns: `final class`, `private` where possible, closure callbacks for communication
- Use programmatic Auto Layout, not frames
- No new dependencies unless critical and approved
- Use Combine `@Published` for settings; NotificationCenter for cross-component broadcast
- `[weak self]` in all escaping closures

### When fixing bugs:
- Check Accessibility permissions first (common root cause)
- Verify AXObserver is registered for the PID in question
- Ensure main thread dispatch for UI updates
- Window list polling and AX events can race — handle gracefully

### Before committing:
- Run `swift build` to verify compilation
- No test suite exists, but build must succeed
- Keep commits focused and descriptive
