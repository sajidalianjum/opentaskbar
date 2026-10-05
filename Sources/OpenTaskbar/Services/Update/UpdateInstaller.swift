import Foundation
import CommonCrypto

// Downloads a release artifact, verifies it, and stages it next to the running
// app. The final swap-and-relaunch is handed to a detached shell helper, because
// an app cannot replace its own bundle while it is running.
final class UpdateInstaller: NSObject {
    enum Stage {
        case downloading
        case verifying
        case unpacking
        case validating
        case installing

        var isTerminal: Bool { self == .installing }
    }

    private let session: URLSession
    private var downloadSession: URLSession?
    private var downloadCompletion: ((Result<URL, UpdateError>) -> Void)?
    private var destinationTask: URLSessionDownloadTask?

    private let workDirectory: URL

    init(session: URLSession = .shared, workDirectory: URL? = nil) {
        self.session = session
        self.workDirectory = workDirectory ?? UpdateInstaller.defaultWorkDirectory()
        super.init()
    }

    static func defaultWorkDirectory() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base
            .appendingPathComponent("com.opentaskbar.app", isDirectory: true)
            .appendingPathComponent("updates", isDirectory: true)
    }

    // Downloads land in their own subdirectory: the work directory also holds
    // the `staging-*` directories that the swap helper reads from, so cleaning
    // up an archive must never mean "remove the work directory".
    var downloadDirectory: URL {
        workDirectory.appendingPathComponent("downloads", isDirectory: true)
    }

    func cancel() {
        destinationTask?.cancel()
        downloadSession?.invalidateAndCancel()
        downloadSession = nil
        downloadDelegate = nil
        destinationTask = nil
        downloadCompletion = nil
    }

    // MARK: - Download

    func download(
        _ asset: ReleaseAsset,
        progress: @escaping (Stage, Double) -> Void,
        completion: @escaping (Result<URL, UpdateError>) -> Void
    ) {
        let directory = downloadDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            completion(.failure(.downloadFailed(error.localizedDescription)))
            return
        }

        let delegate = DownloadDelegate(destinationDirectory: directory)
        delegate.onProgress = { fraction in
            DispatchQueue.main.async { progress(.downloading, fraction) }
        }
        delegate.onCompletion = { result in
            DispatchQueue.main.async { completion(result) }
        }

        self.downloadCompletion = completion
        self.downloadDelegate = delegate
        self.downloadSession = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)

        guard let task = self.downloadSession?.downloadTask(with: asset.downloadURL) else {
            completion(.failure(.downloadFailed("could not start the download")))
            return
        }
        destinationTask = task
        task.resume()
    }

    private var downloadDelegate: DownloadDelegate?

    // MARK: - Verification

    static func sha256(of url: URL) throws -> String {
        guard let stream = InputStream(url: url) else {
            throw UpdateError.validationFailed("could not read \(url.lastPathComponent)")
        }
        stream.open()
        defer { stream.close() }

        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)
        let bufferSize = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                throw UpdateError.validationFailed(stream.streamError?.localizedDescription ?? "read error")
            }
            if read == 0 { break }
            CC_SHA256_Update(&context, buffer, CC_LONG(read))
        }

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&digest, &context)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // Checksums come from two places: the GitHub asset `digest` field, or the
    // `<asset>.sha256` sidecar that `Scripts/build.sh` uploads next to the zip.
    static func expectedChecksum(from asset: ReleaseAsset, session: URLSession = .shared) -> String? {
        if let sha256 = asset.sha256 {
            return sha256
        }

        let sidecarURL = URL(string: asset.downloadURL.absoluteString + ".sha256")
        guard let sidecarURL else { return nil }

        var request = URLRequest(url: sidecarURL)
        request.timeoutInterval = 10
        var text: String?
        let semaphore = DispatchSemaphore(value: 0)
        let task = session.dataTask(with: request) { data, _, _ in
            if let data { text = String(data: data, encoding: .utf8) }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 12)
        return text?.split(whereSeparator: { $0 == " " || $0 == "\n" }).first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    // MARK: - Unpack & validate

    func unpack(_ zip: URL, into directory: URL, progress: @escaping (Stage, Double) -> Void) throws -> URL {
        progress(.unpacking, 0)
        let fm = FileManager.default
        try? fm.removeItem(at: directory)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        // `ditto -x -k` preserves the bundle's symlinks and permissions, which
        // is exactly what Scripts/install.sh relies on.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zip.path, directory.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw UpdateError.unpackFailed(error.localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            throw UpdateError.unpackFailed(zip.lastPathComponent)
        }

        let candidates = (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        guard let bundle = candidates.first(where: { $0.lastPathComponent == "OpenTaskbar.app" }) else {
            throw UpdateError.unpackFailed("OpenTaskbar.app missing from archive")
        }
        progress(.unpacking, 1)
        return bundle
    }

    // Rejects anything that is not a drop-in replacement for the running app:
    // a different bundle identifier, an unexpected version, a missing
    // executable, or a bundle whose signature does not verify.
    func validate(bundle: URL, expectedVersion: AppVersion?) throws {
        let infoURL = bundle.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw UpdateError.validationFailed("Info.plist unreadable")
        }

        let expectedBundleID = Bundle.main.bundleIdentifier
        if let identifier = info["CFBundleIdentifier"] as? String,
           let expectedBundleID,
           identifier != expectedBundleID {
            throw UpdateError.validationFailed("bundle id mismatch: \(identifier)")
        }

        if let expectedVersion,
           let raw = info["CFBundleShortVersionString"] as? String,
           let actual = AppVersion(string: raw),
           actual != expectedVersion {
            throw UpdateError.validationFailed("version mismatch: got \(actual), expected \(expectedVersion)")
        }

        let executable = (info["CFBundleExecutable"] as? String) ?? "OpenTaskbar"
        let binaryURL = bundle.appendingPathComponent("Contents/MacOS/\(executable)")
        guard FileManager.default.isExecutableFile(atPath: binaryURL.path) else {
            throw UpdateError.validationFailed("executable missing")
        }

        guard verifySignature(of: bundle) else {
            throw UpdateError.validationFailed("code signature could not be verified")
        }
    }

    private func verifySignature(of bundle: URL) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", bundle.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    // MARK: - Staging & swap

    // Returns the directory the helper script waits on. Staged under the caches
    // directory so the payload survives our own termination. It is a sibling of
    // `downloads`, never a child of it: clearing an archive must not be able to
    // delete the staged bundle.
    func stagingDirectory(for release: UpdateRelease) -> URL {
        workDirectory.appendingPathComponent("staging-\(release.tagName)", isDirectory: true)
    }

    func stage(bundle: URL, release: UpdateRelease) throws -> URL {
        let stageDirectory = stagingDirectory(for: release)
        let fm = FileManager.default
        try? fm.removeItem(at: stageDirectory)
        try fm.createDirectory(at: stageDirectory, withIntermediateDirectories: true)

        let stagedBundle = stageDirectory.appendingPathComponent("OpenTaskbar.app")
        try fm.copyItem(at: bundle, to: stagedBundle)
        return stageDirectory
    }

    static func canReplaceBundle(at url: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return false }
        return fm.isWritableFile(atPath: URL(fileURLWithPath: url.path).deletingLastPathComponent().path)
    }

    // Whether the swap could actually succeed *from this process*. Unix
    // permissions are not enough on macOS: an app running out of ~/Documents,
    // ~/Desktop or ~/Downloads is inside a TCC-protected folder, so the rename
    // in the helper comes back EPERM ("Operation not permitted") no matter what
    // the mode bits say. Only a real write-then-rename probe tells the truth,
    // and it costs microseconds — do it before downloading anything.
    static func canSelfUpdate(at bundleURL: URL) -> Bool {
        let fm = FileManager.default
        let directory = URL(fileURLWithPath: bundleURL.path).deletingLastPathComponent()

        guard fm.fileExists(atPath: bundleURL.path) else { return false }

        let probe = directory.appendingPathComponent(".opentaskbar-update-probe-\(ProcessInfo.processInfo.processIdentifier)")
        let renamed = directory.appendingPathComponent(".opentaskbar-update-probe-renamed-\(ProcessInfo.processInfo.processIdentifier)")
        defer {
            try? fm.removeItem(at: probe)
            try? fm.removeItem(at: renamed)
        }

        guard fm.createFile(atPath: probe.path, contents: Data("probe".utf8)) else { return false }
        do {
            try fm.moveItem(at: probe, to: renamed)
        } catch {
            return false
        }
        return (try? fm.removeItem(at: renamed)) != nil
    }

    // Writes a self-contained shell script, launches it detached, and returns.
    // The script waits for this process to exit before touching the bundle, so
    // the running app never observes a half-swapped install. It mirrors the
    // steps in Scripts/install.sh: quarantine strip + TCC reconciliation.
    @discardableResult
    func scheduleReplacement(stagedBundle: URL, currentBundle: URL, pid: Int32) throws -> URL {
        let fm = FileManager.default
        let helperDirectory = workDirectory.appendingPathComponent("apply", isDirectory: true)
        try fm.createDirectory(at: helperDirectory, withIntermediateDirectories: true)

        let scriptURL = helperDirectory.appendingPathComponent("apply-update.sh")
        let logURL = helperDirectory.appendingPathComponent("apply-update.log")
        let script = UpdateInstaller.helperScript(
            pid: pid,
            stagedBundle: stagedBundle,
            currentBundle: currentBundle,
            logURL: logURL
        )
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path]
        let logHandle = try? FileHandle(forWritingTo: logURL)
        process.standardOutput = logHandle
        process.standardError = logHandle
        process.standardInput = FileHandle.nullDevice
        try process.run()
        return scriptURL
    }

    static func helperScript(
        pid: Int32,
        stagedBundle: URL,
        currentBundle: URL,
        logURL: URL
    ) -> String {
        """
        #!/bin/sh
        # Generated by OpenTaskbar's updater. Swaps the staged bundle in once the
        # running app has exited, then relaunches it. Mirrors Scripts/install.sh:
        # strips quarantine and reconciles the Accessibility (TCC) grant when the
        # ad-hoc signature changed.
        set -u

        STAGED='\(stagedBundle.path)'
        DEST='\(currentBundle.path)'
        LOG='\(logURL.path)'
        PID=\(pid)
        BUNDLE_ID='\(Bundle.main.bundleIdentifier ?? "com.opentaskbar.app")'
        STATE_FILE="$HOME/.config/opentaskbar/installed-cdhash"

        exec >>"$LOG" 2>&1
        echo "--- $(date) apply start (pid $PID) ---"

        # Any failure before/while swapping leaves the previous app intact, so
        # put the user back on the version they already had rather than
        # stranding them with no app at all.
        fail() {
            echo "error: $1"
            if [ -d "$DEST" ]; then
                echo "relaunching the existing bundle"
                /usr/bin/open "$DEST"
            fi
            exit 1
        }

        # Wait for the running app to exit before replacing its bundle.
        i=0
        while kill -0 "$PID" 2>/dev/null && [ "$i" -lt 100 ]; do
            sleep 0.1
            i=$((i + 1))
        done

        [ -d "$STAGED" ] || fail "staged bundle missing at $STAGED"

        BACKUP="${DEST}.opentaskbar-backup"
        rm -rf "$BACKUP"
        if [ -d "$DEST" ]; then
            mv "$DEST" "$BACKUP" || fail "could not move the existing bundle aside"
        fi

        if ! /usr/bin/ditto "$STAGED" "$DEST"; then
            echo "restoring the previous bundle"
            [ -d "$BACKUP" ] && mv "$BACKUP" "$DEST"
            fail "ditto failed"
        fi

        # The download path never sets quarantine; strip it defensively anyway.
        /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

        # Reconcile the Accessibility grant. macOS keys it to the app's code
        # requirement, which for an ad-hoc build is the cdhash — that changes on
        # every update, so a stale grant would leave the app waiting forever.
        SIGNATURE_KIND="$(/usr/bin/codesign -dv "$DEST" 2>&1 | /usr/bin/awk -F'=' '/^Signature/{print $2}')"
        CDHASH="$(/usr/bin/codesign -dv --verbose=4 "$DEST" 2>&1 | /usr/bin/awk -F'=' '/^CDHash/{print $2}' | head -1)"
        PREVIOUS_CDHASH="$(/bin/cat "$STATE_FILE" 2>/dev/null || true)"
        if [ "$SIGNATURE_KIND" = "adhoc" ] && [ -n "$PREVIOUS_CDHASH" ] && [ "$PREVIOUS_CDHASH" != "$CDHASH" ]; then
            /usr/bin/tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
            echo "cleared the stale Accessibility grant (ad-hoc signature changed)"
        fi
        if [ -n "$CDHASH" ]; then
            /bin/mkdir -p "$(/usr/bin/dirname "$STATE_FILE")" 2>/dev/null || true
            printf '%s' "$CDHASH" > "$STATE_FILE" 2>/dev/null || true
        fi

        rm -rf "$BACKUP" "$STAGED"

        echo "--- $(date) apply done, relaunching ---"
        /usr/bin/open "$DEST"
        """
    }
}

final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    var onProgress: ((Double) -> Void)?
    var onCompletion: ((Result<URL, UpdateError>) -> Void)?

    private let destinationDirectory: URL
    private var finished = false

    init(destinationDirectory: URL) {
        self.destinationDirectory = destinationDirectory
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else {
            onProgress?(0)
            return
        }
        onProgress?(min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0), 1))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard !finished else { return }
        finished = true

        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            onCompletion?(.failure(.httpStatus(http.statusCode)))
            return
        }

        let name = downloadTask.originalRequest?.url?.lastPathComponent ?? "OpenTaskbar.zip"
        let destination = destinationDirectory.appendingPathComponent(name)
        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            onCompletion?(.success(destination))
        } catch {
            onCompletion?(.failure(.downloadFailed(error.localizedDescription)))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !finished, let error else { return }
        finished = true
        let urlError = error as? URLError
        onCompletion?(.failure(.offline(urlError?.localizedDescription ?? error.localizedDescription)))
    }
}