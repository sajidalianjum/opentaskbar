import AppKit

final class TaskbarSettings {
    static let shared = TaskbarSettings()

    enum DockMode: String {
        case coexist
        case autohide
        case hidden
    }

    @Published var dockMode: DockMode {
        didSet { UserDefaults.standard.set(dockMode.rawValue, forKey: "dockMode") }
    }

    @Published var showThumbnails: Bool {
        didSet { UserDefaults.standard.set(showThumbnails, forKey: "showThumbnails") }
    }

    @Published var showAppNames: Bool {
        didSet { UserDefaults.standard.set(showAppNames, forKey: "showAppNames") }
    }

    @Published var taskbarHeight: Double {
        didSet { UserDefaults.standard.set(taskbarHeight, forKey: "taskbarHeight") }
    }

    @Published var showOnAllScreens: Bool {
        didSet { UserDefaults.standard.set(showOnAllScreens, forKey: "showOnAllScreens") }
    }

    private init() {
        let defaults = UserDefaults.standard
        self.dockMode = DockMode(rawValue: defaults.string(forKey: "dockMode") ?? "") ?? .hidden
        self.showThumbnails = defaults.object(forKey: "showThumbnails") as? Bool ?? true
        self.showAppNames = defaults.object(forKey: "showAppNames") as? Bool ?? true
        self.taskbarHeight = defaults.object(forKey: "taskbarHeight") as? Double ?? 48.0
        self.showOnAllScreens = defaults.object(forKey: "showOnAllScreens") as? Bool ?? true
    }
}