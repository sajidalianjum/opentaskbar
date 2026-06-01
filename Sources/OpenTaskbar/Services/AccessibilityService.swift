import AppKit
import ApplicationServices

final class AccessibilityService {
    private typealias AXUIElementGetWindowFunc = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private var axGetWindow: AXUIElementGetWindowFunc?

    init() {
        loadPrivateAPIs()
    }

    private func loadPrivateAPIs() {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        if let sym = dlsym(rtldDefault, "_AXUIElementGetWindow") {
            axGetWindow = unsafeBitCast(sym, to: AXUIElementGetWindowFunc.self)
        }
    }

    func windowsForPID(_ pid: pid_t) -> [WindowInfo] {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)

        guard err == .success, let axWindows = value as? [AXUIElement] else {
            return []
        }

        return axWindows.compactMap { element -> WindowInfo? in
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String) ?? ""

            var minimizedRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &minimizedRef)
            let isMinimized = (minimizedRef as? Bool) ?? false

            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef)
            AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef)

            var frame = CGRect.zero
            if let posValue = positionRef, let sizeValue = sizeRef {
                var point = CGPoint.zero
                var size = CGSize.zero
                if AXValueGetType(posValue as! AXValue) == .cgPoint {
                    AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
                }
                if AXValueGetType(sizeValue as! AXValue) == .cgSize {
                    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
                }
                frame = CGRect(origin: point, size: size)
            }

            var subroleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleRef)
            let subrole = subroleRef as? String ?? ""
            guard subrole == kAXStandardWindowSubrole as String || subrole == kAXDialogSubrole as String || subrole.isEmpty else {
                return nil
            }

            guard let windowID = cgWindowID(from: element) else { return nil }

            var isFullscreen = false
            var fullscreenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &fullscreenRef) == .success {
                isFullscreen = fullscreenRef as? Bool ?? false
            }

            return WindowInfo(
                windowID: windowID,
                pid: pid,
                title: title,
                frame: frame,
                isMinimized: isMinimized,
                isFullscreen: isFullscreen,
                layer: 0,
                alpha: 1.0,
                ownerName: nil
            )
        }
    }

    func cgWindowID(from element: AXUIElement) -> CGWindowID? {
        var windowID: CGWindowID = 0
        guard let axGetWindow = axGetWindow else { return nil }
        let err = axGetWindow(element, &windowID)
        return err == .success ? windowID : nil
    }

    func raiseWindow(_ element: AXUIElement, app: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, element)

        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)

        app.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            app.activate()
        }
    }

    func minimizeWindow(_ element: AXUIElement) {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    func unminimizeWindow(_ element: AXUIElement) {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }

    func closeWindow(_ element: AXUIElement) {
        var closeButton: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXCloseButtonAttribute as CFString, &closeButton) == .success,
              let button = closeButton else { return }
        AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
    }

    func toggleFullscreen(_ element: AXUIElement) {
        var isFullscreen = false
        var fullscreenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &fullscreenRef) == .success {
            isFullscreen = fullscreenRef as? Bool ?? false
        }
        AXUIElementSetAttributeValue(element, "AXFullScreen" as CFString, (!isFullscreen) as CFBoolean)
    }

    func windowElement(for windowID: CGWindowID, pid: pid_t) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let axWindows = value as? [AXUIElement] else {
            return nil
        }

        for window in axWindows {
            if let id = cgWindowID(from: window), id == windowID {
                return window
            }
        }
        return nil
    }
}