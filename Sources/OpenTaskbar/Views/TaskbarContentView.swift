import AppKit

final class TaskbarContentView: NSView {
    private let windowManager: WindowManager
    private let settings = TaskbarSettings.shared

    private var backgroundView: NSVisualEffectView!
    private var appStackView: NSStackView!
    private var contentStackView: NSStackView!
    private var solidBackgroundView: NSView?

    private var startMenuButton: StartMenuButton!
    private var startSeparator: NSView!
    private var appButtons: [AppButtonView] = []
    private var insertionIndicator: NSView!
    private var draggedBundleID: String?

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
        startMenuButton = nil
        startSeparator = nil
        appButtons.removeAll()
        solidBackgroundView = nil

        backgroundView = NSVisualEffectView(frame: .zero)
        backgroundView.material = .sidebar
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = settings.dockMode ? 10 : 0
        backgroundView.layer?.masksToBounds = true

        appStackView = NSStackView()
        appStackView.orientation = .horizontal
        appStackView.alignment = .centerY
        appStackView.spacing = CGFloat(settings.barSpacing)
        appStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        appStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        registerForDraggedTypes([.string])

        insertionIndicator = NSView()
        insertionIndicator.wantsLayer = true
        insertionIndicator.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        insertionIndicator.layer?.cornerRadius = 1.5
        insertionIndicator.isHidden = true
        insertionIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(insertionIndicator)

        startMenuButton = StartMenuButton()
        startMenuButton.target = self
        startMenuButton.action = #selector(startMenuClicked(_:))
        startMenuButton.toolTip = "Search (Spotlight)"
        startMenuButton.isHidden = !settings.showStartButton

        startSeparator = NSView()
        startSeparator.wantsLayer = true
        startSeparator.layer?.backgroundColor = NSColor(red: 66/255, green: 97/255, blue: 123/255, alpha: 0.9).cgColor
        startSeparator.setContentHuggingPriority(.required, for: .horizontal)
        startSeparator.setContentCompressionResistancePriority(.required, for: .horizontal)
        startSeparator.isHidden = !settings.showStartButton

