import AppKit
import ApplicationServices
import Combine

private let log = Logger.shared

final class WindowManager {
    private(set) var appGroups: [AppGroup] = []
    private(set) var closedApps: [AppGroup] = []
    private let accessibilityService = AccessibilityService()
    private let workspaceMonitor = WorkspaceMonitor()
    private(set) var axObserverManager: AXObserverManager
    private var pollTimer: Timer?
    private var constrainTimer: Timer?
    private let pollInterval: TimeInterval = 0.5
    private var nextInsertionOrder = 0
    private var refreshGeneration = 0
    private var refreshInFlight = false
    private var refreshQueued = false
    private var missTracker = WindowGroupingEngine.WindowMissTracker(maxMissesBeforeRemove: 2)
    private var pendingRemovedWindowIDs: Set<CGWindowID> = []

    private var lastFocusedWindow: [String: CGWindowID] = [:]
    private var appsSeenWithWindows: Set<String> = []
    private var titleChangeWorkItem: DispatchWorkItem?
    private var launchingBundleIDs: Set<String> = []
    private var launchTimeouts: [String: Date] = [:]
    private let launchTimeoutDuration: TimeInterval = 8.0
    private let backgroundedLaunchGrace: TimeInterval = 1.5
    private var launchStartedAt: [String: Date] = [:]
    private let insertionOrderTTL: TimeInterval = 30
    private var savedInsertionOrders: [String: (order: Int, savedAt: Date)] = [:]

    var onAppGroupsChanged: (() -> Void)?
    var onFullscreenScreensChanged: (([NSScreen]) -> Void)?

    private var lastFullscreenScreenIDs: Set<CGDirectDisplayID> = []
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

        MenuItemActions.shared.onToggleNeverQuit = { [weak self] bundleID in
            TaskbarSettings.shared.toggleNeverQuit(bundleID)
            self?.refreshAppGroups()
        }

        MenuItemActions.shared.onQuitAllClosed = { [weak self] in
            guard let self else { return }
            let ownID = Bundle.main.bundleIdentifier
            for group in self.closedApps {
                guard let app = group.runningApplication else { continue }
                guard app.bundleIdentifier != ownID else { continue }
                guard app.bundleIdentifier != "com.apple.finder" else { continue }
                app.terminate()
            }
        }

        MenuItemActions.shared.onQuitAllApps = { [weak self] in
            guard let self else { return }
            let ownID = Bundle.main.bundleIdentifier
            var names: [String] = []
            var apps: [NSRunningApplication] = []
            for group in self.appGroups where group.isRunning {
                guard let app = group.runningApplication else { continue }
                guard app.bundleIdentifier != ownID else { continue }
                guard app.bundleIdentifier != "com.apple.finder" else { continue }
                names.append(group.localizedName)
                apps.append(app)
            }
            guard !names.isEmpty else { return }
            let alert = NSAlert()
            alert.messageText = "Quit All Apps"
            alert.informativeText = "Are you sure you want to quit the following \(names.count) \(names.count == 1 ? "app" : "apps")?\n\n\(names.joined(separator: "\n"))"
            alert.addButton(withTitle: "Quit All")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .critical
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            for app in apps {
                app.terminate()
            }
        }

        MenuItemActions.shared.onOpenPreferences = {
            DispatchQueue.main.async {
                SettingsWindowController.shared.showWindow()
            }
        }

        MenuItemActions.shared.onShowDesktop = {
            guard let source = CGEventSource(stateID: .hidSystemState) else { return }
            let f11Down = CGEvent(keyboardEventSource: source, virtualKey: 0x67, keyDown: true)
            let f11Up = CGEvent(keyboardEventSource: source, virtualKey: 0x67, keyDown: false)
            f11Down?.post(tap: .cgSessionEventTap)
            f11Up?.post(tap: .cgSessionEventTap)
        }

