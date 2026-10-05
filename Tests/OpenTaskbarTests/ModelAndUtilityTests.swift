import XCTest
@testable import OpenTaskbar

final class WindowInfoTests: XCTestCase {
    func testValidWindowPassesEligibility() {
        XCTAssertTrue(makeWindow(id: 1).isValid)
    }

    func testZeroAlphaWindowIsInvalid() {
        XCTAssertFalse(makeWindow(id: 1, alpha: 0).isValid)
    }

    func testNonZeroLayerWindowIsInvalid() {
        XCTAssertFalse(makeWindow(id: 1, layer: 1).isValid)
    }

    func testTinyFrameWindowIsInvalid() {
        let tiny = CGRect(x: 0, y: 0, width: 50, height: 50)
        XCTAssertFalse(makeWindow(id: 1, frame: tiny).isValid)
    }

    func testEqualityIgnoresEverythingButWindowID() {
        let a = makeWindow(id: 1, title: "A")
        let b = makeWindow(id: 1, title: "B")
        XCTAssertEqual(a, b)
    }

    func testHashFollowsWindowID() {
        let set: Set<WindowInfo> = [makeWindow(id: 1, title: "A"), makeWindow(id: 1, title: "B"), makeWindow(id: 2)]
        XCTAssertEqual(set.count, 2)
    }
}

final class AppGroupTests: XCTestCase {
    func testEqualityByBundleIdentifierOnly() {
        let empty = makeGroup(bundleID: "com.a")
        let withWindow = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1)])
        XCTAssertEqual(empty, withWindow)
        XCTAssertNotEqual(empty, makeGroup(bundleID: "com.b"))
    }

    func testWindowCountAndMultipleWindows() {
        let single = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1)])
        XCTAssertEqual(single.windowCount, 1)
        XCTAssertFalse(single.hasMultipleWindows)

        let multi = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1), makeWindow(id: 2)])
        XCTAssertEqual(multi.windowCount, 2)
        XCTAssertTrue(multi.hasMultipleWindows)
    }
}

final class ScreenGeometryTests: XCTestCase {
    func testTaskbarHeightScalesWithIconSize() {
        XCTAssertEqual(ScreenGeometry.taskbarHeight(forIconSize: 32), 44)
        XCTAssertEqual(ScreenGeometry.taskbarHeight(forIconSize: 24), 36)
        XCTAssertEqual(ScreenGeometry.taskbarHeight(forIconSize: 48), 60)
    }

    func testTaskbarRectUsesFrameOriginAndHeight() {
        let frame = NSRect(x: 100, y: 50, width: 1440, height: 900)
        let rect = ScreenGeometry.taskbarRect(frame: frame, height: 44)
        XCTAssertEqual(rect.origin.x, 100)
        XCTAssertEqual(rect.width, 1440)
        XCTAssertEqual(rect.height, 44 + ScreenGeometry.edgeHotZoneSlop)
        XCTAssertEqual(rect.origin.y, 50 - ScreenGeometry.edgeHotZoneSlop)
    }

    func testTaskbarRectKeepsVisibleBarInPlace() {
        let frame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = ScreenGeometry.taskbarRect(frame: frame, height: 44)
        XCTAssertEqual(rect.maxY, 44)
        XCTAssertLessThan(rect.minY, frame.minY)
    }

    func testTaskbarRectDockStyleOffsetsFromBottom() {
        let frame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = ScreenGeometry.taskbarRect(frame: frame, height: 44, isDockStyle: true)
        XCTAssertEqual(rect.maxY, ScreenGeometry.dockStyleBottomOffset + 44)
        XCTAssertEqual(rect.height, 44 + ScreenGeometry.edgeHotZoneSlop)
        XCTAssertLessThanOrEqual(rect.minY, frame.minY)
    }

    func testTaskbarRectDockStylePreservesNonZeroOrigin() {
        let frame = NSRect(x: 0, y: 100, width: 1440, height: 900)
        let rect = ScreenGeometry.taskbarRect(frame: frame, height: 44, isDockStyle: true)
        XCTAssertEqual(rect.maxY, 100 + ScreenGeometry.dockStyleBottomOffset + 44)
    }

    func testPanelHeightAddsHotZoneSlop() {
        XCTAssertEqual(ScreenGeometry.panelHeight(barHeight: 44), 44 + ScreenGeometry.edgeHotZoneSlop)
    }

    func testHoverTrackingRectExtendsBelowButton() {
        let button = NSRect(x: 100, y: 10, width: 48, height: 40)
        let rect = ScreenGeometry.hoverTrackingRect(for: button)
        XCTAssertEqual(rect.minX, 100)
        XCTAssertEqual(rect.width, 48)
        XCTAssertEqual(rect.maxY, 50)
        XCTAssertEqual(rect.minY, 10 - ScreenGeometry.hitTestBottomTolerance)
        XCTAssertTrue(rect.contains(NSPoint(x: 120, y: 0)))
    }

