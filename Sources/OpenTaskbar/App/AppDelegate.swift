import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var taskbarPanels: [NSScreen: TaskbarPanel] = [:]
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
            alert.messageText = "OpenTaskbar exited unexpectedly"
            alert.informativeText = "Your Dock has been restored. Would you like to launch OpenTaskbar again?"
            alert.addButton(withTitle: "Launch OpenTaskbar")
            alert.addButton(withTitle: "Quit")
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
        windowManager.start()
        createTaskbarPanels()
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
            taskbarPanels[screen] = panel
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
        let fullscreenIDs = Set(fullscreenScreens.map { ObjectIdentifier($0) })
        for (screen, panel) in taskbarPanels {
            panel.setHiddenForFullscreen(fullscreenIDs.contains(ObjectIdentifier(screen)))
        }
    }

    private func updatePanelsForScreenChanges() {
        let currentScreens = Set(NSScreen.screens)
        let existingScreens = Set(taskbarPanels.keys)

        for screen in currentScreens.subtracting(existingScreens) {
            let panel = TaskbarPanel(screen: screen, windowManager: windowManager)
            taskbarPanels[screen] = panel
            panel.orderFront(nil)
        }

        for screen in existingScreens.subtracting(currentScreens) {
            taskbarPanels[screen]?.close()
            taskbarPanels.removeValue(forKey: screen)
        }

        for (screen, panel) in taskbarPanels {
            panel.updateFrame(for: screen)
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
        menu.addItem(NSMenuItem(title: "About OpenTaskbar", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Restore Dock & Quit", action: #selector(restoreAndQuit), keyEquivalent: "q"))
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