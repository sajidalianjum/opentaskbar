# AGENTS.md — OpenTaskbar

## Project Overview

OpenTaskbar is a macOS app (Swift 5.9, AppKit, macOS 14.0+) that replaces the native Dock with a customizable Windows-style taskbar. It shows running apps with active-state indicators, window badges, hover thumbnails (ScreenCaptureKit) or a window list popover, right-click menus with pin/unpin and close actions, a Spotlight-triggering Start Menu button, drag-to-reorder apps, and per-app window cycling.

**Key constraint:** Requires Accessibility permissions. Screen Recording required for thumbnails.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| UI | AppKit (NSView, NSPanel, NSStackView, NSVisualEffectView) — **no SwiftUI** |
| Build | Swift Package Manager (no Xcode project, no CocoaPods/SPM deps) |
| Concurrency | GCD (`DispatchQueue.main.async`), async/await (thumbnails), `@Published` + `NotificationCenter` for settings |
| Dependencies | **Zero external.** Only Apple SDKs: AppKit, CoreGraphics, ApplicationServices, ScreenCaptureKit, Combine |
| macOS Target | 14.0+ |
| Accessibility | AXUIElement, AXObserver, AXIsProcessTrustedWithOptions, private API `_AXUIElementGetWindow` via `dlsym` |

---

## Directory Structure

