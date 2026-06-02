import AppKit

final class WindowListPopover: NSWindow {
    private var windowRows: [WindowRowView] = []
    private var windows: [WindowInfo] = []
    private var hideWorkItem: DispatchWorkItem?
    private(set) var isHovering = false

    private static let rowHeight: CGFloat = 28
    private static let popoverWidth: CGFloat = 240
    private static let padding: CGFloat = 6
    private static let gapAboveButton: CGFloat = 6

    private let containerView: NSView
    private let visualEffect: NSVisualEffectView
    private var solidBackgroundView: NSView?
    private let stackView: NSStackView

    var onWindowClosed: ((CGWindowID) -> Void)?

    init() {
        containerView = NSView()
        visualEffect = NSVisualEffectView()
        stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: WindowListPopover.popoverWidth, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 10
        containerView.layer?.masksToBounds = true

        visualEffect.material = .sidebar
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.translatesAutoresizingMaskIntoConstraints = false

        stackView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: WindowListPopover.padding),
            stackView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -WindowListPopover.padding),
            stackView.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: WindowListPopover.padding),
            stackView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -WindowListPopover.padding),
        ])

        containerView.addSubview(visualEffect)
        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        let trackingView = PopoverTrackingView()
        trackingView.popover = self
        trackingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(trackingView)
        NSLayoutConstraint.activate([
            trackingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            trackingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            trackingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            trackingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        contentView = containerView
    }

    func show(windows: [WindowInfo], appIcon: NSImage, anchorPoint: NSPoint, screen: NSScreen) {
        cancelHideTimer()
        self.windows = windows

        applyTheme()

        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        windowRows.removeAll()

        for (index, window) in windows.enumerated() {
            let row = WindowRowView(windowInfo: window, index: index, appIcon: appIcon)
            row.onActivate = { [weak self] idx in
                self?.activateWindow(at: idx)
            }
            let windowID = window.windowID
            row.onClose = { [weak self] in
                self?.closeWindow(with: windowID)
            }
            windowRows.append(row)
            stackView.addArrangedSubview(row)

            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
                row.heightAnchor.constraint(equalToConstant: WindowListPopover.rowHeight),
            ])
        }

        let contentHeight = CGFloat(windows.count) * WindowListPopover.rowHeight
            + CGFloat(max(windows.count - 1, 0)) * stackView.spacing
            + WindowListPopover.padding * 2

        let popoverWidth = WindowListPopover.popoverWidth
        let popoverX = anchorPoint.x - popoverWidth / 2
        let popoverY = anchorPoint.y + WindowListPopover.gapAboveButton

        let clampedX = max(screen.visibleFrame.minX,
                           min(popoverX, screen.visibleFrame.maxX - popoverWidth))
        let clampedY = min(popoverY, screen.visibleFrame.maxY - contentHeight)

        setFrame(NSRect(x: clampedX, y: clampedY, width: popoverWidth, height: contentHeight), display: true)
        orderFront(nil)
        invalidateShadow()
    }

    func hide() {
        cancelHideTimer()
        windows = []
        windowRows.removeAll()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        orderOut(nil)
    }

    func scheduleHide(delay: TimeInterval = 0.25) {
        cancelHideTimer()
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.isHovering else { return }
            self.hide()
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func cancelHideTimer() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
    }

    func setHovering(_ hovering: Bool) {
        isHovering = hovering
        if hovering {
            cancelHideTimer()
        }
    }

    private func applyTheme() {
        let settings = TaskbarSettings.shared

        switch settings.backgroundTheme {
        case .system:
            solidBackgroundView?.isHidden = true
            visualEffect.isHidden = false
            visualEffect.material = .sidebar
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.appearance = nil
            containerView.appearance = nil

        case .dark:
            solidBackgroundView?.isHidden = true
            visualEffect.isHidden = false
            visualEffect.material = .sidebar
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.appearance = NSAppearance(named: .darkAqua)
            containerView.appearance = nil

        case .light:
            solidBackgroundView?.isHidden = true
            visualEffect.isHidden = false
            visualEffect.material = .sidebar
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.appearance = NSAppearance(named: .aqua)
            containerView.appearance = nil

        case .custom:
            visualEffect.isHidden = true
            if solidBackgroundView == nil {
                let solid = NSView()
                solid.wantsLayer = true
                solid.layer?.masksToBounds = true
                solid.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(solid, positioned: .below, relativeTo: visualEffect)
                NSLayoutConstraint.activate([
                    solid.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    solid.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    solid.topAnchor.constraint(equalTo: containerView.topAnchor),
                    solid.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                ])
                solidBackgroundView = solid
            }
            solidBackgroundView?.isHidden = false
            let color = settings.customBackgroundColor
            solidBackgroundView?.layer?.backgroundColor = color.cgColor

            let srgb = color.usingColorSpace(.sRGB) ?? color
            let luminance = 0.299 * srgb.redComponent + 0.587 * srgb.greenComponent + 0.114 * srgb.blueComponent
            if luminance > 0.5 {
                containerView.appearance = NSAppearance(named: .aqua)
            } else {
                containerView.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }

    private func activateWindow(at index: Int) {
        guard index < windows.count else { return }
        let window = windows[index]
        let pid = window.pid
        let accessibilityService = AccessibilityService()

        if let app = NSRunningApplication(processIdentifier: pid) {
            if window.isMinimized {
                if let element = accessibilityService.windowElement(for: window.windowID, pid: pid) {
                    accessibilityService.unminimizeWindow(element)
                    app.activate()
                }
            } else {
                if let element = accessibilityService.windowElement(for: window.windowID, pid: pid) {
                    accessibilityService.raiseWindow(element, app: app)
                } else {
                    app.activate()
                }
            }
        }

        hide()
    }

    private func closeWindow(with windowID: CGWindowID) {
        guard let window = windows.first(where: { $0.windowID == windowID }),
              let index = windows.firstIndex(where: { $0.windowID == windowID }),
              index < windowRows.count else { return }

        let service = AccessibilityService()
        if let element = service.windowElement(for: window.windowID, pid: window.pid) {
            service.closeWindow(element)
        }

        windows.remove(at: index)
        let removedRow = windowRows.remove(at: index)
        removedRow.removeFromSuperview()

        updatePopoverSize()

        if windows.count <= 1 {
            hide()
        }

        onWindowClosed?(windowID)
    }

    private func updatePopoverSize() {
        guard !windows.isEmpty else { return }
        let contentHeight = CGFloat(windows.count) * WindowListPopover.rowHeight
            + CGFloat(max(windows.count - 1, 0)) * stackView.spacing
            + WindowListPopover.padding * 2
        var frame = self.frame
        frame.size.height = contentHeight
        setFrame(frame, display: true, animate: true)
        invalidateShadow()
    }
}

private final class PopoverTrackingView: NSView {
    weak var popover: WindowListPopover?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
            owner: self,
            userInfo: nil
        )
        trackingArea = newArea
        addTrackingArea(newArea)
    }

    override func mouseEntered(with event: NSEvent) {
        popover?.setHovering(true)
    }

    override func mouseExited(with event: NSEvent) {
        popover?.setHovering(false)
        popover?.scheduleHide()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }
}

