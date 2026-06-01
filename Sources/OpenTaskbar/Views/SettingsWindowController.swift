import AppKit

final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private let settings = TaskbarSettings.shared

    private init() {}

    func showWindow() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenTaskbar Preferences"
        window.isReleasedWhenClosed = false
        window.center()

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 360))
        setupControls(in: contentView)
        window.contentView = contentView

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupControls(in view: NSView) {
        let padding: CGFloat = 20
        var y: CGFloat = 320

        let dockLabel = NSTextField(labelWithString: "Dock Mode:")
        dockLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        view.addSubview(dockLabel)
        dockLabel.frame = NSRect(x: padding, y: y, width: 150, height: 20)

        let dockSelect = NSPopUpButton(frame: NSRect(x: 170, y: y - 2, width: 200, height: 26))
        dockSelect.addItem(withTitle: "Coexist with Dock")
        dockSelect.addItem(withTitle: "Auto-hide Dock")
        dockSelect.addItem(withTitle: "Fully Hide Dock")
        switch settings.dockMode {
        case .coexist: dockSelect.selectItem(at: 0)
        case .autohide: dockSelect.selectItem(at: 1)
        case .hidden: dockSelect.selectItem(at: 2)
        }
        dockSelect.target = self
        dockSelect.action = #selector(dockModeChanged(_:))
        view.addSubview(dockSelect)

        y -= 40

        let thumbnailsCheck = NSButton(checkboxWithTitle: "Show Window Thumbnails on Hover", target: self, action: #selector(thumbnailsChanged(_:)))
        thumbnailsCheck.state = settings.showThumbnails ? .on : .off
        view.addSubview(thumbnailsCheck)
        thumbnailsCheck.frame = NSRect(x: padding, y: y, width: 300, height: 20)

        y -= 35

        let namesCheck = NSButton(checkboxWithTitle: "Show App Names", target: self, action: #selector(namesChanged(_:)))
        namesCheck.state = settings.showAppNames ? .on : .off
        view.addSubview(namesCheck)
        namesCheck.frame = NSRect(x: padding, y: y, width: 300, height: 20)

        y -= 35

        let allScreensCheck = NSButton(checkboxWithTitle: "Show on All Screens", target: self, action: #selector(allScreensChanged(_:)))
        allScreensCheck.state = settings.showOnAllScreens ? .on : .off
        view.addSubview(allScreensCheck)
        allScreensCheck.frame = NSRect(x: padding, y: y, width: 300, height: 20)

        y -= 45

        let heightLabel = NSTextField(labelWithString: "Taskbar Height:")
        heightLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        view.addSubview(heightLabel)
        heightLabel.frame = NSRect(x: padding, y: y + 5, width: 150, height: 20)

        let heightSlider = NSSlider(frame: NSRect(x: 170, y: y, width: 200, height: 20))
        heightSlider.minValue = 36
        heightSlider.maxValue = 72
        heightSlider.doubleValue = settings.taskbarHeight
        heightSlider.target = self
        heightSlider.action = #selector(heightChanged(_:))
        view.addSubview(heightSlider)

        y -= 30

        let heightValue = NSTextField(labelWithString: "\(Int(settings.taskbarHeight))pt")
        heightValue.font = NSFont.systemFont(ofSize: 12)
        heightValue.tag = 100
        view.addSubview(heightValue)
        heightValue.frame = NSRect(x: 370, y: y + 3, width: 40, height: 20)

        y -= 40

        let resetButton = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults))
        resetButton.bezelStyle = .rounded
        view.addSubview(resetButton)
        resetButton.frame = NSRect(x: padding, y: y, width: 150, height: 30)
    }

    @objc private func dockModeChanged(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 0: settings.dockMode = .coexist
        case 1: settings.dockMode = .autohide
        case 2: settings.dockMode = .hidden
        default: break
        }
        let dockManager = DockManager()
        switch settings.dockMode {
        case .coexist: dockManager.restoreDock()
        case .autohide: dockManager.autoHideDock()
        case .hidden: dockManager.hideDock()
        }
    }

    @objc private func thumbnailsChanged(_ sender: NSButton) {
        settings.showThumbnails = sender.state == .on
    }

    @objc private func namesChanged(_ sender: NSButton) {
        settings.showAppNames = sender.state == .on
    }

    @objc private func allScreensChanged(_ sender: NSButton) {
        settings.showOnAllScreens = sender.state == .on
    }

    @objc private func heightChanged(_ sender: NSSlider) {
        settings.taskbarHeight = sender.doubleValue
        if let window,
           let heightLabel = window.contentView?.viewWithTag(100) as? NSTextField {
            heightLabel.stringValue = "\(Int(sender.doubleValue))pt"
        }
    }

    @objc private func resetDefaults() {
        settings.dockMode = .hidden
        settings.showThumbnails = true
        settings.showAppNames = true
        settings.taskbarHeight = 48.0
        settings.showOnAllScreens = true
        window?.close()
        showWindow()
    }
}