```
OpenTaskbar/
├── Resources/
│   ├── Info.plist                  # Bundle metadata, LSUIElement=true, permissions prompts
│   ├── OpenTaskbar.entitlements    # com.apple.security.automation.accessibility
│   ├── status-icon.png             # Status bar icon 18×18 (generated)
│   ├── status-icon@2x.png          # Status bar icon 36×36 (generated)
│   ├── status-icon@3x.png          # Status bar icon 54×54 (generated)
│   └── OpenTaskbar.icns            # Full app icon
├── Scripts/
│   ├── build.sh                    # swift build -c release (universal, with native-arch fallback) + codesign + entitlements + zip → build/OpenTaskbar-<version>.zip
│   ├── release.sh                  # build.sh + printable (or automated via gh) GitHub Release publishing
│   └── run.sh                      # build.sh + open the .app bundle
├── myscripts/                      # gitignored — local icon sources, not part of the repo
│   ├── opentaskbar.svg             # Full app icon SVG source
│   ├── optaskbar-statusicon.svg    # Status bar icon SVG source (18×18pt template)
│   ├── svg2icns.sh                 # SVG → .icns converter
│   └── generate_status_icon.sh    # SVG → status bar PNGs (18/36/54px)
├── Sources/OpenTaskbar/
│   ├── App/
│   │   ├── main.swift              # NSApplication, .accessory activation policy
│   │   ├── AppDelegate.swift       # Lifecycle, per-screen panels, menu bar item, permission polling
│   │   └── PermissionsManager.swift# AX + Screen Recording runtime checks
├── Tests/OpenTaskbarTests/         # XCTest suite (@testable import OpenTaskbar); run via swift test
│   ├── TestSupport.swift           # makeWindow/makeGroup factories
│   ├── WindowGroupingEngineTests.swift
│   ├── DockManagerTests.swift
│   ├── TaskbarSettingsTests.swift
│   └── ModelAndUtilityTests.swift  # WindowInfo, AppGroup, ScreenGeometry, ThemeManager, SingleInstanceLock, NSImageExtensions, CrashGuard
├── .github/workflows/ci.yml        # swift build + swift test --enable-code-coverage + llvm-cov threshold on push/PR
│   ├── Models/
│   │   ├── WindowInfo.swift        # CGWindowID, pid, title, frame, minimized, fullscreen, layer, alpha, ownerName, isValid (Hashable)
│   │   ├── AppGroup.swift          # Bundle grouping: windows[WindowInfo], icon, active state, insertionOrder, isRunning, isPinned, hasMultipleWindows (Hashable)
│   │   └── TaskbarSettings.swift   # Singleton, @Published + NotificationCenter, UserDefaults persistence (dockMode, barAlignment, barSpacing, iconSize, showStartButton, showAppNames, showThumbnails, showOnAllScreens, backgroundTheme, quitOnLastWindowClose, customBackgroundColor, pinnedBundleIdentifiers)
│   ├── Services/
│   │   ├── WindowManager.swift     # Central orchestrator: app groups, polling (1s), activate/cycle apps, context menus, drag-to-reorder, pin/unpin, focus tracking, MenuItemActions singleton
│   │   ├── WindowGroupingEngine.swift # Pure window-grouping logic (merge/dedup, sort, closed-app eligibility, resurrection filter, insertion-order TTL, launch grace, zoomed-window math, miss tracker) — unit tested
│   │   ├── AccessibilityService.swift# AX wrappers: raise/minimize/unminimize/close/toggle-fullscreen windows, windowsForPID, windowElement lookup
│   │   ├── AXObserverManager.swift # Per-PID AXObserver C callbacks for window events
│   │   ├── WorkspaceMonitor.swift  # NSWorkspace notifications (launch/terminate/activate/deactivate/screens)
│   │   ├── DockManager.swift       # Save/restore Dock autohide/coexist via defaults + killall, ~/.config/opentaskbar/dock-state.plist
│   │   ├── ThemeManager.swift      # Background theme resolution (system/dark/light/glassmorphism/custom, translucent-vibrancy)
│   │   └── ThumbnailService.swift  # Async SCScreenshotManager (macOS 14+) / CGWindowList fallback
│   ├── Utilities/
│   │   ├── SingleInstanceLock.swift# PID file at /tmp/com.opentaskbar.lock
│   │   ├── ScreenGeometry.swift    # Taskbar rect from NSScreen, dynamic height based on icon size
│   │   ├── CGWindowExtensions.swift# CGWindowListCopyWindowInfo filtered wrapper
│   │   ├── NSImageExtensions.swift # resized(to:), roundedCorners(radius:), systemIcon(for:size:)
│   │   ├── CrashGuard.swift        # Dock state save/restore on unexpected exit, clean-exit marker
│   │   ├── Logger.swift            # /tmp/opentaskbar.log debug logging
│   │   └── LoginItemManager.swift  # Launch-at-login registration (SMAppService / legacy)
│   └── Views/
│       ├── TaskbarPanel.swift      # NSPanel: borderless, statusBar level, click-through, per-screen
│       ├── TaskbarContentView.swift# NSVisualEffectView + NSStackView + start/center/right sections, theme support, drag-drop reorder, insertion indicator, overflow
│       ├── AppButtonView.swift     # App icon, name, active indicator bar, count badge, hover, right-click, drag source, window list or thumbnail popover on hover (based on showThumbnails setting)
│       ├── StartMenuButton.swift   # SF Symbol "magnifyingglass" button, triggers Cmd+Space via CGEvent
│       ├── WindowListPopover.swift # Floating NSWindow with per-window rows (icon, title, close button), activate/close/hover-dismiss
│       ├── ThumbnailPopover.swift  # Floating NSWindow with per-window thumbnail cards in a horizontal row, close button on hover, async thumbnail loading via ThumbnailService
│       ├── OverflowChevronButton.swift # "…" button shown when taskbar items overflow the screen width
│       ├── OverflowPopover.swift   # Window listing all overflowed app buttons
│       ├── TooltipWindow.swift     # Lightweight hover tooltip showing window titles
│       └── SettingsWindowController.swift # 420×520 preferences window (NSScrollView + FlippedView, popup buttons, sliders, checkboxes, color well, reset)
├── Package.swift                   # Swift 5.9, macOS 14, single executable target
└── AGENTS.md                       # This file
```

---

## Architecture & Data Flow

### MVC-like pattern

- **Models:** `WindowInfo`, `AppGroup`, `TaskbarSettings` — value types with `Hashable`
- **Views:** AppKit `NSView` subclasses, programmatic Auto Layout, `NSTrackingArea`, target-action, `NSDragging` protocol
- **Controllers/Services:** Managers orchestrate via closures, `NotificationCenter`, and Combine (minimal)

### Data Flow

```
NSWorkspace notifications → WorkspaceMonitor → WindowManager
AXObserver callbacks     → AXObserverManager → WindowManager
1s NSTimer poll          → WindowManager.pollWindows()
                                  ↓
                         WindowManager.refreshAppGroups()
                         (merges AX windows + CGWindowList)
                                  ↓
                         AppDelegate.onAppGroupsChanged
                                  ↓
                         TaskbarPanel → TaskbarContentView.reloadData()
                                  ↓
                         Creates/reuses AppButtonView in NSStackView
                                  ↓
                         AppButtonView hover → WindowListPopover.show()
                         (when showThumbnails==false && hasMultipleWindows)
                                  ↓
                         AppButtonView hover → ThumbnailPopover.show()
                         (when showThumbnails==true)
```

