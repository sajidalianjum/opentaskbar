import AppKit

enum ScreenGeometry {
    static let defaultTaskbarHeight: CGFloat = 48

    static func taskbarRect(for screen: NSScreen, height: CGFloat = defaultTaskbarHeight) -> NSRect {
        let screenFrame = screen.visibleFrame
        let fullScreenFrame = screen.frame

        let yPosition: CGFloat
        if screenFrame.origin.y > 1 {
            yPosition = screenFrame.origin.y - height
        } else {
            yPosition = fullScreenFrame.origin.y
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