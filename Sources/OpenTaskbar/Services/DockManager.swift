import Foundation

final class DockManager {
    private var savedState: [String: Any] = [:]
    private let defaultsPath: String

    init() {
        defaultsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/opentaskbar/dock-state.plist").path
    }

    func hideDock() {
        if !hasSavedState() {
            saveCurrentDockState()
        }
        runDefaults("write", "com.apple.dock", "autohide", "-bool", "true")
        runDefaults("write", "com.apple.dock", "autohide-delay", "-float", "1000")
        restartDock()
    }

    func autoHideDock() {
        if !hasSavedState() {
            saveCurrentDockState()
        }
        runDefaults("write", "com.apple.dock", "autohide", "-bool", "true")
        restartDock()
    }

    func hasSavedState() -> Bool {
        FileManager.default.fileExists(atPath: defaultsPath)
    }

    func restoreDock() {
        if savedState.isEmpty {
            loadStateFromFile()
        }

        let autohide = (savedState["autohide"] as? Bool) ?? false
        runDefaults("write", "com.apple.dock", "autohide", "-bool", autohide ? "true" : "false")

        if let delay = savedState["autohide-delay"] as? Double {
            runDefaults("write", "com.apple.dock", "autohide-delay", "-float", "\(delay)")
        } else {
            runDefaults("delete", "com.apple.dock", "autohide-delay")
        }

        deleteSavedState()
        restartDock()
    }

    private func deleteSavedState() {
        try? FileManager.default.removeItem(atPath: defaultsPath)
        savedState = [:]
    }

    private func loadStateFromFile() {
        guard FileManager.default.fileExists(atPath: defaultsPath) else { return }
        guard let saved = NSDictionary(contentsOfFile: defaultsPath) as? [String: Any] else { return }
        savedState = saved
    }

    private func saveCurrentDockState() {
        savedState = [
            "autohide": shellReadDefaults("read", "com.apple.dock", "autohide") == "1",
            "autohide-delay": Double(shellReadDefaults("read", "com.apple.dock", "autohide-delay") ?? "0.5") ?? 0.5
        ]

        let dir = (defaultsPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        (savedState as NSDictionary).write(toFile: defaultsPath, atomically: true)
    }

    private func runDefaults(_ args: String...) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = args
        try? process.run()
        process.waitUntilExit()
    }

    private func restartDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        try? process.run()
        process.waitUntilExit()
    }

    private func shellReadDefaults(_ args: String...) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}