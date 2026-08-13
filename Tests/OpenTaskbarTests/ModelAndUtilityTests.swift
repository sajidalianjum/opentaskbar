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
        XCTAssertEqual(rect, NSRect(x: 100, y: 50, width: 1440, height: 44))
    }

    func testTaskbarRectDockStyleOffsetsFromBottom() {
        let frame = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = ScreenGeometry.taskbarRect(frame: frame, height: 44, isDockStyle: true)
        XCTAssertEqual(rect.origin.y, ScreenGeometry.dockStyleBottomOffset)
        XCTAssertEqual(rect.height, 44)
    }

    func testTaskbarRectDockStylePreservesNonZeroOrigin() {
        let frame = NSRect(x: 0, y: 100, width: 1440, height: 900)
        let rect = ScreenGeometry.taskbarRect(frame: frame, height: 44, isDockStyle: true)
        XCTAssertEqual(rect.origin.y, 100 + ScreenGeometry.dockStyleBottomOffset)
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
