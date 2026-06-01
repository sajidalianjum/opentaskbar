import AppKit

final class TaskbarSettings {
    static let shared = TaskbarSettings()

    enum DockMode: String {
        case coexist
        case autohide
        case hidden
    }

    enum BarAlignment: String {
        case left
        case center
        case right
    }

    static let settingsDidChange = Notification.Name("TaskbarSettingsDidChange")

    @Published var dockMode: DockMode {
        didSet { UserDefaults.standard.set(dockMode.rawValue, forKey: "dockMode"); postChange() }
    }

    @Published var showThumbnails: Bool {
        didSet { UserDefaults.standard.set(showThumbnails, forKey: "showThumbnails"); postChange() }
    }

    @Published var showAppNames: Bool {
        didSet { UserDefaults.standard.set(showAppNames, forKey: "showAppNames"); postChange() }
    }

    @Published var taskbarHeight: Double {
        didSet { UserDefaults.standard.set(taskbarHeight, forKey: "taskbarHeight"); postChange() }
    }

    @Published var showOnAllScreens: Bool {
        didSet { UserDefaults.standard.set(showOnAllScreens, forKey: "showOnAllScreens"); postChange() }
    }

    @Published var barAlignment: BarAlignment {
        didSet { UserDefaults.standard.set(barAlignment.rawValue, forKey: "barAlignment"); postChange() }
    }

    @Published var compactBar: Bool {
        didSet { UserDefaults.standard.set(compactBar, forKey: "compactBar"); postChange() }
    }

    @Published var barSpacing: Double {
        didSet { UserDefaults.standard.set(barSpacing, forKey: "barSpacing"); postChange() }
    }

    private var lastChangeKey: String?

    private func postChange() {
        NotificationCenter.default.post(name: TaskbarSettings.settingsDidChange, object: self)
    }

    private init() {
        let defaults = UserDefaults.standard
        self.dockMode = DockMode(rawValue: defaults.string(forKey: "dockMode") ?? "") ?? .hidden
        self.showThumbnails = defaults.object(forKey: "showThumbnails") as? Bool ?? true
        self.showAppNames = defaults.object(forKey: "showAppNames") as? Bool ?? false
        self.taskbarHeight = defaults.object(forKey: "taskbarHeight") as? Double ?? 48.0
        self.showOnAllScreens = defaults.object(forKey: "showOnAllScreens") as? Bool ?? true
        self.barAlignment = BarAlignment(rawValue: defaults.string(forKey: "barAlignment") ?? "") ?? .center
        self.compactBar = defaults.object(forKey: "compactBar") as? Bool ?? true
        self.barSpacing = defaults.object(forKey: "barSpacing") as? Double ?? 4.0
    }
}