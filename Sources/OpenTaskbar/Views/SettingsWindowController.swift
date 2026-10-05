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
    private weak var updateStatusLabel: NSTextField?
    private weak var updateButton: NSButton?
    private var updateObserver: NSObjectProtocol?

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
        window.title = L10n.settingsWindowTitle
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
        observeUpdateState()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func observeUpdateState() {
        if let updateObserver {
            NotificationCenter.default.removeObserver(updateObserver)
        }
        updateObserver = NotificationCenter.default.addObserver(
            forName: UpdateManager.statusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshUpdateControls()
        }
        refreshUpdateControls()
    }

    private func refreshUpdateControls() {
        let manager = UpdateManager.shared
        let status = manager.status

        updateStatusLabel?.stringValue = updateStatusText(for: status)
        updateStatusLabel?.textColor = {
            if case .failed = status { return NSColor.secondaryLabelColor }
            return NSColor.tertiaryLabelColor
        }()

        if case .updateAvailable(let release) = status {
            updateButton?.title = L10n.updateInstallNow
            updateButton?.isEnabled = true
            updateButton?.isHidden = false
            updateButton?.tag = 1
            updateButton?.toolTip = L10n.updateAvailableTitle(release.tagName)
        } else {
            updateButton?.title = L10n.updateCheckNow
            updateButton?.toolTip = nil
            updateButton?.tag = 0
            updateButton?.isHidden = false
            updateButton?.isEnabled = !status.isBusy
        }
    }

    private func updateStatusText(for status: UpdateManager.Status) -> String {
        switch status {
        case .idle:
            return managerLastCheckedText()
        case .checking:
            return L10n.updateStatusChecking
        case .upToDate:
            return L10n.updateStatusUpToDate(UpdateManager.shared.currentVersionDescription)
        case .updateAvailable(let release):
            return L10n.updateStatusAvailable(release.tagName)
        case .downloading(_, let fraction):
            return L10n.updateStatusDownloading(Int((fraction * 100).rounded()))
        case .installing:
            return L10n.updateStatusInstalling
        case .failed(let error):
            return L10n.updateStatusFailed(error.errorDescription ?? L10n.updateFailedMessage)
        }
    }

    private func managerLastCheckedText() -> String {
        guard let last = UpdateManager.shared.lastCheckDate else {
            return L10n.updateLastCheckedNever
        }
        return L10n.updateLastChecked(last)
    }

    private func setupControls(in view: NSView) {
        let hPad: CGFloat = 20
        let labelW: CGFloat = 130
        let gap: CGFloat = 8
        let rowGap: CGFloat = 10
        let secGap: CGFloat = 16

        var prev: NSView?

        func section(_ title: String) {
            let label = NSTextField(labelWithString: title)
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
        section(L10n.general)

        let languageSelect = NSPopUpButton()
        let languageOptions = L10n.languageOptions
        for option in languageOptions {
            languageSelect.addItem(withTitle: option.displayName)
            languageSelect.lastItem?.representedObject = option.code
        }
        if let index = languageOptions.firstIndex(where: { $0.code == settings.language }) {
            languageSelect.selectItem(at: index)
        }
        languageSelect.target = self
        languageSelect.action = #selector(languageChanged(_:))
        labeled(L10n.settingsLanguage, control: languageSelect)

        let styleSelect = NSPopUpButton()
        styleSelect.addItem(withTitle: L10n.taskbar)
        styleSelect.addItem(withTitle: L10n.dock)
        styleSelect.selectItem(at: settings.style == .taskbar ? 0 : 1)
        styleSelect.target = self
        styleSelect.action = #selector(styleChanged(_:))
        labeled(L10n.style, control: styleSelect)

        let alignSelect = NSPopUpButton()
        alignSelect.addItem(withTitle: L10n.left)
        alignSelect.addItem(withTitle: L10n.center)
        alignSelect.addItem(withTitle: L10n.right)
        switch settings.barAlignment {
        case .left: alignSelect.selectItem(at: 0)
        case .center: alignSelect.selectItem(at: 1)
        case .right: alignSelect.selectItem(at: 2)
        }
        alignSelect.target = self
        alignSelect.action = #selector(alignmentChanged(_:))
        labeled(L10n.barAlignment, control: alignSelect)

        checkbox(L10n.showOnAllScreens, action: #selector(allScreensChanged(_:)), state: settings.showOnAllScreens ? .on : .off)

        separator()

        // ─── Appearance ───
        section(L10n.appearance)

        let themeSelect = NSPopUpButton()
        themeSelect.addItem(withTitle: L10n.system)
        themeSelect.addItem(withTitle: L10n.dark)
        themeSelect.addItem(withTitle: L10n.light)
        themeSelect.addItem(withTitle: L10n.custom)
        switch settings.backgroundTheme {
        case .system: themeSelect.selectItem(at: 0)
        case .dark: themeSelect.selectItem(at: 1)
        case .light: themeSelect.selectItem(at: 2)
        case .custom: themeSelect.selectItem(at: 3)
        }
        themeSelect.target = self
        themeSelect.action = #selector(themeChanged(_:))
        themeSelect.tag = 200
        labeled(L10n.backgroundTheme, control: themeSelect)

        let cRow = NSView()
        cRow.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cRow)

        let cLabel = NSTextField(labelWithString: L10n.customColor)
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

        let iconVal = NSTextField(labelWithString: L10n.iconSizeValue(Int(settings.iconSize)))
        iconVal.font = NSFont.systemFont(ofSize: 12)
        iconVal.alignment = .right
        iconSizeValueLabel = iconVal
        sliderRow(L10n.appIconSize, slider: iconSlider, valueLabel: iconVal)

        let spaceSlider = NSSlider()
        spaceSlider.minValue = 0
        spaceSlider.maxValue = 16
        spaceSlider.doubleValue = settings.barSpacing
        spaceSlider.target = self
        spaceSlider.action = #selector(spacingChanged(_:))

        let spaceVal = NSTextField(labelWithString: L10n.spacingValue(Int(settings.barSpacing)))
        spaceVal.font = NSFont.systemFont(ofSize: 12)
        spaceVal.alignment = .right
        spacingValueLabel = spaceVal
        sliderRow(L10n.barSpacing, slider: spaceSlider, valueLabel: spaceVal)

        separator()

        // ─── Display Options ───
        section(L10n.displayOptions)

        checkbox(L10n.launchAtLogin, action: #selector(launchAtLoginChanged(_:)), state: settings.launchAtLogin ? .on : .off)
        checkbox(L10n.enableAnimations, action: #selector(animationsChanged(_:)), state: settings.animationsEnabled ? .on : .off)
        checkbox(L10n.showWindowThumbnails, action: #selector(thumbnailsChanged(_:)), state: settings.showThumbnails ? .on : .off)
        checkbox(L10n.minimizeOnActiveAppClick, action: #selector(minimizeOnActiveAppClickChanged(_:)), state: settings.minimizeOnActiveAppClick ? .on : .off)
        checkbox(L10n.showAppNames, action: #selector(namesChanged(_:)), state: settings.showAppNames ? .on : .off)
        checkbox(L10n.showSpotlightButton, action: #selector(startButtonChanged(_:)), state: settings.showStartButton ? .on : .off)
        checkbox(L10n.hideOnFullscreen, action: #selector(hideOnFullscreenChanged(_:)), state: settings.hideOnFullscreen ? .on : .off)
        checkbox(L10n.quitAppsWhenWindowsClose, action: #selector(quitOnCloseChanged(_:)), state: settings.quitOnLastWindowClose ? .on : .off)
        checkbox(L10n.keepZoomedWindowsAboveTaskbar, action: #selector(constrainZoomedChanged(_:)), state: settings.constrainZoomedWindows ? .on : .off)
        checkbox(L10n.showRunningAppsWithoutWindows, action: #selector(showRunningAppsWithoutWindowsChanged(_:)), state: settings.showRunningAppsWithoutWindows ? .on : .off)

        separator()

        // ─── Updates ───
        section(L10n.updateSection)

        checkbox(L10n.updateAutomaticChecks, action: #selector(autoUpdateCheckChanged(_:)), state: settings.autoCheckForUpdates ? .on : .off)
        checkbox(L10n.updateInstallAutomatically, action: #selector(autoInstallUpdatesChanged(_:)), state: settings.installUpdatesAutomatically ? .on : .off)
        checkbox(L10n.updateIncludePrereleases, action: #selector(prereleaseUpdatesChanged(_:)), state: settings.includePrereleaseUpdates ? .on : .off)

        let updateBtn = NSButton(title: L10n.updateCheckNow, target: self, action: #selector(updateButtonPressed(_:)))
        updateBtn.bezelStyle = .rounded
        updateBtn.tag = 0
        updateBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(updateBtn)
        NSLayoutConstraint.activate([
            updateBtn.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? view.topAnchor, constant: rowGap),
            updateBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
            updateBtn.widthAnchor.constraint(equalToConstant: 200),
            updateBtn.heightAnchor.constraint(equalToConstant: 28),
        ])
        prev = updateBtn
        updateButton = updateBtn

        let statusLabel = NSTextField(wrappingLabelWithString: "")
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = NSColor.tertiaryLabelColor
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: prev?.bottomAnchor ?? view.topAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: hPad),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -hPad),
        ])
        prev = statusLabel
        updateStatusLabel = statusLabel

        separator()

        let resetBtn = NSButton(title: L10n.resetDefaults, target: self, action: #selector(resetDefaults))
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

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        guard let code = sender.selectedItem?.representedObject as? String,
              code != settings.language else { return }
        settings.language = code
        // Rebuild the window so every label appears in the newly selected language.
        window?.close()
        self.window = nil
        showWindow()
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

    @objc private func minimizeOnActiveAppClickChanged(_ sender: NSButton) {
        settings.minimizeOnActiveAppClick = sender.state == .on
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

    @objc private func showRunningAppsWithoutWindowsChanged(_ sender: NSButton) {
        settings.showRunningAppsWithoutWindows = sender.state == .on
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
        spacingValueLabel?.stringValue = L10n.spacingValue(Int(sender.doubleValue))
    }

    @objc private func iconSizeChanged(_ sender: NSSlider) {
        settings.iconSize = sender.doubleValue
        iconSizeValueLabel?.stringValue = L10n.iconSizeValue(Int(sender.doubleValue))
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

    @objc private func autoUpdateCheckChanged(_ sender: NSButton) {
        settings.autoCheckForUpdates = sender.state == .on
    }

    @objc private func autoInstallUpdatesChanged(_ sender: NSButton) {
        settings.installUpdatesAutomatically = sender.state == .on
    }

    @objc private func prereleaseUpdatesChanged(_ sender: NSButton) {
        settings.includePrereleaseUpdates = sender.state == .on
    }

    @objc private func updateButtonPressed(_ sender: NSButton) {
        if sender.tag == 1 {
            UpdatePresenter.shared.installPendingUpdate()
        } else {
            UpdatePresenter.shared.checkForUpdates()
        }
        refreshUpdateControls()
    }

    @objc private func resetDefaults() {
        settings.beginBatchUpdates()
        settings.showThumbnails = false
        settings.minimizeOnActiveAppClick = true
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
        settings.showRunningAppsWithoutWindows = false
        settings.autoCheckForUpdates = true
        settings.installUpdatesAutomatically = false
        settings.includePrereleaseUpdates = false
        settings.backgroundTheme = .system
        settings.customBackgroundColor = NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.2, alpha: 1.0)
        settings.language = ""
        settings.endBatchUpdates()
        window?.close()
        showWindow()
    }
}