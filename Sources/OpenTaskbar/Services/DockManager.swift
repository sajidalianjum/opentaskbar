import Foundation

final class DockManager {
    struct DockState: Equatable {
        var autohide: Bool
        var autohideDelay: Double?

        init(autohide: Bool, autohideDelay: Double?) {
            self.autohide = autohide
            self.autohideDelay = autohideDelay
        }

        init(dict: [String: Any]) {
            autohide = (dict["autohide"] as? Bool) ?? false
            if let delay = dict["autohide-delay"] as? Double {
                autohideDelay = delay
            } else if let delay = dict["autohide-delay"] as? NSNumber {
                autohideDelay = delay.doubleValue
            } else {
                autohideDelay = nil
            }
        }

        var asDictionary: [String: Any] {
            var dict: [String: Any] = ["autohide": autohide]
            if let autohideDelay {
                dict["autohide-delay"] = autohideDelay
            }
            return dict
        }

        func restoreCommandArgs(for domain: String) -> [[String]] {
            var commands: [[String]] = [
                ["write", domain, "autohide", "-bool", autohide ? "true" : "false"]
            ]
            if let autohideDelay {
                commands.append(["write", domain, "autohide-delay", "-float", "\(autohideDelay)"])
            } else {
                commands.append(["delete", domain, "autohide-delay"])
            }
            return commands
        }
    }

    private(set) var savedState: [String: Any] = [:]
    private let defaultsPath: String

    init(defaultsPath: String? = nil) {
        if let defaultsPath {
            self.defaultsPath = defaultsPath
        } else {
            self.defaultsPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/opentaskbar/dock-state.plist").path
        }
    }

    func hideDock() {
        if !hasSavedState() {
            saveCurrentDockState()
        }
        runDefaults(["write", "com.apple.dock", "autohide", "-bool", "true"])
        runDefaults(["write", "com.apple.dock", "autohide-delay", "-float", "1000"])
        restartDock()
    }

    func autoHideDock() {
        if !hasSavedState() {
            saveCurrentDockState()
        }
        runDefaults(["write", "com.apple.dock", "autohide", "-bool", "true"])
        restartDock()
    }

    func hasSavedState() -> Bool {
        FileManager.default.fileExists(atPath: defaultsPath)
    }

    func restoreDock() {
        if savedState.isEmpty {
            loadStateFromFile()
        }

        let state = DockState(dict: savedState)
        for args in state.restoreCommandArgs(for: "com.apple.dock") {
            runDefaults(args)
        }

        deleteSavedState()
        restartDock()
    }

    private func deleteSavedState() {
        try? FileManager.default.removeItem(atPath: defaultsPath)
        savedState = [:]
    }

    func loadStateFromFile() {
        guard FileManager.default.fileExists(atPath: defaultsPath) else { return }
        guard let saved = NSDictionary(contentsOfFile: defaultsPath) as? [String: Any] else { return }
        savedState = saved
    }

    func saveCurrentDockState() {
        savedState = [
            "autohide": shellReadDefaults("read", "com.apple.dock", "autohide") == "1",
            "autohide-delay": Double(shellReadDefaults("read", "com.apple.dock", "autohide-delay") ?? "0.5") ?? 0.5
        ]

        let dir = (defaultsPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        (savedState as NSDictionary).write(toFile: defaultsPath, atomically: true)
    }

    private func runDefaults(_ args: [String]) {
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