**Settings propagation:**
```
TaskbarSettings @Published setter → UserDefaults.save + NotificationCenter.post(TaskbarSettingsDidChange)
                                              ↓
                                     TaskbarContentView/WindowListPopover
                                     (re-read settings, rebuild layout)
```

**Drag-to-reorder:**
```
AppButtonView.mouseDragged → NSDraggingSession (pasteboard: bundleID:index)
    → TaskbarContentView.performDragOperation → WindowManager.moveApp(from:to:)
```

### Key Patterns

- **Singletons:** `TaskbarSettings.shared`, `PermissionsManager.shared`, `ThumbnailService.shared`, `SettingsWindowController.shared`, `MenuItemActions.shared`
- **Closure callbacks:** Managers communicate state changes via `var onX: ((T) -> Void)?` closures
- **NotificationCenter:** `TaskbarSettings` uses `@Published` with `didSet` → `postChange()` → `NotificationCenter.default.post(name: TaskbarSettings.settingsDidChange)`. Views subscribe via `addObserver`.
- **Combine (minimal):** One Combine sink in `WindowManager` on `TaskbarSettings.$showAppNames`. Most settings use NotificationCenter instead.
- **C callbacks:** `AXObserverManager` bridges C callbacks → `[weak self]` → main thread
- **Private API:** `_AXUIElementGetWindow` loaded via `dlsym` at runtime
- **Drag-to-reorder:** `NSDraggingSource` protocol on `AppButtonView`, drag validation on `TaskbarContentView`

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

# Build, bundle, and launch (run Scripts/run.sh)
./Scripts/run.sh

# Run (debug binary)
.build/debug/OpenTaskbar

# Run tests
swift test
```

**Icons:** The app icon (`OpenTaskbar.icns`) and status bar PNGs (18×18 (1x), 36×36 (@2x), 54×54 (@3x)) are committed under `Resources/` and copied into the app bundle by `Scripts/build.sh`. They are **not** regenerated at build time. To regenerate them (manual, local-only): edit the SVG sources in `myscripts/` (gitignored) and run `myscripts/generate_status_icon.sh` for the status bar PNGs or `myscripts/svg2icns.sh` for the app icon. Requires `brew install svg2png`. If you change the icons, commit the generated PNGs/icns.

**Tests run via `swift test` (SPM test target, `Tests/OpenTaskbarTests/`); CI via GitHub Actions (`.github/workflows/ci.yml`). No linter/formatter currently exists.**

---

## Coding Conventions

- **Indentation:** 4 spaces
- **Naming:** Classes/types `PascalCase`, properties/methods `camelCase`, file name matches type name
- **Classes:** `final class` everywhere (no inheritance)
- **Access control:** `private(set)` for exposed-but-readonly, `private` for helpers
- **`@objc`:** Used for selectors, NotificationCenter, menu actions
- **Memory:** `[weak self]` in closures, `Set<AnyCancellable>` for Combine (minimal), `deinit` cleanup
- **Error handling:** `try?` + `guard`; minimal `do/catch` (only in ThumbnailService)
- **No storyboards/xibs:** All views programmatic with `NSLayoutConstraint.activate()`
- **No SwiftUI:** Pure AppKit
- **No doc comments:** No `///` inline docs
- **No third-party dependencies**

---

## Known Pain Points & Refactor Targets

