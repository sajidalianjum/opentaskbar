import AppKit

extension NSScreen {
    var displayID: CGDirectDisplayID {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
}

enum ScreenGeometry {
    static let dockStyleBottomOffset: CGFloat = 6

    /// Invisible strip that hangs below the screen edge. The panel keeps the
    /// visible bar exactly where it was and grows downwards, so clicks at the
    /// very bottom of the display still reach the taskbar buttons (Windows
    /// behaviour) instead of falling through to the window behind.
    static let edgeHotZoneSlop: CGFloat = 8

    /// Dead space between a vertically centered button and the bar edges.
    static let hitTestVerticalSlop: CGFloat = 2

    static let hitTestBottomTolerance: CGFloat = edgeHotZoneSlop + hitTestVerticalSlop

    /// Tracking rect for a taskbar item: the item itself plus the invisible strip
    /// below it, so hovering anywhere between the icon and the bottom edge of the
    /// screen counts as hovering the item (Windows behaviour).
    static func hoverTrackingRect(for bounds: NSRect, bottomSlop: CGFloat = hitTestBottomTolerance) -> NSRect {
        NSRect(
            x: bounds.minX,
            y: bounds.minY - bottomSlop,
            width: bounds.width,
            height: bounds.height + bottomSlop
        )
    }

    static func taskbarHeight(forIconSize iconSize: CGFloat) -> CGFloat {
        iconSize + 12
    }

    /// Height of the backing panel: the visible bar plus the off-screen hot zone.
    static func panelHeight(barHeight: CGFloat, hotZoneSlop: CGFloat = edgeHotZoneSlop) -> CGFloat {
        barHeight + hotZoneSlop
    }

    static func taskbarRect(frame: NSRect, height: CGFloat, isDockStyle: Bool = false, hotZoneSlop: CGFloat = edgeHotZoneSlop) -> NSRect {
        var yPosition = frame.origin.y

        if isDockStyle {
            yPosition += dockStyleBottomOffset
        }

        yPosition -= hotZoneSlop

        return NSRect(
            x: frame.origin.x,
            y: yPosition,
            width: frame.width,
            height: height + hotZoneSlop
        )
    }

    /// Stretches neighbouring rects so the gaps between them are clickable,
    /// without growing the outermost rects.
    static func gapFilledRects(_ rects: [NSRect]) -> [NSRect] {
        let sorted = rects.sorted { $0.minX < $1.minX }
        guard sorted.count > 1 else { return sorted }

        var filled = sorted
        for i in 1..<filled.count {
            let mid = (sorted[i - 1].maxX + sorted[i].minX) / 2
            filled[i - 1].size.width = max(filled[i - 1].width, mid - filled[i - 1].minX)
            filled[i].origin.x = min(filled[i].minX, mid)
            filled[i].size.width = sorted[i].maxX - filled[i].minX
        }
        return filled
    }

    /// Index of the rect that should receive a click that landed outside every
    /// button. `bottomTolerance` reaches all the way to the screen edge.
    static func forgivingHitIndex(
        in rects: [NSRect],
        point: NSPoint,
        topTolerance: CGFloat = hitTestVerticalSlop,
        bottomTolerance: CGFloat = hitTestBottomTolerance
    ) -> Int? {
        let filled = gapFilledRects(rects)
        for (index, rect) in filled.enumerated() {
            let horizontalMatch = point.x >= rect.minX && point.x <= rect.maxX
            let verticalMatch = point.y >= rect.minY - bottomTolerance && point.y <= rect.maxY + topTolerance
            if horizontalMatch && verticalMatch {
                return index
            }
        }
        return nil
    }

    static func taskbarRect(for screen: NSScreen, height: CGFloat, isDockStyle: Bool = false, hotZoneSlop: CGFloat = edgeHotZoneSlop) -> NSRect {
        taskbarRect(frame: screen.frame, height: height, isDockStyle: isDockStyle, hotZoneSlop: hotZoneSlop)
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
