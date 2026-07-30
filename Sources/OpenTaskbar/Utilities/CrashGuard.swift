import Foundation

final class CrashGuard {
    private static var signalReadFd: Int32 = 0
    private static var signalWriteFd: Int32 = 0
    private static weak var dockManager: DockManager?

    private static let cleanExitPath = "/tmp/com.opentaskbar.clean_exit"
    private static let crashLogPath = "/tmp/opentaskbar.crash"

    private static func writeCrashLog(_ message: String) {
        let line = "\(Date()): \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: crashLogPath) {
                if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: crashLogPath)) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? line.write(toFile: crashLogPath, atomically: true, encoding: .utf8)
            }
        }
    }

    private static func writeCrashLogSync(_ message: String) {
        let line = "\(Date()): \(message)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: crashLogPath) {
                if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: crashLogPath)) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    handle.closeFile()
                }
            } else {
                try? line.write(toFile: crashLogPath, atomically: true, encoding: .utf8)
            }
        }
    }

    private static let _signalHandler: @convention(c) (Int32) -> Void = { sig in
        var s = sig
        write(CrashGuard.signalWriteFd, &s, MemoryLayout<Int32>.size)
    }

    private static let _exceptionHandler: @convention(c) (NSException) -> Void = { exception in
        CrashGuard.writeCrashLogSync("EXCEPTION: \(exception.name.rawValue) reason=\(exception.reason ?? "nil") userInfo=\(exception.userInfo ?? [:]) callStack=\(exception.callStackSymbols.joined(separator: "\n"))")
        CrashGuard.dockManager?.restoreDock()
    }

    private var dispatchSource: DispatchSourceRead?
    private let dockManagerInstance: DockManager

    init(dockManager: DockManager) {
        self.dockManagerInstance = dockManager
        Self.dockManager = dockManager
    }

    func install() {
        setupPipe()
        installSignalHandlers()
        installExceptionHandler()
    }

    private func setupPipe() {
        var fds: [Int32] = [0, 0]
        let result = pipe(&fds)
        guard result == 0 else { return }

        Self.signalReadFd = fds[0]
        Self.signalWriteFd = fds[1]
        _ = fcntl(Self.signalReadFd, F_SETFL, O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: Self.signalReadFd, queue: .main)
        source.setEventHandler { [weak self] in
            self?.handleSignal()
        }
        source.resume()
        dispatchSource = source
    }

    private func installSignalHandlers() {
        signal(SIGTERM, Self._signalHandler)
        signal(SIGINT, Self._signalHandler)
        signal(SIGQUIT, Self._signalHandler)
    }

    private func handleSignal() {
        dockManagerInstance.restoreDock()

        var sig: Int32 = 0
        while read(Self.signalReadFd, &sig, MemoryLayout<Int32>.size) > 0 {}

        Self.writeCrashLog("SIGNAL \(sig) received")
        let lastSig = sig != 0 ? sig : SIGTERM
        signal(lastSig, SIG_DFL)
        raise(lastSig)
    }

    private func installExceptionHandler() {
        NSSetUncaughtExceptionHandler(Self._exceptionHandler)
    }

    static func markCleanExit() {
        try? "".write(toFile: cleanExitPath, atomically: true, encoding: .utf8)
    }

    static func clearCleanExit() {
        try? FileManager.default.removeItem(atPath: cleanExitPath)
    }

    static func isCleanExit() -> Bool {
        FileManager.default.fileExists(atPath: cleanExitPath)
    }
}
