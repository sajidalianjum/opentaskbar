import Foundation

final class SingleInstanceLock {
    private static let lockPath = FileManager.default.temporaryDirectory.appendingPathComponent("com.opentaskbar.lock")

    static func acquire() -> Bool {
        let path = lockPath.path
        if FileManager.default.fileExists(atPath: path) {
            let pidString = try? String(contentsOfFile: path, encoding: .utf8)
            if let pid = pidString.flatMap(Int.init) {
                if kill(pid_t(pid), 0) == 0 {
                    return false
                }
            }
        }

        try? "\(ProcessInfo.processInfo.processIdentifier)".write(to: lockPath, atomically: true, encoding: .utf8)
        return true
    }

    static func release() {
        try? FileManager.default.removeItem(at: lockPath)
    }
}