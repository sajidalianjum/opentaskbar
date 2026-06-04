import CoreGraphics

struct WindowInfo: Hashable {
    let windowID: CGWindowID
    let pid: pid_t
    var title: String
    var frame: CGRect
    var isMinimized: Bool
    var isFullscreen: Bool
    var layer: Int
    var alpha: Double
    var ownerName: String?
    var documentPath: String? = nil

    var isValid: Bool {
        alpha > 0 && layer == 0 && frame.width > 50 && frame.height > 50
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(windowID)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.windowID == rhs.windowID
    }
}