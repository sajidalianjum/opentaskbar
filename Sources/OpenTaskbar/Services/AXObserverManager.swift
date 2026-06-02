import ApplicationServices

private var sharedManager: AXObserverManager?

final class AXObserverManager {
    private var observers: [pid_t: AXObserver] = [:]
    private var runLoopSources: [pid_t: CFRunLoopSource] = [:]
    private let axService: AccessibilityService

    var onWindowCreated: ((pid_t, AXUIElement) -> Void)?
    var onWindowDestroyed: ((pid_t, AXUIElement) -> Void)?
    var onTitleChanged: ((pid_t, AXUIElement) -> Void)?
    var onWindowMinimized: ((pid_t, AXUIElement) -> Void)?
    var onWindowUnminimized: ((pid_t, AXUIElement) -> Void)?
    var onWindowMoved: ((pid_t, AXUIElement) -> Void)?

    init(axService: AccessibilityService) {
        self.axService = axService
        sharedManager = self
    }

    func addObserver(for pid: pid_t) {
        guard observers[pid] == nil else { return }

        var observer: AXObserver?
        let status = AXObserverCreate(pid, axObserverCallback, &observer)

        guard status == .success, let observer else { return }

        let appElement = AXUIElementCreateApplication(pid)

        let appNotifications: [CFString] = [
            kAXCreatedNotification as CFString,
            kAXUIElementDestroyedNotification as CFString
        ]

        for notification in appNotifications {
            AXObserverAddNotification(observer, appElement, notification, nil)
        }

        let runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        observers[pid] = observer
        runLoopSources[pid] = runLoopSource

        addWindowObserversForApp(pid: pid, appElement: appElement)
    }

    func removeObserver(for pid: pid_t) {
        guard observers[pid] != nil,
              let runLoopSource = runLoopSources[pid] else { return }

        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        observers.removeValue(forKey: pid)
        runLoopSources.removeValue(forKey: pid)
    }

    private func addWindowObserversForApp(pid: pid_t, appElement: AXUIElement) {
        guard let observer = observers[pid] else { return }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let axWindows = value as? [AXUIElement] else { return }

        for window in axWindows {
            var subroleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef)
            let subrole = subroleRef as? String ?? ""

            if subrole == kAXStandardWindowSubrole as String || subrole == kAXDialogSubrole as String || subrole.isEmpty {
                let notifications: [CFString] = [
                    kAXTitleChangedNotification as CFString,
                    kAXWindowMiniaturizedNotification as CFString,
                    kAXWindowDeminiaturizedNotification as CFString,
                    kAXUIElementDestroyedNotification as CFString
                ]
                for notification in notifications {
                    AXObserverAddNotification(observer, window, notification, nil)
                }
            }
        }
    }

    func addWindowObservers(for window: AXUIElement, pid: pid_t) {
        guard let observer = observers[pid] else { return }

        let windowNotifications: [CFString] = [
            kAXTitleChangedNotification as CFString,
            kAXWindowMiniaturizedNotification as CFString,
            kAXWindowDeminiaturizedNotification as CFString,
            kAXUIElementDestroyedNotification as CFString,
            "AXPositionChanged" as CFString,
            "AXSizeChanged" as CFString
        ]

        for notification in windowNotifications {
            AXObserverAddNotification(observer, window, notification, nil)
        }
    }

    func handleNotification(pid: pid_t, element: AXUIElement, notification: String) {
        switch notification {
        case kAXCreatedNotification:
            onWindowCreated?(pid, element)
            addWindowObservers(for: element, pid: pid)

        case kAXUIElementDestroyedNotification:
            onWindowDestroyed?(pid, element)

        case kAXTitleChangedNotification:
            onTitleChanged?(pid, element)

        case kAXWindowMiniaturizedNotification:
            onWindowMinimized?(pid, element)

        case kAXWindowDeminiaturizedNotification:
            onWindowUnminimized?(pid, element)

        case "AXPositionChanged", "AXSizeChanged":
            onWindowMoved?(pid, element)

        default:
            break
        }
    }

    func removeAllObservers() {
        for pid in Array(observers.keys) {
            removeObserver(for: pid)
        }
    }

    deinit {
        removeAllObservers()
        if sharedManager === self {
            sharedManager = nil
        }
    }
}

private func axObserverCallback(_ observer: AXObserver, element: AXUIElement, notification: CFString, refcon: UnsafeMutableRawPointer?) {
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)
    let notifStr = notification as String
    DispatchQueue.main.async {
        sharedManager?.handleNotification(pid: pid, element: element, notification: notifStr)
    }
}