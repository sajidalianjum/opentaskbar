import AppKit
import Combine

final class WindowManager {
    private(set) var appGroups: [AppGroup] = []
    private let accessibilityService = AccessibilityService()
    private let workspaceMonitor = WorkspaceMonitor()
    private(set) var axObserverManager: AXObserverManager
    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 1.0
    private var nextInsertionOrder = 0

    private var lastFocusedWindow: [String: CGWindowID] = [:]
    private var appsSeenWithWindows: Set<String> = []
    private var titleChangeWorkItem: DispatchWorkItem?
    private var launchingBundleIDs: Set<String> = []
    private var launchTimeouts: [String: Date] = [:]
    private let launchTimeoutDuration: TimeInterval = 8.0

    var onAppGroupsChanged: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()

    init() {
        axObserverManager = AXObserverManager(axService: accessibilityService)
        setupObservers()

        MenuItemActions.shared.onWindowActivated = { [weak self] windowID, pid in
            guard let self else { return }
            let bundleID = self.appGroups.first(where: {
                $0.runningApplication?.processIdentifier == pid
            })?.bundleIdentifier
            if let bundleID {
                self.recordWindowFocus(bundleIdentifier: bundleID, windowID: windowID)
            }
        }

        MenuItemActions.shared.onTogglePin = { [weak self] bundleID in
            if TaskbarSettings.shared.isPinned(bundleID) {
                self?.unpinApp(bundleIdentifier: bundleID)
            } else {
                self?.pinApp(bundleIdentifier: bundleID)
            }
        }
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

        axObserverManager.onWindowCreated = { [weak self] (pid, element) in
            self?.handleWindowCreated(pid: pid, element: element)
        }
        axObserverManager.onWindowDestroyed = { [weak self] (pid, element) in
            self?.handleWindowDestroyed(pid: pid, element: element)
        }
        axObserverManager.onTitleChanged = { [weak self] (_: pid_t, _: AXUIElement) in
            self?.titleChangeWorkItem?.cancel()
            let work = DispatchWorkItem { self?.refreshAppGroups() }
            self?.titleChangeWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
        }
        axObserverManager.onWindowMinimized = { [weak self] (pid, element) in
            self?.handleWindowMinimized(pid: pid, element: element)
        }
        axObserverManager.onWindowUnminimized = { [weak self] (pid, element) in
            self?.handleWindowUnminimized(pid: pid, element: element)
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
            self?.constrainZoomedWindows()
        }
    }

    private func pollWindows() {
        let cgWindows = CGWindowExtensions.eligibleWindows()
        let cgPIDs = Set(cgWindows.map(\.pid))
        let trackedPIDs = Set(appGroups.compactMap { $0.runningApplication?.processIdentifier })
        let runningPIDs = Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map(\.processIdentifier))

        let untracked = cgPIDs.subtracting(trackedPIDs).intersection(runningPIDs)
        if !untracked.isEmpty {
            refreshAppGroups()
            return
        }

