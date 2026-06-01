import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var taskbarPanels: [NSScreen: TaskbarPanel] = [:]
    private let windowManager = WindowManager()
    private let dockManager = DockManager()
    private let settings = TaskbarSettings.shared
    private var statusItem: NSStatusItem?
    private var permissionsCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard SingleInstanceLock.acquire() else {
            NSApp.terminate(nil)
            return
        }

        let permissions = PermissionsManager.shared
        if !permissions.isAccessibilityGranted {
            permissions.requestAccessibility()
            startPermissionsPolling()
        } else {
            setupApp()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        dockManager.restoreDock()
        SingleInstanceLock.release()
    }

    private func setupApp() {
        dockManager.hideDock()
        windowManager.start()
        createTaskbarPanels()
        setupStatusItem()
    }

    private func createTaskbarPanels() {
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

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "menubar.dock.rectangle", accessibilityDescription: "OpenTaskbar")
            button.image?.isTemplate = true
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