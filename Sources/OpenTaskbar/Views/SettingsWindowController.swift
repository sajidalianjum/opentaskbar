import AppKit

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private let settings = TaskbarSettings.shared

    private var colorRow: NSView?
    private var colorRowHeight: NSLayoutConstraint?
    private weak var spacingValueLabel: NSTextField?
    private weak var iconSizeValueLabel: NSTextField?

    private init() {}

    func showWindow() {
        if let window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenTaskbar Preferences"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 400)
        window.center()

        guard let contentFrame = window.contentView?.bounds else { return }
        let scrollView = NSScrollView(frame: contentFrame)
        scrollView.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay

        let contentView = FlippedView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = contentView
        window.contentView = scrollView

        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        setupControls(in: contentView)

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setupControls(in view: NSView) {
        let hPad: CGFloat = 20
        let labelW: CGFloat = 130
        let gap: CGFloat = 8
        let rowGap: CGFloat = 10
        let secGap: CGFloat = 16

        var prev: NSView?

        func section(_ title: String) {
            let label = NSTextField(labelWithString: title.uppercased())
            label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            label.textColor = NSColor.secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? view.topAnchor, constant: secGap),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
            ])
            prev = label
        }

        func separator() {
            let line = NSBox()
            line.boxType = .separator
            line.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(line)
            NSLayoutConstraint.activate([
                line.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? view.topAnchor, constant: secGap),
                line.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
                line.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hPad),
            ])
            prev = line
        }

        func labeled<T: NSView>(_ text: String, control: T) {
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.systemFont(ofSize: 13)
            label.translatesAutoresizingMaskIntoConstraints = false
            control.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            view.addSubview(control)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? view.topAnchor, constant: rowGap),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
                label.widthAnchor.constraint(equalToConstant: labelW),

                control.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                control.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: gap),
                control.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hPad),
            ])
            prev = label
        }

        @discardableResult
        func checkbox(_ title: String, action: Selector, state: NSControl.StateValue) -> NSButton {
            let btn = NSButton(checkboxWithTitle: title, target: self, action: action)
            btn.state = state
            btn.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? view.topAnchor, constant: rowGap),
                btn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
            ])
            prev = btn
            return btn
        }

        func sliderRow(_ text: String, slider: NSSlider, valueLabel: NSTextField) {
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.systemFont(ofSize: 13)
            label.translatesAutoresizingMaskIntoConstraints = false
            slider.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            view.addSubview(slider)
            view.addSubview(valueLabel)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? view.topAnchor, constant: rowGap),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
                label.widthAnchor.constraint(equalToConstant: labelW),

                slider.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                slider.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: gap),
                slider.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -gap),

                valueLabel.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                valueLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hPad),
                valueLabel.widthAnchor.constraint(equalToConstant: 42),
            ])
            prev = label
        }

        // ─── General ───
        section("General")

        let styleSelect = NSPopUpButton()
        styleSelect.addItem(withTitle: "Taskbar")
        styleSelect.addItem(withTitle: "Dock")
        styleSelect.selectItem(at: settings.style == .taskbar ? 0 : 1)
        styleSelect.target = self
        styleSelect.action = #selector(styleChanged(_:))
        labeled("Style", control: styleSelect)

        let alignSelect = NSPopUpButton()
        alignSelect.addItem(withTitle: "Left")
        alignSelect.addItem(withTitle: "Center")
        alignSelect.addItem(withTitle: "Right")
        switch settings.barAlignment {
        case .left: alignSelect.selectItem(at: 0)
        case .center: alignSelect.selectItem(at: 1)
        case .right: alignSelect.selectItem(at: 2)
        }
        alignSelect.target = self
        alignSelect.action = #selector(alignmentChanged(_:))
        labeled("Bar Alignment", control: alignSelect)

        checkbox("Show on All Screens", action: #selector(allScreensChanged(_:)), state: settings.showOnAllScreens ? .on : .off)

        separator()

        // ─── Appearance ───
        section("Appearance")

        let themeSelect = NSPopUpButton()
        themeSelect.addItem(withTitle: "System")
        themeSelect.addItem(withTitle: "Dark")
        themeSelect.addItem(withTitle: "Light")
        themeSelect.addItem(withTitle: "Custom")
        switch settings.backgroundTheme {
        case .system: themeSelect.selectItem(at: 0)
        case .dark: themeSelect.selectItem(at: 1)
        case .light: themeSelect.selectItem(at: 2)
        case .custom: themeSelect.selectItem(at: 3)
        }
        themeSelect.target = self
        themeSelect.action = #selector(themeChanged(_:))
        themeSelect.tag = 200
        labeled("Background Theme", control: themeSelect)

        let cRow = NSView()
        cRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cRow)

        let cLabel = NSTextField(labelWithString: "Custom Color")
        cLabel.font = NSFont.systemFont(ofSize: 13)
        cLabel.translatesAutoresizingMaskIntoConstraints = false
        cRow.addSubview(cLabel)

        let cWell = NSColorWell()
        cWell.color = settings.customBackgroundColor
        cWell.target = self
        cWell.action = #selector(customColorChanged(_:))
        cWell.tag = 202
        cWell.translatesAutoresizingMaskIntoConstraints = false
        cRow.addSubview(cWell)

        let cHeight = cRow.heightAnchor.constraint(equalToConstant: settings.backgroundTheme == .custom ? 24 : 0)
        colorRow = cRow
        colorRowHeight = cHeight

        NSLayoutConstraint.activate([
            cRow.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? view.topAnchor, constant: rowGap),
            cRow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cRow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cHeight,

            cLabel.centerYAnchor.constraint(equalTo: cRow.centerYAnchor),
            cLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
            cLabel.widthAnchor.constraint(equalToConstant: labelW),

            cWell.centerYAnchor.constraint(equalTo: cRow.centerYAnchor),
            cWell.leadingAnchor.constraint(equalTo: cLabel.trailingAnchor, constant: gap),
            cWell.widthAnchor.constraint(equalToConstant: 40),
            cWell.heightAnchor.constraint(equalToConstant: 28),
        ])

        let hidden = settings.backgroundTheme != .custom
        cRow.isHidden = hidden
        prev = cRow

        let iconSlider = NSSlider()
        iconSlider.minValue = 16
        iconSlider.maxValue = 64
        iconSlider.doubleValue = settings.iconSize
        iconSlider.target = self
        iconSlider.action = #selector(iconSizeChanged(_:))

        let iconVal = NSTextField(labelWithString: "\(Int(settings.iconSize))pt")
        iconVal.font = NSFont.systemFont(ofSize: 12)
        iconVal.alignment = .right
        iconSizeValueLabel = iconVal
        sliderRow("App Icon Size", slider: iconSlider, valueLabel: iconVal)

        let spaceSlider = NSSlider()
        spaceSlider.minValue = 0
        spaceSlider.maxValue = 16
        spaceSlider.doubleValue = settings.barSpacing
        spaceSlider.target = self
        spaceSlider.action = #selector(spacingChanged(_:))

        let spaceVal = NSTextField(labelWithString: "\(Int(settings.barSpacing))px")
        spaceVal.font = NSFont.systemFont(ofSize: 12)
        spaceVal.alignment = .right
        spacingValueLabel = spaceVal
        sliderRow("Bar Spacing", slider: spaceSlider, valueLabel: spaceVal)

        separator()

        // ─── Display Options ───
        section("Display Options")

        checkbox("Launch at Login", action: #selector(launchAtLoginChanged(_:)), state: settings.launchAtLogin ? .on : .off)
        checkbox("Enable Animations", action: #selector(animationsChanged(_:)), state: settings.animationsEnabled ? .on : .off)
        checkbox("Show Window Thumbnails on Hover", action: #selector(thumbnailsChanged(_:)), state: settings.showThumbnails ? .on : .off)
        checkbox("Show App Names", action: #selector(namesChanged(_:)), state: settings.showAppNames ? .on : .off)
        checkbox("Show Spotlight Button", action: #selector(startButtonChanged(_:)), state: settings.showStartButton ? .on : .off)
        checkbox("Hide Taskbar on Fullscreen", action: #selector(hideOnFullscreenChanged(_:)), state: settings.hideOnFullscreen ? .on : .off)
        checkbox("Quit Apps When All Windows Close", action: #selector(quitOnCloseChanged(_:)), state: settings.quitOnLastWindowClose ? .on : .off)
        checkbox("Keep Zoomed Windows Above Taskbar", action: #selector(constrainZoomedChanged(_:)), state: settings.constrainZoomedWindows ? .on : .off)

        separator()

        let resetBtn = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults))
        resetBtn.bezelStyle = .rounded
        resetBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resetBtn)
        NSLayoutConstraint.activate([
            resetBtn.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? view.topAnchor, constant: secGap),
            resetBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
            resetBtn.widthAnchor.constraint(equalToConstant: 150),
            resetBtn.heightAnchor.constraint(equalToConstant: 28),
        ])
        prev = resetBtn

        NSLayoutConstraint.activate([
            prev!.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -secGap),
        ])
    }

    @objc private func alignmentChanged(_ sender: NSPopUpButton) {
        switch sender.indexOfSelectedItem {
        case 0: settings.barAlignment = .left
        case 1: settings.barAlignment = .center
        case 2: settings.barAlignment = .right
        default: break
        }
    }

    @objc private func styleChanged(_ sender: NSPopUpButton) {
        settings.style = sender.indexOfSelectedItem == 0 ? .taskbar : .dock
    }

    @objc private func thumbnailsChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        if enabled && !PermissionsManager.shared.isScreenRecordingGranted {
            PermissionsManager.shared.requestScreenRecording()
        }
        settings.showThumbnails = enabled
    }

    @objc private func namesChanged(_ sender: NSButton) {
        settings.showAppNames = sender.state == .on
    }

    @objc private func startButtonChanged(_ sender: NSButton) {
        settings.showStartButton = sender.state == .on
    }

    @objc private func allScreensChanged(_ sender: NSButton) {
        settings.showOnAllScreens = sender.state == .on
    }

    @objc private func quitOnCloseChanged(_ sender: NSButton) {
        settings.quitOnLastWindowClose = sender.state == .on
    }

    @objc private func constrainZoomedChanged(_ sender: NSButton) {
        settings.constrainZoomedWindows = sender.state == .on
    }

    @objc private func hideOnFullscreenChanged(_ sender: NSButton) {
        settings.hideOnFullscreen = sender.state == .on
    }

    @objc private func launchAtLoginChanged(_ sender: NSButton) {
        let enabled = sender.state == .on
        settings.launchAtLogin = enabled
        LoginItemManager.setLaunchAtLogin(enabled)
    }

    @objc private func animationsChanged(_ sender: NSButton) {
        settings.animationsEnabled = sender.state == .on
    }

    @objc private func spacingChanged(_ sender: NSSlider) {
        settings.barSpacing = sender.doubleValue
        spacingValueLabel?.stringValue = "\(Int(sender.doubleValue))px"
    }

    @objc private func iconSizeChanged(_ sender: NSSlider) {
        settings.iconSize = sender.doubleValue
        iconSizeValueLabel?.stringValue = "\(Int(sender.doubleValue))pt"
    }

    @objc private func themeChanged(_ sender: NSPopUpButton) {
        let selected: TaskbarSettings.BackgroundTheme
        switch sender.indexOfSelectedItem {
        case 0: selected = .system
        case 1: selected = .dark
        case 2: selected = .light
        case 3: selected = .custom
        default: selected = .system
        }
        settings.backgroundTheme = selected

        let isCustom = selected == .custom
        colorRow?.isHidden = !isCustom
        colorRowHeight?.constant = isCustom ? 24 : 0
    }

    @objc private func customColorChanged(_ sender: NSColorWell) {
        settings.customBackgroundColor = sender.color
    }

    @objc private func resetDefaults() {
        settings.beginBatchUpdates()
        settings.showThumbnails = false
        settings.showAppNames = false
        settings.showStartButton = true
        settings.showOnAllScreens = true
        settings.barAlignment = .center
        settings.style = .taskbar
        settings.barSpacing = 4.0
        settings.iconSize = 32.0
        settings.quitOnLastWindowClose = false
        settings.hideOnFullscreen = true
        settings.launchAtLogin = true
        settings.animationsEnabled = true
        settings.constrainZoomedWindows = false
        settings.backgroundTheme = .system
        settings.customBackgroundColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
        settings.endBatchUpdates()
        window?.close()
        showWindow()
    }
}