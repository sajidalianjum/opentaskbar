import AppKit

final class TaskbarSettings {
    static let shared = TaskbarSettings()

    enum BarAlignment: String {
        case left
        case center
        case right
    }

    enum BackgroundTheme: String {
        case system
        case dark
        case light
        case custom
    }

    enum TaskbarStyle: String {
        case taskbar
        case dock
    }

    static let settingsDidChange = Notification.Name("TaskbarSettingsDidChange")

    @Published var showThumbnails: Bool {
        didSet { UserDefaults.standard.set(showThumbnails, forKey: "showThumbnails"); postChange() }
    }

    @Published var showAppNames: Bool {
        didSet { UserDefaults.standard.set(showAppNames, forKey: "showAppNames"); postChange() }
    }

    @Published var showOnAllScreens: Bool {
        didSet { UserDefaults.standard.set(showOnAllScreens, forKey: "showOnAllScreens"); postChange() }
    }

    @Published var barAlignment: BarAlignment {
        didSet { UserDefaults.standard.set(barAlignment.rawValue, forKey: "barAlignment"); postChange() }
    }

    @Published var style: TaskbarStyle {
        didSet { UserDefaults.standard.set(style.rawValue, forKey: "style"); postChange() }
    }

    @Published var barSpacing: Double {
        didSet { UserDefaults.standard.set(barSpacing, forKey: "barSpacing"); postChange() }
    }

    @Published var iconSize: Double {
        didSet { UserDefaults.standard.set(iconSize, forKey: "iconSize"); postChange() }
    }

    @Published var showStartButton: Bool {
        didSet { UserDefaults.standard.set(showStartButton, forKey: "showStartButton"); postChange() }
    }

        @Published var backgroundTheme: BackgroundTheme {
            didSet {
                UserDefaults.standard.set(backgroundTheme.rawValue, forKey: "backgroundTheme")
                postChange()
            }
        }

    @Published var quitOnLastWindowClose: Bool {
        didSet { UserDefaults.standard.set(quitOnLastWindowClose, forKey: "quitOnLastWindowClose"); postChange() }
    }

    @Published var constrainZoomedWindows: Bool {
        didSet { UserDefaults.standard.set(constrainZoomedWindows, forKey: "constrainZoomedWindows"); postChange() }
    }

    @Published var hideOnFullscreen: Bool {
        didSet { UserDefaults.standard.set(hideOnFullscreen, forKey: "hideOnFullscreen"); postChange() }
    }

    var translucentBar: Bool {
        !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }

