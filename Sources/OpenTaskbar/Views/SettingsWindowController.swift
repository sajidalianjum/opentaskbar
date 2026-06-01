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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenTaskbar Preferences"
        window.isReleasedWhenClosed = false
        window.center()

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 480))
        setupControls(in: contentView)
        window.contentView = contentView

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupControls(in view: NSView) {
        let padding: CGFloat = 20
        var y: CGFloat = 440

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

        let alignmentLabel = NSTextField(labelWithString: "Bar Alignment:")
        alignmentLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        view.addSubview(alignmentLabel)
        alignmentLabel.frame = NSRect(x: padding, y: y, width: 150, height: 20)

        let alignmentSelect = NSPopUpButton(frame: NSRect(x: 170, y: y - 2, width: 200, height: 26))
        alignmentSelect.addItem(withTitle: "Left")
        alignmentSelect.addItem(withTitle: "Center")
        alignmentSelect.addItem(withTitle: "Right")
        switch settings.barAlignment {
        case .left: alignmentSelect.selectItem(at: 0)
        case .center: alignmentSelect.selectItem(at: 1)
        case .right: alignmentSelect.selectItem(at: 2)
        }
        alignmentSelect.target = self
        alignmentSelect.action = #selector(alignmentChanged(_:))
        view.addSubview(alignmentSelect)

        y -= 40

        let compactCheck = NSButton(checkboxWithTitle: "Compact Bar (wrap content only)", target: self, action: #selector(compactChanged(_:)))
        compactCheck.state = settings.compactBar ? .on : .off
        view.addSubview(compactCheck)
        compactCheck.frame = NSRect(x: padding, y: y, width: 300, height: 20)

        y -= 35

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

        y -= 40

        let spacingLabel = NSTextField(labelWithString: "Bar Spacing:")
        spacingLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        view.addSubview(spacingLabel)
        spacingLabel.frame = NSRect(x: padding, y: y + 5, width: 150, height: 20)

        let spacingSlider = NSSlider(frame: NSRect(x: 170, y: y, width: 200, height: 20))
        spacingSlider.minValue = 0
        spacingSlider.maxValue = 16
        spacingSlider.doubleValue = settings.barSpacing
        spacingSlider.target = self
        spacingSlider.action = #selector(spacingChanged(_:))
        view.addSubview(spacingSlider)

        y -= 30

        let spacingValue = NSTextField(labelWithString: "\(Int(settings.barSpacing))px")
        spacingValue.font = NSFont.systemFont(ofSize: 12)
        spacingValue.tag = 101
        view.addSubview(spacingValue)
        spacingValue.frame = NSRect(x: 370, y: y + 3, width: 40, height: 20)

        y -= 40

        let iconSizeLabel = NSTextField(labelWithString: "App Icon Size:")
        iconSizeLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        view.addSubview(iconSizeLabel)
        iconSizeLabel.frame = NSRect(x: padding, y: y + 5, width: 150, height: 20)

        let iconSizeSlider = NSSlider(frame: NSRect(x: 170, y: y, width: 200, height: 20))
        iconSizeSlider.minValue = 16
        iconSizeSlider.maxValue = 64
        iconSizeSlider.doubleValue = settings.iconSize
        iconSizeSlider.target = self
        iconSizeSlider.action = #selector(iconSizeChanged(_:))
        view.addSubview(iconSizeSlider)

        y -= 30

        let iconSizeValue = NSTextField(labelWithString: "\(Int(settings.iconSize))pt")
        iconSizeValue.font = NSFont.systemFont(ofSize: 12)
        iconSizeValue.tag = 102
        view.addSubview(iconSizeValue)
        iconSizeValue.frame = NSRect(x: 370, y: y + 3, width: 40, height: 20)

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

    @objc private func alignmentChanged(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 0: settings.barAlignment = .left
        case 1: settings.barAlignment = .center
        case 2: settings.barAlignment = .right
        default: break
        }
    }

    @objc private func compactChanged(_ sender: NSButton) {
        settings.compactBar = sender.state == .on
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

    @objc private func spacingChanged(_ sender: NSSlider) {
        settings.barSpacing = sender.doubleValue
        if let window,
           let spacingLabel = window.contentView?.viewWithTag(101) as? NSTextField {
            spacingLabel.stringValue = "\(Int(sender.doubleValue))px"
        }
    }

    @objc private func iconSizeChanged(_ sender: NSSlider) {
        settings.iconSize = sender.doubleValue
        if let window,
           let iconSizeLabel = window.contentView?.viewWithTag(102) as? NSTextField {
            iconSizeLabel.stringValue = "\(Int(sender.doubleValue))pt"
        }
    }

    @objc private func resetDefaults() {
        settings.dockMode = .hidden
        settings.showThumbnails = true
        settings.showAppNames = false
        settings.showOnAllScreens = true
        settings.barAlignment = .center
        settings.compactBar = true
        settings.barSpacing = 4.0
        settings.iconSize = 32.0
        window?.close()
        showWindow()
    }
}