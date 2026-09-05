import Foundation
import CoreGraphics

enum WindowGroupingEngine {
    static func mergeWindows(axWindows: [WindowInfo], cgWindows: [WindowInfo]) -> [WindowInfo] {
        var result: [WindowInfo] = []
        var seenIDs = Set<CGWindowID>()

        for axWindow in axWindows {
            if axWindow.isValid && !seenIDs.contains(axWindow.windowID) {
                seenIDs.insert(axWindow.windowID)
                result.append(axWindow)
            }
        }

        for cgWindow in cgWindows {
            if !seenIDs.contains(cgWindow.windowID) {
                seenIDs.insert(cgWindow.windowID)
                result.append(cgWindow)
            }
        }

        return result
    }

    static func sortGroups(_ groups: [AppGroup], pinnedIDs: [String]) -> [AppGroup] {
        groups.sorted { lhs, rhs in
            let lhsIsPinned = pinnedIDs.contains(lhs.bundleIdentifier)
            let rhsIsPinned = pinnedIDs.contains(rhs.bundleIdentifier)
            if lhsIsPinned && rhsIsPinned {
                let li = pinnedIDs.firstIndex(of: lhs.bundleIdentifier) ?? Int.max
                let ri = pinnedIDs.firstIndex(of: rhs.bundleIdentifier) ?? Int.max
                return li < ri
            }
            if lhsIsPinned { return true }
            if rhsIsPinned { return false }
            return lhs.insertionOrder < rhs.insertionOrder
        }
    }

    static func closedAppCandidates(
        from groups: [AppGroup],
        previousBundlesWithWindows: Set<String>,
        ownBundleID: String?,
        neverQuitBundleIDs: Set<String>,
        isAlive: (AppGroup) -> Bool = { _ in true }
    ) -> [AppGroup] {
        groups.filter { group in
            guard isAlive(group), group.windows.isEmpty, !group.isLaunching else { return false }
            guard group.bundleIdentifier != ownBundleID else { return false }
            guard group.bundleIdentifier != "com.apple.finder" else { return false }
            guard !previousBundlesWithWindows.contains(group.bundleIdentifier) else { return false }
            guard !neverQuitBundleIDs.contains(group.bundleIdentifier) else { return false }
            return true
        }
    }

    static func keepGroupAfterRebuild(
        _ group: AppGroup,
        previousBundlesWithWindows: Set<String>,
        currentBundleIDs: Set<String>,
        pinnedBundleIDs: Set<String>,
        keepRunningEmptyGroups: Bool = false
    ) -> Bool {
        if !group.windows.isEmpty || pinnedBundleIDs.contains(group.bundleIdentifier) || group.isLaunching {
            return true
        }
        if keepRunningEmptyGroups && group.runningApplication?.isTerminated == false {
            return true
        }
        guard previousBundlesWithWindows.contains(group.bundleIdentifier) else { return false }
        return currentBundleIDs.contains(group.bundleIdentifier)
    }

    static func shouldKeepLaunching(
        hasWindows: Bool,
        startedAt: Date,
        now: Date,
        grace: TimeInterval
    ) -> Bool {
        !hasWindows && now.timeIntervalSince(startedAt) < grace
    }

    static func isZoomedFrame(_ frame: CGRect, visibleFrame: CGRect) -> Bool {
        let widthRatio = frame.width / visibleFrame.width
        let heightRatio = frame.height / visibleFrame.height
        return widthRatio >= 0.98 && heightRatio >= 0.98
    }

    static func constrainedTargetHeight(
        frame: CGRect,
        visibleFrame: CGRect,
        taskbarTop: CGFloat,
        minimumHeight: CGFloat = 100
    ) -> CGFloat? {
        let targetHeight = visibleFrame.maxY - taskbarTop
        guard targetHeight >= minimumHeight else { return nil }
        guard abs(frame.height - targetHeight) > 1 else { return nil }
        return targetHeight
    }

    static func coverageRatio(_ frame: CGRect, in screen: CGRect) -> CGFloat {
        let intersection = frame.intersection(screen)
        let area = screen.width * screen.height
        guard area > 0 else { return 0 }
        return (intersection.width * intersection.height) / area
    }

