import XCTest
@testable import OpenTaskbar

final class WindowGroupingEngineTests: XCTestCase {
    // MARK: mergeWindows — duplicate window IDs across AX/CG sources

    func testMergeDeduplicatesSameWindowFromAXAndCG() {
        let ax = makeWindow(id: 1)
        let cg = makeWindow(id: 1)
        let result = WindowGroupingEngine.mergeWindows(axWindows: [ax], cgWindows: [cg])
        XCTAssertEqual(result.map(\.windowID), [1])
    }

    func testMergePrefersAXWindowOverCGDuplicate() {
        let ax = makeWindow(id: 1, title: "AX title")
        let cg = makeWindow(id: 1, title: "CG title")
        let result = WindowGroupingEngine.mergeWindows(axWindows: [ax], cgWindows: [cg])
        XCTAssertEqual(result.map(\.windowID), [1])
        XCTAssertEqual(result.first?.title, "AX title")
    }

    func testMergeDropsInvalidAXWindowAndKeepsCGWindow() {
        let invalidAX = makeWindow(id: 2, layer: 1)
        let cg = makeWindow(id: 2)
        let result = WindowGroupingEngine.mergeWindows(axWindows: [invalidAX], cgWindows: [cg])
        XCTAssertEqual(result.map(\.windowID), [2])
    }

    func testMergeKeepsDistinctWindowsAXFirstThenCG() {
        let ax1 = makeWindow(id: 1)
        let ax2 = makeWindow(id: 2)
        let cg3 = makeWindow(id: 3)
        let result = WindowGroupingEngine.mergeWindows(axWindows: [ax1, ax2], cgWindows: [cg3])
        XCTAssertEqual(result.map(\.windowID), [1, 2, 3])
    }

    // MARK: sortGroups — pinned first, then insertion order

    func testSortPlacesPinnedAppsFirstInPinOrder() {
        let a = makeGroup(bundleID: "com.a", insertionOrder: 0)
        let b = makeGroup(bundleID: "com.b", insertionOrder: 1)
        let c = makeGroup(bundleID: "com.c", insertionOrder: 2)
        let sorted = WindowGroupingEngine.sortGroups([a, b, c], pinnedIDs: ["com.c", "com.a"])
        XCTAssertEqual(sorted.map(\.bundleIdentifier), ["com.c", "com.a", "com.b"])
    }

    func testSortOrdersNonPinnedAppsByInsertionOrder() {
        let a = makeGroup(bundleID: "com.a", insertionOrder: 3)
        let b = makeGroup(bundleID: "com.b", insertionOrder: 1)
        let c = makeGroup(bundleID: "com.c", insertionOrder: 2)
        let sorted = WindowGroupingEngine.sortGroups([a, b, c], pinnedIDs: [])
        XCTAssertEqual(sorted.map(\.bundleIdentifier), ["com.b", "com.c", "com.a"])
    }

    // MARK: closedAppCandidates — what lands in the closed-apps list

    func testRunningAppWithoutWindowsIsClosedAppCandidate() {
        let group = makeGroup(bundleID: "com.a")
        let result = WindowGroupingEngine.closedAppCandidates(
            from: [group],
            previousBundlesWithWindows: [],
            ownBundleID: nil,
            neverQuitBundleIDs: []
        )
        XCTAssertEqual(result.map(\.bundleIdentifier), ["com.a"])
    }