        startMenuButton.translatesAutoresizingMaskIntoConstraints = false
        startSeparator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            startMenuButton.widthAnchor.constraint(equalToConstant: 36),
            startMenuButton.heightAnchor.constraint(equalToConstant: max(taskbarHeight - 4, 1)),
        ])

        if settings.dockMode {
            contentStackView = NSStackView()
            contentStackView.orientation = .horizontal
            contentStackView.alignment = .centerY
            contentStackView.spacing = 8
            contentStackView.addArrangedSubview(startMenuButton)
            contentStackView.addArrangedSubview(startSeparator)
            contentStackView.addArrangedSubview(appStackView)
            contentStackView.setContentHuggingPriority(.required, for: .horizontal)

            addSubview(backgroundView)
            addSubview(contentStackView)

            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            contentStackView.translatesAutoresizingMaskIntoConstraints = false

            let padding: CGFloat = 8

            activeConstraints = [
                backgroundView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor, constant: -padding),
                backgroundView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: padding),
                backgroundView.topAnchor.constraint(equalTo: topAnchor),
                backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

                contentStackView.centerYAnchor.constraint(equalTo: centerYAnchor),

                startSeparator.widthAnchor.constraint(equalToConstant: 1),
                startSeparator.heightAnchor.constraint(lessThanOrEqualTo: contentStackView.heightAnchor, multiplier: 0.5),
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
            contentStackView = NSStackView()
            contentStackView.orientation = .horizontal
            contentStackView.alignment = .centerY
            contentStackView.spacing = 8

            switch settings.barAlignment {
            case .center:
                contentStackView.addArrangedSubview(startMenuButton)
                contentStackView.addArrangedSubview(startSeparator)
                contentStackView.addArrangedSubview(appStackView)
                contentStackView.setContentHuggingPriority(.required, for: .horizontal)
            case .left:
                let rightSpacer = NSView()
                rightSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                rightSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                contentStackView.addArrangedSubview(startMenuButton)
                contentStackView.addArrangedSubview(startSeparator)
                contentStackView.addArrangedSubview(appStackView)
                contentStackView.addArrangedSubview(rightSpacer)
            case .right:
                let leftSpacer = NSView()
                leftSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
                leftSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                contentStackView.addArrangedSubview(leftSpacer)
                contentStackView.addArrangedSubview(startMenuButton)
                contentStackView.addArrangedSubview(startSeparator)
                contentStackView.addArrangedSubview(appStackView)
            }

            addSubview(backgroundView)
            addSubview(contentStackView)

            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            contentStackView.translatesAutoresizingMaskIntoConstraints = false

            activeConstraints = [
                backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
                backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
                backgroundView.topAnchor.constraint(equalTo: topAnchor),
                backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),

                contentStackView.topAnchor.constraint(equalTo: topAnchor),
                contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor),

                startSeparator.widthAnchor.constraint(equalToConstant: 1),
                startSeparator.heightAnchor.constraint(lessThanOrEqualTo: contentStackView.heightAnchor, multiplier: 0.5),
            ]

            if settings.barAlignment == .center {
                activeConstraints.append(contentStackView.centerXAnchor.constraint(equalTo: centerXAnchor))
                contentStackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8).isActive = true
                contentStackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8).isActive = true
            } else {
                activeConstraints.append(contentsOf: [
                    contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
                    contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                ])
            }
        }

        NSLayoutConstraint.activate(activeConstraints)
        applyTheme()
        reloadData()
    }

    private func applyTheme() {
        ThemeManager.apply(
            to: backgroundView,
            solidView: &solidBackgroundView,
            parent: self,
            material: .sidebar,
            cornerRadius: backgroundView.layer?.cornerRadius ?? 0
        )
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
                button.onNeedsRefresh = { [weak self] windowID in
                    self?.windowManager.removeWindow(withID: windowID)
                }
                button.onFocusChanged = { [weak self] windowID, bundleID in
                    self?.windowManager.recordWindowFocus(bundleIdentifier: bundleID, windowID: windowID)
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
                    newButton.onNeedsRefresh = { [weak self] windowID in
                        self?.windowManager.removeWindow(withID: windowID)
                    }
                    newButton.onFocusChanged = { [weak self] windowID, bundleID in
                        self?.windowManager.recordWindowFocus(bundleIdentifier: bundleID, windowID: windowID)
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

        let showStart = settings.showStartButton
        startMenuButton?.isHidden = !showStart
        startSeparator?.isHidden = !showStart
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
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

    @objc private func startMenuClicked(_ sender: StartMenuButton) {
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let spaceDown = CGEvent(keyboardEventSource: source, virtualKey: 0x31, keyDown: true)
        spaceDown?.flags = .maskCommand
        let spaceUp = CGEvent(keyboardEventSource: source, virtualKey: 0x31, keyDown: false)
        spaceUp?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        cmdDown?.post(tap: .cgSessionEventTap)
        spaceDown?.post(tap: .cgSessionEventTap)
        spaceUp?.post(tap: .cgSessionEventTap)
        cmdUp?.post(tap: .cgSessionEventTap)
    }

    private func showContextMenu(for index: Int) {
        let menu = windowManager.contextMenu(forAppAt: index)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func updateButtonIndices() {
        for (i, button) in appButtons.enumerated() {
            button.index = i
        }
    }

    private func showInsertionIndicator(at xPosition: CGFloat) {
        insertionIndicator.isHidden = false
        let barHeight = taskbarHeight
        insertionIndicator.frame = NSRect(
            x: xPosition - 1.5,
            y: (bounds.height - barHeight + 8),
            width: 3,
            height: barHeight - 16
        )
    }

    private func hideInsertionIndicator() {
        insertionIndicator.isHidden = true
    }

    private func insertionIndex(for localPoint: NSPoint) -> Int {
        for (i, button) in appButtons.enumerated() {
            let buttonFrame = button.convert(button.bounds, to: self)
            if localPoint.x < buttonFrame.midX {
                return i
            }
        }
        return appButtons.count
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let string = sender.draggingPasteboard.string(forType: .string),
              let bundleID = string.split(separator: ":").first.map(String.init) else { return [] }
        draggedBundleID = bundleID
        return .move
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let location = sender.draggingLocation
        let localPoint = convert(location, from: nil)
        let index = insertionIndex(for: localPoint)

        var xPos: CGFloat = 0
        if index < appButtons.count {
            xPos = appButtons[index].convert(appButtons[index].bounds, to: self).minX
        } else if let lastButton = appButtons.last {
            xPos = lastButton.convert(lastButton.bounds, to: self).maxX
        }
        showInsertionIndicator(at: xPos)

        return .move
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        hideInsertionIndicator()
        draggedBundleID = nil
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return draggedBundleID != nil
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        hideInsertionIndicator()
        defer { draggedBundleID = nil }
        guard let string = sender.draggingPasteboard.string(forType: .string),
              let sourceIndex = Int(string.split(separator: ":").last.map(String.init) ?? ""),
              sourceIndex < appButtons.count else { return false }

        let localPoint = convert(sender.draggingLocation, from: nil)
        let destinationIndex = insertionIndex(for: localPoint)
        guard sourceIndex != destinationIndex else { return false }

        windowManager.moveApp(from: sourceIndex, to: destinationIndex)
        return true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}