1. **No window drag-to-reorder** on the taskbar (app-level drag-to-reorder exists; individual windows cannot be reordered)
2. **SettingsWindowController** uses manual frame layout helpers (`FlippedView`, `labeled()`/`sliderRow()`/`checkbox()` functions), not a proper Auto Layout constraints-based layout
3. **1s poll timer** compares full window sets each cycle; could be optimized to avoid full refresh when nothing changed
4. **`MenuItemActions`** is a singleton (`shared`) that creates its own `AccessibilityService` instance rather than sharing the one from `WindowManager`; callback wiring is fragile
5. **Tests cover pure logic only** — `WindowGroupingEngine` (including state transitions), models, `DockManager`, and utilities (`ScreenGeometry`, `ThemeManager`, `SingleInstanceLock`, `NSImageExtensions`) are unit tested; AppKit/AX-driven flows (panels, observers, popovers) have no test coverage
6. **CI runs `swift build` + `swift test --enable-code-coverage` with an llvm-cov threshold** — no linting, formatting, or release-bundle verification in CI
7. **No localization** — all strings hardcoded in English
8. **No SwiftUI `@main`** — uses classic `NSApplicationMain` pattern
9. **`StartMenuButton`** simulates Cmd+Space via `CGEvent` — fragile if Spotlight is remapped or disabled, and requires accessibility permissions
10. **`WindowListPopover` and `ThumbnailPopover`** are mutually exclusive based on `showThumbnails`; no toggle to show both simultaneously
11. **`customBackgroundColor`** persisted via `NSKeyedArchiver`/`NSKeyedUnarchiver` — no secure coding, can crash if stored data is corrupted
12. **Settings window** does not resize dynamically when toggling custom color row visibility

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
- **`StartMenuButton`** simulates Cmd+Space via `CGEventPost` to open Spotlight — fragile if user has remapped the shortcut.
- **`WindowListPopover`** replaces thumbnail hover when `showThumbnails` is `false`. It's a full `NSWindow` with per-row activate and close buttons, auto-hides on mouse exit with a 250ms delay.
- **`ThumbnailPopover`** shown on hover when `showThumbnails` is `true`. Displays per-window thumbnail cards in a horizontal row with app icon placeholders, async capture via `ThumbnailService`, close button on card hover, and click-to-activate. Auto-hides on mouse exit with a 250ms delay. Requires Screen Recording permission.
- **Drag-to-reorder** apps via `NSDraggingSession` — `AppButtonView` is the drag source, `TaskbarContentView` handles drop. Bundle order and pinned order are both maintained.
- **Pin/unpin** via context menu — pinned apps appear even when not running, sorted by pin order before running apps.
- **Background theme** (`system`/`dark`/`light`/`custom`) — custom theme uses luminance-based text contrast switching.
- **Compact bar mode** renders the taskbar as a floating pill with rounded corners instead of full-width bar.
- **Settings** propagate via `NotificationCenter` (not Combine) — views observe `TaskbarSettings.settingsDidChange` and fully rebuild on any change.
- **`MenuItemActions.shared`** is a standalone singleton with its own `AccessibilityService` — not shared with `WindowManager`'s instance.
- **Animations** use `CABasicAnimation` / `CAKeyframeAnimation` exclusively (GPU render-server, zero main thread cost). No `animator()` proxy, no `NSAnimationContext`. All animations gated behind `TaskbarSettings.animationsEnabled` (default `true`). Three animation types:
  - **Launch entry**: slide-up + fade-in on first appearance in taskbar (`viewDidMoveToWindow`). 300ms ease-out via `transform.translation.y` + `opacity`.
  - **Minimize bounce**: 667ms 3-keyframe elastic (`transform.translation.y` drop→overshoot→settle + `transform.scale.y` squash/stretch).
  - **Restore bounce**: inverse of minimize, same timing.
  - Click feedback uses instant background color change (no animated scale — iOS-style press proved jerky).
- **View reuse in `reloadData()`**: `TaskbarContentView.reloadData()` calls `button.updateAppGroupState(group)` for matching bundle IDs instead of creating/swapping views. Exit animation (200ms opacity fade + slide down) for removed app buttons.

---

## Guidelines for AI Agents

### When adding features:
- Match existing patterns: `final class`, `private` where possible, closure callbacks for communication
- Use programmatic Auto Layout, not frames
- No new dependencies unless critical and approved
- Use `@Published` + `NotificationCenter` for settings; NotificationCenter for cross-component broadcast (Combine is used minimally)
- `[weak self]` in all escaping closures
- **Animations:** Use `CABasicAnimation`/`CAKeyframeAnimation` on layer properties (`opacity`, `transform.translation.y`, `transform.scale`). Always gate behind `animationsEnabled`. Never use `animator()` proxy, `NSAnimationContext`, or infinite repeating animations. Set model value + add animation with `fromValue`/`toValue`. Capture `presentation()` before `removeAnimation` for smooth transitions. Reuse views via `updateAppGroupState()` — never recreate for state-only changes.

### When fixing bugs:
- Check Accessibility permissions first (common root cause)
- Verify AXObserver is registered for the PID in question
- Ensure main thread dispatch for UI updates
- Window list polling and AX events can race — handle gracefully
- Settings rebuild the entire view on any change — be mindful of performance
- `StartMenuButton` CGEvent simulation may fail on non-US keyboards or remapped shortcuts

### Before committing:
- Run `swift build` to verify compilation
- Run `swift test`; all tests must pass
- Keep commits focused and descriptive