    func testNeverQuitAppsAreExcludedFromClosedApps() {
        let group = makeGroup(bundleID: "com.a")
        let result = WindowGroupingEngine.closedAppCandidates(
            from: [group],
            previousBundlesWithWindows: [],
            ownBundleID: nil,
            neverQuitBundleIDs: ["com.a"]
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testFinderAndSelfAreExcludedFromClosedApps() {
        let finder = makeGroup(bundleID: "com.apple.finder")
        let own = makeGroup(bundleID: "com.opentaskbar")
        let result = WindowGroupingEngine.closedAppCandidates(
            from: [finder, own],
            previousBundlesWithWindows: [],
            ownBundleID: "com.opentaskbar",
            neverQuitBundleIDs: []
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testAppThatPreviouslyHadWindowsIsExcludedFromClosedApps() {
        let group = makeGroup(bundleID: "com.a")
        let result = WindowGroupingEngine.closedAppCandidates(
            from: [group],
            previousBundlesWithWindows: ["com.a"],
            ownBundleID: nil,
            neverQuitBundleIDs: []
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testLaunchingAppIsExcludedFromClosedApps() {
        let group = makeGroup(bundleID: "com.a", isLaunching: true)
        let result = WindowGroupingEngine.closedAppCandidates(
            from: [group],
            previousBundlesWithWindows: [],
            ownBundleID: nil,
            neverQuitBundleIDs: []
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testAppWithWindowsIsExcludedFromClosedApps() {
        let group = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1)])
        let result = WindowGroupingEngine.closedAppCandidates(
            from: [group],
            previousBundlesWithWindows: [],
            ownBundleID: nil,
            neverQuitBundleIDs: []
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testTerminatedAppIsExcludedFromClosedApps() {
        let group = makeGroup(bundleID: "com.a")
        let result = WindowGroupingEngine.closedAppCandidates(
            from: [group],
            previousBundlesWithWindows: [],
            ownBundleID: nil,
            neverQuitBundleIDs: [],
            isAlive: { _ in false }
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testNonRunningGroupIsExcludedFromClosedApps() {
        let group = makeGroup(bundleID: "com.a")
        let result = WindowGroupingEngine.closedAppCandidates(
            from: [group],
            previousBundlesWithWindows: [],
            ownBundleID: nil,
            neverQuitBundleIDs: [],
            isAlive: { _ in false }
        )
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: keepGroupAfterRebuild — no icon resurrection from stale rebuilds

    func testWindowedGroupIsAlwaysKept() {
        let group = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1)])
        XCTAssertTrue(WindowGroupingEngine.keepGroupAfterRebuild(
            group,
            previousBundlesWithWindows: [],
            currentBundleIDs: [],
            pinnedBundleIDs: []
        ))
    }

    func testPinnedGroupIsAlwaysKeptEvenWithoutWindows() {
        let group = makeGroup(bundleID: "com.a")
        XCTAssertTrue(WindowGroupingEngine.keepGroupAfterRebuild(
            group,
            previousBundlesWithWindows: [],
            currentBundleIDs: [],
            pinnedBundleIDs: ["com.a"]
        ))
    }

    func testLaunchingGroupIsAlwaysKept() {
        let group = makeGroup(bundleID: "com.a", isLaunching: true)
        XCTAssertTrue(WindowGroupingEngine.keepGroupAfterRebuild(
            group,
            previousBundlesWithWindows: [],
            currentBundleIDs: [],
            pinnedBundleIDs: []
        ))
    }

    func testGroupThatNeverHadWindowsIsNotKept() {
        let group = makeGroup(bundleID: "com.a")
        XCTAssertFalse(WindowGroupingEngine.keepGroupAfterRebuild(
            group,
            previousBundlesWithWindows: [],
            currentBundleIDs: ["com.a"],
            pinnedBundleIDs: []
        ))
    }

    func testClosedGroupIsNotResurrectedByStaleRebuild() {
        let group = makeGroup(bundleID: "com.a")
        XCTAssertFalse(WindowGroupingEngine.keepGroupAfterRebuild(
            group,
            previousBundlesWithWindows: ["com.a"],
            currentBundleIDs: [],
            pinnedBundleIDs: []
        ))
    }

    func testGroupStillInCurrentStateSurvivesStaleRebuild() {
        let group = makeGroup(bundleID: "com.a")
        XCTAssertTrue(WindowGroupingEngine.keepGroupAfterRebuild(
            group,
            previousBundlesWithWindows: ["com.a"],
            currentBundleIDs: ["com.a"],
            pinnedBundleIDs: []
        ))
    }

    func testRunningEmptyGroupKeptWhenKeepRunningEmptyGroupsEnabled() {
        let app = NSRunningApplication(processIdentifier: getpid())
        let group = makeGroup(bundleID: "com.a", runningApplication: app)
        XCTAssertTrue(WindowGroupingEngine.keepGroupAfterRebuild(
            group,
            previousBundlesWithWindows: [],
            currentBundleIDs: [],
            pinnedBundleIDs: [],
            keepRunningEmptyGroups: true
        ))
    }

    func testNotRunningEmptyGroupNotKeptEvenWhenKeepRunningEmptyGroupsEnabled() {
        let group = makeGroup(bundleID: "com.a")
        XCTAssertFalse(WindowGroupingEngine.keepGroupAfterRebuild(
            group,
            previousBundlesWithWindows: [],
            currentBundleIDs: ["com.a"],
            pinnedBundleIDs: [],
            keepRunningEmptyGroups: true
        ))
    }

    // MARK: shouldKeepLaunching — grace period before launching state clears

    func testLaunchingKeptBeforeGraceElapses() {
        let now = Date()
        XCTAssertTrue(WindowGroupingEngine.shouldKeepLaunching(
            hasWindows: false,
            startedAt: now,
            now: now.addingTimeInterval(1.0),
            grace: 1.5
        ))
    }

    func testLaunchingClearsOnceGraceElapsesEvenWhenBackgrounded() {
        let now = Date()
        XCTAssertFalse(WindowGroupingEngine.shouldKeepLaunching(
            hasWindows: false,
            startedAt: now,
            now: now.addingTimeInterval(1.5),
            grace: 1.5
        ))
    }

    func testLaunchingClearsImmediatelyWhenWindowsAppear() {
        let now = Date()
        XCTAssertFalse(WindowGroupingEngine.shouldKeepLaunching(
            hasWindows: true,
            startedAt: now,
            now: now,
            grace: 1.5
        ))
    }

    // MARK: InsertionOrderResolver — 30s TTL preserves app position

    func testFreshBundleGetsNextOrderAndIncrements() {
        var resolver = WindowGroupingEngine.InsertionOrderResolver(nextOrder: 3, savedOrders: [:])
        XCTAssertEqual(resolver.order(for: "com.a", existing: nil, now: Date(), ttl: 30), 3)
        XCTAssertEqual(resolver.order(for: "com.b", existing: nil, now: Date(), ttl: 30), 4)
        XCTAssertEqual(resolver.nextOrder, 5)
    }

    func testExistingGroupOrderWinsWithoutConsumingSavedOrder() {
        let now = Date()
        var resolver = WindowGroupingEngine.InsertionOrderResolver(
            nextOrder: 0,
            savedOrders: ["com.a": (order: 7, savedAt: now)]
        )
        XCTAssertEqual(resolver.order(for: "com.a", existing: 2, now: now, ttl: 30), 2)
        XCTAssertEqual(resolver.savedOrders["com.a"]?.order, 7)
        XCTAssertEqual(resolver.nextOrder, 0)
    }

    func testSavedOrderWithinTTLIsReusedAndConsumed() {
        let now = Date()
        var resolver = WindowGroupingEngine.InsertionOrderResolver(
            nextOrder: 0,
            savedOrders: ["com.a": (order: 7, savedAt: now)]
        )
        XCTAssertEqual(resolver.order(for: "com.a", existing: nil, now: now.addingTimeInterval(10), ttl: 30), 7)
        XCTAssertNil(resolver.savedOrders["com.a"])
        XCTAssertEqual(resolver.nextOrder, 0)
    }

    func testExpiredSavedOrderGetsFreshOrder() {
        let now = Date()
        var resolver = WindowGroupingEngine.InsertionOrderResolver(
            nextOrder: 0,
            savedOrders: ["com.a": (order: 7, savedAt: now)]
        )
        XCTAssertEqual(resolver.order(for: "com.a", existing: nil, now: now.addingTimeInterval(31), ttl: 30), 0)
        XCTAssertEqual(resolver.nextOrder, 1)
    }

    // MARK: reorderGroups — moveApp index math, renumbering, pin interplay

    private func makeOrderedGroups(_ bundleIDs: [String]) -> [AppGroup] {
        bundleIDs.enumerated().map { makeGroup(bundleID: $0.element, insertionOrder: $0.offset) }
    }

    func testReorderMovesGroupDownWithAdjustedDestination() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 0, to: 2, pinnedIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.b", "com.a", "com.c"])
        XCTAssertEqual(result.groups.map(\.insertionOrder), [0, 1, 2])
        XCTAssertEqual(result.nextOrder, 3)
        XCTAssertNil(result.pinnedBundleIDs)
    }

    func testReorderMovesGroupDownMultipleSlots() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c", "com.d"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 0, to: 3, pinnedIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.b", "com.c", "com.a", "com.d"])
    }

    func testReorderMovesGroupUp() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 2, to: 0, pinnedIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.c", "com.a", "com.b"])
        XCTAssertEqual(result.groups.map(\.insertionOrder), [0, 1, 2])
        XCTAssertEqual(result.nextOrder, 3)
    }

    func testReorderMovesGroupToEndSlot() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 0, to: 3, pinnedIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.b", "com.c", "com.a"])
        XCTAssertEqual(result.groups.map(\.insertionOrder), [0, 1, 2])
        XCTAssertEqual(result.nextOrder, 3)
        XCTAssertTrue(result.didReorder)
    }

    func testReorderMovesGroupToEndSlotUpdatingPinOrder() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 0, to: 3, pinnedIDs: ["com.a", "com.b", "com.c"])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.b", "com.c", "com.a"])
        XCTAssertEqual(result.pinnedBundleIDs, ["com.b", "com.c", "com.a"])
    }

    func testReorderMovesSecondLastToEndSlot() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 1, to: 3, pinnedIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a", "com.c", "com.b"])
        XCTAssertTrue(result.didReorder)
    }

    func testReorderOutOfBoundsDestinationIsNoOp() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 0, to: 99, pinnedIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a", "com.b", "com.c"])
        XCTAssertNil(result.nextOrder)
        XCTAssertFalse(result.didReorder)
    }

    func testReorderOutOfBoundsSourceIsNoOp() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 99, to: 0, pinnedIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a", "com.b", "com.c"])
        XCTAssertNil(result.nextOrder)
    }

    func testReorderToSameIndexIsNoOp() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 1, to: 1, pinnedIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a", "com.b", "com.c"])
        XCTAssertNil(result.nextOrder)
    }

    func testReorderRenumbersInsertionOrdersFromZero() {
        let groups = [
            makeGroup(bundleID: "com.a", insertionOrder: 10),
            makeGroup(bundleID: "com.b", insertionOrder: 20),
            makeGroup(bundleID: "com.c", insertionOrder: 30),
        ]
        let result = WindowGroupingEngine.reorderGroups(groups, from: 2, to: 0, pinnedIDs: [])
        XCTAssertEqual(result.groups.map(\.insertionOrder), [0, 1, 2])
    }

    func testReorderEmptyGroupsIsNoOp() {
        let result = WindowGroupingEngine.reorderGroups([], from: 0, to: 0, pinnedIDs: [])
        XCTAssertTrue(result.groups.isEmpty)
        XCTAssertNil(result.nextOrder)
    }

    func testReorderUpdatesPinOrderWhenPinnedAppMovesWithinPinnedRegion() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 1, to: 0, pinnedIDs: ["com.a", "com.b"])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.b", "com.a", "com.c"])
        XCTAssertEqual(result.pinnedBundleIDs, ["com.b", "com.a"])
    }

    func testReorderDoesNotUpdatePinOrderBeyondPinnedRegion() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 0, to: 2, pinnedIDs: ["com.a"])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.b", "com.a", "com.c"])
        XCTAssertNil(result.pinnedBundleIDs)
    }

    func testReorderUnpinnedAppDoesNotTouchPinOrder() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 1, to: 0, pinnedIDs: ["com.a"])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.b", "com.a", "com.c"])
        XCTAssertNil(result.pinnedBundleIDs)
    }

    func testReorderPinnedAppPastPinnedRegionLeavesPinOrderUntouched() {
        let groups = makeOrderedGroups(["com.a", "com.b", "com.c"])
        let result = WindowGroupingEngine.reorderGroups(groups, from: 0, to: 2, pinnedIDs: ["com.a"])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.b", "com.a", "com.c"])
        XCTAssertNil(result.pinnedBundleIDs)
    }

    // MARK: closingEmptyGroups — remove empty unpinned groups

    func testClosingEmptyGroupsRemovesEmptyUnpinnedGroups() {
        let empty = makeGroup(bundleID: "com.empty", insertionOrder: 0)
        let withWindow = makeGroup(bundleID: "com.windowed", windows: [makeWindow(id: 1)], insertionOrder: 1)
        let result = WindowGroupingEngine.closingEmptyGroups([empty, withWindow], pinnedBundleIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.windowed"])
        XCTAssertEqual(result.closed.map(\.bundleIdentifier), ["com.empty"])
    }

    func testClosingEmptyGroupsKeepsPinnedEmptyGroups() {
        let empty = makeGroup(bundleID: "com.pinned", insertionOrder: 0)
        let result = WindowGroupingEngine.closingEmptyGroups([empty], pinnedBundleIDs: ["com.pinned"])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.pinned"])
        XCTAssertTrue(result.closed.isEmpty)
    }

    func testClosingEmptyGroupsKeepsGroupsWithWindows() {
        let group = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1), makeWindow(id: 2)])
        let result = WindowGroupingEngine.closingEmptyGroups([group], pinnedBundleIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a"])
        XCTAssertTrue(result.closed.isEmpty)
    }

    func testClosingEmptyGroupsPreservesOrderOfSurvivors() {
        let a = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1)], insertionOrder: 0)
        let empty1 = makeGroup(bundleID: "com.empty1", insertionOrder: 1)
        let b = makeGroup(bundleID: "com.b", windows: [makeWindow(id: 2)], insertionOrder: 2)
        let empty2 = makeGroup(bundleID: "com.empty2", insertionOrder: 3)
        let result = WindowGroupingEngine.closingEmptyGroups([a, empty1, b, empty2], pinnedBundleIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a", "com.b"])
        XCTAssertEqual(result.closed.map(\.bundleIdentifier), ["com.empty1", "com.empty2"])
    }

    func testClosingEmptyGroupsKeepsLiveEmptyGroupsWhenFlagEnabled() {
        let app = NSRunningApplication(processIdentifier: getpid())
        let empty = makeGroup(bundleID: "com.empty", runningApplication: app)
        let result = WindowGroupingEngine.closingEmptyGroups([empty], pinnedBundleIDs: [], keepRunningEmptyGroups: true)
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.empty"])
        XCTAssertEqual(result.closed.map(\.bundleIdentifier), ["com.empty"])
    }

    func testClosingEmptyGroupsRemovesNonRunningEmptyGroupsEvenWhenFlagEnabled() {
        let empty = makeGroup(bundleID: "com.empty")
        let result = WindowGroupingEngine.closingEmptyGroups([empty], pinnedBundleIDs: [], keepRunningEmptyGroups: true)
        XCTAssertTrue(result.groups.isEmpty)
        XCTAssertEqual(result.closed.map(\.bundleIdentifier), ["com.empty"])
    }

    func testRemovingWindowKeepsLiveEmptyGroupWhenFlagEnabled() {
        let app = NSRunningApplication(processIdentifier: getpid())
        let group = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1)], runningApplication: app)
        let result = WindowGroupingEngine.removingWindow(
            1,
            from: [group],
            pinnedBundleIDs: [],
            keepRunningEmptyGroups: true
        )
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a"])
        XCTAssertTrue(result.groups[0].windows.isEmpty)
        XCTAssertEqual(result.closed.map(\.bundleIdentifier), ["com.a"])
    }

    // MARK: removingWindow — window removal + empty-group closure

    func testRemovingWindowKeepsGroupWithRemainingWindows() {
        let group = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1), makeWindow(id: 2)])
        let result = WindowGroupingEngine.removingWindow(1, from: [group], pinnedBundleIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a"])
        XCTAssertEqual(result.groups.first?.windows.map(\.windowID), [2])
        XCTAssertTrue(result.closed.isEmpty)
    }

    func testRemovingLastWindowClosesUnpinnedGroup() {
        let group = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1)])
        let result = WindowGroupingEngine.removingWindow(1, from: [group], pinnedBundleIDs: [])
        XCTAssertTrue(result.groups.isEmpty)
        XCTAssertEqual(result.closed.map(\.bundleIdentifier), ["com.a"])
    }

    func testRemovingLastWindowKeepsPinnedGroupEmpty() {
        let group = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1)])
        let result = WindowGroupingEngine.removingWindow(1, from: [group], pinnedBundleIDs: ["com.a"])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a"])
        XCTAssertTrue(result.groups.first?.windows.isEmpty ?? false)
        XCTAssertTrue(result.closed.isEmpty)
    }

    func testRemovingUnknownWindowIsNoOp() {
        let group = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1)])
        let result = WindowGroupingEngine.removingWindow(99, from: [group], pinnedBundleIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a"])
        XCTAssertEqual(result.groups.first?.windows.map(\.windowID), [1])
        XCTAssertTrue(result.closed.isEmpty)
    }

    func testRemovingWindowOnlyAffectsOwningGroup() {
        let a = makeGroup(bundleID: "com.a", windows: [makeWindow(id: 1)])
        let b = makeGroup(bundleID: "com.b", windows: [makeWindow(id: 2), makeWindow(id: 3)])
        let result = WindowGroupingEngine.removingWindow(2, from: [a, b], pinnedBundleIDs: [])
        XCTAssertEqual(result.groups.map(\.bundleIdentifier), ["com.a", "com.b"])
        XCTAssertEqual(result.groups.first { $0.bundleIdentifier == "com.a" }?.windows.map(\.windowID), [1])
        XCTAssertEqual(result.groups.first { $0.bundleIdentifier == "com.b" }?.windows.map(\.windowID), [3])
        XCTAssertTrue(result.closed.isEmpty)
    }

    // MARK: WindowMissTracker — consecutive CG misses before removal

    func testSingleMissDoesNotRemoveWindow() {
        var tracker = WindowGroupingEngine.WindowMissTracker(maxMissesBeforeRemove: 2)
        XCTAssertFalse(tracker.miss(windowID: 1))
        XCTAssertEqual(tracker.missCounts[1], 1)
    }

    func testConsecutiveMissesReachThreshold() {
        var tracker = WindowGroupingEngine.WindowMissTracker(maxMissesBeforeRemove: 2)
        XCTAssertFalse(tracker.miss(windowID: 1))
        XCTAssertTrue(tracker.miss(windowID: 1))
    }

    func testHitResetsMissCount() {
        var tracker = WindowGroupingEngine.WindowMissTracker(maxMissesBeforeRemove: 2)
        _ = tracker.miss(windowID: 1)
        tracker.hit(windowID: 1)
        XCTAssertFalse(tracker.miss(windowID: 1))
    }

    func testMissesDoNotAccumulateAcrossWindows() {
        var tracker = WindowGroupingEngine.WindowMissTracker(maxMissesBeforeRemove: 2)
        _ = tracker.miss(windowID: 1)
        XCTAssertFalse(tracker.miss(windowID: 2))
    }

    func testPruneDropsUntrackedWindowIDs() {
        var tracker = WindowGroupingEngine.WindowMissTracker(maxMissesBeforeRemove: 2)
        _ = tracker.miss(windowID: 1)
        _ = tracker.miss(windowID: 2)
        tracker.prune(keeping: [2])
        XCTAssertNil(tracker.missCounts[1])
        XCTAssertEqual(tracker.missCounts[2], 1)
    }

    // MARK: zoomed-window geometry

    func testZoomedFrameDetectionUses98PercentThreshold() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertTrue(WindowGroupingEngine.isZoomedFrame(CGRect(x: 0, y: 0, width: 1440, height: 900), visibleFrame: visible))
        XCTAssertTrue(WindowGroupingEngine.isZoomedFrame(CGRect(x: 0, y: 0, width: 1420, height: 890), visibleFrame: visible))
        XCTAssertFalse(WindowGroupingEngine.isZoomedFrame(CGRect(x: 0, y: 0, width: 1000, height: 800), visibleFrame: visible))
    }

    func testConstrainedTargetHeightIsVisibleMaxYMinusTaskbarTop() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 874)
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertEqual(
            WindowGroupingEngine.constrainedTargetHeight(frame: frame, visibleFrame: visible, taskbarTop: 44),
            830
        )
    }

    func testConstrainedTargetHeightSkipsWhenHeightAlreadyMatches() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 874)
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 830)
        XCTAssertNil(WindowGroupingEngine.constrainedTargetHeight(frame: frame, visibleFrame: visible, taskbarTop: 44))
    }

    func testConstrainedTargetHeightSkipsSubPixelDifference() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 874)
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 831)
        XCTAssertNil(WindowGroupingEngine.constrainedTargetHeight(frame: frame, visibleFrame: visible, taskbarTop: 44))
    }

    func testConstrainedTargetHeightSkipsWhenTargetTooSmall() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 150)
        let frame = CGRect(x: 0, y: 0, width: 1440, height: 150)
        XCTAssertNil(WindowGroupingEngine.constrainedTargetHeight(frame: frame, visibleFrame: visible, taskbarTop: 60))
    }

    // MARK: fullscreen coverage math

    func testCoverageRatioFullScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertEqual(WindowGroupingEngine.coverageRatio(screen, in: screen), 1.0, accuracy: 0.0001)
    }

    func testCoverageRatioHalfScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let half = CGRect(x: 0, y: 0, width: 720, height: 900)
        XCTAssertEqual(WindowGroupingEngine.coverageRatio(half, in: screen), 0.5, accuracy: 0.0001)
    }

    func testCoverageRatioDisjointFrames() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let outside = CGRect(x: 5000, y: 5000, width: 100, height: 100)
        XCTAssertEqual(WindowGroupingEngine.coverageRatio(outside, in: screen), 0)
    }

    func testCoverageRatioZeroAreaScreen() {
        let screen = CGRect(x: 0, y: 0, width: 0, height: 0)
        XCTAssertEqual(WindowGroupingEngine.coverageRatio(CGRect(x: 0, y: 0, width: 100, height: 100), in: screen), 0)
    }

    // MARK: CG coordinate conversion

    func testCGBoundsForPrimaryScreen() {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
        XCTAssertEqual(
            WindowGroupingEngine.cgBounds(screenFrame: primary, primaryScreenFrame: primary),
            CGRect(x: 0, y: 0, width: 1440, height: 900)
        )
    }

    func testCGBoundsFlipsYForSecondaryScreenAbovePrimary() {
        let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let secondary = CGRect(x: 0, y: 900, width: 1440, height: 900)
        XCTAssertEqual(
            WindowGroupingEngine.cgBounds(screenFrame: secondary, primaryScreenFrame: primary),
            CGRect(x: 0, y: -900, width: 1440, height: 900)
        )
    }
}
