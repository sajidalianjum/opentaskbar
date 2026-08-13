import Foundation

final class SingleInstanceLock {
    private static let lockPath = FileManager.default.temporaryDirectory.appendingPathComponent("com.opentaskbar.lock")

    static func acquire(lockFilePath: String? = nil) -> Bool {
        let path = lockFilePath ?? lockPath.path
        if FileManager.default.fileExists(atPath: path) {
            let pidString = try? String(contentsOfFile: path, encoding: .utf8)
            if let pid = pidString.flatMap(Int.init) {
                if kill(pid_t(pid), 0) == 0 {
                    return false
                }
            }
        }

        try? "\(ProcessInfo.processInfo.processIdentifier)".write(toFile: path, atomically: true, encoding: .utf8)
        return true
    }

    static func release(lockFilePath: String? = nil) {
        let path = lockFilePath ?? lockPath.path
        try? FileManager.default.removeItem(atPath: path)
    }
}
