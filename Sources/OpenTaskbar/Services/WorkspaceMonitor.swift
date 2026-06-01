import AppKit

final class WorkspaceMonitor {
    private var observers: [NSObjectProtocol] = []

    var onAppLaunched: ((NSRunningApplication) -> Void)?
    var onAppTerminated: ((NSRunningApplication) -> Void)?
    var onAppActivated: ((NSRunningApplication) -> Void)?
    var onAppDeactivated: ((NSRunningApplication) -> Void)?
    var onScreenParametersChanged: (() -> Void)?

    func start() {
        let nc = NSWorkspace.shared.notificationCenter

        let launchObserver = nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.onAppLaunched?(app)
        }

        let terminateObserver = nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.onAppTerminated?(app)
        }

        let activateObserver = nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.onAppActivated?(app)
        }

        let deactivateObserver = nc.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.onAppDeactivated?(app)
        }

        let screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.onScreenParametersChanged?()
        }

        observers = [launchObserver, terminateObserver, activateObserver, deactivateObserver, screenObserver]
    }

    func stop() {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
    }

    deinit {
        stop()
    }
}