    func testHoverTrackingRectMatchesClickAreaDownToPanelBottom() {
        let barHeight = ScreenGeometry.taskbarHeight(forIconSize: 32)
        let panel = ScreenGeometry.panelHeight(barHeight: barHeight)
        let button = NSRect(x: 100, y: panel - barHeight + 2, width: 48, height: barHeight - 4)
        let tracking = ScreenGeometry.hoverTrackingRect(for: button)
        XCTAssertEqual(tracking.minY, 0)
        XCTAssertEqual(tracking.maxY, button.maxY)

        let screenEdgeY = ScreenGeometry.edgeHotZoneSlop
        XCTAssertNotNil(ScreenGeometry.forgivingHitIndex(in: [button], point: NSPoint(x: 120, y: screenEdgeY)))
        XCTAssertTrue(tracking.contains(NSPoint(x: 120, y: screenEdgeY)))
    }

    func testGapFilledRectsCloseInteriorGapsOnly() {
        let rects = [
            NSRect(x: 0, y: 0, width: 40, height: 40),
            NSRect(x: 48, y: 0, width: 40, height: 40),
            NSRect(x: 96, y: 0, width: 40, height: 40),
        ]
        let filled = ScreenGeometry.gapFilledRects(rects)
        XCTAssertEqual(filled.count, 3)
        XCTAssertEqual(filled[0].minX, 0)
        XCTAssertEqual(filled[0].maxX, 44)
        XCTAssertEqual(filled[1].minX, 44)
        XCTAssertEqual(filled[2].maxX, 136)
    }

    func testForgivingHitReachesBottomEdgeOfScreen() {
        let button = NSRect(x: 100, y: 10, width: 48, height: 40)
        let point = NSPoint(x: 120, y: 0)
        XCTAssertEqual(ScreenGeometry.forgivingHitIndex(in: [button], point: point), 0)
    }

    func testForgivingHitRespectsBottomTolerance() {
        let button = NSRect(x: 100, y: 10, width: 48, height: 40)
        let tooLow = NSPoint(x: 120, y: 10 - ScreenGeometry.hitTestBottomTolerance - 0.5)
        XCTAssertNil(ScreenGeometry.forgivingHitIndex(in: [button], point: tooLow))
    }

    func testForgivingHitDoesNotReachDeepAboveButton() {
        let button = NSRect(x: 100, y: 10, width: 48, height: 40)
        let tooHigh = NSPoint(x: 120, y: 50 + ScreenGeometry.hitTestVerticalSlop + 0.5)
        XCTAssertNil(ScreenGeometry.forgivingHitIndex(in: [button], point: tooHigh))
    }

    func testForgivingHitFillsGapBetweenButtons() {
        let rects = [
            NSRect(x: 0, y: 10, width: 48, height: 40),
            NSRect(x: 56, y: 10, width: 48, height: 40),
        ]
        XCTAssertEqual(ScreenGeometry.forgivingHitIndex(in: rects, point: NSPoint(x: 51, y: 30)), 0)
        XCTAssertEqual(ScreenGeometry.forgivingHitIndex(in: rects, point: NSPoint(x: 53, y: 30)), 1)
        XCTAssertEqual(ScreenGeometry.forgivingHitIndex(in: rects, point: NSPoint(x: 53, y: 0)), 1)
    }

    func testForgivingHitIgnoresEmptyBarArea() {
        let button = NSRect(x: 100, y: 10, width: 48, height: 40)
        XCTAssertNil(ScreenGeometry.forgivingHitIndex(in: [button], point: NSPoint(x: 20, y: 30)))
    }

    func testForgivingHitReachesScreenEdgeInBarStyleLayout() {
        let barHeight = ScreenGeometry.taskbarHeight(forIconSize: 32)
        let panel = ScreenGeometry.panelHeight(barHeight: barHeight)
        let buttonHeight = barHeight - 4
        let button = NSRect(x: 100, y: panel - barHeight + 2, width: 48, height: buttonHeight)

        // Bottom of the panel == bottom of the screen (slop hangs off-screen).
        XCTAssertEqual(ScreenGeometry.forgivingHitIndex(in: [button], point: NSPoint(x: 120, y: 0)), 0)
        // Bottom edge of the display.
        XCTAssertEqual(ScreenGeometry.forgivingHitIndex(in: [button], point: NSPoint(x: 120, y: ScreenGeometry.edgeHotZoneSlop)), 0)
    }

