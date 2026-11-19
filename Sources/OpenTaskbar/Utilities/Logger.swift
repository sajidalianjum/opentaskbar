import Foundation

final class Logger {
    static let shared = Logger()
    private let logFile: String = "/tmp/opentaskbar.log"
    private let maxLogSize: UInt64 = 5 * 1024 * 1024
    private let queue = DispatchQueue(label: "com.opentaskbar.logger")

    private init() {
        try? "=== OpenTaskbar log started \(Date()) ===\n".write(toFile: logFile, atomically: true, encoding: .utf8)
    }

    func log(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        let filename = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "\(timestamp) [\(filename):\(line) \(function)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        let logFile = self.logFile
        let maxLogSize = self.maxLogSize
        queue.async {
            // Use the throwing API: -[NSFileHandle writeData:] raises an
            // Objective-C exception (e.g. ENOSPC when the disk is full), which
            // Swift cannot catch and which terminated the app.
            guard let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logFile)) else { return }
            defer { try? handle.close() }
            guard let size = try? handle.seekToEnd() else { return }
            if size > maxLogSize {
                try? handle.truncate(atOffset: 0)
                try? handle.seek(toOffset: 0)
            }
            try? handle.write(contentsOf: data)
        }
    }
}
