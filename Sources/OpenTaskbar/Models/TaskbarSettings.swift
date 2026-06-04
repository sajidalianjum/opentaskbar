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

    @Published var dockMode: Bool {
        didSet { UserDefaults.standard.set(dockMode, forKey: "dockMode"); postChange() }
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
            if backgroundTheme == .system {
                translucentBar = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            }
            postChange()
        }
    }

    @Published var quitOnLastWindowClose: Bool {
        didSet { UserDefaults.standard.set(quitOnLastWindowClose, forKey: "quitOnLastWindowClose"); postChange() }
    }

    @Published var constrainZoomedWindows: Bool {
        didSet { UserDefaults.standard.set(constrainZoomedWindows, forKey: "constrainZoomedWindows"); postChange() }
    }

    @Published var translucentBar: Bool {
        didSet { UserDefaults.standard.set(translucentBar, forKey: "translucentBar"); postChange() }
    }

    @Published var customBackgroundColorData: Data {
        didSet { UserDefaults.standard.set(customBackgroundColorData, forKey: "customBackgroundColor"); postChange() }
    }

    @Published var pinnedBundleIdentifiers: [String] {
        didSet { UserDefaults.standard.set(pinnedBundleIdentifiers, forKey: "pinnedBundleIdentifiers"); postChange() }
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
    private var accessibilityObserver: NSObjectProtocol?

    private func postChange() {
        guard !suppressPostChange else { return }
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
        self.dockMode = defaults.object(forKey: "dockMode") as? Bool ?? true
        self.barSpacing = defaults.object(forKey: "barSpacing") as? Double ?? 4.0
        self.iconSize = defaults.object(forKey: "iconSize") as? Double ?? 32.0
        self.quitOnLastWindowClose = defaults.object(forKey: "quitOnLastWindowClose") as? Bool ?? false
        self.constrainZoomedWindows = defaults.object(forKey: "constrainZoomedWindows") as? Bool ?? false
        self.translucentBar = defaults.object(forKey: "translucentBar") as? Bool ?? !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        self.backgroundTheme = BackgroundTheme(rawValue: defaults.string(forKey: "backgroundTheme") ?? "") ?? .system
        self.pinnedBundleIdentifiers = defaults.stringArray(forKey: "pinnedBundleIdentifiers") ?? []
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
            guard let self, self.backgroundTheme == .system else { return }
            self.translucentBar = !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        }
    }
}