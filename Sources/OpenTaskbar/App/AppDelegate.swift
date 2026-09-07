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
        guard SingleInstanceLock.acquire() else {
            NSApp.terminate(nil)
            return
        }

        crashGuard.install()

        let permissions = PermissionsManager.shared
        if !permissions.isAccessibilityGranted {
            permissions.requestAccessibility()
            startPermissionsPolling()
        } else {
            setupApp()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        CrashGuard.markCleanExit()
        SingleInstanceLock.release()
    }

    private func setupApp() {
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

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = loadStatusBarIcon()
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: L10n.aboutOpenTaskbar, action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.preferences, action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: L10n.restoreDockAndQuit, action: #selector(restoreAndQuit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showPreferences() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func restoreAndQuit() {
        dockManager.restoreDock()
        NSApp.terminate(nil)
    }

    private func startPermissionsPolling() {
        permissionsCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if PermissionsManager.shared.isAccessibilityGranted {
                self.permissionsCheckTimer?.invalidate()
                self.permissionsCheckTimer = nil
                self.setupApp()
            }
        }
    }
}