        MenuItemActions.shared.onOpenActivityMonitor = {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                let config = NSWorkspace.OpenConfiguration()
                config.activates = true
                NSWorkspace.shared.open(appURL, configuration: config)
            }
        }

        MenuItemActions.shared.onForceQuitApp = { bundleID in
            guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else { return }
            let appName = app.localizedName ?? bundleID
            let alert = NSAlert()
            alert.messageText = "Force Quit \(appName)?"
            alert.informativeText = "You will lose any unsaved changes. This action cannot be undone."
            alert.addButton(withTitle: "Force Quit")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .critical
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            app.forceTerminate()
        }

        MenuItemActions.shared.onQuitAppsToTheRight = { [weak self] index in
            guard let self else { return }
            let ownID = Bundle.main.bundleIdentifier
            var names: [String] = []
            var apps: [NSRunningApplication] = []
            for i in (index + 1)..<self.appGroups.count {
                let group = self.appGroups[i]
                guard group.isRunning, let app = group.runningApplication else { continue }
                guard app.bundleIdentifier != ownID else { continue }
                guard app.bundleIdentifier != "com.apple.finder" else { continue }
                names.append(group.localizedName)
                apps.append(app)
            }
            guard !names.isEmpty else { return }
            let alert = NSAlert()
            alert.messageText = "Quit Apps to the Right"
            alert.informativeText = "Do you want to quit the following \(names.count) \(names.count == 1 ? "app" : "apps")?\n\n\(names.joined(separator: "\n"))"
            alert.addButton(withTitle: "Quit All")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .critical
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            for app in apps {
                app.terminate()
            }
        }
    }

    func start() {
        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        for app in runningApps {
            axObserverManager.addObserver(for: app.processIdentifier)
        }
        refreshAppGroups()
        workspaceMonitor.start()
        startPolling()

        // At login/boot the Dock has just been hidden and the screen geometry
        // (visible frame) has not settled yet, so a maximized window restored by
        // macOS can be constrained against a stale frame and end up too short.
        // Restarting the app re-runs the constraint once the geometry is settled,
        // which is why that appears to "fix" the height. Rebuild the app groups and
        // re-evaluate the constraint a moment after startup so a fresh boot
        // produces the same result, and again whenever the display layout changes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.refreshAppGroups()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        constrainZoomedWindows()
    }

    func stop() {
        workspaceMonitor.stop()
        axObserverManager.removeAllObservers()
        pollTimer?.invalidate()
        pollTimer = nil
        constrainTimer?.invalidate()
        constrainTimer = nil
        NotificationCenter.default.removeObserver(self)
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
        workspaceMonitor.onActiveSpaceChanged = { [weak self] in
            self?.refreshAppGroups()
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
        }
        constrainTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.constrainZoomedWindows()
        }
        constrainTimer?.tolerance = 0.5
    }

    private func addClosedApp(_ group: AppGroup) {
        guard let candidate = WindowGroupingEngine.closedAppCandidates(
            from: [group],
            previousBundlesWithWindows: [],
            ownBundleID: Bundle.main.bundleIdentifier,
            neverQuitBundleIDs: Set(TaskbarSettings.shared.neverQuitBundleIdentifiers),
            isAlive: { group in group.runningApplication?.isTerminated == false }
        ).first else { return }
        if !closedApps.contains(where: { $0.bundleIdentifier == candidate.bundleIdentifier }) {
            closedApps.append(candidate)
        }
    }

    private func removeClosedApp(bundleIdentifier: String) {
        closedApps.removeAll { $0.bundleIdentifier == bundleIdentifier }
    }

    private func pollWindows() {
        let cgWindows = CGWindowExtensions.eligibleWindows()
        let cgPIDs = Set(cgWindows.map(\.pid))
        let groups = appGroups
        let trackedPIDs = Set(groups.compactMap { $0.runningApplication?.processIdentifier })
        let runningPIDs = Set(NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }.map(\.processIdentifier))

        let untracked = cgPIDs.subtracting(trackedPIDs).intersection(runningPIDs)
        if !untracked.isEmpty {
            log.log("pollWindows: untracked PIDs found \(untracked.map(String.init).joined(separator: ",")) — triggering refresh")
            refreshAppGroups()
            return
        }

        var didChange = false
        var needsRefresh = false
        for i in groups.indices {
            guard i < appGroups.count else { continue }
            guard let pid = appGroups[i].runningApplication?.processIdentifier else { continue }
            let cgIDs = Set(cgWindows.filter { $0.pid == pid }.map(\.windowID))
            var removedWindowIDs: [CGWindowID] = []
            for j in appGroups[i].windows.indices {
                let window = appGroups[i].windows[j]
                if window.isMinimized && cgIDs.contains(window.windowID) {
                    appGroups[i].windows[j].isMinimized = false
                    didChange = true
                } else if !window.isMinimized {
                    if cgIDs.contains(window.windowID) {
                        missTracker.hit(windowID: window.windowID)
                        pendingRemovedWindowIDs.remove(window.windowID)
                    } else {
                        let element = accessibilityService.windowElement(for: window.windowID, pid: pid)
                        var minimized: CFTypeRef?
                        if let element,
                           AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &minimized) == .success,
                           (minimized as? Bool) == true {
                            appGroups[i].windows[j].isMinimized = true
                            didChange = true
                        } else {
                            if missTracker.miss(windowID: window.windowID) {
                                removedWindowIDs.append(window.windowID)
                            }
                        }
                    }
                }
            }
            if !removedWindowIDs.isEmpty {
                appGroups[i].windows.removeAll { removedWindowIDs.contains($0.windowID) }
                for windowID in removedWindowIDs {
                    missTracker.hit(windowID: windowID)
                    pendingRemovedWindowIDs.insert(windowID)
                }
                if appGroups[i].windows.isEmpty {
                    addClosedApp(appGroups[i])
                }
                didChange = true
            }
            let knownIDs = Set(appGroups[i].windows.map(\.windowID))
            if !cgIDs.isSubset(of: knownIDs) {
                needsRefresh = true
            }
        }
        let groupCountBefore = appGroups.count
        let closingResult = WindowGroupingEngine.closingEmptyGroups(
            appGroups,
            pinnedBundleIDs: TaskbarSettings.shared.pinnedBundleIdentifiers
        )
        appGroups = closingResult.groups
        for group in closingResult.closed {
            savedInsertionOrders[group.bundleIdentifier] = (group.insertionOrder, Date())
            for window in group.windows {
                missTracker.hit(windowID: window.windowID)
            }
            addClosedApp(group)
        }
        if appGroups.count != groupCountBefore {
            didChange = true
        }
        if needsRefresh {
            refreshAppGroups()
            return
        }

        if didChange {
            notifyChanged()
        } else {
            updateFullscreenScreens()
        }
    }

    func refreshAppGroups() {
        if refreshInFlight {
            refreshQueued = true
            return
        }
        refreshInFlight = true
        refreshQueued = false
        refreshGeneration += 1
        let generation = refreshGeneration

        cleanupExpiredLaunches()

        let runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let cgWindows = CGWindowExtensions.eligibleWindows()
        log.log("refreshAppGroups: appGroups=\(appGroups.count) runningApps=\(runningApps.count) cgWindows=\(cgWindows.count)")

        let chromePids = runningApps.filter { $0.bundleIdentifier?.contains("chrome") == true || $0.bundleIdentifier?.contains("Chrom") == true }.map { "\($0.processIdentifier):\($0.bundleIdentifier ?? "?")" }
        if !chromePids.isEmpty {
            log.log("Chrome processes found: \(chromePids.joined(separator: ", "))")
        }

        let duplicateIDs = Dictionary(grouping: appGroups, by: { $0.bundleIdentifier }).filter { $0.value.count > 1 }
        if !duplicateIDs.isEmpty {
            log.log("DUPLICATE bundle IDs detected: \(duplicateIDs.map { "\($0.key):\($0.value.count)" }.joined(separator: ", "))")
        }

        let existingMap = Dictionary(appGroups.map { ($0.bundleIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        let pinnedIDs = TaskbarSettings.shared.pinnedBundleIdentifiers
        let previousBundlesWithWindows = Set(
            appGroups.filter { !$0.windows.isEmpty }.map(\.bundleIdentifier)
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            var axMap: [pid_t: [WindowInfo]] = [:]
            for app in runningApps {
                guard app.isTerminated == false else { continue }
                axMap[app.processIdentifier] = self.accessibilityService.windowsForPID(app.processIdentifier)
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard generation == self.refreshGeneration else {
                    self.refreshInFlight = false
                    if self.refreshQueued {
                        self.refreshAppGroups()
                    }
                    return
                }
                self.buildAndApplyAppGroups(
                    runningApps: runningApps,
                    cgWindows: cgWindows,
                    axMap: axMap,
                    existingMap: existingMap,
                    pinnedIDs: pinnedIDs,
                    previousBundlesWithWindows: previousBundlesWithWindows
                )
                self.refreshInFlight = false
                if self.refreshQueued {
                    self.refreshAppGroups()
                }
            }
        }
    }

    private func buildAndApplyAppGroups(
        runningApps: [NSRunningApplication],
        cgWindows: [WindowInfo],
        axMap: [pid_t: [WindowInfo]],
        existingMap: [String: AppGroup],
        pinnedIDs: [String],
        previousBundlesWithWindows: Set<String>
    ) {
        log.log("buildAndApplyAppGroups: runningApps=\(runningApps.count) cgWindows=\(cgWindows.count) axMap keys=\(axMap.keys) existingMap=\(existingMap.count) pinned=\(pinnedIDs.count)")

        // Log per-PID AX window counts
        for (pid, windows) in axMap {
            let bid = runningApps.first { $0.processIdentifier == pid }?.bundleIdentifier ?? "?"
            log.log("  AX: pid=\(pid) bid=\(bid) windows=\(windows.count)")
        }

        var updatedGroups: [AppGroup] = []
        var runningBundleIDs = Set<String>()
        var insertionResolver = WindowGroupingEngine.InsertionOrderResolver(
            nextOrder: nextInsertionOrder,
            savedOrders: savedInsertionOrders
        )

        for app in runningApps {
            let pid = app.processIdentifier
            let bundleID = app.bundleIdentifier ?? "unknown-\(pid)"
            runningBundleIDs.insert(bundleID)
            let appWindows = cgWindows.filter { $0.pid == pid }
            let axWindows = axMap[pid] ?? []
            var mergedWindows = WindowGroupingEngine.mergeWindows(axWindows: axWindows, cgWindows: appWindows)
            if !pendingRemovedWindowIDs.isEmpty {
                mergedWindows.removeAll { pendingRemovedWindowIDs.contains($0.windowID) }
            }
            mergedWindows.sort { $0.windowID < $1.windowID }

            let order = insertionResolver.order(
                for: bundleID,
                existing: existingMap[bundleID]?.insertionOrder,
                now: Date(),
                ttl: insertionOrderTTL
            )

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
        nextInsertionOrder = insertionResolver.nextOrder
        savedInsertionOrders = insertionResolver.savedOrders

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
                if WindowGroupingEngine.shouldKeepLaunching(
                    hasWindows: !updatedGroups[i].windows.isEmpty,
                    startedAt: launchStartedAt[bundleID] ?? Date(),
                    now: Date(),
                    grace: backgroundedLaunchGrace
                ) {
                    updatedGroups[i].isLaunching = true
                } else {
                    launchingBundleIDs.remove(bundleID)
                    launchTimeouts.removeValue(forKey: bundleID)
                    launchStartedAt.removeValue(forKey: bundleID)
                }
            }
        }

        updatedGroups = WindowGroupingEngine.sortGroups(updatedGroups, pinnedIDs: pinnedIDs)

        for group in updatedGroups {
            if !group.windows.isEmpty {
                appsSeenWithWindows.insert(group.bundleIdentifier)
            }
        }

        if TaskbarSettings.shared.quitOnLastWindowClose {
            for group in updatedGroups where group.windows.isEmpty {
                guard group.bundleIdentifier != "com.apple.finder" else { continue }
                guard !TaskbarSettings.shared.isNeverQuit(group.bundleIdentifier) else { continue }
                if appsSeenWithWindows.contains(group.bundleIdentifier) {
                    group.runningApplication?.terminate()
                }
            }
        }

        for group in updatedGroups where group.windows.isEmpty && !TaskbarSettings.shared.isPinned(group.bundleIdentifier) && !group.isLaunching {
            savedInsertionOrders[group.bundleIdentifier] = (group.insertionOrder, Date())
        }

        for i in updatedGroups.indices where !launchingBundleIDs.contains(updatedGroups[i].bundleIdentifier) {
            updatedGroups[i].isLaunching = false
        }

        closedApps.removeAll()
        closedApps = WindowGroupingEngine.closedAppCandidates(
            from: updatedGroups,
            previousBundlesWithWindows: previousBundlesWithWindows,
            ownBundleID: Bundle.main.bundleIdentifier,
            neverQuitBundleIDs: Set(TaskbarSettings.shared.neverQuitBundleIdentifiers),
            isAlive: { group in group.runningApplication?.isTerminated == false }
        )
        log.log("buildAndApplyAppGroups: closedApps=\(closedApps.count)")

        // A background AX read can race a poll snapshot. If we already know
        // this app had windows, keep the group so a transient empty read does
        // not drop its icon — unless the poll already confirmed the close by
        // removing the group from the current state, in which case a stale
        // rebuild must not resurrect it.
        let currentBundleIDs = Set(appGroups.map(\.bundleIdentifier))
        appGroups = updatedGroups.filter { group in
            WindowGroupingEngine.keepGroupAfterRebuild(
                group,
                previousBundlesWithWindows: previousBundlesWithWindows,
                currentBundleIDs: currentBundleIDs,
                pinnedBundleIDs: Set(pinnedIDs)
            )
        }

        let liveWindowIDs = Set(appGroups.flatMap(\.windows).map(\.windowID))
        missTracker.prune(keeping: liveWindowIDs)
        pendingRemovedWindowIDs.removeAll()

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
                      WindowGroupingEngine.isZoomedFrame(liveFrame, visibleFrame: screen.visibleFrame)
                else { continue }

                let tbTop = taskbarTop(for: screen)
                let windowBottom = liveFrame.minY

                guard windowBottom < tbTop,
                      let targetHeight = WindowGroupingEngine.constrainedTargetHeight(
                          frame: liveFrame,
                          visibleFrame: screen.visibleFrame,
                          taskbarTop: tbTop
                      )
                else { continue }

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

    private func handleAppLaunched(_ app: NSRunningApplication) {
        axObserverManager.addObserver(for: app.processIdentifier)
        if let bundleID = app.bundleIdentifier {
            if !appGroups.contains(where: { $0.bundleIdentifier == bundleID && !$0.windows.isEmpty }) {
                launchingBundleIDs.insert(bundleID)
                launchTimeouts[bundleID] = Date().addingTimeInterval(launchTimeoutDuration)
                launchStartedAt[bundleID] = Date()
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
            launchStartedAt.removeValue(forKey: bundleID)
            savedInsertionOrders.removeValue(forKey: bundleID)
        }
        refreshAppGroups()
    }

    private func cleanupExpiredLaunches() {
        let now = Date()
        for (bundleID, timeout) in launchTimeouts {
            if now >= timeout {
                launchingBundleIDs.remove(bundleID)
                launchTimeouts.removeValue(forKey: bundleID)
                launchStartedAt.removeValue(forKey: bundleID)
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
        let groups = appGroups
        for i in groups.indices {
            guard i < appGroups.count else { continue }
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
        let groups = appGroups
        for i in groups.indices {
            guard i < appGroups.count else { continue }
            guard appGroups[i].runningApplication?.processIdentifier == pid else { continue }
            if let j = appGroups[i].windows.firstIndex(where: { $0.windowID == windowID }) {
                appGroups[i].windows[j].isMinimized = true
                missTracker.hit(windowID: windowID)
                pendingRemovedWindowIDs.remove(windowID)
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
        let groups = appGroups
        for i in groups.indices {
            guard i < appGroups.count else { continue }
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
        let groups = appGroups
        for i in groups.indices {
            guard i < appGroups.count else { continue }
            guard appGroups[i].runningApplication?.processIdentifier == pid else { continue }
            if !appGroups[i].windows.contains(where: { $0.windowID == info.windowID }) {
                appGroups[i].windows.append(info)
                appGroups[i].windows.sort { $0.windowID < $1.windowID }
                removeClosedApp(bundleIdentifier: appGroups[i].bundleIdentifier)
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
        let cgWindows = CGWindowExtensions.eligibleWindows()
        let stillInCG = cgWindows.contains { $0.windowID == windowID }
        if stillInCG {
            refreshAppGroups()
            return
        }
        let removalResult = WindowGroupingEngine.removingWindow(
            windowID,
            from: appGroups,
            pinnedBundleIDs: TaskbarSettings.shared.pinnedBundleIdentifiers
        )
        appGroups = removalResult.groups
        missTracker.hit(windowID: windowID)
        pendingRemovedWindowIDs.insert(windowID)
        for group in removalResult.closed {
            savedInsertionOrders[group.bundleIdentifier] = (group.insertionOrder, Date())
            addClosedApp(group)
        }
        for group in appGroups where group.windows.isEmpty {
            addClosedApp(group)
        }
        notifyChanged()
    }

    private func notifyChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onAppGroupsChanged?()
            self.updateFullscreenScreens()
        }
    }

    private func updateFullscreenScreens() {
        guard TaskbarSettings.shared.hideOnFullscreen else {
            if !lastFullscreenScreenIDs.isEmpty {
                lastFullscreenScreenIDs.removeAll()
                onFullscreenScreensChanged?([])
            }
            return
        }

        var screens: [NSScreen] = []
        var ids = Set<CGDirectDisplayID>()

        for screen in screensWithCoveringWindows() {
            let id = screen.displayID
            if ids.insert(id).inserted {
                screens.append(screen)
            }
        }

        for group in appGroups {
            for window in group.windows where !window.isMinimized && window.isFullscreen {
                guard let screen = screenContaining(frame: window.frame) else { continue }
                let id = screen.displayID
                if ids.insert(id).inserted {
                    screens.append(screen)
                }
            }
        }

        if let frontApp = NSWorkspace.shared.frontmostApplication {
            for screen in screensWithAXFullscreen(app: frontApp) {
                let id = screen.displayID
                if ids.insert(id).inserted {
                    screens.append(screen)
                }
            }
        }

        guard ids != lastFullscreenScreenIDs else { return }
        guard onFullscreenScreensChanged != nil else { return }
        lastFullscreenScreenIDs = ids
        onFullscreenScreensChanged?(screens)
    }

    private func screensWithCoveringWindows() -> [NSScreen] {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let ourPid = ProcessInfo.processInfo.processIdentifier
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var result: [NSScreen] = []
        var seen = Set<ObjectIdentifier>()

        for screen in NSScreen.screens {
            let cgScreen = cgBounds(for: screen)
            let screenArea = cgScreen.width * cgScreen.height
            guard screenArea > 0 else { continue }

            var frontmostCovers = false

            for info in windowList {
                guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ourPid,
                      let alpha = info[kCGWindowAlpha as String] as? Double, alpha > 0,
                      let layer = info[kCGWindowLayer as String] as? Int,
                      layer >= 0, layer <= 3, // kCGNormalWindowLevel...kCGFloatingWindowLevel
                      let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat]
                else { continue }

                let frame = CGRect(
                    x: boundsDict["X"] ?? 0,
                    y: boundsDict["Y"] ?? 0,
                    width: boundsDict["Width"] ?? 0,
                    height: boundsDict["Height"] ?? 0
                )

                // Only normal-level (0) and floating-level (3) windows can be an
                // app's fullscreen window. Everything else is an overlay that
                // must not hide the taskbar:
                //   - background windows (Finder desktop, wallpaper, backstop)
                //     live below 0 and always cover the whole screen;
                //   - Chrome/Finder periodically create anonymous full-screen
                //     overlay windows at layer 500, and the Screenshot app owns
                //     a persistent full-screen overlay at layer 24. Without this
                //     filter, the taskbar would hide whenever the frontmost app
                //     has such an overlay on screen (e.g. while using Chrome).
                //
                // >=0.98 separates true fullscreen (Chrome HTML5 video fullscreen covers
                // the full screen, 1.0) from large windowed/maximized windows
                // (max ~0.97 with a visible menu bar).
                let coverage = WindowGroupingEngine.coverageRatio(frame, in: cgScreen)
                guard coverage >= 0.98 else { continue }

                if let frontmostPID = frontmostPID, pid == frontmostPID {
                    frontmostCovers = true
                    break
                }
            }

            guard frontmostCovers else { continue }

            let id = ObjectIdentifier(screen)
            if seen.insert(id).inserted {
                result.append(screen)
            }
        }

        return result
    }

    private func screensWithAXFullscreen(app: NSRunningApplication) -> [NSScreen] {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let axWindows = value as? [AXUIElement] else {
            return []
        }

        var screens: [NSScreen] = []
        var seen = Set<ObjectIdentifier>()

        for element in axWindows {
            var fullscreenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &fullscreenRef) == .success,
                  let isFullscreen = fullscreenRef as? Bool, isFullscreen else {
                continue
            }

            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
            AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)

            var frame = CGRect.zero
            if let posValue = positionRef, let sizeValue = sizeRef {
                var point = CGPoint.zero
                var size = CGSize.zero
                if CFGetTypeID(posValue) == AXValueGetTypeID(),
                   AXValueGetType(posValue as! AXValue) == .cgPoint {
                    AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
                }
                if CFGetTypeID(sizeValue) == AXValueGetTypeID(),
                   AXValueGetType(sizeValue as! AXValue) == .cgSize {
                    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
                }
                frame = CGRect(origin: point, size: size)
            }

            guard let screen = screenContaining(frame: frame) else { continue }
            let id = ObjectIdentifier(screen)
            if seen.insert(id).inserted {
                screens.append(screen)
            }
        }

        return screens
    }

    private func cgBounds(for screen: NSScreen) -> CGRect {
        let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.main
        let primaryFrame = primary?.frame ?? screen.frame
        return WindowGroupingEngine.cgBounds(screenFrame: screen.frame, primaryScreenFrame: primaryFrame)
    }

    func recordWindowFocus(bundleIdentifier: String, windowID: CGWindowID) {
        lastFocusedWindow[bundleIdentifier] = windowID
    }

    func activateApp(at index: Int) {
        guard index < appGroups.count else { return }
        let group = appGroups[index]

        if group.bundleIdentifier == "com.apple.finder" && group.windows.isEmpty {
            let script = """
            tell application "Finder"
                activate
                open POSIX file "\(NSHomeDirectory())"
            end tell
            """
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            if let error {
                print("Failed to open Finder home folder: \(error)")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.refreshAppGroups()
            }
            return
        }

        guard let app = group.runningApplication else {
            let bundleID = group.bundleIdentifier
            if launchingBundleIDs.contains(bundleID) { return }
            launchingBundleIDs.insert(bundleID)
            launchTimeouts[bundleID] = Date().addingTimeInterval(launchTimeoutDuration)
            launchStartedAt[bundleID] = Date()
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
            let isNeverQuit = TaskbarSettings.shared.isNeverQuit(group.bundleIdentifier)
            let neverQuitItem = NSMenuItem(title: isNeverQuit ? "Allow Quit When Closed" : "Don't Quit When Closed", action: #selector(MenuItemActions.shared.toggleNeverQuit(_:)), keyEquivalent: "")
            neverQuitItem.target = MenuItemActions.shared
            neverQuitItem.representedObject = ["bundleID": group.bundleIdentifier]
            neverQuitItem.state = isNeverQuit ? .on : .off
            menu.addItem(neverQuitItem)
        }

        if group.isRunning {
            menu.addItem(NSMenuItem.separator())

            let quitMenu = NSMenu()
            let quitSubItem = NSMenuItem(title: "Quit", action: nil, keyEquivalent: "")
            quitSubItem.submenu = quitMenu
            menu.addItem(quitSubItem)

            let quitItem = NSMenuItem(title: "Quit \(appName)", action: #selector(MenuItemActions.shared.quitApp(_:)), keyEquivalent: "q")
            quitItem.target = MenuItemActions.shared
            quitItem.representedObject = ["bundleID": group.bundleIdentifier]
            quitMenu.addItem(quitItem)

            let hasAppsToRight = (index + 1) < appGroups.count && !appGroups[(index + 1)...].allSatisfy { !$0.isRunning }
            if hasAppsToRight {
                let quitRightItem = NSMenuItem(title: "Quit Apps to the Right", action: #selector(MenuItemActions.shared.quitAppsToTheRight(_:)), keyEquivalent: "")
                quitRightItem.target = MenuItemActions.shared
                quitRightItem.representedObject = ["index": index]
                quitMenu.addItem(quitRightItem)
            }

            quitMenu.addItem(NSMenuItem.separator())

            let forceQuitItem = NSMenuItem(title: "Force Quit \(appName)", action: #selector(MenuItemActions.shared.forceQuitApp(_:)), keyEquivalent: "")
            forceQuitItem.target = MenuItemActions.shared
            forceQuitItem.representedObject = ["bundleID": group.bundleIdentifier]
            quitMenu.addItem(forceQuitItem)
        }

        return menu
    }

    func removeWindow(withID windowID: CGWindowID) {
        let removalResult = WindowGroupingEngine.removingWindow(
            windowID,
            from: appGroups,
            pinnedBundleIDs: TaskbarSettings.shared.pinnedBundleIdentifiers
        )
        appGroups = removalResult.groups
        for group in removalResult.closed {
            savedInsertionOrders[group.bundleIdentifier] = (group.insertionOrder, Date())
        }
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
        let movedBundleID = sourceIndex < appGroups.count ? appGroups[sourceIndex].bundleIdentifier : nil
        let reorderResult = WindowGroupingEngine.reorderGroups(
            appGroups,
            from: sourceIndex,
            to: destinationIndex,
            pinnedIDs: TaskbarSettings.shared.pinnedBundleIdentifiers
        )
        guard reorderResult.didReorder, let nextOrder = reorderResult.nextOrder else { return }
        appGroups = reorderResult.groups
        nextInsertionOrder = nextOrder
        if reorderResult.pinnedBundleIDs != nil, let movedBundleID {
            TaskbarSettings.shared.reorderPinned(bundleID: movedBundleID, to: destinationIndex)
        }
        notifyChanged()
    }
}

final class MenuItemActions: NSObject {
    static let shared = MenuItemActions()

    var onWindowActivated: ((CGWindowID, pid_t) -> Void)?
    var onTogglePin: ((String) -> Void)?
    var onToggleNeverQuit: ((String) -> Void)?
    var onQuitAllClosed: (() -> Void)?
    var onQuitAllApps: (() -> Void)?
    var onOpenPreferences: (() -> Void)?
    var onForceQuitApp: ((String) -> Void)?
    var onQuitAppsToTheRight: ((Int) -> Void)?
    var onShowDesktop: (() -> Void)?
    var onOpenActivityMonitor: (() -> Void)?

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

    @objc func forceQuitApp(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let bundleID = info["bundleID"] else { return }
        onForceQuitApp?(bundleID)
    }

    @objc func quitAppsToTheRight(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Int],
              let index = info["index"] else { return }
        onQuitAppsToTheRight?(index)
    }

    @objc func togglePin(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let bundleID = info["bundleID"] else { return }
        onTogglePin?(bundleID)
    }

    @objc func toggleNeverQuit(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: String],
              let bundleID = info["bundleID"] else { return }
        onToggleNeverQuit?(bundleID)
    }

    @objc func quitAllClosed(_ sender: NSMenuItem) {
        onQuitAllClosed?()
    }

    @objc func quitAllApps(_ sender: NSMenuItem) {
        onQuitAllApps?()
    }

    @objc func openPreferences(_ sender: NSMenuItem) {
        onOpenPreferences?()
    }

    @objc func showDesktop(_ sender: NSMenuItem) {
        onShowDesktop?()
    }

    @objc func openActivityMonitor(_ sender: NSMenuItem) {
        onOpenActivityMonitor?()
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
        let script = """
        tell application "Finder"
            activate
            open POSIX file "\(path)"
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error {
            print("Failed to open folder in Finder: \(error)")
        }
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
