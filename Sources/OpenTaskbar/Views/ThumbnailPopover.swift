import AppKit

final class ThumbnailPopover: NSWindow {
    private var cards: [ThumbnailCardView] = []
    private var windows: [WindowInfo] = []
    private var loadingTasks: Set<Task<Void, Never>> = []
    private var hideWorkItem: DispatchWorkItem?
    private(set) var isHovering = false

    private let visualEffect: NSVisualEffectView
    private var solidBackgroundView: NSView?
    private let stackView: NSStackView

    static let cardWidth: CGFloat = 160
    static let cardHeight: CGFloat = 126
    static let cardSpacing: CGFloat = 8
    static let popoverPadding: CGFloat = 8
    static let maxPopoverWidth: CGFloat = 1000

    var onWindowClosed: ((CGWindowID) -> Void)?
    var onWindowActivated: ((CGWindowID, pid_t) -> Void)?

    init() {
        visualEffect = NSVisualEffectView()
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = Self.cardSpacing

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: Self.cardHeight + Self.popoverPadding * 2),
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

        contentView!.wantsLayer = true
        contentView!.layer?.cornerRadius = 10
        contentView!.layer?.masksToBounds = true

        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.translatesAutoresizingMaskIntoConstraints = false

        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView!.addSubview(visualEffect)
        contentView!.addSubview(stackView)

        let trackingView = PopoverTrackingView()
        trackingView.popover = self
        trackingView.translatesAutoresizingMaskIntoConstraints = false
        contentView!.addSubview(trackingView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor, constant: Self.popoverPadding),
            stackView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor, constant: -Self.popoverPadding),
            stackView.topAnchor.constraint(equalTo: contentView!.topAnchor, constant: Self.popoverPadding),
            stackView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor, constant: -Self.popoverPadding),

            visualEffect.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: contentView!.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),

            trackingView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            trackingView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            trackingView.topAnchor.constraint(equalTo: contentView!.topAnchor),
            trackingView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),
        ])
    }

    func show(windows: [WindowInfo], appIcon: NSImage, anchorPoint: NSPoint, screen: NSScreen) {
        cancelHideTimer()
        cancelAllLoads()

        self.windows = windows
        cards.removeAll()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        applyTheme()

        for window in windows {
            let card = ThumbnailCardView(windowInfo: window, appIcon: appIcon)
            card.onActivate = { [weak self] in
                self?.activateWindow(window)
            }
            card.onClose = { [weak self] in
                self?.closeWindow(window)
            }
            cards.append(card)
            stackView.addArrangedSubview(card)

            NSLayoutConstraint.activate([
                card.widthAnchor.constraint(equalToConstant: Self.cardWidth),
                card.heightAnchor.constraint(equalToConstant: Self.cardHeight),
            ])
        }

        let count = CGFloat(windows.count)
        let contentWidth = Self.popoverPadding * 2 + Self.cardWidth * count + Self.cardSpacing * max(count - 1, 0)
        let clampedWidth = min(contentWidth, Self.maxPopoverWidth)
        let contentHeight = Self.popoverPadding * 2 + Self.cardHeight

        let popoverX = anchorPoint.x - clampedWidth / 2
        let popoverY = anchorPoint.y + 6

        let clampedX = max(screen.visibleFrame.minX,
                           min(popoverX, screen.visibleFrame.maxX - clampedWidth))
        let clampedY = min(popoverY, screen.visibleFrame.maxY - contentHeight)

        setFrame(NSRect(x: clampedX, y: clampedY, width: clampedWidth, height: contentHeight), display: true)
        orderFront(nil)
        invalidateShadow()

        for card in cards {
            let task = card.loadThumbnail()
            if let task {
                loadingTasks.insert(task)
            }
        }
    }

    func hide() {
        cancelHideTimer()
        cancelAllLoads()
        windows = []
        cards.removeAll()
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

    private func cancelAllLoads() {
        for task in loadingTasks {
            task.cancel()
        }
        loadingTasks.removeAll()
    }

    private func applyTheme() {
        var dummyShadow: NSView? = nil
        ThemeManager.apply(
            to: visualEffect,
            solidView: &solidBackgroundView,
            parent: contentView!,
            material: .popover,
            cornerRadius: contentView!.layer?.cornerRadius ?? 0,
            shadowView: &dummyShadow
        )
    }

    private func activateWindow(_ window: WindowInfo) {
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

        onWindowActivated?(window.windowID, window.pid)
        hide()
    }

    private func closeWindow(_ window: WindowInfo) {
        guard let index = windows.firstIndex(where: { $0.windowID == window.windowID }),
              index < cards.count else { return }

        let service = AccessibilityService()
        if let element = service.windowElement(for: window.windowID, pid: window.pid) {
            service.closeWindow(element)
        }

        windows.remove(at: index)
        let removedCard = cards.remove(at: index)
        removedCard.removeFromSuperview()

        updatePopoverSize()

        if windows.count <= 1 {
            hide()
        }

        onWindowClosed?(window.windowID)
    }

    private func updatePopoverSize() {
        guard !windows.isEmpty else {
            hide()
            return
        }
        let count = CGFloat(windows.count)
        let contentWidth = Self.popoverPadding * 2 + Self.cardWidth * count + Self.cardSpacing * max(count - 1, 0)
        let clampedWidth = min(contentWidth, Self.maxPopoverWidth)
        let contentHeight = Self.popoverPadding * 2 + Self.cardHeight

        var frame = self.frame
        frame.size.width = clampedWidth
        frame.size.height = contentHeight
        setFrame(frame, display: true, animate: true)
        invalidateShadow()
    }
}

