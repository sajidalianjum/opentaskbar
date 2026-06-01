import AppKit
import Combine

final class WindowManager {
    private(set) var appGroups: [AppGroup] = []
    private let accessibilityService = AccessibilityService()
    private let workspaceMonitor = WorkspaceMonitor()
    private(set) var axObserverManager: AXObserverManager
    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 2.0

    var onAppGroupsChanged: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()

    init() {
        axObserverManager = AXObserverManager(axService: accessibilityService)
        setupObservers()
    }

    func start() {
        refreshAppGroups()
        workspaceMonitor.start()
        startPolling()
    }

    func stop() {
        workspaceMonitor.stop()
        axObserverManager.removeAllObservers()
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func setupObservers() {
        workspaceMonitor.onAppLaunched = { [weak self] app in
            self?.handleAppLaunched(app)
        }
        workspaceMonitor.onAppTerminated = { [weak self] app in
            self?.handleAppTerminated(app)
        }
        workspaceMonitor.onAppActivated = { [weak self] app in
            self?.handleAppActivated(app)
        }
        workspaceMonitor.onAppDeactivated = { [weak self] _ in
            self?.updateActiveStates()
        }

        axObserverManager.onWindowCreated = { [weak self] (_: pid_t, _: AXUIElement) in
            self?.refreshAppGroups()
        }
        axObserverManager.onWindowDestroyed = { [weak self] (pid: pid_t, _: AXUIElement) in
            self?.removeWindow(for: pid)
        }
        axObserverManager.onTitleChanged = { [weak self] (_: pid_t, _: AXUIElement) in
            self?.refreshAppGroups()
        }
        axObserverManager.onWindowMinimized = { [weak self] (_: pid_t, _: AXUIElement) in
            self?.refreshAppGroups()
        }
        axObserverManager.onWindowUnminimized = { [weak self] (_: pid_t, _: AXUIElement) in
            self?.refreshAppGroups()
        }

        TaskbarSettings.shared.$showAppNames
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.notifyChanged()
            }
            .store(in: &cancellables)
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollWindows()
        }
    }

    private func pollWindows() {
        let cgWindows = CGWindowExtensions.eligibleWindows()
        var changed = false

        for i in appGroups.indices {
            let group = appGroups[i]
            let currentIDs = Set(group.windows.map(\.windowID))
            let pidWindows = cgWindows.filter { $0.pid == group.runningApplication?.processIdentifier }
            let newIDs = Set(pidWindows.map(\.windowID))

            if currentIDs != newIDs {
                changed = true
            }
        }

        if changed {
            refreshAppGroups()
        }
    }

    func refreshAppGroups() {
        let runningApps = NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular
        }

        var newGroups: [AppGroup] = []
        let cgWindows = CGWindowExtensions.eligibleWindows()

        for app in runningApps {
            let pid = app.processIdentifier
            let appWindows = cgWindows.filter { $0.pid == pid }

            let axWindows = accessibilityService.windowsForPID(pid)
            var mergedWindows = mergeWindows(axWindows: axWindows, cgWindows: appWindows)

            if mergedWindows.isEmpty && appWindows.isEmpty {
                let group = AppGroup(
                    bundleIdentifier: app.bundleIdentifier ?? "unknown-\(pid)",
                    localizedName: app.localizedName ?? "Unknown",
                    icon: app.icon ?? NSImage(),
                    runningApplication: app,
                    windows: [],
                    isActive: app.isActive
                )
                newGroups.append(group)
                continue
            }

            mergedWindows.sort { $0.windowID < $1.windowID }

            let group = AppGroup(
                bundleIdentifier: app.bundleIdentifier ?? "unknown-\(pid)",
                localizedName: app.localizedName ?? "Unknown",
                icon: app.icon ?? NSImage(),
                runningApplication: app,
                windows: mergedWindows,
                isActive: app.isActive
            )
            newGroups.append(group)
        }

        newGroups.sort { group1, group2 in
            if group1.isActive != group2.isActive {
                return group1.isActive && !group2.isActive
            }
            if group1.hasMultipleWindows != group2.hasMultipleWindows {
                return group1.hasMultipleWindows && !group2.hasMultipleWindows
            }
            return group1.localizedName.localizedCaseInsensitiveCompare(group2.localizedName) == .orderedAscending
        }

        appGroups = newGroups
        notifyChanged()
    }

    private func mergeWindows(axWindows: [WindowInfo], cgWindows: [WindowInfo]) -> [WindowInfo] {
        var result: [WindowInfo] = []
        var seenIDs = Set<CGWindowID>()

        for axWindow in axWindows {
            if axWindow.isValid && !seenIDs.contains(axWindow.windowID) {
                seenIDs.insert(axWindow.windowID)
                result.append(axWindow)
            }
        }

        for cgWindow in cgWindows {
            if !seenIDs.contains(cgWindow.windowID) {
                seenIDs.insert(cgWindow.windowID)
                result.append(cgWindow)
            }
        }

        return result
    }

    private func handleAppLaunched(_ app: NSRunningApplication) {
        axObserverManager.addObserver(for: app.processIdentifier)
        refreshAppGroups()
    }

    private func handleAppTerminated(_ app: NSRunningApplication) {
        axObserverManager.removeObserver(for: app.processIdentifier)
        appGroups.removeAll { $0.runningApplication?.processIdentifier == app.processIdentifier }
        notifyChanged()
    }

    private func handleAppActivated(_ app: NSRunningApplication) {
        updateActiveStates()
    }

    private func updateActiveStates() {
        let frontApp = NSWorkspace.shared.frontmostApplication
        for i in appGroups.indices {
            appGroups[i].isActive = appGroups[i].runningApplication?.processIdentifier == frontApp?.processIdentifier
        }
        notifyChanged()
    }

    private func removeWindow(for pid: pid_t) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshAppGroups()
        }
    }

    private func notifyChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.onAppGroupsChanged?()
        }
    }

    func activateApp(at index: Int) {
        guard index < appGroups.count else { return }
        let group = appGroups[index]

        guard let app = group.runningApplication else { return }

        let visibleWindows = group.windows.filter { !$0.isMinimized }

        if group.isActive && visibleWindows.count <= 1 {
            if let window = visibleWindows.first ?? group.windows.first {
                if window.isMinimized {
                    let element = accessibilityService.windowElement(for: window.windowID, pid: app.processIdentifier)
                    if let element {
                        accessibilityService.unminimizeWindow(element)
                    }
                } else {
                    let element = accessibilityService.windowElement(for: window.windowID, pid: app.processIdentifier)
                    if let element {
                        accessibilityService.minimizeWindow(element)
                    }
                }
            }
            return
        }

        if let window = visibleWindows.first ?? group.windows.first {
            if window.isMinimized {
                let element = accessibilityService.windowElement(for: window.windowID, pid: app.processIdentifier)
                if let element {
                    accessibilityService.unminimizeWindow(element)
                }
            } else {
                let element = accessibilityService.windowElement(for: window.windowID, pid: app.processIdentifier)
                if let element {
                    accessibilityService.raiseWindow(element, app: app)
                } else {
                    app.activate()
                }
            }
        } else {
            app.activate()
        }
    }

    func cycleWindows(forAppAt index: Int) {
        guard index < appGroups.count else { return }
        let group = appGroups[index]

        guard let app = group.runningApplication, group.hasMultipleWindows else {
            activateApp(at: index)
            return
        }

        let visibleWindows = group.windows.filter { !$0.isMinimized }
        guard !visibleWindows.isEmpty else {
            activateApp(at: index)
            return
        }

        let currentFront = visibleWindows.first
        if let front = currentFront,
           let element = accessibilityService.windowElement(for: front.windowID, pid: app.processIdentifier) {
            accessibilityService.raiseWindow(element, app: app)
        }
    }

    func windowMenu(forAppAt index: Int) -> NSMenu {
        let group = appGroups[index]
        let menu = NSMenu()

        for (i, window) in group.windows.enumerated() {
            let title = window.title.isEmpty ? "Window \(i + 1)" : window.title
            let item = NSMenuItem(title: title, action: #selector(MenuItemActions.activateWindow(_:)), keyEquivalent: "")
            item.representedObject = ["windowID": Int(window.windowID), "pid": Int(window.pid)]
            menu.addItem(item)
        }

        if group.windows.count > 1 {
            menu.addItem(NSMenuItem.separator())
            let closeAll = NSMenuItem(title: "Close All Windows", action: #selector(MenuItemActions.closeAllWindows(_:)), keyEquivalent: "")
            closeAll.representedObject = ["pid": Int(group.runningApplication?.processIdentifier ?? 0)]
            menu.addItem(closeAll)
        }

        return menu
    }

    func contextMenu(forAppAt index: Int) -> NSMenu {
        guard index < appGroups.count else { return NSMenu() }
        let group = appGroups[index]
        let menu = NSMenu()

        let appName = group.localizedName
        let appItem = NSMenuItem(title: appName, action: nil, keyEquivalent: "")
        appItem.isEnabled = false
        menu.addItem(appItem)
        menu.addItem(NSMenuItem.separator())

        for (i, window) in group.windows.enumerated() {
            let title = window.title.isEmpty ? "Window \(i + 1)" : window.title
            let windowItem = NSMenuItem(title: title, action: #selector(MenuItemActions.activateWindow(_:)), keyEquivalent: "\(i + 1)")
            windowItem.representedObject = ["windowID": Int(window.windowID), "pid": Int(window.pid)]
            menu.addItem(windowItem)
        }

        if !group.windows.isEmpty {
            menu.addItem(NSMenuItem.separator())

            let closeAll = NSMenuItem(title: "Close All", action: #selector(MenuItemActions.closeAllWindows(_:)), keyEquivalent: "")
            closeAll.representedObject = ["pid": Int(group.runningApplication?.processIdentifier ?? 0)]
            menu.addItem(closeAll)
        }

        menu.addItem(NSMenuItem.separator())

        if group.isRunning {
            let quitItem = NSMenuItem(title: "Quit \(appName)", action: #selector(MenuItemActions.quitApp(_:)), keyEquivalent: "q")
            quitItem.representedObject = ["bundleID": group.bundleIdentifier]
            menu.addItem(quitItem)
        }

        return menu
    }
}

final class MenuItemActions: NSObject {
    @objc static func activateWindow(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Int],
              let windowID = info["windowID"],
              let pid = info["pid"] else { return }

        let axService = AccessibilityService()
        if let element = axService.windowElement(for: CGWindowID(windowID), pid: pid_t(pid)) {
            if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
                axService.raiseWindow(element, app: app)
            }
        }
    }

    @objc static func closeAllWindows(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Int],
              let pid = info["pid"] else { return }

        let axService = AccessibilityService()
        let windows = axService.windowsForPID(pid_t(pid))
        for window in windows {
            if let element = axService.windowElement(for: window.windowID, pid: pid_t(pid)) {
                axService.closeWindow(element)
            }
        }
    }

    @objc static func quitApp(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let bundleID = info["bundleID"] else { return }

        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleID }
        for app in runningApps {
            app.terminate()
        }
    }
}