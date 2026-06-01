import AppKit

struct AppGroup: Hashable {
    let bundleIdentifier: String
    let localizedName: String
    let icon: NSImage
    let runningApplication: NSRunningApplication?
    var windows: [WindowInfo]
    var isActive: Bool
    var insertionOrder: Int

    var windowCount: Int {
        windows.count
    }

    var hasMultipleWindows: Bool {
        windows.count > 1
    }

    var isRunning: Bool {
        runningApplication != nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: AppGroup, rhs: AppGroup) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}