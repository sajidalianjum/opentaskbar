import AppKit

// Presents the updater to the user: the "new version is available" alert with
// Install / Release Notes / Skip / Later, plus any failure. Kept apart from
// UpdateManager so the state machine stays free of UI policy.
final class UpdatePresenter {
    static let shared = UpdatePresenter()

    private var observer: NSObjectProtocol?
    private var isPresenting = false
    private var presentedVersion: String?
    private var isUserInitiatedCheck = false

    private let settings = TaskbarSettings.shared
    private let manager = UpdateManager.shared

    private init() {}

    func start() {
        stop()
        observer = NotificationCenter.default.addObserver(
            forName: UpdateManager.statusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleStatusChange()
        }
        handleStatusChange()
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    // Manual entry point (status-bar menu / Settings button).
    func checkForUpdates(userInitiated: Bool = true) {
        if userInitiated {
            isUserInitiatedCheck = true
            presentedVersion = nil
        }
        manager.checkForUpdates(userInitiated: userInitiated)
    }

    func installPendingUpdate() {
        guard let release = manager.pendingRelease else { return }
        manager.install(release)
    }

    private func handleStatusChange() {
        guard !isPresenting else { return }

        switch manager.status {
        case .updateAvailable(let release):
            let manual = isUserInitiatedCheck
            isUserInitiatedCheck = false
            if settings.installUpdatesAutomatically {
                Logger.shared.log("Auto-installing \(release.tagName)")
                manager.install(release)
            } else {
                presentUpdateAvailable(release, userInitiated: manual)
            }
        case .failed(let error):
            isUserInitiatedCheck = false
            presentFailure(error)
        case .upToDate:
            Logger.shared.log("Update check finished: already up to date")
            if isUserInitiatedCheck {
                isUserInitiatedCheck = false
                presentUpToDate()
            }
        case .installing:
            isUserInitiatedCheck = false
            Logger.shared.log("Installing update; the app will restart momentarily")
        case .checking, .downloading, .idle:
            break
        }
    }

    private func presentUpdateAvailable(_ release: UpdateRelease, userInitiated: Bool = false) {
        if !userInitiated {
            // Prompt once per version per session during background checks; repeated background checks stay quiet.
            guard presentedVersion != release.tagName else { return }
        }
        presentedVersion = release.tagName
        isPresenting = true
        defer { isPresenting = false }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.updateAvailableTitle(release.tagName)
        alert.addButton(withTitle: L10n.updateInstallAndRelaunch)
        alert.addButton(withTitle: L10n.updateShowReleaseNotes)
        alert.addButton(withTitle: L10n.updateSkipVersion)
        alert.addButton(withTitle: L10n.updateRemindLater)

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            manager.install(release)
        case .alertSecondButtonReturn:
            manager.openReleasePage(release)
        case .alertThirdButtonReturn:
            manager.skip(release)
        default:
            // "Remind Me Later" - clear presentedVersion so future checks can prompt again.
            presentedVersion = nil
        }
    }

    private func presentFailure(_ error: UpdateError) {
        isPresenting = true
        defer { isPresenting = false }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L10n.updateFailedTitle
        alert.informativeText = error.errorDescription ?? L10n.updateFailedMessage
        alert.addButton(withTitle: L10n.ok)
        alert.addButton(withTitle: L10n.updateShowReleaseNotes)

        if alert.runModal() == .alertSecondButtonReturn {
            manager.openReleasesPage()
        }
    }

    private func presentUpToDate() {
        isPresenting = true
        defer { isPresenting = false }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = L10n.updateStatusUpToDate(manager.currentVersionDescription)
        alert.addButton(withTitle: L10n.ok)
        alert.runModal()
    }
}