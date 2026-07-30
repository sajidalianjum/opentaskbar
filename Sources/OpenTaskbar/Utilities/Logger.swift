import Foundation

final class Logger {
    static let shared = Logger()
    private let logFile: String = "/tmp/opentaskbar.log"
    private let queue = DispatchQueue(label: "com.opentaskbar.logger")

    private init() {
        try? "=== OpenTaskbar log started \(Date()) ===\n".write(toFile: logFile, atomically: true, encoding: .utf8)
    }

    func log(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        let filename = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "\(timestamp) [\(filename):\(line) \(function)] \(message)\n"
        queue.async {
            if let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: self.logFile)) {
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            }
        }
    }
}