    func testForgivingHitReachesScreenEdgeInDockStyleLayout() {
        let barHeight = ScreenGeometry.taskbarHeight(forIconSize: 32)
        let panel = ScreenGeometry.panelHeight(barHeight: barHeight)
        let buttonHeight = barHeight - 4
        let button = NSRect(x: 100, y: panel - barHeight + 2, width: 48, height: buttonHeight)

        // Pill floats 6pt above the screen edge, so the gap below it is bigger.
        let contentYOfScreenEdge = panel - barHeight - ScreenGeometry.dockStyleBottomOffset
        XCTAssertEqual(ScreenGeometry.forgivingHitIndex(in: [button], point: NSPoint(x: 120, y: contentYOfScreenEdge)), 0)
    }
}

final class CrashGuardTests: XCTestCase {
    override func tearDown() {
        CrashGuard.clearCleanExit()
        super.tearDown()
    }

    func testCleanExitMarkerRoundTrip() {
        CrashGuard.clearCleanExit()
        XCTAssertFalse(CrashGuard.isCleanExit())
        CrashGuard.markCleanExit()
        XCTAssertTrue(CrashGuard.isCleanExit())
        CrashGuard.clearCleanExit()
        XCTAssertFalse(CrashGuard.isCleanExit())
    }
}

final class ThemeManagerTests: XCTestCase {
    func testLightColorUsesAquaAppearance() {
        let appearance = ThemeManager.appearance(for: NSColor.white)
        XCTAssertEqual(appearance.bestMatch(from: [.darkAqua, .aqua]), .aqua)
    }

    func testDarkColorUsesDarkAquaAppearance() {
        let appearance = ThemeManager.appearance(for: NSColor.black)
        XCTAssertEqual(appearance.bestMatch(from: [.darkAqua, .aqua]), .darkAqua)
    }

    func testMidGrayUsesDarkAquaAppearance() {
        let gray = NSColor(calibratedWhite: 0.4, alpha: 1.0)
        let appearance = ThemeManager.appearance(for: gray)
        XCTAssertEqual(appearance.bestMatch(from: [.darkAqua, .aqua]), .darkAqua)
    }
}

final class SingleInstanceLockTests: XCTestCase {
    private var lockPath: String = ""

    override func setUp() {
        super.setUp()
        lockPath = NSTemporaryDirectory() + "opentaskbar-lock-\(UUID().uuidString)"
    }

    override func tearDown() {
        SingleInstanceLock.release(lockFilePath: lockPath)
        super.tearDown()
    }

    func testAcquireCreatesLockFileAndReleaseRemovesIt() {
        XCTAssertTrue(SingleInstanceLock.acquire(lockFilePath: lockPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockPath))
        SingleInstanceLock.release(lockFilePath: lockPath)
        XCTAssertFalse(FileManager.default.fileExists(atPath: lockPath))
    }

    func testAcquireFailsWhileAnotherLiveProcessHoldsLock() {
        try? "\(ProcessInfo.processInfo.processIdentifier)".write(toFile: lockPath, atomically: true, encoding: .utf8)
        XCTAssertFalse(SingleInstanceLock.acquire(lockFilePath: lockPath))
    }

    func testAcquireSucceedsWhenLockHeldByDeadProcess() {
        try? "999999".write(toFile: lockPath, atomically: true, encoding: .utf8)
        XCTAssertTrue(SingleInstanceLock.acquire(lockFilePath: lockPath))
        let contents = try? String(contentsOfFile: lockPath, encoding: .utf8)
        XCTAssertEqual(contents, "\(ProcessInfo.processInfo.processIdentifier)")
    }

    func testAcquireSucceedsWhenLockFileIsCorrupt() {
        try? "not-a-pid".write(toFile: lockPath, atomically: true, encoding: .utf8)
        XCTAssertTrue(SingleInstanceLock.acquire(lockFilePath: lockPath))
    }
}

final class NSImageExtensionsTests: XCTestCase {
    func testResizedImageReturnsRequestedSize() {
        let image = NSImage(size: NSSize(width: 64, height: 64))
        let resized = image.resized(to: NSSize(width: 20, height: 20))
        XCTAssertEqual(resized.size, NSSize(width: 20, height: 20))
    }

    func testResizedImagePreservesTemplateFlag() {
        let image = NSImage(size: NSSize(width: 64, height: 64))
        image.isTemplate = true
        let resized = image.resized(to: NSSize(width: 20, height: 20))
        XCTAssertTrue(resized.isTemplate)
    }

    func testSystemIconReturnsRequestedSize() {
        let icon = NSImage.systemIcon(for: "magnifyingglass", size: NSSize(width: 24, height: 24))
        XCTAssertEqual(icon.size, NSSize(width: 24, height: 24))
    }
}
