import AppKit

final class TaskbarContentView: NSView {
    private let windowManager: WindowManager
    private let settings = TaskbarSettings.shared

    private var backgroundView: NSVisualEffectView!
    private var appStackView: NSStackView!
    private var contentStackView: NSStackView!
    private var showDesktopButton: ShowDesktopButton!
    private var settingsButton: NSButton!

    private var appButtons: [AppButtonView] = []

    private var activeConstraints: [NSLayoutConstraint] = []

    private var taskbarHeight: CGFloat {
        ScreenGeometry.taskbarHeight(forIconSize: CGFloat(settings.iconSize))
    }

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        super.init(frame: .zero)
        setupViews()
        observeSettings()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true
        subviews.forEach { $0.removeFromSuperview() }
        activeConstraints.removeAll()
        appButtons.removeAll()

        backgroundView = NSVisualEffectView(frame: .zero)
        backgroundView.material = .sidebar
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = settings.compactBar ? 10 : 0
        backgroundView.layer?.masksToBounds = true

        appStackView = NSStackView()
        appStackView.orientation = .horizontal
        appStackView.alignment = .centerY
        appStackView.spacing = CGFloat(settings.barSpacing)
        appStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        appStackView.setContentCompressionResistancePriority(.required, for: .horizontal)

        showDesktopButton = ShowDesktopButton()
        showDesktopButton.target = self
        showDesktopButton.action = #selector(showDesktopClicked(_:))
        showDesktopButton.toolTip = "Show Desktop"

