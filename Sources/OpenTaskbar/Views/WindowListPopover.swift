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
    private let stackView: NSStackView

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

        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.layer?.cornerRadius = 8
        visualEffect.layer?.masksToBounds = true
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
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
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

    func show(windows: [WindowInfo], anchorPoint: NSPoint, screen: NSScreen) {
        cancelHideTimer()
        self.windows = windows

        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        windowRows.removeAll()

        for (index, window) in windows.enumerated() {
            let row = WindowRowView(windowInfo: window, index: index)
            row.onActivate = { [weak self] idx in
                self?.activateWindow(at: idx)
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
}

private final class WindowRowView: NSView {
    private let windowInfo: WindowInfo
    private let index: Int
    private let titleLabel: NSTextField
    private let indicatorDot: NSView
    private var trackingArea: NSTrackingArea?

    var onActivate: ((Int) -> Void)?

    init(windowInfo: WindowInfo, index: Int) {
        self.windowInfo = windowInfo
        self.index = index

        let title = windowInfo.title.isEmpty ? "Window \(index + 1)" : windowInfo.title
        titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.textColor = windowInfo.isMinimized ? .tertiaryLabelColor : .labelColor

        indicatorDot = NSView()
        indicatorDot.wantsLayer = true
        indicatorDot.layer?.cornerRadius = windowInfo.isMinimized ? 2 : 3
        if windowInfo.isMinimized {
            indicatorDot.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
        } else {
            indicatorDot.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        }

        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 4

        addSubview(indicatorDot)
        addSubview(titleLabel)

        indicatorDot.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let dotSize: CGFloat = windowInfo.isMinimized ? 5 : 7

        NSLayoutConstraint.activate([
            indicatorDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            indicatorDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            indicatorDot.widthAnchor.constraint(equalToConstant: dotSize),
            indicatorDot.heightAnchor.constraint(equalToConstant: dotSize),

            titleLabel.leadingAnchor.constraint(equalTo: indicatorDot.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        setupTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }

    override func mouseUp(with event: NSEvent) {
        onActivate?(index)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        setupTrackingArea()
    }
}