private final class WindowRowView: NSView {
    private let windowInfo: WindowInfo
    private let index: Int
    private let titleLabel: NSTextField
    private let iconImageView: NSImageView
    private let closeButton: NSButton
    private var trackingArea: NSTrackingArea?

    var onActivate: ((Int) -> Void)?
    var onClose: (() -> Void)?

    init(windowInfo: WindowInfo, index: Int, appIcon: NSImage) {
        self.windowInfo = windowInfo
        self.index = index

        let title = windowInfo.title.isEmpty ? "Window \(index + 1)" : windowInfo.title
        titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.textColor = windowInfo.isMinimized ? .tertiaryLabelColor : .labelColor

        let iconCopy = appIcon.copy() as! NSImage
        iconImageView = NSImageView(image: iconCopy)
        iconImageView.imageScaling = .scaleProportionallyUpOrDown

        closeButton = NSButton()
        closeButton.bezelStyle = .smallSquare
        closeButton.isBordered = false
        closeButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeButton.imagePosition = .imageOnly
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.isHidden = true

        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 4

        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(closeButton)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let iconSize: CGFloat = 16

        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: iconSize),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -2),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        closeButton.target = self
        closeButton.action = #selector(closeButtonClicked)

        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func closeButtonClicked() {
        onClose?()
    }

    private func setupTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        trackingArea = newArea
        addTrackingArea(newArea)
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        closeButton.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
        closeButton.isHidden = true
    }

    override func mouseUp(with event: NSEvent) {
        onActivate?(index)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .arrow)
    }
}