        settingsButton = NSButton(image: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Settings")!, target: nil, action: #selector(showActionMenu))
        settingsButton.isBordered = false
        settingsButton.imagePosition = .imageOnly
        settingsButton.bezelStyle = .regularSquare
        settingsButton.contentTintColor = .secondaryLabelColor
        settingsButton.toolTip = "OpenTaskbar"

        let rightStack = NSStackView(views: [showDesktopButton, settingsButton])
        rightStack.orientation = .horizontal
        rightStack.spacing = 8
        rightStack.alignment = .centerY
        rightStack.setContentHuggingPriority(.required, for: .horizontal)

        showDesktopButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            showDesktopButton.widthAnchor.constraint(equalToConstant: 36),
            showDesktopButton.heightAnchor.constraint(equalToConstant: max(taskbarHeight - 4, 1)),
        ])

        let separator = NSView()
        separator.wantsLayer = true
        separator.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        separator.setContentHuggingPriority(.required, for: .horizontal)
        separator.setContentCompressionResistancePriority(.required, for: .horizontal)

        if settings.compactBar {
            contentStackView = NSStackView()
            contentStackView.orientation = .horizontal
            contentStackView.alignment = .centerY
            contentStackView.spacing = 8
            contentStackView.addArrangedSubview(appStackView)
            contentStackView.addArrangedSubview(separator)
            contentStackView.addArrangedSubview(rightStack)
            contentStackView.setContentHuggingPriority(.required, for: .horizontal)

            addSubview(backgroundView)
            addSubview(contentStackView)

            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            contentStackView.translatesAutoresizingMaskIntoConstraints = false
            separator.translatesAutoresizingMaskIntoConstraints = false

            let padding: CGFloat = 8

            activeConstraints = [
                backgroundView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: -padding),
                backgroundView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: padding),
                backgroundView.topAnchor.constraint(equalTo: topAnchor),
                backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

                contentStackView.centerYAnchor.constraint(equalTo: centerYAnchor),

                separator.widthAnchor.constraint(equalToConstant: 1),
                separator.heightAnchor.constraint(lessThanOrEqualTo: contentStackView.heightAnchor, multiplier: 0.5),
            ]

            switch settings.barAlignment {
            case .center:
                activeConstraints.append(contentStackView.centerXAnchor.constraint(equalTo: centerXAnchor))
            case .left:
                activeConstraints.append(contentsOf: [
                    contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
                    contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                ])
            case .right:
                activeConstraints.append(contentsOf: [
                    contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
                    contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                ])
            }
        } else {
            let leftSpacer = NSView()
            leftSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            leftSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            let rightSpacer = NSView()
            rightSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            rightSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            contentStackView = NSStackView()
            contentStackView.orientation = .horizontal
            contentStackView.alignment = .centerY
            contentStackView.spacing = 8

            switch settings.barAlignment {
            case .center:
                contentStackView.addArrangedSubview(leftSpacer)
                contentStackView.addArrangedSubview(appStackView)
                contentStackView.addArrangedSubview(separator)
                contentStackView.addArrangedSubview(rightStack)
                contentStackView.addArrangedSubview(rightSpacer)
            case .left:
                contentStackView.addArrangedSubview(appStackView)
                contentStackView.addArrangedSubview(separator)
                contentStackView.addArrangedSubview(rightStack)
                contentStackView.addArrangedSubview(rightSpacer)
            case .right:
                contentStackView.addArrangedSubview(leftSpacer)
                contentStackView.addArrangedSubview(appStackView)
                contentStackView.addArrangedSubview(separator)
                contentStackView.addArrangedSubview(rightStack)
            }

            addSubview(backgroundView)
            addSubview(contentStackView)

            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            contentStackView.translatesAutoresizingMaskIntoConstraints = false
            separator.translatesAutoresizingMaskIntoConstraints = false

            activeConstraints = [
                backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
                backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
                backgroundView.topAnchor.constraint(equalTo: topAnchor),
                backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

                contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                contentStackView.topAnchor.constraint(equalTo: topAnchor),
                contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor),

                separator.widthAnchor.constraint(equalToConstant: 1),
                separator.heightAnchor.constraint(lessThanOrEqualTo: contentStackView.heightAnchor, multiplier: 0.5),
            ]
        }

        NSLayoutConstraint.activate(activeConstraints)
        reloadData()
    }

    func reloadData() {
        let groups = windowManager.appGroups
        let showNames = settings.showAppNames
        appStackView.spacing = CGFloat(settings.barSpacing)

        let existingIDs = appButtons.map(\.bundleIdentifier)
        let newIDs = groups.map(\.bundleIdentifier)

        if existingIDs != newIDs {
            appStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            appButtons.removeAll()

            for (index, group) in groups.enumerated() {
                let button = AppButtonView(appGroup: group, index: index, showName: showNames)
                button.target = self
                button.action = #selector(appButtonClicked(_:))
                button.rightAction = { [weak self] index in
                    self?.showContextMenu(for: index)
                }

                appButtons.append(button)
                appStackView.addArrangedSubview(button)

                let btnWidth: CGFloat = showNames ? 140 : CGFloat(settings.iconSize) + 16
                button.widthAnchor.constraint(equalToConstant: btnWidth).isActive = true
                button.heightAnchor.constraint(equalToConstant: max(taskbarHeight - 4, 1)).isActive = true
            }
        } else {
            for (index, group) in groups.enumerated() {
                if index < appButtons.count {
                    let oldButton = appButtons[index]
                    let newButton = AppButtonView(appGroup: group, index: index, showName: showNames)
                    newButton.target = self
                    newButton.action = #selector(appButtonClicked(_:))
                    newButton.rightAction = { [weak self] index in
                        self?.showContextMenu(for: index)
                    }

                    appStackView.removeArrangedSubview(oldButton)
                    oldButton.removeFromSuperview()
                    appStackView.insertArrangedSubview(newButton, at: index)

                    let btnWidth: CGFloat = showNames ? 140 : CGFloat(settings.iconSize) + 16
                    newButton.widthAnchor.constraint(equalToConstant: btnWidth).isActive = true
                    newButton.heightAnchor.constraint(equalToConstant: max(taskbarHeight - 4, 1)).isActive = true

                    appButtons[index] = newButton
                }
            }
        }

        showDesktopButton?.isShowingDesktop = windowManager.isShowingDesktop
    }

    private func observeSettings() {
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: TaskbarSettings.settingsDidChange, object: nil)
    }

    @objc private func settingsChanged() {
        let needsRebuild = true
        if needsRebuild {
            setupViews()
        }
    }

    @objc private func appButtonClicked(_ sender: AppButtonView) {
        windowManager.activateApp(at: sender.index)
    }

    @objc private func showDesktopClicked(_ sender: ShowDesktopButton) {
        if windowManager.isShowingDesktop {
            windowManager.restoreDesktop()
        } else {
            windowManager.showDesktop()
        }
    }

    private func showContextMenu(for index: Int) {
        let menu = windowManager.contextMenu(forAppAt: index)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func showActionMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About OpenTaskbar", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Restore Dock & Quit", action: #selector(restoreAndQuit), keyEquivalent: "q"))

        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func showPreferences() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func restoreAndQuit() {
        NSApp.terminate(nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}