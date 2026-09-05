import XCTest
import CoreGraphics
@testable import OpenTaskbar

func makeWindow(
    id: CGWindowID,
    pid: pid_t = 1,
    title: String = "",
    frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600),
    minimized: Bool = false,
    fullscreen: Bool = false,
    layer: Int = 0,
    alpha: Double = 1.0
) -> WindowInfo {
    WindowInfo(
        windowID: id,
        pid: pid,
        title: title,
        frame: frame,
        isMinimized: minimized,
        isFullscreen: fullscreen,
        layer: layer,
        alpha: alpha,
        ownerName: "Test"
    )
}

func makeGroup(
    bundleID: String,
    windows: [WindowInfo] = [],
    isLaunching: Bool = false,
    insertionOrder: Int = 0,
    runningApplication: NSRunningApplication? = nil
) -> AppGroup {
    AppGroup(
        bundleIdentifier: bundleID,
        localizedName: bundleID,
        icon: NSImage(),
        runningApplication: runningApplication,
        windows: windows,
        isActive: false,
        insertionOrder: insertionOrder,
        isLaunching: isLaunching
    )
}