    static func cgBounds(screenFrame: CGRect, primaryScreenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.minX,
            y: primaryScreenFrame.height - screenFrame.maxY,
            width: screenFrame.width,
            height: screenFrame.height
        )
    }

    struct InsertionOrderResolver {
        private(set) var nextOrder: Int
        private(set) var savedOrders: [String: (order: Int, savedAt: Date)]

        init(nextOrder: Int, savedOrders: [String: (order: Int, savedAt: Date)]) {
            self.nextOrder = nextOrder
            self.savedOrders = savedOrders
        }

        mutating func order(for bundleID: String, existing: Int?, now: Date, ttl: TimeInterval) -> Int {
            if let existing {
                return existing
            }
            if let saved = savedOrders[bundleID], now.timeIntervalSince(saved.savedAt) <= ttl {
                savedOrders.removeValue(forKey: bundleID)
                return saved.order
            }
            let order = nextOrder
            nextOrder += 1
            return order
        }
    }

    struct ReorderResult {
        let groups: [AppGroup]
        let nextOrder: Int?
        let pinnedBundleIDs: [String]?

        var didReorder: Bool { nextOrder != nil }
    }

    static func reorderGroups(
        _ groups: [AppGroup],
        from sourceIndex: Int,
        to destinationIndex: Int,
        pinnedIDs: [String]
    ) -> ReorderResult {
        guard sourceIndex < groups.count, destinationIndex < groups.count, sourceIndex != destinationIndex else {
            return ReorderResult(groups: groups, nextOrder: nil, pinnedBundleIDs: nil)
        }

        var result = groups
        let group = result.remove(at: sourceIndex)
        let adjustedDest = sourceIndex < destinationIndex ? destinationIndex - 1 : destinationIndex
        result.insert(group, at: adjustedDest)

        var updatedPinnedIDs: [String]? = nil
        if pinnedIDs.contains(group.bundleIdentifier) {
            let pinnedCount = pinnedIDs.count
            if destinationIndex < pinnedCount {
                var updated = pinnedIDs
                updated.removeAll { $0 == group.bundleIdentifier }
                let clampedIndex = min(destinationIndex, updated.count)
                updated.insert(group.bundleIdentifier, at: clampedIndex)
                updatedPinnedIDs = updated
            }
        }

        for i in result.indices {
            result[i].insertionOrder = i
        }

        return ReorderResult(groups: result, nextOrder: result.count, pinnedBundleIDs: updatedPinnedIDs)
    }

    static func closingEmptyGroups(
        _ groups: [AppGroup],
        pinnedBundleIDs: [String],
        keepRunningEmptyGroups: Bool = false
    ) -> (groups: [AppGroup], closed: [AppGroup]) {
        var result = groups
        var closed: [AppGroup] = []
        result.removeAll { group in
            if group.windows.isEmpty && !pinnedBundleIDs.contains(group.bundleIdentifier) {
                closed.append(group)
                if keepRunningEmptyGroups && group.runningApplication?.isTerminated == false {
                    return false
                }
                return true
            }
            return false
        }
        return (result, closed)
    }

    static func removingWindow(
        _ windowID: CGWindowID,
        from groups: [AppGroup],
        pinnedBundleIDs: [String],
        keepRunningEmptyGroups: Bool = false
    ) -> (groups: [AppGroup], closed: [AppGroup]) {
        var result = groups
        for i in result.indices {
            result[i].windows.removeAll { $0.windowID == windowID }
        }
        return closingEmptyGroups(result, pinnedBundleIDs: pinnedBundleIDs, keepRunningEmptyGroups: keepRunningEmptyGroups)
    }

    struct WindowMissTracker {
        private(set) var missCounts: [CGWindowID: Int] = [:]
        let maxMissesBeforeRemove: Int

        init(maxMissesBeforeRemove: Int) {
            self.maxMissesBeforeRemove = maxMissesBeforeRemove
        }

        mutating func hit(windowID: CGWindowID) {
            missCounts.removeValue(forKey: windowID)
        }

        mutating func miss(windowID: CGWindowID) -> Bool {
            let misses = (missCounts[windowID] ?? 0) + 1
            missCounts[windowID] = misses
            return misses >= maxMissesBeforeRemove
        }

        mutating func prune(keeping liveWindowIDs: Set<CGWindowID>) {
            missCounts = missCounts.filter { liveWindowIDs.contains($0.key) }
        }
    }
}
