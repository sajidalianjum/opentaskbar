import AppKit

enum ScreenGeometry {
    static let dockStyleBottomOffset: CGFloat = 6

    static func taskbarHeight(forIconSize iconSize: CGFloat) -> CGFloat {
        iconSize + 12
    }

    static func taskbarRect(frame: NSRect, height: CGFloat, isDockStyle: Bool = false) -> NSRect {
        var yPosition = frame.origin.y

        if isDockStyle {
            yPosition += dockStyleBottomOffset
        }

        return NSRect(
            x: frame.origin.x,
            y: yPosition,
            width: frame.width,
            height: height
        )
    }

    static func taskbarRect(for screen: NSScreen, height: CGFloat, isDockStyle: Bool = false) -> NSRect {
        taskbarRect(frame: screen.frame, height: height, isDockStyle: isDockStyle)
    }

    static func mainScreen() -> NSScreen? {
        NSScreen.main
    }

    static func screenHeight(for screen: NSScreen) -> CGFloat {
        screen.frame.height
    }

    static func screenScale(for screen: NSScreen) -> CGFloat {
        screen.backingScaleFactor
    }
}
