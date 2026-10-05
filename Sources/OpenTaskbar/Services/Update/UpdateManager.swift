import AppKit

// Owns the update lifecycle: periodic checks, the "is there something newer"
// decision, and the download → verify → install pipeline. UI lives in
// Views/UpdatePresenter.swift and in the Settings / status-bar surfaces; this
// type only publishes state and asks the app delegate to quit when the staged
// bundle is ready to be swapped in.
final class UpdateManager {
    static let shared = UpdateManager()
    static let statusDidChange = Notification.Name("UpdateManagerStatusDidChange")

    enum Status: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(UpdateRelease)
        case downloading(UpdateRelease, fraction: Double)
        case installing(UpdateRelease)
        case failed(UpdateError)

        var release: UpdateRelease? {
            switch self {
            case .updateAvailable(let release): return release
            case .downloading(let release, _): return release
            case .installing(let release): return release
            default: return nil
            }
        }

        var isBusy: Bool {
            switch self {
            case .checking, .downloading, .installing: return true
            default: return false
            }
        }
    }

    private(set) var status: Status = .idle {
        didSet {
            guard status != oldValue else { return }
            onStatusChange?(status)
            NotificationCenter.default.post(name: UpdateManager.statusDidChange, object: self)
        }
    }

    var onStatusChange: ((Status) -> Void)?
    // Set by AppDelegate: restores the Dock and terminates so the helper script
    // can replace the bundle.
    var onReadyToRelaunch: (() -> Void)?

    private let feedClient: UpdateFeedClient
    private let installer: UpdateInstaller
    private let history: UpdateHistoryStore
    private let settings: TaskbarSettings

    private var launchTimer: Timer?
    private var pollTimer: Timer?
    private var isChecking = false

    let currentVersion: AppVersion?

    init(
        feedClient: UpdateFeedClient = UpdateFeedClient(),
        installer: UpdateInstaller = UpdateInstaller(),
        history: UpdateHistoryStore = .shared,
        settings: TaskbarSettings = .shared
    ) {
        self.feedClient = feedClient
        self.installer = installer
        self.history = history
        self.settings = settings
        self.currentVersion = AppVersion.bundleVersion
    }

    deinit {
        launchTimer?.invalidate()
        pollTimer?.invalidate()
    }

    // MARK: - Scheduling

    func start() {
        Logger.shared.log("Updater starting; current version \(currentVersion?.description ?? "unknown")")
        history.confirmPendingInstall(runningVersion: currentVersion)
        scheduleLaunchCheck()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.performScheduledCheck()
        }
    }

    private func scheduleLaunchCheck() {
        launchTimer?.invalidate()
        guard settings.autoCheckForUpdates else {
            Logger.shared.log("Automatic update checks are disabled")
            return
        }
        // Stagger past launch so the taskbar and permission checks settle first.
        launchTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            self?.performScheduledCheck()
        }
    }

    private func performScheduledCheck() {
        guard settings.autoCheckForUpdates else { return }
        guard history.shouldCheckNow() else { return }
        Logger.shared.log("Performing scheduled update check")
        checkForUpdates(userInitiated: false)
    }

    // MARK: - Checking

    func checkForUpdates(userInitiated: Bool) {
        guard !isChecking, !status.isBusy else { return }

        guard let currentVersion else {
            // A bundle without a version string cannot be reasoned about safely.
            Logger.shared.log("Cannot check for updates: the bundle has no readable version")
            return
        }

        isChecking = true
        status = .checking

        feedClient.fetchLatestRelease { [weak self] result in
            guard let self else { return }
            self.isChecking = false
            self.history.lastCheckDate = Date()

            switch result {
            case .failure(.notModified):
                // 304: the release we already saw is still the newest.
                self.handleUpToDate(currentVersion: currentVersion)
            case .failure(let error):
                Logger.shared.log("Update check failed: \(error.errorDescription ?? String(describing: error))")
                if userInitiated {
                    self.status = .failed(error)
                }
            case .success(let release):
                self.evaluate(release, against: currentVersion, userInitiated: userInitiated)
            }
        }
    }

    private func handleUpToDate(currentVersion: AppVersion) {
        history.skippedVersion = nil
        status = .upToDate
    }

    // Pure decision, kept separate so the "should I nag?" rules are testable.
    func evaluate(
        _ release: UpdateRelease,
        against currentVersion: AppVersion,
        userInitiated: Bool
    ) {
        guard let releaseVersion = release.version else {
            Logger.shared.log("Ignoring \(release.tagName): the tag is not a version")
            handleUpToDate(currentVersion: currentVersion)
            return
        }

        guard release.prerelease == false || settings.includePrereleaseUpdates else {
            Logger.shared.log("Ignoring \(release.tagName): prerelease and prerelease channel is off")
            handleUpToDate(currentVersion: currentVersion)
            return
        }

        if let installed = history.lastInstalledVersion.flatMap({ AppVersion(string: $0) }),
           installed >= releaseVersion {
            // We already installed this one; the running bundle simply predates it.
            Logger.shared.log("Ignoring \(release.tagName): already installed")
            handleUpToDate(currentVersion: currentVersion)
            return
        }

        guard releaseVersion > currentVersion else {
            Logger.shared.log("Up to date (\(currentVersion)); latest release is \(release.tagName)")
            handleUpToDate(currentVersion: currentVersion)
            return
        }

        guard release.appAsset != nil else {
            Logger.shared.log("Release \(release.tagName) has no macOS app asset")
            if userInitiated {
                status = .failed(.noAssetAvailable)
            }
            return
        }

        if !userInitiated, history.isSkipped(release.tagName) {
            Logger.shared.log("Release \(release.tagName) available but the user skipped it")
            status = .idle
            return
        }

        Logger.shared.log("Update available: \(currentVersion) -> \(release.tagName)")
        status = .updateAvailable(release)
    }

    // MARK: - Installing

    func install(_ release: UpdateRelease) {
        guard !status.isBusy else { return }

        let currentBundle = Bundle.main.bundleURL
        guard UpdateInstaller.canSelfUpdate(at: currentBundle) else {
            // Permissions alone are not enough: macOS protects ~/Documents,
            // ~/Desktop and ~/Downloads from being modified by other apps, so a
            // build running out of the project's source folder can never swap
            // itself. Say so now, before downloading anything.
            let error = UpdateError.selfUpdateBlocked(currentBundle.path)
            Logger.shared.log("Install aborted: \(error.errorDescription ?? String(describing: error))")
            status = .failed(error)
            return
        }

        guard let asset = release.appAsset else {
            status = .failed(.noAssetAvailable)
            return
        }

        status = .downloading(release, fraction: 0)
        Logger.shared.log("Downloading \(asset.name) (\(asset.size) bytes)")

        installer.download(asset) { [weak self] stage, fraction in
            self?.reportProgress(stage: stage, fraction: fraction, release: release)
        } completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.status = .failed(error)
            case .success(let zipURL):
                self.verifyAndInstall(zipURL: zipURL, asset: asset, release: release)
            }
        }
    }

    private func reportProgress(stage: UpdateInstaller.Stage, fraction: Double, release: UpdateRelease) {
        switch stage {
        case .downloading:
            status = .downloading(release, fraction: fraction * 0.7)
        case .verifying:
            status = .downloading(release, fraction: 0.72)
        case .unpacking:
            status = .downloading(release, fraction: 0.78 + fraction * 0.12)
        case .validating:
            status = .downloading(release, fraction: 0.92)
        case .installing:
            status = .installing(release)
        }
    }

    private func verifyAndInstall(zipURL: URL, asset: ReleaseAsset, release: UpdateRelease) {
        status = .downloading(release, fraction: 0.7)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let expected = UpdateInstaller.expectedChecksum(from: asset)
            if let expected {
                do {
                    let actual = try UpdateInstaller.sha256(of: zipURL)
                    guard actual == expected else {
                        DispatchQueue.main.async {
                            self.status = .failed(.checksumMismatch(expected: expected, actual: actual))
                        }
                        return
                    }
                    Logger.shared.log("Checksum verified for \(asset.name)")
                } catch {
                    DispatchQueue.main.async {
                        self.status = .failed(.validationFailed(error.localizedDescription))
                    }
                    return
                }
            } else {
                // No digest from GitHub and no sidecar: still safe (HTTPS + a
                // verified signature) but worth recording.
                Logger.shared.log("No published checksum for \(asset.name); relying on the code signature")
            }

            DispatchQueue.main.async {
                self.unpackAndInstall(zipURL: zipURL, release: release)
            }
        }
    }

    private func unpackAndInstall(zipURL: URL, release: UpdateRelease) {
        let unpackDirectory = UpdateInstaller.defaultWorkDirectory().appendingPathComponent("unpacked", isDirectory: true)
        do {
            let bundle = try installer.unpack(zipURL, into: unpackDirectory) { [weak self] stage, fraction in
                self?.reportProgress(stage: stage, fraction: fraction, release: release)
            }
            status = .downloading(release, fraction: 0.92)

            try installer.validate(bundle: bundle, expectedVersion: release.version)
            Logger.shared.log("Validated \(bundle.lastPathComponent) for \(release.tagName)")

            let stageDirectory = try installer.stage(bundle: bundle, release: release)
            let stagedBundle = stageDirectory.appendingPathComponent("OpenTaskbar.app")
            guard FileManager.default.fileExists(atPath: stagedBundle.path) else {
                throw UpdateError.validationFailed("staging produced no bundle at \(stagedBundle.lastPathComponent)")
            }

            // Remove only the unpacked archive and the download itself. The work
            // directory also holds `staging-*`, which the helper reads from once
            // we exit — deleting anything above the archive would break the swap.
            try? FileManager.default.removeItem(at: unpackDirectory)
            try? FileManager.default.removeItem(at: zipURL)

            status = .installing(release)
            // Only a *promise* is recorded here; UpdateManager.confirmPendingInstall()
            // promotes it once the relaunched app reports the new version.
            history.pendingInstallVersion = release.tagName
            history.skippedVersion = nil

            try installer.scheduleReplacement(
                stagedBundle: stagedBundle,
                currentBundle: Bundle.main.bundleURL,
                pid: ProcessInfo.processInfo.processIdentifier
            )
            Logger.shared.log("Helper scheduled; terminating for replacement and relaunch")

            // Give the log a beat to flush, then hand over to the app delegate.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.onReadyToRelaunch?()
            }
        } catch {
            status = .failed((error as? UpdateError) ?? .validationFailed(error.localizedDescription))
        }
    }

    // MARK: - Misc

    func openReleasePage(_ release: UpdateRelease) {
        NSWorkspace.shared.open(release.htmlURL)
    }

    func openReleasesPage() {
        NSWorkspace.shared.open(UpdateFeedClient.releasePageURL())
    }

    func skip(_ release: UpdateRelease) {
        history.skippedVersion = release.tagName
        status = .idle
    }

    func dismissStatus() {
        guard !status.isBusy else { return }
        status = .idle
    }

    var pendingRelease: UpdateRelease? {
        status.release
    }

    var lastCheckDate: Date? {
        history.lastCheckDate
    }

    var currentVersionDescription: String {
        currentVersion?.description ?? "—"
    }
}

private extension UpdateError {
    func description() -> String {
        if let description = errorDescription { return description }
        return String(describing: self)
    }
}