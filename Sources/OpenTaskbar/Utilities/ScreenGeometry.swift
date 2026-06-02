import AppKit

enum ScreenGeometry {
    static let compactBarBottomOffset: CGFloat = 6

    static func taskbarHeight(forIconSize iconSize: CGFloat) -> CGFloat {
        iconSize + 12
    }

    static func taskbarRect(for screen: NSScreen, height: CGFloat, compactBar: Bool = false, dockReservesSpace: Bool = false) -> NSRect {
        let fullScreenFrame = screen.frame

        var yPosition: CGFloat
        if dockReservesSpace {
            let screenFrame = screen.visibleFrame
            yPosition = screenFrame.origin.y > 1 ? screenFrame.origin.y - height : fullScreenFrame.origin.y
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