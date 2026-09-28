import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var taskbarPanels: [CGDirectDisplayID: TaskbarPanel] = [:]
    private let windowManager = WindowManager()
    private let dockManager = DockManager()
    private let crashGuard: CrashGuard
    private let settings = TaskbarSettings.shared
    private var statusItem: NSStatusItem?
    private var permissionsCheckTimer: Timer?

    override init() {
        crashGuard = CrashGuard(dockManager: dockManager)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.shared.log("Launching OpenTaskbar (pid \(ProcessInfo.processInfo.processIdentifier), bundle \(Bundle.main.bundleIdentifier ?? "unknown"))")

        guard SingleInstanceLock.acquire() else {
            Logger.shared.log("Another OpenTaskbar instance already holds the lock; terminating this launch")
            NSApp.terminate(nil)
            return
        }

        crashGuard.install()

        let permissions = PermissionsManager.shared
        if !permissions.isAccessibilityGranted {
            Logger.shared.log("Accessibility permission not granted; prompting and polling every 2s. If you already granted it, the grant may be stale after an update — run: tccutil reset Accessibility com.opentaskbar.app")
            permissions.requestAccessibility()
            setupPermissionPendingStatusItem()
            startPermissionsPolling()
        } else {
            setupApp()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.shared.log("OpenTaskbar terminating")
        CrashGuard.markCleanExit()
        SingleInstanceLock.release()
    }

    private func setupApp() {
        Logger.shared.log("Accessibility granted; setting up taskbar panels and status item")
        let crashed = !CrashGuard.isCleanExit() && dockManager.hasSavedState()

        if crashed {
            dockManager.restoreDock()
            CrashGuard.clearCleanExit()

            let alert = NSAlert()
            alert.messageText = L10n.unexpectedExitTitle
            alert.informativeText = L10n.dockRestoredMessage
            alert.addButton(withTitle: L10n.launchOpenTaskbar)
            alert.addButton(withTitle: L10n.quit)
            alert.alertStyle = .informational

            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                NSApp.terminate(nil)
                return
            }
        }

        if settings.launchAtLogin {
            LoginItemManager.setLaunchAtLogin(true)
        }
        dockManager.hideDock()
        createTaskbarPanels()
        windowManager.start()
        setupStatusItem()

        NotificationCenter.default.addObserver(
            forName: TaskbarSettings.settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildStatusMenu()
        }
    }

    private func createTaskbarPanels() {
        windowManager.onAppGroupsChanged = { [weak self] in
            guard let self else { return }
            for panel in self.taskbarPanels.values {
                panel.reloadContent()
            }
        }
        windowManager.onFullscreenScreensChanged = { [weak self] screens in
            self?.updatePanelVisibility(fullscreenScreens: screens)
        }

        for screen in NSScreen.screens {
            let panel = TaskbarPanel(screen: screen, windowManager: windowManager)
            taskbarPanels[screen.displayID] = panel
            panel.orderFront(nil)
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updatePanelsForScreenChanges()
        }
    }

    private func updatePanelVisibility(fullscreenScreens: [NSScreen]) {
        let fullscreenIDs = Set(fullscreenScreens.map { $0.displayID })
        for (displayID, panel) in taskbarPanels {
            panel.setHiddenForFullscreen(fullscreenIDs.contains(displayID))
        }
    }

    private func updatePanelsForScreenChanges() {
        let currentScreens = NSScreen.screens
        let currentIDs = Set(currentScreens.map(\.displayID))
        let existingIDs = Set(taskbarPanels.keys)

        for screen in currentScreens where !existingIDs.contains(screen.displayID) {
            let panel = TaskbarPanel(screen: screen, windowManager: windowManager)
            taskbarPanels[screen.displayID] = panel
            panel.orderFront(nil)
        }

        for id in existingIDs.subtracting(currentIDs) {
            taskbarPanels[id]?.close()
            taskbarPanels.removeValue(forKey: id)
        }

        for screen in currentScreens {
            taskbarPanels[screen.displayID]?.updateFrame(for: screen)
        }
    }

    private func loadStatusBarIcon() -> NSImage? {
        guard let resources = Bundle.main.resourceURL else { return nil }

        let scale = Int(NSScreen.main?.backingScaleFactor ?? 2)
        let suffix: String
        switch scale {
        case 1: suffix = ""
        case 2: suffix = "@2x"
        default: suffix = "@3x"
        }

        let url = resources.appendingPathComponent("status-icon\(suffix).png")
        guard let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    private func setupPermissionPendingStatusItem() {
        createStatusItemIfNeeded()
        rebuildPermissionPendingMenu()
    }

    private func createStatusItemIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = loadStatusBarIcon()
            button.toolTip = L10n.accessibilityPermissionRequired
        }
        statusItem = item
    }

    private func rebuildPermissionPendingMenu() {
        let menu = NSMenu()
        let pendingItem = NSMenuItem(title: L10n.accessibilityPermissionRequired, action: nil, keyEquivalent: "")
        pendingItem.isEnabled = false
        menu.addItem(pendingItem)
        menu.addItem(NSMenuItem(title: L10n.openSystemSettings, action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.restoreDockAndQuit, action: #selector(restoreAndQuit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func setupStatusItem() {
        createStatusItemIfNeeded()
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.aboutOpenTaskbar, action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.preferences, action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.restoreDockAndQuit, action: #selector(restoreAndQuit), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showPreferences() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func restoreAndQuit() {
        Logger.shared.log("Restore Dock & Quit requested")
        dockManager.restoreDock()
        NSApp.terminate(nil)
    }

    @objc private func openAccessibilitySettings() {
        PermissionsManager.shared.requestAccessibility()
    }

    private func startPermissionsPolling() {
        permissionsCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if PermissionsManager.shared.isAccessibilityGranted {
                Logger.shared.log("Accessibility permission detected; continuing startup")
                self.permissionsCheckTimer?.invalidate()
                self.permissionsCheckTimer = nil
                self.setupApp()
            }
        }
    }
}