extension ThumbnailPopover {
    final class ThumbnailCardView: NSView {
        let windowInfo: WindowInfo
        private let appIcon: NSImage

        private var imageView: NSImageView!
        private var titleLabel: NSTextField!
        private var closeButton: NSButton!
        private var trackingArea: NSTrackingArea?

        var onActivate: (() -> Void)?
        var onClose: (() -> Void)?

        init(windowInfo: WindowInfo, appIcon: NSImage) {
            self.windowInfo = windowInfo
            self.appIcon = appIcon
            super.init(frame: .zero)
            setupView()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setupView() {
            wantsLayer = true
            layer?.cornerRadius = 6
            layer?.masksToBounds = true

            let placeholderIcon = appIcon.resized(to: NSSize(width: 64, height: 64))
            imageView = NSImageView(image: placeholderIcon)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 4
            imageView.layer?.masksToBounds = true

            let title = windowInfo.title.isEmpty ? "Window" : windowInfo.title
            titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            titleLabel.textColor = windowInfo.isMinimized ? .tertiaryLabelColor : .labelColor
            titleLabel.alignment = .center
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.maximumNumberOfLines = 1
            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            closeButton = NSButton()
            closeButton.bezelStyle = .smallSquare
            closeButton.isBordered = false
            closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
            if let image = closeButton.image {
                let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
                closeButton.image = image.withSymbolConfiguration(config)
            }
            closeButton.imagePosition = .imageOnly
            closeButton.contentTintColor = NSColor.systemGray.withAlphaComponent(0.7)
            closeButton.isHidden = true

            addSubview(imageView)
            addSubview(titleLabel)
            addSubview(closeButton)

            imageView.translatesAutoresizingMaskIntoConstraints = false
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            closeButton.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
                imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 144),
                imageView.heightAnchor.constraint(equalToConstant: 90),

                titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
                titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
                titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
                titleLabel.heightAnchor.constraint(equalToConstant: 16),

                closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 2),
                closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
                closeButton.widthAnchor.constraint(equalToConstant: 26),
                closeButton.heightAnchor.constraint(equalToConstant: 26),
            ])

            closeButton.target = self
            closeButton.action = #selector(closeClicked)

            setupTrackingArea()
        }

        func loadThumbnail() -> Task<Void, Never>? {
            let windowID = windowInfo.windowID
            return Task { @MainActor [weak self] in
                guard let self else { return }
                if let image = await ThumbnailService.shared.thumbnail(for: windowID) {
                    guard !Task.isCancelled else { return }
                    self.imageView.image = image
                }
            }
        }

        @objc private func closeClicked() {
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
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
            closeButton.isHidden = false
        }

        override func mouseExited(with event: NSEvent) {
            layer?.backgroundColor = nil
            closeButton.isHidden = true
        }

        override func mouseUp(with event: NSEvent) {
            onActivate?()
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
}

private final class PopoverTrackingView: NSView {
    weak var popover: ThumbnailPopover?
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
