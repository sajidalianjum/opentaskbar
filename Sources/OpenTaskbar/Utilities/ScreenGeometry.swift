import AppKit

enum ScreenGeometry {
    static let dockModeBottomOffset: CGFloat = 6

    static func taskbarHeight(forIconSize iconSize: CGFloat) -> CGFloat {
        iconSize + 12
    }

    static func taskbarRect(for screen: NSScreen, height: CGFloat, dockMode: Bool = false) -> NSRect {
        let fullScreenFrame = screen.frame
        var yPosition = fullScreenFrame.origin.y

        if dockMode {
            yPosition += dockModeBottomOffset
        }

        return NSRect(
            x: fullScreenFrame.origin.x,
            y: yPosition,
            width: fullScreenFrame.width,
            height: height
        )
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