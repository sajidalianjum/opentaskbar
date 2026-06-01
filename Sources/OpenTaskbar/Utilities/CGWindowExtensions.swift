import CoreGraphics
import ApplicationServices

enum CGWindowExtensions {
    static func eligibleWindows() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let ourPid = ProcessInfo.processInfo.processIdentifier

        return windowList.compactMap { info -> WindowInfo? in
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pid != ourPid,
                  let windowID = info[kCGWindowNumber as String] as? CGWindowID,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let alpha = info[kCGWindowAlpha as String] as? Double,
                  alpha > 0
            else { return nil }

            let title = info[kCGWindowName as String] as? String ?? ""
            let ownerName = info[kCGWindowOwnerName as String] as? String
            let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let frame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            guard frame.width > 50 && frame.height > 50 else { return nil }

            let isMinimized = false
            let isFullscreen = info["kCGIsFullscreen"] as? Bool ?? false

            return WindowInfo(
                windowID: windowID,
                pid: pid,
                title: title,
                frame: frame,
                isMinimized: isMinimized,
                isFullscreen: isFullscreen,
                layer: layer,
                alpha: alpha,
                ownerName: ownerName
            )
        }
    }

    static func windowInfo(for windowID: CGWindowID) -> WindowInfo? {
        guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        guard let info = windowList.first(where: { $0[kCGWindowNumber as String] as? CGWindowID == windowID }) else {
            return nil
        }

        guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
              let windowID = info[kCGWindowNumber as String] as? CGWindowID,
              let layer = info[kCGWindowLayer as String] as? Int,
              let alpha = info[kCGWindowAlpha as String] as? Double
        else { return nil }

        let title = info[kCGWindowName as String] as? String ?? ""
        let ownerName = info[kCGWindowOwnerName as String] as? String
        let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
        let frame = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        return WindowInfo(
            windowID: windowID,
            pid: pid,
            title: title,
            frame: frame,
            isMinimized: false,
            isFullscreen: false,
            layer: layer,
            alpha: alpha,
            ownerName: ownerName
        )
    }
}