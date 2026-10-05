import AppKit

// Presents the updater to the user: the "new version is available" alert with
// Install / Release Notes / Skip / Later, plus any failure. Kept apart from
// UpdateManager so the state machine stays free of UI policy.
final class UpdatePresenter {
    static let shared = UpdatePresenter()

    private var observer: NSObjectProtocol?
    private var isPresenting = false
    private var presentedVersion: String?

    private let settings = TaskbarSettings.shared
    private let manager = UpdateManager.shared

    private init() {}

    func start() {
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
            if settings.installUpdatesAutomatically {
                Logger.shared.log("Auto-installing \(release.tagName)")
                manager.install(release)
            } else {
                presentUpdateAvailable(release)
            }
        case .failed(let error):
            presentFailure(error)
        case .upToDate:
            Logger.shared.log("Update check finished: already up to date")
        case .installing:
            Logger.shared.log("Installing update; the app will restart momentarily")
        case .checking, .downloading, .idle:
            break
        }
    }

    private func presentUpdateAvailable(_ release: UpdateRelease) {
        // Prompt once per version per session; repeated checks stay quiet.
        guard presentedVersion != release.tagName else { return }
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

        // runModal() answers with the ordinal of the chosen button.
        switch alert.runModal().rawValue {
        case 0:
            manager.install(release)
        case 1:
            manager.openReleasePage(release)
        case 2:
            manager.skip(release)
        default:
            break
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

        if alert.runModal().rawValue == 1 {
            manager.openReleasesPage()
        }
    }
}