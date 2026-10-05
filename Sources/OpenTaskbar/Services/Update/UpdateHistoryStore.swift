import Foundation

// Bookkeeping for the updater. Deliberately separate from TaskbarSettings:
// these are not user-facing preferences, they are the updater's memory
// (when did we last look, what did the user defer) and are wiped when the
// updater is reset. Injectable `UserDefaults` so it is unit-testable.
final class UpdateHistoryStore {
    static let shared = UpdateHistoryStore()

    static let defaultCheckInterval: TimeInterval = 24 * 60 * 60

    private let defaults: UserDefaults
    private let checkInterval: TimeInterval

    init(defaults: UserDefaults = .standard, checkInterval: TimeInterval = UpdateHistoryStore.defaultCheckInterval) {
        self.defaults = defaults
        self.checkInterval = checkInterval
    }

    var lastCheckDate: Date? {
        get { defaults.object(forKey: Keys.lastCheck) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastCheck) }
    }

    // The version the user chose to skip ("Remind me later" is per-version).
    var skippedVersion: String? {
        get { defaults.string(forKey: Keys.skippedVersion) }
        set {
            guard let newValue = newValue else {
                defaults.removeObject(forKey: Keys.skippedVersion)
                return
            }
            defaults.set(newValue, forKey: Keys.skippedVersion)
        }
    }

    var lastInstalledVersion: String? {
        get { defaults.string(forKey: Keys.lastInstalled) }
        set { defaults.set(newValue, forKey: Keys.lastInstalled) }
    }

    // Written just before the app exits to install an update, and promoted to
    // `lastInstalledVersion` on the next launch only if the new version is
    // actually the one running. An install that never completed therefore
    // cannot leave a stale record that hides the update forever.
    var pendingInstallVersion: String? {
        get { defaults.string(forKey: Keys.pendingInstall) }
        set { defaults.set(newValue, forKey: Keys.pendingInstall) }
    }

    func confirmPendingInstall(runningVersion: AppVersion?) {
        guard let pending = pendingInstallVersion else { return }
        pendingInstallVersion = nil
        guard let runningVersion, AppVersion(string: pending) == runningVersion else { return }
        lastInstalledVersion = pending
    }

    func shouldCheckNow(at date: Date = Date()) -> Bool {
        guard let last = lastCheckDate else { return true }
        return date.timeIntervalSince(last) >= checkInterval
    }

    func isSkipped(_ version: String) -> Bool {
        skippedVersion == version
    }

    func reset() {
        defaults.removeObject(forKey: Keys.lastCheck)
        defaults.removeObject(forKey: Keys.skippedVersion)
        defaults.removeObject(forKey: Keys.lastInstalled)
        defaults.removeObject(forKey: Keys.pendingInstall)
    }

    private enum Keys {
        static let lastCheck = "opentaskbar.update.lastCheck"
        static let skippedVersion = "opentaskbar.update.skippedVersion"
        static let lastInstalled = "opentaskbar.update.lastInstalledVersion"
        static let pendingInstall = "opentaskbar.update.pendingInstallVersion"
    }
}