        for group in appGroups {
            guard let pid = group.runningApplication?.processIdentifier else { continue }
            let cgIDs = Set(cgWindows.filter { $0.pid == pid }.map(\.windowID))
            for window in group.windows where !window.isMinimized {
                if !cgIDs.contains(window.windowID) {
                    refreshAppGroups()
                    return
                }
            }
        }
    }

    func refreshAppGroups() {
        cleanupExpiredLaunches()

        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let cgWindows = CGWindowExtensions.eligibleWindows()
        let existingMap = Dictionary(uniqueKeysWithValues: appGroups.map { ($0.bundleIdentifier, $0) })
        let pinnedIDs = TaskbarSettings.shared.pinnedBundleIdentifiers

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            var axMap: [pid_t: [WindowInfo]] = [:]
            for app in runningApps {
                axMap[app.processIdentifier] = self.accessibilityService.windowsForPID(app.processIdentifier)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.buildAndApplyAppGroups(
                    runningApps: runningApps,
                    cgWindows: cgWindows,
                    axMap: axMap,
                    existingMap: existingMap,
                    pinnedIDs: pinnedIDs
                )
            }
        }
    }

    private func buildAndApplyAppGroups(
        runningApps: [NSRunningApplication],
        cgWindows: [WindowInfo],
        axMap: [pid_t: [WindowInfo]],
        existingMap: [String: AppGroup],
        pinnedIDs: [String]
    ) {
        var updatedGroups: [AppGroup] = []
        var runningBundleIDs = Set<String>()

        for app in runningApps {
            let pid = app.processIdentifier
            let bundleID = app.bundleIdentifier ?? "unknown-\(pid)"
            runningBundleIDs.insert(bundleID)
            let appWindows = cgWindows.filter { $0.pid == pid }
            let axWindows = axMap[pid] ?? []
            var mergedWindows = mergeWindows(axWindows: axWindows, cgWindows: appWindows)
            mergedWindows.sort { $0.windowID < $1.windowID }

            let order: Int
            if let existing = existingMap[bundleID] {
                order = existing.insertionOrder
            } else {
                order = nextInsertionOrder
                nextInsertionOrder += 1
            }

            let group = AppGroup(
                bundleIdentifier: bundleID,
                localizedName: app.localizedName ?? "Unknown",
                icon: app.icon ?? NSImage(),
                runningApplication: app,
                windows: mergedWindows.isEmpty && appWindows.isEmpty ? [] : mergedWindows,
                isActive: app.processIdentifier == NSWorkspace.shared.frontmostApplication?.processIdentifier,
                insertionOrder: order
            )
            updatedGroups.append(group)
        }

        for pinnedID in pinnedIDs {
            guard !runningBundleIDs.contains(pinnedID) else { continue }

            var appName = pinnedID
            var icon = NSImage()

            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: pinnedID) {
                if let localizedName = try? appURL.resourceValues(forKeys: [.localizedNameKey]).localizedName {
                    appName = localizedName
                } else {
                    appName = FileManager.default.displayName(atPath: appURL.path)
                }
                icon = NSWorkspace.shared.icon(forFile: appURL.path)
            } else {
                TaskbarSettings.shared.pinnedBundleIdentifiers.removeAll { $0 == pinnedID }
                continue
            }

            let group = AppGroup(
                bundleIdentifier: pinnedID,
                localizedName: appName,
                icon: icon,
                runningApplication: nil,
                windows: [],
                isActive: false,
                insertionOrder: -1
            )
            updatedGroups.append(group)
        }

        for i in updatedGroups.indices {
            let bundleID = updatedGroups[i].bundleIdentifier
            if launchingBundleIDs.contains(bundleID) {
                if !updatedGroups[i].windows.isEmpty {
                    launchingBundleIDs.remove(bundleID)
                    launchTimeouts.removeValue(forKey: bundleID)
                } else {
                    updatedGroups[i].isLaunching = true
                }
            }
        }

        updatedGroups.sort { lhs, rhs in
            let lhsIsPinned = TaskbarSettings.shared.isPinned(lhs.bundleIdentifier)
            let rhsIsPinned = TaskbarSettings.shared.isPinned(rhs.bundleIdentifier)
            if lhsIsPinned && rhsIsPinned {
                let li = pinnedIDs.firstIndex(of: lhs.bundleIdentifier) ?? Int.max
                let ri = pinnedIDs.firstIndex(of: rhs.bundleIdentifier) ?? Int.max
                return li < ri
            }
            if lhsIsPinned { return true }
            if rhsIsPinned { return false }
            return lhs.insertionOrder < rhs.insertionOrder
        }

        for group in updatedGroups {
            if !group.windows.isEmpty {
                appsSeenWithWindows.insert(group.bundleIdentifier)
            }
        }

        if TaskbarSettings.shared.quitOnLastWindowClose {
            for group in updatedGroups where group.windows.isEmpty {
                if appsSeenWithWindows.contains(group.bundleIdentifier) {
                    group.runningApplication?.terminate()
                }
            }
        }

        appGroups = updatedGroups.filter { !$0.windows.isEmpty || TaskbarSettings.shared.isPinned($0.bundleIdentifier) || $0.isLaunching }

        constrainZoomedWindows()
        notifyChanged()
    }

    private func constrainZoomedWindows() {
        guard TaskbarSettings.shared.constrainZoomedWindows else { return }

        let ownPID = ProcessInfo.processInfo.processIdentifier

        for group in appGroups {
            guard let app = group.runningApplication else { continue }
            let pid = app.processIdentifier
            guard pid != ownPID else { continue }

            for window in group.windows {
                guard !window.isMinimized, !window.isFullscreen else { continue }

                guard let element = accessibilityService.windowElement(for: window.windowID, pid: pid),
                      let liveFrame = accessibilityService.frame(for: element),
                      liveFrame.width > 0, liveFrame.height > 0
                else { continue }

                guard let screen = screenContaining(frame: liveFrame),
                      isZoomedFrame(liveFrame, on: screen)
                else { continue }

                let tbTop = taskbarTop(for: screen)
                let windowBottom = liveFrame.minY

                guard windowBottom < tbTop else { continue }

                let targetHeight = screen.visibleFrame.maxY - tbTop - 4

                if abs(liveFrame.height - targetHeight) <= 1 {
                    continue
                }

                guard targetHeight >= 100 else { continue }

                var newFrame = liveFrame
                newFrame.size.height = targetHeight
                accessibilityService.setFrame(element, frame: newFrame)
            }
        }
    }

    private func taskbarTop(for screen: NSScreen) -> CGFloat {
        let height = ScreenGeometry.taskbarHeight(forIconSize: CGFloat(TaskbarSettings.shared.iconSize))
        let rect = ScreenGeometry.taskbarRect(for: screen, height: height, isDockStyle: TaskbarSettings.shared.style == .dock)
        return rect.maxY
    }

    private func screenContaining(frame: CGRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(frame) })
    }

    private func isZoomedFrame(_ frame: CGRect, on screen: NSScreen) -> Bool {
        let vf = screen.visibleFrame
        let widthRatio = frame.width / vf.width
        let heightRatio = frame.height / vf.height
        return widthRatio >= 0.98 && heightRatio >= 0.98
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
        if let bundleID = app.bundleIdentifier {
            if !appGroups.contains(where: { $0.bundleIdentifier == bundleID && !$0.windows.isEmpty }) {
                launchingBundleIDs.insert(bundleID)
                launchTimeouts[bundleID] = Date().addingTimeInterval(launchTimeoutDuration)
            }
        }
        refreshAppGroups()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.axObserverManager.addObserver(for: app.processIdentifier)
            self?.refreshAppGroups()
        }
    }

    private func handleAppTerminated(_ app: NSRunningApplication) {
        axObserverManager.removeObserver(for: app.processIdentifier)
        if let bundleID = app.bundleIdentifier {
            lastFocusedWindow.removeValue(forKey: bundleID)
            appsSeenWithWindows.remove(bundleID)
            launchingBundleIDs.remove(bundleID)
            launchTimeouts.removeValue(forKey: bundleID)
        }
        refreshAppGroups()
    }

    private func cleanupExpiredLaunches() {
        let now = Date()
        for (bundleID, timeout) in launchTimeouts {
            if now >= timeout {
                launchingBundleIDs.remove(bundleID)
                launchTimeouts.removeValue(forKey: bundleID)
            }
        }
    }

    private func handleAppActivated(_ app: NSRunningApplication) {
        if !appGroups.contains(where: { $0.runningApplication?.processIdentifier == app.processIdentifier }) {
            refreshAppGroups()
        } else {
            updateActiveStates()
        }
    }

    private func updateActiveStates() {
        let frontApp = NSWorkspace.shared.frontmostApplication
        let frontPID = frontApp?.processIdentifier
        for i in appGroups.indices {
            let pid = appGroups[i].runningApplication?.processIdentifier
            appGroups[i].isActive = pid == frontPID
        }
        notifyChanged()
    }

    private func handleWindowMinimized(pid: pid_t, element: AXUIElement) {
        guard let windowID = accessibilityService.cgWindowID(from: element) else {
            refreshAppGroups()
            return
        }
        for i in appGroups.indices {
            guard appGroups[i].runningApplication?.processIdentifier == pid else { continue }
            if let j = appGroups[i].windows.firstIndex(where: { $0.windowID == windowID }) {
                appGroups[i].windows[j].isMinimized = true
                notifyChanged()
                return
            }
        }
        refreshAppGroups()
    }

    private func handleWindowUnminimized(pid: pid_t, element: AXUIElement) {
        guard let windowID = accessibilityService.cgWindowID(from: element) else {
            refreshAppGroups()
            return
        }
        for i in appGroups.indices {
            guard appGroups[i].runningApplication?.processIdentifier == pid else { continue }
            if let j = appGroups[i].windows.firstIndex(where: { $0.windowID == windowID }) {
                appGroups[i].windows[j].isMinimized = false
                notifyChanged()
                return
            }
        }
        refreshAppGroups()
    }

    private func handleWindowCreated(pid: pid_t, element: AXUIElement) {
        guard let info = accessibilityService.windowInfo(from: element, pid: pid) else {
            refreshAppGroups()
            return
        }
        for i in appGroups.indices {
            guard appGroups[i].runningApplication?.processIdentifier == pid else { continue }
            if !appGroups[i].windows.contains(where: { $0.windowID == info.windowID }) {
                appGroups[i].windows.append(info)
                appGroups[i].windows.sort { $0.windowID < $1.windowID }
                notifyChanged()
                return
            }
        }
        refreshAppGroups()
    }

    private func handleWindowDestroyed(pid: pid_t, element: AXUIElement) {
        guard let windowID = accessibilityService.cgWindowID(from: element) else {
            refreshAppGroups()
            return
        }
        for i in appGroups.indices {
            appGroups[i].windows.removeAll { $0.windowID == windowID }
        }
        appGroups.removeAll { $0.windows.isEmpty && !TaskbarSettings.shared.isPinned($0.bundleIdentifier) }
        notifyChanged()
    }

    private func notifyChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.onAppGroupsChanged?()
        }
    }

    func recordWindowFocus(bundleIdentifier: String, windowID: CGWindowID) {
        lastFocusedWindow[bundleIdentifier] = windowID
    }

    func activateApp(at index: Int) {
        guard index < appGroups.count else { return }
        let group = appGroups[index]

        if group.bundleIdentifier == "com.apple.finder" && group.windows.isEmpty {
            Task {
                NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
            }
            return
        }

        guard let app = group.runningApplication else {
            let bundleID = group.bundleIdentifier
            if launchingBundleIDs.contains(bundleID) { return }
            launchingBundleIDs.insert(bundleID)
            launchTimeouts[bundleID] = Date().addingTimeInterval(launchTimeoutDuration)
            refreshAppGroups()
            Task {
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    NSWorkspace.shared.open(appURL, configuration: config)
                }
            }
            return
        }

        if group.windows.isEmpty {
            Task {
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: group.bundleIdentifier) {
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    NSWorkspace.shared.open(appURL, configuration: config)
                } else {
                    NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == group.bundleIdentifier })?.activate(options: .activateAllWindows)
                }
            }
            return
        }

        let isFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier

        let visibleWindows = group.windows.filter { !$0.isMinimized }

        let preferredWindow: WindowInfo?
        if let lastID = lastFocusedWindow[group.bundleIdentifier] {
            preferredWindow = visibleWindows.first { $0.windowID == lastID }
                ?? group.windows.first { $0.windowID == lastID }
        } else {
            preferredWindow = nil
        }

        if isFrontmost && visibleWindows.count <= 1 {
            if let window = preferredWindow ?? visibleWindows.first ?? group.windows.first {
                if window.isMinimized {
                    let element = accessibilityService.windowElement(for: window.windowID, pid: app.processIdentifier)
                    if let element {
                        accessibilityService.unminimizeWindow(element)
                        app.activate()
                    }
                }
                refreshAppGroups()
                return
            }
        }

        if let window = preferredWindow ?? visibleWindows.first ?? group.windows.first {
            if window.isMinimized {
                let element = accessibilityService.windowElement(for: window.windowID, pid: app.processIdentifier)
                if let element {
                    accessibilityService.unminimizeWindow(element)
                    accessibilityService.raiseWindow(element, app: app)
                } else {
                    app.activate()
                }
            } else {
                let element = accessibilityService.windowElement(for: window.windowID, pid: app.processIdentifier)
                if let element {
                    accessibilityService.raiseWindow(element, app: app)
                } else {
                    app.activate()
                }
            }
            recordWindowFocus(bundleIdentifier: group.bundleIdentifier, windowID: window.windowID)
            refreshAppGroups()
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
            let item = NSMenuItem(title: title, action: #selector(MenuItemActions.shared.activateWindow(_:)), keyEquivalent: "")
            item.target = MenuItemActions.shared
            item.representedObject = ["windowID": Int(window.windowID), "pid": Int(window.pid)]
            menu.addItem(item)
        }

        if group.windows.count > 1 {
            menu.addItem(NSMenuItem.separator())
            let closeAll = NSMenuItem(title: "Close All Windows", action: #selector(MenuItemActions.shared.closeAllWindows(_:)), keyEquivalent: "")
            closeAll.target = MenuItemActions.shared
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

        if group.bundleIdentifier == "com.apple.finder" {
            let newWindow = NSMenuItem(title: "New Finder Window", action: #selector(MenuItemActions.shared.newFinderWindow(_:)), keyEquivalent: "n")
            newWindow.target = MenuItemActions.shared
            menu.addItem(newWindow)

            let openSub = NSMenu()
            let openItem = NSMenuItem(title: "Open", action: nil, keyEquivalent: "")
            openItem.submenu = openSub
            menu.addItem(openItem)

            let locations: [(String, String)] = [
                ("Home", NSHomeDirectory()),
                ("Desktop", "\(NSHomeDirectory())/Desktop"),
                ("Downloads", "\(NSHomeDirectory())/Downloads"),
                ("Documents", "\(NSHomeDirectory())/Documents"),
                ("Applications", "/Applications"),
            ]
            for (name, path) in locations {
                let item = NSMenuItem(title: name, action: #selector(MenuItemActions.shared.openFolder(_:)), keyEquivalent: "")
                item.target = MenuItemActions.shared
                item.representedObject = ["path": path]
                openSub.addItem(item)
            }

            let emptyTrash = NSMenuItem(title: "Empty Trash…", action: #selector(MenuItemActions.shared.emptyTrash(_:)), keyEquivalent: "")
            emptyTrash.target = MenuItemActions.shared
            menu.addItem(emptyTrash)

            menu.addItem(NSMenuItem.separator())
        }

        for (i, window) in group.windows.enumerated() {
            let title = window.title.isEmpty ? "Window \(i + 1)" : window.title
            let windowItem = NSMenuItem(title: title, action: #selector(MenuItemActions.shared.activateWindow(_:)), keyEquivalent: "\(i + 1)")
            windowItem.target = MenuItemActions.shared
            windowItem.representedObject = ["windowID": Int(window.windowID), "pid": Int(window.pid)]
            menu.addItem(windowItem)
        }

        if !group.windows.isEmpty {
            menu.addItem(NSMenuItem.separator())

            let closeAll = NSMenuItem(title: "Close All", action: #selector(MenuItemActions.shared.closeAllWindows(_:)), keyEquivalent: "")
            closeAll.target = MenuItemActions.shared
            closeAll.representedObject = ["pid": Int(group.runningApplication?.processIdentifier ?? 0)]
            menu.addItem(closeAll)
        }

        menu.addItem(NSMenuItem.separator())

        let isPinned = TaskbarSettings.shared.isPinned(group.bundleIdentifier)
        let pinItem = NSMenuItem(title: isPinned ? "Unpin from taskbar" : "Pin to taskbar", action: #selector(MenuItemActions.shared.togglePin(_:)), keyEquivalent: "")
        pinItem.target = MenuItemActions.shared
        pinItem.representedObject = ["bundleID": group.bundleIdentifier]
        menu.addItem(pinItem)

        if group.isRunning {
            menu.addItem(NSMenuItem.separator())

            let quitItem = NSMenuItem(title: "Quit \(appName)", action: #selector(MenuItemActions.shared.quitApp(_:)), keyEquivalent: "q")
            quitItem.target = MenuItemActions.shared
            quitItem.representedObject = ["bundleID": group.bundleIdentifier]
            menu.addItem(quitItem)
        }

        return menu
    }

    func removeWindow(withID windowID: CGWindowID) {
        for i in appGroups.indices {
            appGroups[i].windows.removeAll { $0.windowID == windowID }
        }
        appGroups.removeAll { $0.windows.isEmpty && !TaskbarSettings.shared.isPinned($0.bundleIdentifier) }
        notifyChanged()
    }

    func pinApp(bundleIdentifier: String) {
        guard !TaskbarSettings.shared.isPinned(bundleIdentifier) else { return }
        TaskbarSettings.shared.pinnedBundleIdentifiers.append(bundleIdentifier)
        refreshAppGroups()
    }

    func unpinApp(bundleIdentifier: String) {
        TaskbarSettings.shared.pinnedBundleIdentifiers.removeAll { $0 == bundleIdentifier }
        refreshAppGroups()
    }

    func moveApp(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex < appGroups.count, destinationIndex < appGroups.count, sourceIndex != destinationIndex else { return }
        let group = appGroups[sourceIndex]
        appGroups.remove(at: sourceIndex)
        let adjustedDest = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
        appGroups.insert(group, at: adjustedDest)

        let pinnedIDs = TaskbarSettings.shared.pinnedBundleIdentifiers
        let movedBundleID = group.bundleIdentifier
        if TaskbarSettings.shared.isPinned(movedBundleID) {
            let pinnedCount = pinnedIDs.count
            if destinationIndex < pinnedCount {
                TaskbarSettings.shared.reorderPinned(bundleID: movedBundleID, to: destinationIndex)
            }
        }

        notifyChanged()
    }
}

final class MenuItemActions: NSObject {
    static let shared = MenuItemActions()

    var onWindowActivated: ((CGWindowID, pid_t) -> Void)?
    var onTogglePin: ((String) -> Void)?

    @objc func activateWindow(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Int],
              let windowID = info["windowID"],
              let pid = info["pid"] else { return }

        let axService = AccessibilityService()
        if let element = axService.windowElement(for: CGWindowID(windowID), pid: pid_t(pid)) {
            if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
                axService.raiseWindow(element, app: app)
            }
        }
        onWindowActivated?(CGWindowID(windowID), pid_t(pid))
    }

    @objc func closeAllWindows(_ sender: NSMenuItem) {
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

    @objc func quitApp(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let bundleID = info["bundleID"] else { return }

        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == bundleID }
        for app in runningApps {
            app.terminate()
        }
    }

    @objc func togglePin(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let bundleID = info["bundleID"] else { return }
        onTogglePin?(bundleID)
    }

    @objc func newFinderWindow(_ sender: NSMenuItem) {
        let script = """
        tell application "Finder"
            activate
            make new Finder window
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            print("Failed to create new Finder window: \(error)")
        }
    }

    @objc func openFolder(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let path = info["path"] else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    @objc func emptyTrash(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Empty the Trash?"
        alert.informativeText = "Are you sure you want to permanently delete all items in the Trash?"
        alert.addButton(withTitle: "Empty Trash")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .critical
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let script = """
        tell application "Finder"
            empty trash
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            print("Failed to empty trash: \(error)")
        }
    }
}