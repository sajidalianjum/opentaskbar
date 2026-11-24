import XCTest
@testable import OpenTaskbar

final class TaskbarLayoutTests: XCTestCase {
    func testTaskbarBackgroundExtendsThroughBottomHotZone() {
        let barHeight = ScreenGeometry.taskbarHeight(forIconSize: 32)
        let panelHeight = ScreenGeometry.panelHeight(barHeight: barHeight)
        let background = backgroundFrame(style: .taskbar, panelHeight: panelHeight)

        XCTAssertEqual(background.minY, 0)
        XCTAssertEqual(background.maxY, panelHeight)
    }

    func testDockBackgroundKeepsVisiblePillHeight() {
        let barHeight = ScreenGeometry.taskbarHeight(forIconSize: 32)
        let panelHeight = ScreenGeometry.panelHeight(barHeight: barHeight)
        let background = backgroundFrame(style: .dock, panelHeight: panelHeight)

        XCTAssertEqual(background.minY, ScreenGeometry.edgeHotZoneSlop)
        XCTAssertEqual(background.height, barHeight)
    }

    private func backgroundFrame(style: TaskbarSettings.TaskbarStyle, panelHeight: CGFloat) -> NSRect {
        let settings = TaskbarSettings.shared
        let originalStyle = settings.style
        let originalIconSize = settings.iconSize
        settings.iconSize = 32
        settings.style = style

        let windowManager = WindowManager()
        defer {
            windowManager.stop()
            settings.style = originalStyle
            settings.iconSize = originalIconSize
        }

        let contentView = TaskbarContentView(windowManager: windowManager)
        contentView.frame = NSRect(x: 0, y: 0, width: 800, height: panelHeight)
        contentView.layoutSubtreeIfNeeded()

        guard let background = contentView.subviews.first(where: { $0 is NSVisualEffectView }) else {
            XCTFail("Taskbar background view is missing")
            return .zero
        }
        return background.frame
    }
}
