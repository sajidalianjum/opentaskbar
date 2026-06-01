import AppKit

final class TaskbarContentView: NSView {
    private let windowManager: WindowManager
    private let settings = TaskbarSettings.shared

    private var backgroundView: NSVisualEffectView!
    private var appStackView: NSStackView!
    private var rightSection: NSView!
    private var clockLabel: NSTextField!
    private var settingsButton: NSButton!
    private var containerStackView: NSStackView!

    private var appButtons: [AppButtonView] = []
    private var clockTimer: Timer?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        super.init(frame: .zero)
        setupViews()
        startClock()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        wantsLayer = true

        backgroundView = NSVisualEffectView(frame: .zero)
        backgroundView.material = .sidebar
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 10
        backgroundView.layer?.masksToBounds = true

        containerStackView = NSStackView()
        containerStackView.orientation = .horizontal
        containerStackView.alignment = .centerY
        containerStackView.spacing = 0

        let leftSpacer = NSView()
        leftSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        leftSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        appStackView = NSStackView()
        appStackView.orientation = .horizontal
        appStackView.alignment = .centerY
        appStackView.spacing = 2
        appStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        rightSection = NSView()
        rightSection.wantsLayer = true

        clockLabel = NSTextField(labelWithString: "")
        clockLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        clockLabel.textColor = .labelColor
        clockLabel.alignment = .center
        clockLabel.setContentHuggingPriority(.required, for: .horizontal)

        settingsButton = NSButton(image: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Settings")!, target: nil, action: #selector(showActionMenu))
        settingsButton.isBordered = false
        settingsButton.imagePosition = .imageOnly
        settingsButton.bezelStyle = .regularSquare
        settingsButton.contentTintColor = .secondaryLabelColor
        settingsButton.toolTip = "OpenTaskbar"

        let rightStack = NSStackView(views: [clockLabel, settingsButton])
        rightStack.orientation = .horizontal
        rightStack.spacing = 8
        rightStack.alignment = .centerY
        rightStack.setContentHuggingPriority(.required, for: .horizontal)

        let rightSpacer = NSView()
        rightSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        rightSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        containerStackView.addArrangedSubview(leftSpacer)
        containerStackView.addArrangedSubview(appStackView)
        containerStackView.addArrangedSubview(rightSpacer)
        containerStackView.addArrangedSubview(rightStack)

        addSubview(backgroundView)
        addSubview(containerStackView)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        containerStackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

            containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            containerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            containerStackView.topAnchor.constraint(equalTo: topAnchor),
            containerStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateClock()
    }

    func reloadData() {
        appStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        appButtons.removeAll()

        let groups = windowManager.appGroups
        let showNames = settings.showAppNames

        for (index, group) in groups.enumerated() {
            let button = AppButtonView(appGroup: group, index: index, showName: showNames)
            button.target = self
            button.action = #selector(appButtonClicked(_:))
            button.rightAction = { [weak self] index in
                self?.showContextMenu(for: index)
            }

            appButtons.append(button)
            appStackView.addArrangedSubview(button)

            button.widthAnchor.constraint(equalToConstant: showNames ? 140 : 44).isActive = true
            button.heightAnchor.constraint(equalToConstant: settings.taskbarHeight - 4).isActive = true
        }
    }

    @objc private func appButtonClicked(_ sender: AppButtonView) {
        windowManager.activateApp(at: sender.index)
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

        let _ = NSApp.currentEvent
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

    private func startClock() {
        updateClock()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
    }

    private func updateClock() {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        clockLabel?.stringValue = formatter.string(from: Date())
    }

    deinit {
        clockTimer?.invalidate()
    }
}