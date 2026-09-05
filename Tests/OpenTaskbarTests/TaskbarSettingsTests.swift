import XCTest
@testable import OpenTaskbar

final class TaskbarSettingsTests: XCTestCase {
    private var originalPinned: [String] = []
    private var originalNeverQuit: [String] = []
    private var originalBackgroundColorData: Data = Data()
    private var originalBackgroundTheme: TaskbarSettings.BackgroundTheme = .system
    private var originalIconSize: Double = 32

    override func setUp() {
        super.setUp()
        originalPinned = TaskbarSettings.shared.pinnedBundleIdentifiers
        originalNeverQuit = TaskbarSettings.shared.neverQuitBundleIdentifiers
        originalBackgroundColorData = TaskbarSettings.shared.customBackgroundColorData
        originalBackgroundTheme = TaskbarSettings.shared.backgroundTheme
        originalIconSize = TaskbarSettings.shared.iconSize
    }

    override func tearDown() {
        TaskbarSettings.shared.pinnedBundleIdentifiers = originalPinned
        TaskbarSettings.shared.neverQuitBundleIdentifiers = originalNeverQuit
        TaskbarSettings.shared.customBackgroundColorData = originalBackgroundColorData
        TaskbarSettings.shared.backgroundTheme = originalBackgroundTheme
        TaskbarSettings.shared.iconSize = originalIconSize
        super.tearDown()
    }

    func testTogglePinAddsAndRemoves() {
        let settings = TaskbarSettings.shared
        settings.pinnedBundleIdentifiers = []
        XCTAssertFalse(settings.isPinned("com.a"))
        settings.togglePin("com.a")
        XCTAssertTrue(settings.isPinned("com.a"))
        settings.togglePin("com.a")
        XCTAssertFalse(settings.isPinned("com.a"))
    }

    func testToggleNeverQuitAddsAndRemoves() {
        let settings = TaskbarSettings.shared
        settings.neverQuitBundleIdentifiers = []
        XCTAssertFalse(settings.isNeverQuit("com.a"))
        settings.toggleNeverQuit("com.a")
        XCTAssertTrue(settings.isNeverQuit("com.a"))
        settings.toggleNeverQuit("com.a")
        XCTAssertFalse(settings.isNeverQuit("com.a"))
    }

    func testMovePinRearrangesPinOrder() {
        let settings = TaskbarSettings.shared
        settings.pinnedBundleIdentifiers = ["com.a", "com.b", "com.c"]
        settings.movePin(from: 0, to: 2)
        XCTAssertEqual(settings.pinnedBundleIdentifiers, ["com.b", "com.c", "com.a"])
    }

    func testMovePinIgnoresOutOfBoundsIndices() {
        let settings = TaskbarSettings.shared
        settings.pinnedBundleIdentifiers = ["com.a", "com.b"]
        settings.movePin(from: 0, to: 5)
        XCTAssertEqual(settings.pinnedBundleIdentifiers, ["com.a", "com.b"])
        settings.movePin(from: -1, to: 1)
        XCTAssertEqual(settings.pinnedBundleIdentifiers, ["com.a", "com.b"])
    }

    func testReorderPinnedMovesBundleToIndex() {
        let settings = TaskbarSettings.shared
        settings.pinnedBundleIdentifiers = ["com.a", "com.b", "com.c"]
        settings.reorderPinned(bundleID: "com.c", to: 0)
        XCTAssertEqual(settings.pinnedBundleIdentifiers, ["com.c", "com.a", "com.b"])
    }

    func testReorderPinnedClampsIndexToBounds() {
        let settings = TaskbarSettings.shared
        settings.pinnedBundleIdentifiers = ["com.a", "com.b", "com.c"]
        settings.reorderPinned(bundleID: "com.a", to: 99)
        XCTAssertEqual(settings.pinnedBundleIdentifiers, ["com.b", "com.c", "com.a"])
    }

    func testBatchUpdatesCoalesceChangeNotifications() {
        let settings = TaskbarSettings.shared
        var count = 0
        let token = NotificationCenter.default.addObserver(
            forName: TaskbarSettings.settingsDidChange,
            object: nil,
            queue: nil
        ) { _ in count += 1 }

        settings.beginBatchUpdates()
        settings.pinnedBundleIdentifiers = ["com.a"]
        settings.iconSize = 40
        settings.endBatchUpdates()

        XCTAssertEqual(count, 1)
        NotificationCenter.default.removeObserver(token)
    }

    func testCorruptCustomBackgroundColorDataFallsBackToDefault() {
        let settings = TaskbarSettings.shared
        settings.customBackgroundColorData = Data([0x00, 0x01, 0x02])
        let fallback = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
        let color = settings.customBackgroundColor
        XCTAssertEqual(color.redComponent, fallback.redComponent, accuracy: 0.0001)
        XCTAssertEqual(color.greenComponent, fallback.greenComponent, accuracy: 0.0001)
        XCTAssertEqual(color.blueComponent, fallback.blueComponent, accuracy: 0.0001)
    }

    func testCustomBackgroundColorSetterRoundTrips() {
        let settings = TaskbarSettings.shared
        let color = NSColor(calibratedRed: 0.3, green: 0.6, blue: 0.9, alpha: 1.0)
        settings.customBackgroundColor = color
        let restored = settings.customBackgroundColor
        XCTAssertEqual(restored.redComponent, color.redComponent, accuracy: 0.0001)
        XCTAssertEqual(restored.greenComponent, color.greenComponent, accuracy: 0.0001)
        XCTAssertEqual(restored.blueComponent, color.blueComponent, accuracy: 0.0001)
    }

    func testTranslucentBarFollowsSystemReduceTransparency() {
        let expected = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        XCTAssertEqual(TaskbarSettings.shared.translucentBar, expected)
    }

    func testGlassmorphismNoLongerValidTheme() {
        XCTAssertNil(TaskbarSettings.BackgroundTheme(rawValue: "glassmorphism"))
    }

    func testReorderPinnedSuppressesChangeNotifications() {
        let settings = TaskbarSettings.shared
        var count = 0
        let token = NotificationCenter.default.addObserver(
            forName: TaskbarSettings.settingsDidChange,
            object: nil,
            queue: nil
        ) { _ in count += 1 }

        settings.pinnedBundleIdentifiers = ["com.a", "com.b", "com.c"]
        count = 0
        settings.reorderPinned(bundleID: "com.c", to: 0)
        XCTAssertEqual(count, 0, "reorderPinned must not post change notifications")
        XCTAssertEqual(settings.pinnedBundleIdentifiers, ["com.c", "com.a", "com.b"])

        settings.iconSize = 40
        XCTAssertEqual(count, 1, "a direct property set should post exactly one notification")
        NotificationCenter.default.removeObserver(token)
    }

    func testSettingsPersistToUserDefaults() {
        let settings = TaskbarSettings.shared
        settings.iconSize = 42
        XCTAssertEqual(UserDefaults.standard.double(forKey: "iconSize"), 42)
    }
}
