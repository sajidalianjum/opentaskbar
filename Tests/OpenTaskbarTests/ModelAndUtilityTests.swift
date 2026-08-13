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