    @Published var customBackgroundColorData: Data {
        didSet { UserDefaults.standard.set(customBackgroundColorData, forKey: "customBackgroundColor"); postChange() }
    }

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin"); postChange() }
    }

    @Published var animationsEnabled: Bool {
        didSet { UserDefaults.standard.set(animationsEnabled, forKey: "animationsEnabled"); postChange() }
    }

    @Published var hoverDelay: Double {
        didSet { UserDefaults.standard.set(hoverDelay, forKey: "hoverDelay"); postChange() }
    }

    @Published var pinnedBundleIdentifiers: [String] {
        didSet { UserDefaults.standard.set(pinnedBundleIdentifiers, forKey: "pinnedBundleIdentifiers"); postChange() }
    }

    @Published var neverQuitBundleIdentifiers: [String] {
        didSet { UserDefaults.standard.set(neverQuitBundleIdentifiers, forKey: "neverQuitBundleIdentifiers"); postChange() }
    }

    func isPinned(_ bundleID: String) -> Bool {
        pinnedBundleIdentifiers.contains(bundleID)
    }

    func togglePin(_ bundleID: String) {
        if isPinned(bundleID) {
            pinnedBundleIdentifiers.removeAll { $0 == bundleID }
        } else {
            pinnedBundleIdentifiers.append(bundleID)
        }
    }

    func isNeverQuit(_ bundleID: String) -> Bool {
        neverQuitBundleIdentifiers.contains(bundleID)
    }

    func toggleNeverQuit(_ bundleID: String) {
        if isNeverQuit(bundleID) {
            neverQuitBundleIdentifiers.removeAll { $0 == bundleID }
        } else {
            neverQuitBundleIdentifiers.append(bundleID)
        }
    }

    func movePin(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < pinnedBundleIdentifiers.count,
              destinationIndex >= 0, destinationIndex < pinnedBundleIdentifiers.count else { return }
        let id = pinnedBundleIdentifiers.remove(at: sourceIndex)
        pinnedBundleIdentifiers.insert(id, at: destinationIndex)
    }

    var customBackgroundColor: NSColor {
        get {
            if let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: customBackgroundColorData) {
                return color
            }
            return NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                customBackgroundColorData = data
            }
        }
    }

    private var lastChangeKey: String?
    private var suppressPostChange = false
    private var batchDepth = 0
    private var accessibilityObserver: NSObjectProtocol?

    func beginBatchUpdates() { batchDepth += 1 }

    func endBatchUpdates() {
        batchDepth = max(batchDepth - 1, 0)
        if batchDepth == 0 { postChange() }
    }

    private func postChange() {
        guard !suppressPostChange else { return }
        guard batchDepth == 0 else { return }
        NotificationCenter.default.post(name: TaskbarSettings.settingsDidChange, object: self)
    }

    func reorderPinned(bundleID: String, to newIndex: Int) {
        suppressPostChange = true
        var updated = pinnedBundleIdentifiers
        updated.removeAll { $0 == bundleID }
        let clampedIndex = min(newIndex, updated.count)
        updated.insert(bundleID, at: clampedIndex)
        pinnedBundleIdentifiers = updated
        suppressPostChange = false
    }

    private init() {
        let defaults = UserDefaults.standard
        self.showThumbnails = defaults.object(forKey: "showThumbnails") as? Bool ?? false
        self.showStartButton = defaults.object(forKey: "showStartButton") as? Bool ?? true
        self.showAppNames = defaults.object(forKey: "showAppNames") as? Bool ?? false
        self.showOnAllScreens = defaults.object(forKey: "showOnAllScreens") as? Bool ?? true
        self.barAlignment = BarAlignment(rawValue: defaults.string(forKey: "barAlignment") ?? "") ?? .center
        self.style = TaskbarStyle(rawValue: defaults.string(forKey: "style") ?? "") ?? .taskbar
        self.barSpacing = defaults.object(forKey: "barSpacing") as? Double ?? 4.0
        self.iconSize = defaults.object(forKey: "iconSize") as? Double ?? 32.0
        self.quitOnLastWindowClose = defaults.object(forKey: "quitOnLastWindowClose") as? Bool ?? false
        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? true
        self.animationsEnabled = defaults.object(forKey: "animationsEnabled") as? Bool ?? true
        self.hoverDelay = defaults.object(forKey: "hoverDelay") as? Double ?? 0.4
        self.constrainZoomedWindows = defaults.object(forKey: "constrainZoomedWindows") as? Bool ?? false
        self.hideOnFullscreen = defaults.object(forKey: "hideOnFullscreen") as? Bool ?? true
        self.backgroundTheme = BackgroundTheme(rawValue: defaults.string(forKey: "backgroundTheme") ?? "") ?? .system
        defaults.removeObject(forKey: "translucentBar")
        self.pinnedBundleIdentifiers = defaults.stringArray(forKey: "pinnedBundleIdentifiers") ?? []
        self.neverQuitBundleIdentifiers = defaults.stringArray(forKey: "neverQuitBundleIdentifiers") ?? []
        if let saved = defaults.data(forKey: "customBackgroundColor") {
            self.customBackgroundColorData = saved
        } else {
            let defaultColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
            self.customBackgroundColorData = (try? NSKeyedArchiver.archivedData(withRootObject: defaultColor, requiringSecureCoding: false)) ?? Data()
        }

        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.postChange()
        }
    }
}