import AppKit

enum ScreenGeometry {
    static let compactBarBottomOffset: CGFloat = 6

    static func taskbarHeight(forIconSize iconSize: CGFloat) -> CGFloat {
        iconSize + 24
    }

    static func taskbarRect(for screen: NSScreen, height: CGFloat, compactBar: Bool = false) -> NSRect {
        let screenFrame = screen.visibleFrame
        let fullScreenFrame = screen.frame

        var yPosition: CGFloat
        if screenFrame.origin.y > 1 {
            yPosition = screenFrame.origin.y - height
        } else {
            yPosition = fullScreenFrame.origin.y
        }

        if compactBar {
            yPosition += compactBarBottomOffset
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