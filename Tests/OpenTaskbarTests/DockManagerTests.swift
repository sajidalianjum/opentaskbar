import XCTest
@testable import OpenTaskbar

final class DockManagerTests: XCTestCase {
    private var tempDir: String = ""

    override func setUp() {
        super.setUp()
        tempDir = NSTemporaryDirectory() + "opentaskbar-dock-tests-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    private func tempDefaultsPath() -> String {
        tempDir + "/dock-state.plist"
    }

    // MARK: DockState — defaults and round-trip

    func testDockStateDefaultsFromEmptyDict() {
        let state = DockManager.DockState(dict: [:])
        XCTAssertFalse(state.autohide)
        XCTAssertNil(state.autohideDelay)
    }

    func testDockStateRoundTripThroughDictionary() {
        let original = DockManager.DockState(autohide: true, autohideDelay: 0.25)
        let restored = DockManager.DockState(dict: original.asDictionary)
        XCTAssertEqual(original, restored)
    }

    func testDockStateRoundTripWithoutDelay() {
        let original = DockManager.DockState(autohide: true, autohideDelay: nil)
        let restored = DockManager.DockState(dict: original.asDictionary)
        XCTAssertEqual(original, restored)
        XCTAssertNil(restored.autohideDelay)
    }

    // MARK: restoreCommandArgs — write-vs-delete decision

    func testRestoreArgsWriteDelayWhenPresent() {
        let state = DockManager.DockState(autohide: true, autohideDelay: 0.25)
        let commands = state.restoreCommandArgs(for: "com.apple.dock")
        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0], ["write", "com.apple.dock", "autohide", "-bool", "true"])
        XCTAssertEqual(commands[1], ["write", "com.apple.dock", "autohide-delay", "-float", "0.25"])
    }

    func testRestoreArgsDeleteDelayWhenAbsent() {
        let state = DockManager.DockState(autohide: false, autohideDelay: nil)
        let commands = state.restoreCommandArgs(for: "com.apple.dock")
        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0], ["write", "com.apple.dock", "autohide", "-bool", "false"])
        XCTAssertEqual(commands[1], ["delete", "com.apple.dock", "autohide-delay"])
    }

    // MARK: file round-trip with injected temp path

    func testSaveWritesFileAndHasSavedState() {
        let manager = DockManager(defaultsPath: tempDefaultsPath())
        XCTAssertFalse(manager.hasSavedState())
        manager.saveCurrentDockState()
        XCTAssertTrue(manager.hasSavedState())
    }

    func testSavedFileContainsDockStateKeys() {
        let manager = DockManager(defaultsPath: tempDefaultsPath())
        manager.saveCurrentDockState()
        guard let plist = NSDictionary(contentsOfFile: tempDefaultsPath()) as? [String: Any] else {
            return XCTFail("saved plist could not be read back")
        }
        XCTAssertNotNil(plist["autohide"])
        XCTAssertNotNil(plist["autohide-delay"])
    }

    func testLoadStateFromFileRoundTripsSavedValues() {
        let writer = DockManager(defaultsPath: tempDefaultsPath())
        writer.saveCurrentDockState()
        let reader = DockManager(defaultsPath: tempDefaultsPath())
        reader.loadStateFromFile()
        XCTAssertNotNil(reader.savedState["autohide"])
        XCTAssertNotNil(reader.savedState["autohide-delay"])
    }

    func testLoadStateFromMissingFileLeavesSavedStateEmpty() {
        let manager = DockManager(defaultsPath: tempDefaultsPath())
        manager.loadStateFromFile()
        XCTAssertTrue(manager.savedState.isEmpty)
    }

    func testLoadStateFromCorruptFileLeavesSavedStateEmpty() {
        try? "not a plist".write(toFile: tempDefaultsPath(), atomically: true, encoding: .utf8)
        let manager = DockManager(defaultsPath: tempDefaultsPath())
        manager.loadStateFromFile()
        XCTAssertTrue(manager.savedState.isEmpty)
    }
}
